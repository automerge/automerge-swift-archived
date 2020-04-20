//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation


public final class Context {

    struct KeyPathElement: Equatable {
        enum Key: Equatable {
            case string(String)
            case number(Int)
        }

        let key: Key
        let objectId: UUID
    }

    init<T>(doc: Document<T>, actorId: UUID, applyPatch: ((ObjectDiff, Any, ReferenceDictionary<String, Any>) -> Void)?) {
        self.cache = doc._cache
        self.updated = ReferenceDictionary<String, Any>()
        self.actorId = actorId
        self.ops = []
        self.applyPatch = applyPatch!
    }

    init(actorId: UUID,
         applyPatch: @escaping (ObjectDiff, Any, ReferenceDictionary<String, Any>) -> Void,
         updated: ReferenceDictionary<String, Any>,
         cache: ReferenceDictionary<String, Any>,
         ops: [Op] = []
    ) {
        self.actorId = actorId
        self.applyPatch = applyPatch
        self.updated = updated
        self.cache = cache
        self.ops = ops
    }

    let actorId: UUID
    let applyPatch: (ObjectDiff, Any, ReferenceDictionary<String, Any>) -> Void
    var updated: ReferenceDictionary<String, Any>
    var cache: ReferenceDictionary<String, Any>

    var idUpdated: Bool {
        return !ops.isEmpty
    }

    private (set) var ops: [Op]


    /**
     * Records an assignment to a particular key in a map, or a particular index in a list.
     * `objectId` is the ID of the object being modified, `key` is the property name or list
     * index being updated, and `value` is the new value being assigned. If `insert` is true,
     * a new list element is inserted at index `key`, and `value` is assigned to that new list
     * element. Returns a patch describing the new value. The return value is of the form
     * `{objectId, type, props}` if `value` is an object, or `{value, datatype}` if it is a
     * primitive value. For string, number, boolean, or null the datatype is omitted.
     */

    func setValue<T>(objectId: UUID, key: String, value: T, insert: Bool? = nil) -> Diff {
        precondition(!key.isEmpty, "The key of a map entry must not be an empty string")
        switch value {
        case  let value as Double:
            let operation = Op(action: .set, obj: objectId, key: .string(key), insert: insert, child: nil, value: .number(value), datatype: nil)
            ops.append(operation)
            return .value(.init(value: .number(value)))
        case  let value as Int:
            let operation = Op(action: .set, obj: objectId, key: .string(key), insert: insert, child: nil, value: .number(Double(value)), datatype: nil)
            ops.append(operation)
            return .value(.init(value: .number(Double(value))))
        case let value as [String: Any]:
            return .object(createNestedObjects(obj: objectId, key: key, value: value, insert: insert))
        default:
            fatalError()
        }
    }

//    setValue(objectId, key, value, insert) {
//      if (!objectId) {
//        throw new RangeError('setValue needs an objectId')
//      }
//      if (key === '') {
//        throw new RangeError('The key of a map entry must not be an empty string')
//      }
//
//      if (isObject(value) && !(value instanceof Date) && !(value instanceof Counter)) {
//        // Nested object (map, list, text, or table)
//        return this.createNestedObjects(objectId, key, value, insert)
//      } else {
//        // Date or counter object, or primitive value (number, string, boolean, or null)
//        const description = this.getValueDescription(value)
//        const operation = Object.assign({action: 'set', obj: objectId, key}, description)
//        if (insert) operation.insert = true
//        this.addOp(operation)
//        return description
//      }
//    }

    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    func createNestedObjects(obj: UUID, key: String?, value: [String: Any], insert: Bool? = nil) -> ObjectDiff {
        precondition(value[OBJECT_ID] == nil, "Cannot create a reference to an existing document object")
        let child = UUID()
        let key = key ?? child.uuidString
        let operation = Op(action: .makeMap, obj: obj, key: .string(key), child: child)
        ops.append(operation)

        let props = Props()
        for nested in value.keys {
            let valuePatch = setValue(objectId: child, key: nested, value: value[nested], insert: nil)
            props[nested] = [actorId.uuidString: valuePatch]
        }

        return ObjectDiff(objectId: child, type: .map, props: props)

        // Create a new map object
        //    const operation = {action: 'makeMap', obj, key, child}
        //    if (insert) operation.insert = true
        //    this.addOp(operation)
        //
        //    let props = {}
        //    for (let nested of Object.keys(value)) {
        //      const valuePatch = this.setValue(child, nested, value[nested], false)
        //      props[nested] = {[this.actorId]: valuePatch}
        //    }
        //    return {objectId: child, type: 'map', props}
        //  }
    }
    //createNestedObjects(obj, key, value, insert) {
    //  if (value[OBJECT_ID]) {
    //    throw new RangeError('Cannot create a reference to an existing document object')
    //  }
    //  const child = uuid()
    //  if (key === null) key = child
    //
    //  if (value instanceof Text) {
    //    // Create a new Text object
    //    const operation = {action: 'makeText', obj, key, child}
    //    if (insert) operation.insert = true
    //    this.addOp(operation)
    //
    //    const subpatch = {objectId: child, type: 'text', edits: [], props: {}}
    //    this.insertListItems(subpatch, 0, [...value], true)
    //    return subpatch
    //
    //  } else if (value instanceof Table) {
    //    // Create a new Table object
    //    if (value.count > 0) {
    //      throw new RangeError('Assigning a non-empty Table object is not supported')
    //    }
    //    const operation = {action: 'makeTable', obj, key, child}
    //    if (insert) operation.insert = true
    //    this.addOp(operation)
    //    return {objectId: child, type: 'table', props: {}}
    //
    //  } else if (Array.isArray(value)) {
    //    // Create a new list object
    //    const operation = {action: 'makeList', obj, key, child}
    //    if (insert) operation.insert = true
    //    this.addOp(operation)
    //
    //    const subpatch = {objectId: child, type: 'list', edits: [], props: {}}
    //    this.insertListItems(subpatch, 0, value, true)
    //    return subpatch
    //
    //  } else {
    //    // Create a new map object
    //    const operation = {action: 'makeMap', obj, key, child}
    //    if (insert) operation.insert = true
    //    this.addOp(operation)
    //
    //    let props = {}
    //    for (let nested of Object.keys(value)) {
    //      const valuePatch = this.setValue(child, nested, value[nested], false)
    //      props[nested] = {[this.actorId]: valuePatch}
    //    }
    //    return {objectId: child, type: 'map', props}
    //  }
    //}

    /**
     * Updates the map object at path `path`, setting the property with name
     * `key` to `value`.
     */

    func setMapKey<T: Equatable>(path: [KeyPathElement], key: String, value: T) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let anyObject = getObject(objectId: objectId)
        let object = cast(anyObject)
        if object[key] is Counter {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        // If the assigned field value is the same as the existing value, and
        // the assignment does not resolve a conflict, do nothing
        if (object[key] as? T) != value {
            applyAt(path: path, callback: { subpatch in
                let valuePatch = setValue(objectId: objectId, key: key, value: value, insert: nil)
                subpatch.props?[key] = [actorId.uuidString: valuePatch]
            })
        } else if (object[CONFLICTS] as? [String: [Any]])?[key]?.count ?? 0 > 1 {

        }

    }
//    setMapKey(path, key, value) {
//      if (typeof key !== 'string') {
//        throw new RangeError(`The key of a map entry must be a string, not ${typeof key}`)
//      }
//
//      const objectId = path.length === 0 ? ROOT_ID : path[path.length - 1].objectId
//      const object = this.getObject(objectId)
//      if (object[key] instanceof Counter) {
//        throw new RangeError('Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.')
//      }
//
//      // If the assigned field value is the same as the existing value, and
//      // the assignment does not resolve a conflict, do nothing
//      if (object[key] !== value || Object.keys(object[CONFLICTS][key] || {}).length > 1 || value === undefined) {
//        this.applyAtPath(path, subpatch => {
//          const valuePatch = this.setValue(objectId, key, value, false)
//          subpatch.props[key] = {[this.actorId]: valuePatch}
//        })
//      }
//    }

    /**
     * Takes a value and returns an object describing the value (in the format used by patches).
     */
    func getValueDescription(value: Any) -> Diff {
        switch value {
        case let double as Double:
            return .value(.init(value: .number(double), datatype: nil))
        default:
            fatalError()
        }
    }
//    getValueDescription(value) {
//      if (!['object', 'boolean', 'number', 'string'].includes(typeof value)) {
//        throw new TypeError(`Unsupported type of value: ${typeof value}`)
//      }
//
//      if (isObject(value)) {
//        if (value instanceof Date) {
//          // Date object, represented as milliseconds since epoch
//          return {value: value.getTime(), datatype: 'timestamp'}
//
//        } else if (value instanceof Counter) {
//          // Counter object
//          return {value: value.value, datatype: 'counter'}
//
//        } else {
//          // Nested object (map, list, text, or table)
//          const objectId = value[OBJECT_ID]
//          if (!objectId) {
//            throw new RangeError(`Object ${JSON.stringify(value)} has no objectId`)
//          }
//          return {objectId, type: this.getObjectType(objectId)}
//        }
//      } else {
//        // Primitive value (number, string, boolean, or null)
//        return {value}
//      }
//    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    private func getObject(objectId: UUID) -> Any {
        guard let object = updated[objectId] ?? cache[objectId] else {
            fatalError("Target object does not exist: \(objectId)")
        }
        return object
    }
//    getObject(objectId) {
//      const object = this.updated[objectId] || this.cache[objectId]
//      if (!object) throw new RangeError(``)
//      return object
//    }

    /**
     * Constructs a new patch, calls `callback` with the subpatch at the location `path`,
     * and then immediately applies the patch to the document.
     */
    func applyAt(path: [KeyPathElement], callback: (ObjectDiff) -> Void) {
        let patch = Patch(clock: [:], version: 0, diffs: ObjectDiff(objectId: ROOT_ID, type: .map))
        callback(getSubpatch(patch: patch, path: path))
        applyPatch(patch.diffs, cache[ROOT_ID], updated)
    }
//    applyAtPath(path, callback) {
//      let patch = {diffs: {objectId: ROOT_ID, type: 'map'}}
//      callback(this.getSubpatch(patch, path))
//      this.applyPatch(patch.diffs, this.cache[ROOT_ID], this.updated)
//    }

    /**
     * Recurses along `path` into the patch object `patch`, creating nodes along the way as needed
     * by mutating the patch object. Returns the subpatch at the given path.
     */
    func getSubpatch(patch: Patch, path: [KeyPathElement]) -> ObjectDiff {
        var subPatch = patch.diffs
        var object = getObject(objectId: ROOT_ID)
        for pathElem in path {
            guard case .string(let key) = pathElem.key else {
                fatalError()
            }
            if subPatch.props == nil {
                subPatch.props = [:]
            }
            if subPatch.props?[key] == nil {
                subPatch.props?[key] = getValuesDescriptions(path: path, object: object, key: key)
            }
            var nextOpId: UUID?
            let values = subPatch.props![key]!
            for opId in values.keys {
                if case .object(let object) = values[opId]!, object.objectId == pathElem.objectId {
                    nextOpId = UUID(uuidString: opId)!
                }
            }
            guard let nextOpId2 = nextOpId, case .object(let objectDiff) = values[nextOpId2.uuidString] else {
                fatalError("Cannot find path object with objectId \(pathElem.objectId)")
            }
            subPatch = objectDiff
            object = getPropertyValue(object: object, key: key, opId: nextOpId2.uuidString)

        }

        if subPatch.props == nil {
            subPatch.props = [:]
        }

        return subPatch
    }
//    getSubpatch(patch, path) {
//      let subpatch = patch.diffs, object = this.getObject(ROOT_ID)
//
//      for (let pathElem of path) {
//        if (!subpatch.props) {
//          subpatch.props = {}
//        }
//        if (!subpatch.props[pathElem.key]) {
//          subpatch.props[pathElem.key] = this.getValuesDescriptions(path, object, pathElem.key)
//        }
//
//        let nextOpId = null, values = subpatch.props[pathElem.key]
//        for (let opId of Object.keys(values)) {
//          if (values[opId].objectId === pathElem.objectId) {
//            nextOpId = opId
//          }
//        }
//        if (!nextOpId) {
//          throw new RangeError(``)
//        }
//        subpatch = values[nextOpId]
//        object = this.getPropertyValue(object, pathElem.key, nextOpId)
//      }
//
//      if (!subpatch.props) {
//        subpatch.props = {}
//      }
//      return subpatch
//    }

    /**
     * Returns the value at property `key` of object `object`. In the case of a conflict, returns
     * the value whose assignment operation has the ID `opId`.
     */
    func getPropertyValue(object: Any, key: String, opId: String) -> Any {
        if object is Table {
            fatalError()
        } else {
            fatalError()
        }
    }
//    getPropertyValue(object, key, opId) {
//      if (object instanceof Table) {
//        return object.byId(key)
//      } else {
//        return object[CONFLICTS][key][opId]
//      }
//    }

    /**
     * Builds the values structure describing a single property in a patch. Finds all the values of
     * property `key` of `object` (there might be multiple values in the case of a conflict), and
     * returns an object that maps operation IDs to descriptions of values.
     */
    func getValuesDescriptions(path: [KeyPathElement], object: Any, key: String) -> ReferenceDictionary<String, Diff> {
        switch object {
        case let _ as Table:
            fatalError()
        case let map as [String: Any]:
            guard let conflicts = map[CONFLICTS] else {
                fatalError("No children at key \(key) of path \(path)")
            }
            let typedConflicts = conflicts as! ReferenceDictionary<String, String>
            let values = ReferenceDictionary<String, Diff>()
            for opId in typedConflicts.keys {
                values[opId] = getValueDescription(value: typedConflicts[opId])
            }

            return values
        default:
            fatalError()
        }

    }
//    getValuesDescriptions(path, object, key) {
//      if (object instanceof Table) {
//        // Table objects don't have conflicts, since rows are identified by their unique objectId
//        const value = object.byId(key)
//        if (value) {
//          return {[key]: this.getValueDescription(value)}
//        } else {
//          return {}
//        }
//      } else {
//        // Map, list, or text objects
//        const conflicts = object[CONFLICTS][key], values = {}
//        if (!conflicts) {
//          throw new RangeError(`No children at key ${key} of path ${JSON.stringify(path)}`)
//        }
//        for (let opId of Object.keys(conflicts)) {
//          values[opId] = this.getValueDescription(conflicts[opId])
//        }
//        return values
//      }
//    }

}



/////**
//// * Records an operation to update the object with ID `obj`, setting `key`
//// * to `value`. Returns an object in which the value has been normalized: if it
//// * is a reference to another object, `{value: otherObjectId, link: true}` is
//// * returned; otherwise `{value: primitiveValue, datatype: someType}` is
//// * returned. The datatype is only present for values that need to be
//// * interpreted in a special way (timestamps, counters); for primitive types
//// * (string, number, boolean, null) the datatype property is omitted.
//// */
////setValue(obj, key, value) {
////  if (!['object', 'boolean', 'number', 'string'].includes(typeof value)) {
////    throw new TypeError(`Unsupported type of value: ${typeof value}`)
////  }
////
////  if (isObject(value)) {
////    if (value instanceof Date) {
////      // Date object, translate to timestamp (milliseconds since epoch)
////      const timestamp = value.getTime()
////      this.addOp({action: 'set', obj, key, value: timestamp, datatype: 'timestamp'})
////      return {value: timestamp, datatype: 'timestamp'}
////
////    } else if (value instanceof Counter) {
////      // Counter object, save current value
////      this.addOp({action: 'set', obj, key, value: value.value, datatype: 'counter'})
////      return {value: value.value, datatype: 'counter'}
////
////    } else {
////      // Reference to another object
////      const childId = this.createNestedObjects(value)
////      this.addOp({action: 'link', obj, key, value: childId})
////      return {value: childId, link: true}
////    }
////  } else {
////    // Primitive value (number, string, boolean, or null)
////    this.addOp({action: 'set', obj, key, value})
////    return {value}
////  }
////}


func cast(_ obj: Any) -> ReferenceDictionary<String, Any> {
    if let abc = obj as? ReferenceDictionary<String, String> {
        return ReferenceDictionary(abc.store)
    }
    return obj as! ReferenceDictionary<String, Any>
}
