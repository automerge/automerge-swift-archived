//
//  Document.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

/// A wrapper around your codable model that tracks collaborative changes and provides an immutable views of the model's history.
public struct Document<T: Codable> {

    private struct State {
        var seq: Int
        var maxOp: Int
        var deps: [ObjectId]
        var clock: Clock
    }

    /// The identity of the collaborator responsible for this document.
    public let actor: Actor
    
    /// The current state of the wrapped model.
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
    
    /// Creates a new document with the provided instance of a model.
    /// - Parameters:
    ///   - initialState: The initial state of a collaborative model.
    ///   - actor: The identity of the collaborator that owns this document.
    public init(_ initialState: T, actor: Actor = Actor()) {
        var newDocument = Document<T>(actor: actor, backend: RSBackend())
        newDocument.change(message: "Initialization", { doc in
            doc.set(initialState)
        })
        self = newDocument
    }
    
    /// Creates a new document from an encoded change history.
    /// - Parameters:
    ///   - data: A byte buffer of the encoded change history of the model.
    ///   - actor: The identity of the collaborator that owns this document.
    public init(data: [UInt8], actor: Actor = Actor()) {
        let backend = RSBackend(data: data)
        var doc = Document<T>(actor: actor, backend: backend)

        let patch = backend.getPatch()
        doc.applyPatch(patch: patch)
        self = doc
    }
    
    /// Creates a new document from the encoded list of changes.
    /// - Parameters:
    ///   - changes: A list of byte buffers that represent the changes to the model.
    ///   - actor: The identity of the collaborator that owns this document.
    public init(changes: [[UInt8]], actor: Actor = Actor()) {
        let backend = RSBackend()
        let patch = backend.apply(changes: changes)
        var doc = Document<T>(actor: actor, backend: backend)

        doc.applyPatch(patch: patch)
        self = doc
    }

    /// Provide updates to the document by changing your model object within the provided closure.
    /// - Parameters:
    ///   - message: An optional message describing the change or reasons for the change
    ///   - execute: A closure that provides a proxy of the current instance of your model to update.
    /// - Returns: A change request to send to other collaborators, nil if the model wasn't updated.
    ///
    /// ```swift
    /// struct Model: Codable, Equatable {
    ///     var bird: String?
    /// }
    /// // Create a model with an initial empty state.
    /// var doc = Document(Model(bird: nil))
    /// // Update the model to set a value.
    /// doc.change { proxy in
    ///     proxy.bird?.set(newValue: "magpie")
    /// }
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
    
    /// Updates the document by applying the provided patch.
    /// - Parameter patch: A patch provided by a remote collaborator.
    ///
    /// The patch may be a result of a local change or a remote change.
    /// If it is the result of a local change, the `seq` field from  the change request
    /// should be included in the patch, so that the changes can be matched.
    public mutating func applyPatch(patch: Patch) {
        applyPatchToDoc(patch: patch, fromBackend: true, context: nil)
    }

    /// Returns a byte buffer that represents the change history of the document
    /// - Returns: An encoded change history of the document.
    public func save() -> [UInt8] {
        return backend.save()
    }
    
    /// Returns a proxy wrapper for the model document.
    public func rootProxy() -> Proxy<T> {
        let context = Context(cache: cache, actorId: actor, maxOp: state.maxOp)
        return .rootProxy(context: context)
    }
    
    /// Returns a list of byte buffers that represent the change history of the document.
    /// - Returns: A list of the changes to the document.
    public func allChanges() -> [[UInt8]] {
        return backend.getChanges()
    }
    
    /// Updates the document by applying the provided list of changes
    /// - Parameter changes: A list of byte buffers that represent the changes to the document.
    public mutating func apply(changes: [[UInt8]]) {
        let patch = writableBackend().apply(changes: changes)
        applyPatch(patch: patch)
    }
    
    /// Merges the change history from a document that shares the same model object into the current document.
    /// - Parameter remoteDocument: A ``Document`` from a collaborator.
    public mutating func merge(_ remoteDocument: Document<T>) {
        precondition(actor != remoteDocument.actor, "Cannot merge an actor with itself")
        apply(changes: remoteDocument.allChanges())
    }
    
    /// Returns the list of missing dependencies.
    public func getMissingsDeps() -> [String] {
        return backend.getMissingDeps()
    }
    
    /// Returns a list of the identifiers for changes in the document's history.
    public func getHeads() -> [String] {
        return backend.getHeads()
    }
    
    /// Returns a list of changes between the current document and the document provided.
    /// - Parameter oldDocument: A ``Document`` from a collaborator or an earlier saved version.
    /// - Returns: A list of changes between the two documents.
    public func getChanges(between oldDocument: Document<T>) -> [[UInt8]] {
        return backend.getChanges(heads: oldDocument.backend.getHeads())
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
        context: Context,
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
            ops: context.ops
        )

        let patch = writableBackend().applyLocalChange(request: request)

        applyPatchToDoc(patch: patch, fromBackend: true, context: context)

        
        return request
    }

    private mutating func writableBackend() -> RSBackend {
        if !isKnownUniquelyReferenced(&self.backend) {
            backend = backend.clone()
        }

        return backend
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
        updated[.root] = newRoot

        if fromBackend {
            if let clockValue = patch.clock[actor.actorId], clockValue > state.seq {
                state.seq = clockValue
            }
            state.clock = patch.clock
            state.deps = patch.deps
            state.maxOp = max(state.maxOp, patch.maxOp)
        }

        cache.merge(updated, uniquingKeysWith: { old, new in return new })

        if case .map(let newRoot)? = updated[.root] {
            self.root = newRoot
        } else {
            fatalError()
        }
    }

}

