//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public struct Document<T: Codable> {

    private struct State {
        var seq: Int
        var version: Int
        var clock: Clock
        var canUndo: Bool
        var canRedo: Bool
    }

    /// Returns the Automerge actor ID of the given document.
    public let actor: Actor
    public var content: T {
        let context = Context(cache: cache, actorId: actor)

        return Proxy<T>.rootProxy(context: context).get()
    }

    private var backend: RSBackend
    private var state: State
    private var root: [String: Any]

    private init(actor: Actor, backend: RSBackend) {
        self.actor = actor
        self.backend = backend
        self.root = [
            OBJECT_ID: ROOT_ID,
            CONFLICTS: [Key: [String: Any]]()
        ]
        self.root[CACHE] = [ROOT_ID: root]
        self.state = State(seq: 0, version: 0, clock: [:], canUndo: false, canRedo: false)
    }

    public init(_ initialState: T, actor: Actor = Actor()) {
        var newDocument = Document<T>(actor: actor, backend: RSBackend())
        newDocument.change(message: "Initialization", undoable: false, { doc in
            doc.set(initialState)
        })
        self = newDocument
    }

    public init(data: [UInt8], actor: Actor = Actor()) {
        let backend = RSBackend(data: data)
        var doc = Document<T>(actor: actor, backend: backend)

        let patch = backend.getPatch()
        doc.applyPatch(patch: patch)
        self = doc
    }

    public init(changes: [[UInt8]], actor: Actor = Actor()) {
        let (backend, patch) = RSBackend().apply(changes: changes)
        var doc = Document<T>(actor: actor, backend: backend)

        doc.applyPatch(patch: patch)
        self = doc
    }

    private var cache: [String: [String: Any]] {
       root[CACHE] as! [String: [String: Any]]
    }

    /**
     * Changes a document `doc` according to actions taken by the local user.
     * `options` is an object that can contain the following properties:
     *  - `message`: an optional descriptive string that is attached to the change.
     *  - `undoable`: false if the change should not affect the undo history.
     * If `options` is a string, it is treated as `message`.
     *
     * The actual change is made within the callback function `callback`, which is
     * given a mutable version of the document as argument. Returns a two-element
     * array `[doc, request]` where `doc` is the updated document, and `request`
     * is the change request to send to the backend. If nothing was actually
     * changed, returns the original `doc` and a `null` change request.
     */
    @discardableResult
    public mutating func change(message: String = "", undoable: Bool = true, _ execute: (Proxy<T>) -> Void) -> Request? {
        let context = Context(cache: cache, actorId: actor)
        execute(.rootProxy(context: context))
        if context.idUpdated {
            return makeChange(requestType: .change, context: context, message: message, undoable: undoable)
        } else {
            return nil
        }
    }

    /**
     * Adds a new change request to the list of pending requests, and returns an
     * updated document root object. `requestType` is a string indicating the type
     * of request, which may be "change", "undo", or "redo". For the "change" request
     * type, the details of the change are taken from the context object `context`.
     * `options` contains properties that may affect how the change is processed; in
     * particular, the `message` property of `options` is an optional human-readable
     * string describing the change.
     */
    private mutating func makeChange(requestType: Request.RequestType,
                             context: Context?,
                             message: String,
                             undoable: Bool
    ) -> Request?
    {
        state.seq += 1
        let request = Request(requestType: requestType,
                              message: message,
                              time: Date(),
                              actor: actor,
                              seq: state.seq,
                              version: state.version,
                              ops: context?.ops ?? [],
                              undoable: undoable
        )

        let(newBackend, patch) = backend.applyLocalChange(request: request)
        self.backend = newBackend

        applyPatchToDoc(patch: patch, fromBackend: true, context: context)
        return request
    }

    /**
     * Applies the changes described in `patch` to the document with root object
     * `doc`. The state object `state` is attached to the new root object.
     * `fromBackend` should be set to `true` if the patch came from the backend,
     * and to `false` if the patch is a transient local (optimistically applied)
     * change from the frontend.
     */
    private mutating func applyPatchToDoc(patch: Patch, fromBackend: Bool, context: Context?) {
        var updated = [String: [String: Any]]()
        var newRoot = interpretPatch(patch: patch.diffs, obj: root, updated: &updated)
        let cache = newRoot?[CACHE]
        newRoot?[CACHE] = context?.updated ?? cache
        updated[ROOT_ID] = newRoot

        if fromBackend {
            if let clockValue = patch.clock[actor.actorId], clockValue > state.seq {
                state.seq = clockValue
            }
            state.clock = patch.clock
            state.version = patch.version
            state.canUndo = patch.canUndo
            state.canRedo = patch.canRedo
        }

        updateRootObject(update: &updated)
    }

    /**
     * Applies `patch` to the document root object `doc`. This patch must come
     * from the backend; it may be the result of a local change or a remote change.
     * If it is the result of a local change, the `seq` field from the change
     * request should be included in the patch, so that we can match them up here.
     */
    public mutating func applyPatch(patch: Patch) {
        applyPatchToDoc(patch: patch, fromBackend: true, context: nil)
    }

    /**
     * Takes a set of objects that have been updated (in `updated`) and an updated state object
     * `state`, and returns a new immutable document root object based on `doc` that reflects
     * those updates.
     */
    private mutating func updateRootObject(update: inout [String: [String: Any]]) {
        var newDoc = update[ROOT_ID]
        if newDoc == nil {
            newDoc = cache[ROOT_ID]
            update[ROOT_ID] = newDoc
        }
        for objectId in cache.keys where update[objectId] == nil {
            update[objectId] = cache[objectId]
        }
        newDoc?[CACHE] = update

        self.root = newDoc!
    }

    public func save() -> [UInt8] {
        return backend.save()
    }

    /**
     * Returns `true` if undo is currently possible on the document `doc` (because
     * there is a local change that has not already been undone); `false` if not.
     */
    public var canUndo: Bool {
        return state.canUndo
    }

    /**
     * Returns `true` if redo is currently possible on the document (because
     * a prior action was an undo that has not already been redone); `false` if not.
     */
    public var canRedo: Bool {
        return state.canRedo
    }

    public func rootProxy() -> Proxy<T> {
        let context = Context(cache: cache, actorId: actor)
        return .rootProxy(context: context)
    }

    public func allChanges() -> [[UInt8]] {
        return backend.getChanges()
    }

    public mutating func apply(changes: [[UInt8]]) {
        let(newBackend, patch) = backend.apply(changes: changes)
        backend = newBackend
        applyPatch(patch: patch)
    }

    public mutating func merge(_ remoteDocument: Document<T>) {
        precondition(actor != remoteDocument.actor, "Cannot merge an actor with itself")
        apply(changes: remoteDocument.allChanges())
    }

    /**
     Creates a request to perform an undo on the document `doc`, returning a
     two-element array `[doc, request]` where `doc` is the updated document, and
     `request` needs to be sent to the backend. `options` is an object as
     described in the documentation for the `change` function; it may contain a
     `message` property with an optional change description to attach to the undo.
     Note that the undo does not take effect immediately: only after the request
     is sent to the backend, and the backend responds with a patch, does the
     user-visible document update actually happen.
     */
    @discardableResult
    public mutating func undo(message: String = "", undoable: Bool = true) -> Request? {
        if !canUndo {
            return nil
        }
        return makeChange(requestType: .undo, context: nil, message: message, undoable: undoable)
    }

    /**
     * Creates a request to perform a redo of a prior undo on the document ,
     * returning a two-element array `[doc, request]` where `doc` is the updated
     * document, and `request` needs to be sent to the backend. `options` is an
     * object as described in the documentation for the `change` function; it may
     * contain a `message` property with an optional change description to attach
     * to the redo. Note that the redo does not take effect immediately: only
     * after the request is sent to the backend, and the backend responds with a
     * patch, does the user-visible document update actually happen.
     */
    @discardableResult
    public mutating func redo(message: String = "", undoable: Bool = true) -> Request? {
        if !canRedo {
            return nil
        }
        return makeChange(requestType: .redo, context: nil, message: message, undoable: undoable)
    }

}


