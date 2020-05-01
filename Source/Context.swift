//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public final class Context {

    struct KeyPathElement: Equatable {
        let key: Key
        let objectId: String
    }

    init<T>(doc: Document<T>, actorId: UUID) {
        self.cache = doc.cache
        self.updated = [String: [String: Any]]()
        self.actorId = actorId
        self.ops = []
        self.applyPatch = interpretPatch
    }

    init(actorId: UUID,
         applyPatch: @escaping (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]?,
         updated: [String: [String: Any]],
         cache: [String: [String: Any]],
         ops: [Op] = []
    ) {
        self.actorId = actorId
        self.applyPatch = applyPatch
        self.updated = updated
        self.cache = cache
        self.ops = ops
    }

    let actorId: UUID
    let applyPatch: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]?
    var updated: [String: [String: Any]]
    var cache: [String: [String: Any]]
    var instantiateObject: (() -> Void)!

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

    func setValue<T>(objectId: String, key: Key?, value: T, insert: Bool? = nil) -> Diff {
        switch value {
        case  let value as Double:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .number(value))
            ops.append(operation)
            return .value(.number(value))
        case  let value as Int:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .number(Double(value)))
            ops.append(operation)
            return .value(.number(Double(value)))
        case let string as String:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .string(string))
            ops.append(operation)
            return .value(.string(string))
        case let character as Character:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .string(String(character)))
            ops.append(operation)
            return .value(.string(String(character)))
        case let date as Date:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .number(date.timeIntervalSince1970), datatype: .timestamp)
            ops.append(operation)
            return .value(.init(value: .number(date.timeIntervalSince1970), datatype: .timestamp))
        case let couter as Counter:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .number(couter.value), datatype: .counter)
            ops.append(operation)
            return .value(.init(value: .number(couter.value), datatype: .counter))
        case let value as [String: Any]:
            return .object(createNestedObjects(obj: objectId, key: key, value: value, insert: insert))
        case let array as [Any]:
            return .object(createNestedObjects(obj: objectId, key: key, value: array, insert: insert))
        case let text as Text:
            return .object(createNestedObjects(obj: objectId, key: key, value: text, insert: insert))
        case let table as Table:
            return .object(createNestedObjects(obj: objectId, key: key, value: table, insert: insert))
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
    private func createNestedObjects(obj: String, key: Key?, value: Any, insert: Bool? = nil) -> ObjectDiff {
        let child = UUID().uuidString
        let key = key ?? .string(child)
        switch value {
        case let object as [String: Any]:
            precondition(object[OBJECT_ID] == nil, "Cannot create a reference to an existing document object")
            let operation = Op(action: .makeMap, obj: obj, key: key, child: child)
            ops.append(operation)

            var props = Props()
            for nested in object.keys {
                let valuePatch = setValue(objectId: child, key: .string(nested), value: object[nested], insert: nil)
                props[.string(nested)] = [actorId.uuidString: valuePatch]
            }

            return ObjectDiff(objectId: child, type: .map, props: props)
        case let array as Array<Any>:
            let operation = Op(action: .makeList, obj: obj, key: key, insert: insert, child: child)
            ops.append(operation)
            let subpatch = ObjectDiff(objectId: child, type: .list, edits: [], props: [:])
            insertListItems(subPatch: subpatch, index: 0, values: array, newObject: true)

            return subpatch
        case let text as Text:
            let operation = Op(action: .makeText, obj: obj, key: key, insert: insert, child: child)
            ops.append(operation)
            let subpatch = ObjectDiff(objectId: child, type: .text, edits: [], props: [:])
            insertListItems(subPatch: subpatch, index: 0, values: text.elms, newObject: true)

            return subpatch
        case is Table:
            //    if (value.count > 0) {
            //      throw new RangeError('Assigning a non-empty Table object is not supported')
            //    }
            let operation = Op(action: .makeTable, obj: obj, key: key, insert: insert, child: child)
            ops.append(operation)
            let subpatch = ObjectDiff(objectId: child, type: .table, props: [:])

            return subpatch
        default:
            fatalError()
        }
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
     * Inserts a sequence of new list elements `values` into a list, starting at position `index`.
     * `newObject` is true if we are creating a new list object, and false if we are updating an
     * existing one. `subpatch` is the patch for the list object being modified. Mutates
     * `subpatch` to reflect the sequence of values.
     */
    func insertListItems(subPatch: ObjectDiff, index: Int, values: [Any], newObject: Bool) {
        let list = newObject ? [] : getList(objectId: subPatch.objectId)
        precondition(index >= 0 && index <= list.count, "List index \(index) is out of bounds for list of length \(list.count)")

        values.enumerated().forEach({ offset, element in
            let valuePatch = setValue(objectId: subPatch.objectId, key: .index(index + offset), value: element, insert: true)
            subPatch.edits?.append(Edit(action: .insert, index: index + offset))
            subPatch.props?[.index(index + offset)] = [actorId.uuidString: valuePatch]
        })
    }
    //    insertListItems(subpatch, index, values, newObject) {
    //      const list = newObject ? [] : this.getObject(subpatch.objectId)
    //      if (index < 0 || index > list.length) {
    //        throw new RangeError(`List index ${index} is out of bounds for list of length ${list.length}`)
    //      }
    //
    //      for (let offset = 0; offset < values.length; offset++) {
    //        const valuePatch = this.setValue(subpatch.objectId, index + offset, values[offset], true)
    //        subpatch.edits.push({action: 'insert', index: index + offset})
    //        subpatch.props[index + offset] = {[this.actorId]: valuePatch}
    //      }
    //    }

    /**
     * Updates the list object at path `path`, deleting `deletions` list elements starting from
     * list index `start`, and inserting the list of new elements `insertions` at that position.
     */
    func spice<T>(path: [KeyPathElement], start: Int, deletions: Int, insertions: [T]) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        let list = object[LIST_VALUES] as! [Any]
        if (start < 0 || deletions < 0 || start > list.count - deletions) {
            fatalError("\(deletions) deletions starting at index \(start) are out of bounds for list of length \(list.count)")
        }
        if deletions == 0 && insertions.count == 0 {
            return
        }
        let patch = Patch(clock: [:], version: 0, diffs: ObjectDiff(objectId: ROOT_ID, type: .map))
        let subPatch = getSubpatch(patch: patch, path: path)
        if subPatch.edits == nil {
            subPatch.edits = []
        }
        if deletions > 0 {
            (0..<deletions).forEach({ _ in
                ops.append(Op(action: .del, obj: objectId, key: .index(start)))
                subPatch.edits?.append(Edit(action: .remove, index: start))
            })
        }
        if insertions.count > 0 {
            insertListItems(subPatch: subPatch, index: start, values: insertions, newObject: false)
        }
        cache[ROOT_ID] = applyPatch(patch.diffs, cache[ROOT_ID]!, &updated)
        updated[ROOT_ID] = cache[ROOT_ID]

    }
//    splice(path, start, deletions, insertions) {
//      const objectId = path.length === 0 ? ROOT_ID : path[path.length - 1].objectId
//      let list = this.getObject(objectId)
//      if (start < 0 || deletions < 0 || start > list.length - deletions) {
//        throw new RangeError()
//      }
//      if (deletions === 0 && insertions.length === 0) return
//
//      let patch = {diffs: {objectId: ROOT_ID, type: 'map'}}
//      let subpatch = this.getSubpatch(patch, path)
//      if (!subpatch.edits) subpatch.edits = []
//
//      if (deletions > 0) {
//        for (let i = 0; i < deletions; i++) {
//          this.addOp({action: 'del', obj: objectId, key: start})
//          subpatch.edits.push({action: 'remove', index: start})
//        }
//      }
//
//      if (insertions.length > 0) {
//        this.insertListItems(subpatch, start, insertions, false)
//      }
//      this.applyPatch(patch.diffs, this.cache[ROOT_ID], this.updated)
//    }

    /**
     * Updates the map object at path `path`, setting the property with name
     * `key` to `value`.
     */

    func setMapKey<T>(path: [KeyPathElement], key: String, value: T) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        if object[key] is Counter {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        // If the assigned field value is the same as the existing value, and
        // the assignment does not resolve a conflict, do nothing
        applyAt(path: path, callback: { subpatch in
            let valuePatch = setValue(objectId: objectId, key: .string(key), value: value, insert: nil)
            subpatch.props?[.string(key)] = [actorId.uuidString: valuePatch]
        })

    }

    /**
     * Updates the map object at path `path`, setting the property with name
     * `key` to `value`.
     */

    func setMapKey<T: Equatable>(path: [KeyPathElement], key: String, value: T) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        if object[key] is Counter {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        // If the assigned field value is the same as the existing value, and
        // the assignment does not resolve a conflict, do nothing
        if (object[key] as? T) != value {
            applyAt(path: path, callback: { subpatch in
                let valuePatch = setValue(objectId: objectId, key: .string(key), value: value, insert: nil)
                subpatch.props?[.string(key)] = [actorId.uuidString: valuePatch]
            })
        } else if (object[CONFLICTS] as? [String: [Any]])?[key]?.count ?? 0 > 1 {
            fatalError()
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
     * Returns the value associated with the property named `key` on the object
     * at path `path`. If the value is an object, returns a proxy for it.
     */
    func getObjectField(path: [KeyPathElement], objectId: String, key: Key) -> Any? {
        let object = getObject(objectId: objectId)
        switch key {
        case .index(let index):
            fatalError()
        case .string(let string):
            return object[string]
        }
    }
//    getObjectField(path, objectId, key) {
//      if (!['string', 'number'].includes(typeof key)) return
//      const object = this.getObject(objectId)
//
//      if (object[key] instanceof Counter) {
//        return getWriteableCounter(object[key].value, this, path, objectId, key)
//
//      } else if (isObject(object[key])) {
//        const childId = object[key][OBJECT_ID]
//        const subpath = path.concat([{key, objectId: childId}])
//        // The instantiateObject function is added to the context object by rootObjectProxy()
//        return this.instantiateObject(subpath, childId)
//
//      } else {
//        return object[key]
//      }
//    }


    /**
     * Takes a value and returns an object describing the value (in the format used by patches).
     */
    private func getValueDescription(value: Any) -> Diff {
        switch value {
        case let double as Double:
            return .value(.init(value: .number(double)))
        case let int as Int:
            return .value(.init(value: .number(Double(int))))
        case let date as Date:
            return .value(.init(value: .number(date.timeIntervalSince1970), datatype: .timestamp))
        case let counter as Counter:
            return .value(.init(value: .number(counter.value), datatype: .counter))
        case is NSNull:
            return .value(.init(value: .null))
        case let object as [String : Any]:
            guard let objectId = object[OBJECT_ID] as? String else {
                fatalError("Object \(value) has no objectId")
            }
            return .object(.init(objectId: objectId, type: getObjectType(objectId: objectId), edits: nil, props: nil))

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
     * Returns a string that is either 'map', 'table', 'list', or 'text', indicating
     * the type of the object with ID `objectId`.
     */
    private func getObjectType(objectId: String) -> CollectionType {
        if objectId == ROOT_ID {
            return .map
        }
        let object = getObject(objectId: objectId)
        if object[LIST_VALUES] != nil {
            return .list
        } else if object[TABLE_VALUES] != nil{
            return .table
        } else {
            return .map
        }
    }
    //    getObjectType(objectId) {
    //      if (objectId === ROOT_ID) return 'map'
    //      const object = this.getObject(objectId)
    //      if (object instanceof Text) return 'text'
    //      if (object instanceof Table) return 'table'
    //      if (Array.isArray(object)) return 'list'
    //      return 'map'
    //    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    private func getList(objectId: String) -> [Any] {
        guard let object = (updated[objectId] ?? cache[objectId]) else {
            fatalError("Target object does not exist: \(objectId)")
        }
        return object[LIST_VALUES] as! [Any]
    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    func getObject(objectId: String) -> [String: Any] {
        let updatedObject = updated[objectId]
        let cachedObject = cache[objectId]
        guard let object = updatedObject ?? cachedObject else {
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
        cache[ROOT_ID] = applyPatch(patch.diffs, cache[ROOT_ID], &updated)
        updated[ROOT_ID] = cache[ROOT_ID]
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
        var object: Any = getObject(objectId: ROOT_ID)
        for pathElem in path {
            guard case .string(let key) = pathElem.key else {
                fatalError()
            }
            if subPatch.props == nil {
                subPatch.props = [:]
            }
            if subPatch.props?[pathElem.key] == nil {
                subPatch.props?[pathElem.key] = getValuesDescriptions(path: path, object: object, key: key)
            }
            var nextOpId: String?
            let values = subPatch.props![pathElem.key]!
            for opId in values.keys {
                if case .object(let object) = values[opId]!, object.objectId == pathElem.objectId {
                    nextOpId = opId
                }
            }
            guard let nextOpId2 = nextOpId, case .object(let objectDiff) = values[nextOpId2] else {
                fatalError("Cannot find path object with objectId \(pathElem.objectId)")
            }
            subPatch = objectDiff
            object = getPropertyValue(object: object, key: key, opId: nextOpId2)

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
//          throw new RangeError(`Cannot find path object with objectId ${pathElem.objectId}`)
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
        switch object {
        case let table as Table:
            fatalError()
        case let object as [String: Any]:
            return ((object[CONFLICTS] as! [Key: Any])[.string(key)] as! [String: Any])[opId]
        default:
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
    func getValuesDescriptions(path: [KeyPathElement], object: Any, key: String) -> [String: Diff] {
        switch object {
        case is Table:
            fatalError()
        case let map as [String: Any]:
            guard let conflicts = (map[CONFLICTS] as? [Key: Any])?[.string(key)] else {
                fatalError("No children at key \(key) of path \(path)")
            }
            let typedConflicts = conflicts as! [String: Any]
            var values = [String: Diff]()
            for opId in typedConflicts.keys {
                values[opId] = getValueDescription(value: typedConflicts[opId]!)
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

    /**
     * Updates the list object at path `path`, replacing the current value at
     * position `index` with the new value `value`.
     */
    func setListIndexpath<T: Equatable>(path: [KeyPathElement], index: Int, value: T) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        let list = object[LIST_VALUES] as! [Any]
        if index == list.count {
            fatalError()
        }
        precondition(!(list[index] is Counter), "Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        if (list[index] as? T) != value {
            applyAt(path: path) { subpatch in
                let valuePatch = setValue(objectId: objectId, key: .index(index), value: value, insert: nil)
                subpatch.props?[.index(index)] = [actorId.uuidString: valuePatch]
            }
        }

    }
//    setListIndex(path, index, value) {
//      const objectId = path.length === 0 ? ROOT_ID : path[path.length - 1].objectId
//      const list = this.getObject(objectId)
//      if (index === list.length) {
//        return this.splice(path, index, 0, [value])
//      }
//      if (index < 0 || index > list.length) {
//        throw new RangeError(`List index ${index} is out of bounds for list of length ${list.length}`)
//      }
//      if (list[index] instanceof Counter) {
//        throw new RangeError('Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.')
//      }
//
//      // If the assigned list element value is the same as the existing value, and
//      // the assignment does not resolve a conflict, do nothing
//      if (list[index] !== value || Object.keys(list[CONFLICTS][index] || {}).length > 1 || value === undefined) {
//        this.applyAtPath(path, subpatch => {
//          const valuePatch = this.setValue(objectId, index, value, false)
//          subpatch.props[index] = {[this.actorId]: valuePatch}
//        })
//      }
//    }

    /**
    * Updates the table object at path `path`, adding a new entry `row`.
    * Returns the objectId of the new row.
    */
    func addTableRow(path: [KeyPathElement], row: [String: Any]) -> String {
        precondition(row[OBJECT_ID] == nil, "Cannot reuse an existing object as table row")
        precondition(row["id"] == nil, "A table row must not have an id property; it is generated automatically")

        let valuePatch = setValue(objectId: path[path.count - 1].objectId, key: nil, value: row)
        applyAt(path: path) { subpatch in
            subpatch.props?[.string(valuePatch.objectId!)] = [valuePatch.objectId!: valuePatch]
        }

        return valuePatch.objectId!
    }


//    addTableRow(path, row) {
//      if (!isObject(row) || Array.isArray(row)) {
//        throw new TypeError('A table row must be an object')
//      }
//      if (row[OBJECT_ID]) {
//        throw new TypeError('Cannot reuse an existing object as table row')
//      }
//      if (row.id) {
//        throw new TypeError('A table row must not have an "id" property; it is generated automatically')
//      }
//
//      const valuePatch = this.setValue(path[path.length - 1].objectId, null, row, false)
//      this.applyAtPath(path, subpatch => {
//        subpatch.props[valuePatch.objectId] = {[valuePatch.objectId]: valuePatch}
//      })
//      return valuePatch.objectId
//    }

    /**
     * Updates the table object at path `path`, deleting the row with ID `rowId`.
     */
    func deleteTableRow(path: [KeyPathElement], rowId: UUID) {
        let objectId =  path[path.count - 1].objectId
        let table = getObject(objectId: objectId)
        fatalError()
    }
//    deleteTableRow(path, rowId) {
//      const objectId = path[path.length - 1].objectId, table = this.getObject(objectId)
//
//      if (table.byId(rowId)) {
//        this.addOp({action: 'del', obj: objectId, key: rowId})
//        this.applyAtPath(path, subpatch => {
//          subpatch.props[rowId] = {}
//        })
//      }
//    }

}
