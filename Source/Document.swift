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
        var requests: [RequestMetaData<T>]
        var version: Int
        var clock: Clock
        var canUndo: Bool
        var canRedo: Bool
    }

    var options: Options
    var state: State
    var root: [String: Any]
    var change: Bool = false

    init(options: Options) {
        self.options = options
        self.root = [
            OBJECT_ID: ROOT_ID,
            CONFLICTS: [Key: [String: Any]]()
        ]
        self.root[CACHE] = [ROOT_ID: root]
        self.state = State(seq: 0, requests: [], version: 0, clock: [:], canUndo: false, canRedo: false)
    }

    public init(_ initialState: T, options: Options = Options()) {
        var newDocument = Document<T>(options: options)
        newDocument.change(options: .init(message: "Initialization", undoable: true), execute: { doc in
            doc.set(object: initialState)
        })
        self = newDocument
    }

    public init(_ data: [UInt8], actorId: ActorId = ActorId()) {
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

//    function load(data, options) {
//      const state = backend.load(data)
//      const patch = backend.getPatch(state)
//      patch.state = state
//      return Frontend.applyPatch(init(options), patch)
//    }
    
    init(root: [String: Any], state: State, options: Options) {
        self.options = options
        self.root = root
        self.state = state
    }

    var cache: [String: [String: Any]] {
        get {
            root[CACHE] as! [String: [String: Any]]
        }
        set {
            root[CACHE] = newValue
        }
    }


    //function init(options) {
    //  if (typeof options === 'string') {
    //    options = {actorId: options}
    //  } else if (typeof options === 'undefined') {
    //    options = {}
    //  } else if (!isObject(options)) {
    //    throw new TypeError(`Unsupported value for init() options: ${options}`)
    //  }
    //  if (options.actorId === undefined && !options.deferActorId) {
    //    options.actorId = uuid()
    //  }
    //
    //  const root = {}, cache = {[ROOT_ID]: root}
    //  const state = {seq: 0, requests: [], version: 0, clock: {}, canUndo: false, canRedo: false}
    //  if (options.backend) {
    //    state.backendState = options.backend.init()
    //  }
    //  Object.defineProperty(root, OBJECT_ID, {value: ROOT_ID})
    //  Object.defineProperty(root, OPTIONS,   {value: Object.freeze(options)})
    //  Object.defineProperty(root, CONFLICTS, {value: Object.freeze({})})
    //  Object.defineProperty(root, CACHE,     {value: Object.freeze(cache)})
    //  Object.defineProperty(root, STATE,     {value: Object.freeze(state)})
    //  return Object.freeze(root)
    //}



    /**
     * Returns the Automerge actor ID of the given document.
     */
    public var actor: ActorId {
        return options.actorId
    }

    public var content: T {
        let context = Context(doc: self, actorId: options.actorId)
        
        return Proxy<T>.rootProxy(contex: context).value
    }

    public func getObjectId<Y: Codable>(_ keyPath: KeyPath<T, Y>, _ keyPathString: String) -> String? {
        let context = Context(doc: self, actorId: options.actorId)
        return Proxy<Y>.rootProxy(contex: context)[keyPath, keyPathString]?.objectId
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
        execute(.rootProxy(contex: context))
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
        execute(.rootProxy(contex: context))
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
//    function canUndo(doc) {
//      return !!doc[STATE].canUndo && !isUndoRedoInFlight(doc)
//    }

    /**
     * Fetches the conflicts on the property `key` of `object`, which may be any
     * object in a document. If `object` is a list, then `key` must be a list
     * index; if `object` is a map, then `key` must be a property name.
     */
    public func conflicts<Y>(for keyPath: WritableKeyPath<T, Y>, _ keyPathString: String) -> Y? {
        return nil
    }
//    function getConflicts(object, key) {
//      if (object[CONFLICTS] && object[CONFLICTS][key] &&
//          Object.keys(object[CONFLICTS][key]).length > 1) {
//        return object[CONFLICTS][key]
//      }
//    }

    public func allChanges() -> [[UInt8]] {
        return options.backend.getChanges()
    }
}



