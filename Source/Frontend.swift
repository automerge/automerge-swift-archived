//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

let ROOT_ID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

public struct Document<T> {

    public struct Options {
        let actorId: UUID
    }

    struct State {
        var seq: Int
        var requests: [Any]
        var version: Int
        var clock: Clock
        var canUndo: Bool
        var canRedo: Bool

        var backend: Backend?
    }

//    public let root: [String: Any]
    let _options: Options
    let _objectId: UUID
    let _conflicts: [String: [String: Diff]]
    let _cache: [String: Any]
    let _state: State
    let change: Any?
    let backend: Backend = Backend()


//    public init(root: [String: Any], options: Options) {
//        self = Document<T>(options: options).change(options: ChangeOptions(message: "Initialization", undoable: true), execute: { context in
////            context.set(value: options, keyPath: "")
//        }).0
//    }

    public init(options: Options) {
        self._objectId = ROOT_ID
        self._options = options
        self._conflicts = [:]
        self._cache = [ROOT_ID.uuidString: [:]]
        self.change = nil
        self._state = State(seq: 0, requests: [], version: 0, clock: [:], canUndo: false, canRedo: false)
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
     * Returns a new document object initialized with the given state.
     */
//    function from(initialState, options) {
//      return change(init(options), 'Initialization', doc => Object.assign(doc, initialState))
//    }

    /**
     * Returns the Automerge actor ID of the given document.
     */
    var actorId: UUID {
        return _options.actorId
    }

    //    function getActorId(doc) {
    //      return doc[STATE].actorId || doc[OPTIONS].actorId
    //    }

    public struct ChangeOptions {
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
    public func change(options: ChangeOptions? = nil, execute: (Context) -> Void) -> (Document<T>, Request?) {
        if change != nil {
            fatalError("Calls to Automerge.change cannot be nested")
        }
        let context = Context(doc: self, actorId: _options.actorId, applyPatch: nil)
        execute(context)
        if context.idUpdated {
            return makeChange(requestType: .change, context: context, options: options)
        } else {
            return (self, nil)
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
    func makeChange(requestType: Request.RequestType,
                    context: Context,
                    options: ChangeOptions?) -> (Document<T>, Request?
        ) {
            var state = self._state
            state.seq += 1

            let request = Request(requestType: requestType,
                                  message: options?.message ?? "",
                                  time: Date(),
                                  actor: self._options.actorId,
                                  seq: state.seq,
                                  version: state.version,
                                  ops: context.ops,
                                  undoable: options?.undoable ?? true
            )

            let(newBackend, patch) = backend.applyLocalChange(request: request)
            state.backend = newBackend

            return (applyPatchToDoc(patch: patch, state: state, fromBackend: false), request)

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
    func applyPatchToDoc(patch: Patch, state: State, fromBackend: Bool) -> Document<T> {
        fatalError("")
        var updated = [String: Any]()
        interpretPatch(patch: patch.diffs, obj: self, updated: &updated)

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

}

func canUndo(document: Any) -> Bool {
    #warning("unimplemented")
    return false
}


