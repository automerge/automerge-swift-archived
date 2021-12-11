//
//  Document.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

/// A wrapper around your codable model that tracks collaborative changes and provides an immutable views of the model's history.
///
/// Use a document by creating a document around your model using ``Document/init(_:actor:)``, and update your model within a trailing closure provided by ``Document/change(message:_:)``.
///
/// The initializer takes an optional ``Actor`` parameter.
/// An actor has a ``Actor/actorId``, a string that uniquely identifies the collaborator.
/// if you omit the actor, an actor with a random ID is generated.
/// If you pass in your own actor ID, ensure that there can never be two different collaborators with the same actor ID.
/// Even if you have two different processes running on the same machine, they must have distinct actor IDs.
/// Unless you intend otherwise, don't provode an actor and let the actor be auto-generated.
///
/// Persist your document using ``Document/save()``, which writes a compact version of the change history that you can write to disk.
/// Create a new document from the binary data created from ``Document/save()`` with the initializer ``Document/init(data:actor:)``.
///
/// With a document representing the state of your model, and another document representing a collaborator's model state, get the changes using ``Document/getChanges(between:)``, and selectively apply them to either document using ``Document/apply(changes:)``.
/// The Automerge library is agnostic to the network layer.
/// Use whatever communication mechanism you like to get changes from one collaborator to another.
/// Note that ``Document/getChanges(between:)`` takes an old document state as argument and returns a list of all the changes that are different between the new and old document.
/// If you want a list of all the changes ever made in doc, call ``Document/allChanges()``.
///
/// The counterpart, ``Document/apply(changes:)`` applies the list of changes to the document.
/// Automerge guarantees that when two documents have applied the same set of changes — even if the changes were applied in a different order — the two documents are equal.
/// This property is known as convergence, and it is at the core of what Automerge provides.
///
/// You can instantiate a document from another collaborator with its encoded change history using ``Document/init(data:actor:)``, or using a list of changes with the ``Document/init(changes:actor:)`` initializer.
/// You can merge the collaborator's change history into your document using ``Document/merge(_:)``.
///
/// You can inspect the details of the change history by initializing ``History`` with your document.
///
/// ## Topics
///
/// ### Creating a Document
///
/// - ``Document/init(_:actor:)``
/// - ``Document/init(data:actor:)``
/// - ``Document/init(changes:actor:)``
///
/// ### Updating a Document
///
/// - ``Document/change(message:_:)``
///
/// ### Getting and Applying Changes from a Collaborator
///
/// - ``Document/getChanges(between:)``
/// - ``Document/apply(changes:)``
///
/// ### Merging Documents
///
/// - ``Document/merge(_:)``
///
/// ### Inspecting a Document
///
/// - ``Document/content``
/// - ``Document/actor``
/// - ``Document/rootProxy()``
///
/// ### Saving a Document
///
/// - ``save()``
///
/// ### Applying a Patch
///
/// - ``Document/applyPatch(patch:)``
///
/// ### Inspecting the Change History
///
/// - ``Document/allChanges()``
/// - ``Document/getHeads()``
/// - ``Document/getMissingsDeps()``
///
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
    ///
    /// - Parameters:
    ///   - message: An optional message describing the change or reasons for the change. The change message isn't interpreted by Automerge, and is saved in the change history.
    ///   - execute: A closure that provides a proxy of the current instance of your model to update.
    /// - Returns: A change request to send to other collaborators, nil if the model wasn't updated.
    ///
    /// The optional message argument allows you to include a string describing the change, not interpreted by Automerge, and saved in the change history.
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
    /// ```
    ///
    /// Within the closure provided by this method, use `set` to update a value, or `set` a nil value to remove a property.
    /// All primitive data types are supported, as well as arrays.
    /// ```swift
    ///
    /// ```
    ///
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
    ///
    /// This function requires that the current document the remote document provided have different actor IDs (that is, they originated from different calls to ``Document/init(_:actor:)``).
    /// It inspects the provided document for any changes that aren't in the current document, and applies them.
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

