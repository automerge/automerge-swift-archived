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
        var maxOp: Int
        var deps: [ObjectId]
        var clock: Clock
    }

    /// Returns the Automerge actor ID of the given document.
    public let actor: Actor
    public var content: T {
        let context = Context(cache: cache, actorId: actor, maxOp: state.maxOp)

        return Proxy<T>.rootProxy(context: context).get()
    }

    private var backend: RSBackend
    private var state: State
    private var root: Map
    private var cache: [ObjectId: Object]

    private init(actor: Actor, backend: RSBackend) {
        self.actor = actor
        self.backend = backend
        self.root = Map(objectId: .root, mapValues: [:], conflicts: [:])
        self.cache = [.root: .map(root)]
        self.state = State(seq: 0, maxOp: 0, deps: [], clock: [:])
    }

    public init(_ initialState: T, actor: Actor = Actor()) {
        var newDocument = Document<T>(actor: actor, backend: RSBackend())
        newDocument.change(message: "Initialization", { doc in
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
        let backend = RSBackend()
        let patch = backend.apply(changes: changes)
        var doc = Document<T>(actor: actor, backend: backend)

        doc.applyPatch(patch: patch)
        self = doc
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
    public mutating func change(message: String = "", _ execute: (Proxy<T>) -> Void) -> Request? {
        let context = Context(cache: cache, actorId: actor, maxOp: state.maxOp)
        execute(.rootProxy(context: context))
        if context.idUpdated {
            return makeChange(context: context, message: message)
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
    private mutating func makeChange(
        context: Context?,
        message: String
    ) -> Request?
    {
        state.seq += 1
        let request = Request(
            startOp: state.maxOp + 1,
            deps: state.deps,
            message: message,
            time: Date(),
            actor: actor,
            seq: state.seq,
            ops: context?.ops ?? []
        )

        let backend: RSBackend
        if isKnownUniquelyReferenced(&self.backend) {
            backend = self.backend
        } else {
            backend = self.backend.clone()
        }
        let patch = backend.applyLocalChange(request: request)
        self.backend = backend

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
        var updated = [ObjectId: Object]()
        let newRoot = interpretPatch(patch: patch.diffs, obj: .map(root), updated: &updated)
        var cache = self.cache
        cache = context?.updated ?? cache
        updated[.root] = newRoot

        if fromBackend {
            if let clockValue = patch.clock[actor.actorId], clockValue > state.seq {
                state.seq = clockValue
            }
            state.clock = patch.clock
            state.deps = patch.deps
            state.maxOp = max(state.maxOp, patch.maxOp)
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
    private mutating func updateRootObject(update: inout [ObjectId: Object]) {
        var newDoc = update[.root]
        if newDoc == nil {
            newDoc = cache[.root]
            update[.root] = newDoc
        }
        cache.merge(update, uniquingKeysWith: { old, new in return new })

        if case .map(let newRoot)? = newDoc {
            self.root = newRoot
        } else {
            fatalError()
        }
    }

    public func save() -> [UInt8] {
        return backend.save()
    }

    public func rootProxy() -> Proxy<T> {
        let context = Context(cache: cache, actorId: actor, maxOp: state.maxOp)
        return .rootProxy(context: context)
    }

    public func allChanges() -> [[UInt8]] {
        return backend.getChanges()
    }

    public mutating func apply(changes: [[UInt8]]) {
        let backend: RSBackend
        if isKnownUniquelyReferenced(&self.backend) {
            backend = self.backend
        } else {
            backend = self.backend.clone()
        }
        let patch = backend.apply(changes: changes)
        self.backend = backend
        applyPatch(patch: patch)
    }

    public mutating func merge(_ remoteDocument: Document<T>) {
        precondition(actor != remoteDocument.actor, "Cannot merge an actor with itself")
        apply(changes: remoteDocument.allChanges())
    }

    public func getMissingsDeps() -> [String] {
        return backend.getMissingDeps()
    }

    public func getHeads() -> [String] {
        return backend.getHeads()
    }

    public func getChanges(between oldDocument: Document<T>) -> [[UInt8]] {
        return backend.getChanges(heads: oldDocument.backend.getHeads())
    }

    public func getChanges(since heads: [String]) -> [[UInt8]] {
        return backend.getChanges(heads: heads)
    }

}


