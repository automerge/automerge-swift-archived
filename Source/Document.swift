//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation
public struct Document<T: Codable> {

    public struct Options {

        public init(
            actorId: ActorId = ActorId(),
            backend: Backend = RSBackend()
        ) {
            self.actorId = actorId
            self.backend = backend
        }
        
        let actorId: ActorId
        var backend: Backend
    }

    struct State {
        var seq: Int
        var version: Int
        var clock: Clock
        var canUndo: Bool
        var canRedo: Bool
    }

    var options: Options
    var state: State
    var root: [String: Any]
    var change: Bool = false

    private init(options: Options) {
        self.options = options
        self.root = [
            OBJECT_ID: ROOT_ID,
            CONFLICTS: [Key: [String: Any]]()
        ]
        self.root[CACHE] = [ROOT_ID: root]
        self.state = State(seq: 0, version: 0, clock: [:], canUndo: false, canRedo: false)
    }

    public init(_ initialState: T, options: Options = Options()) {
        var newDocument = Document<T>(options: options)
        newDocument.change(options: .init(message: "Initialization", undoable: true), execute: { doc in
            doc.set(initialState)
        })
        self = newDocument
    }

    public init(data: [UInt8], actorId: ActorId = ActorId()) {
        let backend = RSBackend(data: data)
        var doc = Document<T>(options: .init(actorId: actorId, backend: backend))

        let patch = backend.getPatch()
        doc.applyPatch(patch: patch)
        self = doc
    }

    public init(changes: [[UInt8]], actorId: ActorId = ActorId()) {
        let backend = RSBackend(changes: changes)
        var doc = Document<T>(options: .init(actorId: actorId, backend: backend))

        let patch = backend.getPatch()
        doc.applyPatch(patch: patch)
        self = doc
    }

    var cache: [String: [String: Any]] {
        get {
            root[CACHE] as! [String: [String: Any]]
        }
        set {
            root[CACHE] = newValue
        }
    }

    /// Returns the Automerge actor ID of the given document.
    public var actor: ActorId {
        return options.actorId
    }

    public var content: T {
        let context = Context(doc: self, actorId: options.actorId)
        
        return Proxy<T>.rootProxy(context: context).get()
    }

    public struct ChangeOptions {
        public init(message: String = "", undoable: Bool = true) {
            self.message = message
            self.undoable = undoable
        }
        let message: String
        let undoable: Bool
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
    public mutating func change(options: ChangeOptions, execute: (Proxy<T>) -> Void) -> Request? {
        if change {
            fatalError("Calls to Automerge.change cannot be nested")
        }
        let context = Context(doc: self, actorId: self.options.actorId)
        execute(.rootProxy(context: context))
        if context.idUpdated {
            return makeChange(requestType: .change, context: context, options: options)
        } else {
            return nil
        }
    }

    @discardableResult
    public mutating func change(_ execute: (Proxy<T>) -> Void) -> Request? {
        if change {
            fatalError("Calls to Automerge.change cannot be nested")
        }
        let context = Context(doc: self, actorId: self.options.actorId)
        execute(.rootProxy(context: context))
        if context.idUpdated {
            return makeChange(requestType: .change, context: context, options: nil)
        } else {
            return nil
        }
    }

    //function change(doc, options, callback) {
    //  if (doc[OBJECT_ID] !== ROOT_ID) {
    //    throw new TypeError('The first argument to Automerge.change must be the document root')
    //  }
    //  if (doc[CHANGE]) {
    //    throw new TypeError('Calls to Automerge.change cannot be nested')
    //  }
    //  if (typeof options === 'function' && callback === undefined) {
    //    ;[options, callback] = [callback, options]
    //  }
    //  if (typeof options === 'string') {
    //    options = {message: options}
    //  }
    //  if (options !== undefined && !isObject(options)) {
    //    throw new TypeError('Unsupported type of options')
    //  }
    //
    //  const actorId = getActorId(doc)
    //  if (!actorId) {
    //    throw new Error('Actor ID must be initialized with setActorId() before making a change')
    //  }
    //  const context = new Context(doc, actorId)
    //  callback(rootObjectProxy(context))
    //
    //  if (Object.keys(context.updated).length === 0) {
    //    // If the callback didn't change anything, return the original document object unchanged
    //    return [doc, null]
    //  } else {
    //    return makeChange(doc, 'change', context, options)
    //  }
    //}

    /**
     * Adds a new change request to the list of pending requests, and returns an
     * updated document root object. `requestType` is a string indicating the type
     * of request, which may be "change", "undo", or "redo". For the "change" request
     * type, the details of the change are taken from the context object `context`.
     * `options` contains properties that may affect how the change is processed; in
     * particular, the `message` property of `options` is an optional human-readable
     * string describing the change.
     */
    mutating func makeChange(requestType: Request.RequestType,
                    context: Context?,
                    options: ChangeOptions?) -> Request?
    {
            var state = self.state
            state.seq += 1

            let request = Request(requestType: requestType,
                                  message: options?.message ?? "",
                                  time: Date(),
                                  actor: self.options.actorId.actorId,
                                  seq: state.seq,
                                  version: state.version,
                                  ops: context?.ops ?? [],
                                  undoable: options?.undoable ?? true
            )

        let backend = self.options.backend
        let(newBackend, patch) = backend.applyLocalChange(request: request)
        self.options.backend = newBackend

        applyPatchToDoc(patch: patch, fromBackend: true, context: context)
        return request
    }


    //    function makeChange(doc, requestType, context, options) {
    //      const actor = getActorId(doc)
    //      if (!actor) {
    //        throw new Error('Actor ID must be initialized with setActorId() before making a change')
    //      }
    //      const state = copyObject(doc[STATE])
    //      state.seq += 1
    //
    //      const request = {requestType, actor, seq: state.seq, version: state.version}
    //      if (options && options.message !== undefined) {
    //        request.message = options.message
    //      }
    //      if (options && options.undoable === false) {
    //        request.undoable = false
    //      }
    //      if (context) {
    //        request.ops = context.ops
    //      }
    //
    //      if (doc[OPTIONS].backend) {
    //        const [backendState, patch] = doc[OPTIONS].backend.applyLocalChange(state.backendState, request)
    //        state.backendState = backendState
    //        // NOTE: When performing a local change, the patch is effectively applied twice -- once by the
    //        // context invoking interpretPatch as soon as any change is made, and the second time here
    //        // (after a round-trip through the backend). This is perhaps more robust, as changes only take
    //        // effect in the form processed by the backend, but the downside is a performance cost.
    //        // Should we change this?
    //        return [applyPatchToDoc(doc, patch, state, true), request]
    //
    //      } else {
    //        if (!context) context = new Context(doc, actor)
    //        const queuedRequest = copyObject(request)
    //        queuedRequest.before = doc
    //        state.requests = state.requests.concat([queuedRequest])
    //        return [updateRootObject(doc, context.updated, state), request]
    //      }
    //    }

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

        updateRootObject(update: &updated, state: state)
    }

    //    function applyPatchToDoc(doc, patch, state, fromBackend) {
    //      const actor = getActorId(doc)
    //      const updated = {}
    //      interpretPatch(patch.diffs, doc, updated)
    //
    //      if (fromBackend) {
    //        if (!patch.clock) throw new RangeError('patch is missing clock field')
    //        if (patch.clock[actor] && patch.clock[actor] > state.seq) {
    //          state.seq = patch.clock[actor]
    //        }
    //        state.clock   = patch.clock
    //        state.version = patch.version
    //        state.canUndo = patch.canUndo
    //        state.canRedo = patch.canRedo
    //      }
    //      return updateRootObject(doc, updated, state)
    //    }

    /**
     * Applies `patch` to the document root object `doc`. This patch must come
     * from the backend; it may be the result of a local change or a remote change.
     * If it is the result of a local change, the `seq` field from the change
     * request should be included in the patch, so that we can match them up here.
     */

    mutating func applyPatch(patch: Patch) {
        applyPatchToDoc(patch: patch, fromBackend: true, context: nil)
    }
//    function applyPatch(doc, patch) {
//      const state = copyObject(doc[STATE])
//
//      if (doc[OPTIONS].backend) {
//        if (!patch.state) {
//          throw new RangeError('When an immediate backend is used, a patch must contain the new backend state')
//        }
//        state.backendState = patch.state
//        return applyPatchToDoc(doc, patch, state, true)
//      }
//
//      let baseDoc
//
//      if (state.requests.length > 0) {
//        baseDoc = state.requests[0].before
//        if (patch.actocr === getActorId(doc) && patch.seq !== undefined) {
//          if (state.requests[0].seq !== patch.seq) {
//            throw new RangeError(`Mismatched sequence number: patch ${patch.seq} does not match next request ${state.requests[0].seq}`)
//          }
//          state.requests = state.requests.slice(1).map(copyObject)
//        } else {
//          state.requests = state.requests.slice().map(copyObject)
//        }
//      } else {
//        baseDoc = doc
//        state.requests = []
//      }
//
//      let newDoc = applyPatchToDoc(baseDoc, patch, state, true)
//      if (state.requests.length === 0) {
//        return newDoc
//      } else {
//        state.requests[0].before = newDoc
//        return updateRootObject(doc, {}, state)
//      }
//    }

    /**
    * Takes a set of objects that have been updated (in `updated`) and an updated state object
    * `state`, and returns a new immutable document root object based on `doc` that reflects
    * those updates.
    */
    mutating func updateRootObject(update: inout [String: [String: Any]], state: State) {
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
        self.state = state
    }


//    function updateRootObject(doc, updated, state) {
//      let newDoc = updated[ROOT_ID]
//      if (!newDoc) {
//        newDoc = cloneRootObject(doc[CACHE][ROOT_ID])
//        updated[ROOT_ID] = newDoc
//      }
//      Object.defineProperty(newDoc, OPTIONS,  {value: doc[OPTIONS]})
//      Object.defineProperty(newDoc, CACHE,    {value: updated})
//      Object.defineProperty(newDoc, STATE,    {value: state})
//
//
//      for (let objectId of Object.keys(doc[CACHE])) {
//        if (!updated[objectId]) {
//          updated[objectId] = doc[CACHE][objectId]
//        }
//      }
//
//      if (doc[OPTIONS].freeze) {
//        Object.freeze(updated)
//      }
//      return newDoc
//    }

    public func save() -> [UInt8] {
        return options.backend.save()
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
        let context = Context(doc: self, actorId: self.options.actorId)
        return .rootProxy(context: context)
    }

    public func allChanges() -> [[UInt8]] {
        return options.backend.getChanges()
    }

    public mutating func apply(changes: [[UInt8]]) {
        let(newBackend, patch) = options.backend.apply(changes: changes)

        self.options.backend = newBackend

        applyPatch(patch: patch)
    }

//    function applyChanges(doc, changes) {
//      const oldState = Frontend.getBackendState(doc)
//      const [newState, patch] = backend.applyChanges(oldState, changes)
//      patch.state = newState
//      return Frontend.applyPatch(doc, patch)
//    }

    public mutating func merge(_ remoteDocument: Document<T>) {
        precondition(actor != remoteDocument.actor, "Cannot merge an actor with itself")
        apply(changes: remoteDocument.allChanges())
    }

//    function merge(localDoc, remoteDoc) {
//      if (Frontend.getActorId(localDoc) === Frontend.getActorId(remoteDoc)) {
//        throw new RangeError('Cannot merge an actor with itself')
//      }
//      // Just copy all changes from the remote doc; any duplicates will be ignored
//      return applyChanges(localDoc, getAllChanges(remoteDoc))
//    }

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
    public mutating func undo(options: ChangeOptions = ChangeOptions()) -> Request? {
        if !canUndo {
            return nil
        }
        return makeChange(requestType: .undo, context: nil, options: options)
    }


//    function undo(doc, options) {
//      if (typeof options === 'string') {
//        options = {message: options}
//      }
//      if (options !== undefined && !isObject(options)) {
//        throw new TypeError('Unsupported type of options')
//      }
//      if (!doc[STATE].canUndo) {
//        throw new Error('Cannot undo: there is nothing to be undone')
//      }
//      if (isUndoRedoInFlight(doc)) {
//        throw new Error('Can only have one undo in flight at any one time')
//      }
//      return makeChange(doc, 'undo', null, options)
//    }

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
    public mutating func redo(options: ChangeOptions = ChangeOptions()) -> Request? {
        if !canRedo {
            return nil
        }
        return makeChange(requestType: .redo, context: nil, options: options)
    }
//    function redo(doc, options) {
//      if (typeof options === 'string') {
//        options = {message: options}
//      }
//      if (options !== undefined && !isObject(options)) {
//        throw new TypeError('Unsupported type of options')
//      }
//      if (!doc[STATE].canRedo) {
//        throw new Error('Cannot redo: there is no prior undo')
//      }
//      if (isUndoRedoInFlight(doc)) {
//        throw new Error('Can only have one redo in flight at any one time')
//      }
//      return makeChange(doc, 'redo', null, options)
//    }

    public func history() -> [Commit<T>] {
        let actor = self.actor
        let history = allChanges()
        return history.enumerated().map({ index, change in
            return Commit(snapshot: Document(changes: Array(history[0...index]), actorId: actor).content)
        })
    }
}

//function getHistory(doc) {
//  const actor = Frontend.getActorId(doc)
//  const history = getAllChanges(doc)
//  return history.map((change, index) => {
//    return {
//      get change () {
//        return decodeChange(change)
//      },
//      get snapshot () {
//        const state = backend.loadChanges(backend.init(), history.slice(0, index + 1))
//        const patch = backend.getPatch(state)
//        patch.state = state
//        return Frontend.applyPatch(init(actor), patch)
//      }
//    }
//  })
//}

public struct Commit<T> {
    public let snapshot: T
}


