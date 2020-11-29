//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

final class Context {

    struct KeyPathElement: Equatable {
        let key: Key
        let objectId: String
    }

    convenience init(cache: [String: [String: Any]], actorId: Actor) {
        self.init(actorId: actorId, applyPatch: interpretPatch, updated: [String: [String: Any]](), cache: cache, ops: [])
    }

    init(actorId: Actor,
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
        self.dateFormatter = EncoderDateFormatter()
    }

    private let actorId: Actor
    private let applyPatch: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]?
    private(set) var updated: [String: [String: Any]]
    private var cache: [String: [String: Any]]
    private let dateFormatter: EncoderDateFormatter

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
    func setValue<T>(objectId: String, key: Key?, value: T, insert: Bool) -> Diff {
        switch value {
        case let number as NSNumber:
            switch CFNumberGetType(number) {
            case .intType, .sInt8Type, .sInt16Type, .sInt32Type, .sInt64Type:
                let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .int(number.intValue))
                ops.append(operation)
                return .value(.int(number.intValue))
            case .charType:
                let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .bool(number.boolValue))
                ops.append(operation)
                return .value(.bool(number.boolValue))
            case .floatType, .float32Type, .float64Type, .cgFloatType:
                let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .double(number.doubleValue))
                ops.append(operation)
                return .value(.double(number.doubleValue))
            default:
                fatalError("Unsuported")
            }
        case let bool as Bool:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .bool(bool))
            ops.append(operation)
            return .value(.bool(bool))
        case  let value as Int:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .int(value))
            ops.append(operation)
            return .value(.int(value))
        case  let value as Double:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .double(value))
            ops.append(operation)
            return .value(.double(value))
        case let string as String:
            if string.starts(with: "_am_date:"), let date = EncoderDateFormatter().date(from: string) {
                let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .double(date.timeIntervalSince1970), datatype: .timestamp)
                ops.append(operation)
                return .value(.init(value: .double(date.timeIntervalSince1970), datatype: .timestamp))
            } else {
                let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .string(string))
                ops.append(operation)
                return .value(.string(string))
            }
        case let uuid as UUID:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .string(uuid.uuidString))
            ops.append(operation)
            return .value(.string(uuid.uuidString))
        case let character as Character:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .string(String(character)))
            ops.append(operation)
            return .value(.string(String(character)))
        case let date as Date:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .double(date.timeIntervalSince1970), datatype: .timestamp)
            ops.append(operation)
            return .value(.init(value: .double(date.timeIntervalSince1970), datatype: .timestamp))
        case let couter as Counter:
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .int(couter.value), datatype: .counter)
            ops.append(operation)
            return .value(.init(value: .int(couter.value), datatype: .counter))
        case let object as [String: Any]:
            return setValue(objectId: objectId, key: key, object: object, insert: insert)
        case let array as [Any]:
            return .object(createNestedObjects(obj: objectId, key: key, value: array, insert: insert))
        case is Optional<Any>:
            let operation = Op(action: .del, obj: objectId, key: key!, insert: insert)
            ops.append(operation)
            return .value(.null)
        default:
            fatalError()
        }
    }

    func setValue(objectId: String, key: Key?, object: [String: Any], insert: Bool) -> Diff {
        if let counterValue = object[COUNTER_VALUE] as? Int {
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .int(counterValue), datatype: .counter)
            ops.append(operation)
            return .value(.init(value: .int(counterValue), datatype: .counter))
        } else {
            return .object(createNestedObjects(obj: objectId, key: key, value: object, insert: insert))
        }
    }

    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    private func createNestedObjects(obj: String, key: Key?, value: Any, insert: Bool) -> ObjectDiff {
        let child = UUID().uuidString
        let key = key ?? .string(child)
        switch value {
        case let object as [String: Any]:
            precondition(object[OBJECT_ID] == nil, "Cannot create a reference to an existing document object")
            if object[ISTEXT] != nil, let elms = object[LIST_VALUES] as? [String]  {
                let operation = Op(action: .makeText, obj: obj, key: key, insert: insert, child: child)
                ops.append(operation)
                let subpatch = ObjectDiff(objectId: child, type: .text, edits: [], props: [:])
                insertListItems(subPatch: subpatch, index: 0, values: elms, newObject: true)

                return subpatch
            }

            if object[TABLE_VALUES] != nil {
                let operation = Op(action: .makeTable, obj: obj, key: key, insert: insert, child: child)
                ops.append(operation)
                let subpatch = ObjectDiff(objectId: child, type: .table, props: [:])

                return subpatch
            }

            let operation = Op(action: .makeMap, obj: obj, key: key, insert: insert, child: child)
            ops.append(operation)

            var props = Props()
            for nested in object.keys.sorted() {
                let valuePatch = setValue(objectId: child, key: .string(nested), value: object[nested], insert: false)
                props[.string(nested)] = [actorId.actorId: valuePatch]
            }

            return ObjectDiff(objectId: child, type: .map, props: props)
        case let array as Array<Any>:
            let operation = Op(action: .makeList, obj: obj, key: key, insert: insert, child: child)
            ops.append(operation)
            let subpatch = ObjectDiff(objectId: child, type: .list, edits: [], props: [:])
            insertListItems(subPatch: subpatch, index: 0, values: array, newObject: true)

            return subpatch

        default:
            fatalError()
        }
    }

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
            subPatch.props?[.index(index + offset)] = [actorId.actorId: valuePatch]
        })
    }

    /**
     * Updates the list object at path `path`, deleting `deletions` list elements starting from
     * list index `start`, and inserting the list of new elements `insertions` at that position.
     */
    func splice<T>(path: [KeyPathElement], start: Int, deletions: Int, insertions: [T]) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        let list = object[LIST_VALUES] as! [Any]
        if (start < 0 || deletions < 0 || start > list.count - deletions) {
            fatalError("\(deletions) deletions starting at index \(start) are out of bounds for list of length \(list.count)")
        }
        if deletions == 0 && insertions.count == 0 {
            return
        }
        let patch = Patch(clock: [:], version: 0, canUndo: false, canRedo: false, diffs: ObjectDiff(objectId: ROOT_ID, type: .map))
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
            let valuePatch = setValue(objectId: objectId, key: .string(key), value: value, insert: false)
            subpatch.props?[.string(key)] = [actorId.actorId: valuePatch]
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
                let valuePatch = setValue(objectId: objectId, key: .string(key), value: value, insert: false)
                subpatch.props?[.string(key)] = [actorId.actorId: valuePatch]
            })
        } else if (object[CONFLICTS] as? [String: [Any]])?[key]?.count ?? 0 > 1 {
            fatalError()
        }

    }


    /**
     * Takes a value and returns an object describing the value (in the format used by patches).
     */
    private func getValueDescription(value: Any) -> Diff {
        switch value {
        case let int as Int:
            return .value(.init(value: .int(int)))
        case let double as Double:
            return .value(.init(value: .double(double)))
        case let date as Date:
            return .value(.init(value: .double(date.timeIntervalSince1970), datatype: .timestamp))
        case let counter as Counter:
            return .value(.init(value: .int(counter.value), datatype: .counter))
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
            return object[ISTEXT] == nil ? .list : .text
        } else if object[TABLE_VALUES] != nil{
            return .table
        } else {
            return .map
        }
    }

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

    /**
     * Constructs a new patch, calls `callback` with the subpatch at the location `path`,
     * and then immediately applies the patch to the document.
     */
    func applyAt(path: [KeyPathElement], callback: (ObjectDiff) -> Void) {
        let patch = Patch(clock: [:], version: 0, canUndo: false, canRedo: false, diffs: ObjectDiff(objectId: ROOT_ID, type: .map))
        callback(getSubpatch(patch: patch, path: path))
        cache[ROOT_ID] = applyPatch(patch.diffs, cache[ROOT_ID], &updated)
        updated[ROOT_ID] = cache[ROOT_ID]
    }

    /**
     * Recurses along `path` into the patch object `patch`, creating nodes along the way as needed
     * by mutating the patch object. Returns the subpatch at the given path.
     */
    func getSubpatch(patch: Patch, path: [KeyPathElement]) -> ObjectDiff {
        var subPatch = patch.diffs
        var object: [String: Any] = getObject(objectId: ROOT_ID)
        for pathElem in path {
            if subPatch.props == nil {
                subPatch.props = [:]
            }
            if subPatch.props?[pathElem.key] == nil {
                subPatch.props?[pathElem.key] = getValuesDescriptions(path: path, object: object, key: pathElem.key)
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
            object = getPropertyValue(object: object, key: pathElem.key, opId: nextOpId2)

        }
        if subPatch.props == nil {
            subPatch.props = [:]
        }

        return subPatch
    }

    /**
     * Returns the value at property `key` of object `object`. In the case of a conflict, returns
     * the value whose assignment operation has the ID `opId`.
     */
    func getPropertyValue(object: [String: Any], key: Key, opId: String) -> [String: Any] {
        if object[TABLE_VALUES] != nil {
            guard case .string(let stringKey) = key,
               let entries = object[TABLE_VALUES] as? [String: [String: Any]],
               let value = entries[stringKey] else {
                fatalError()
            }
            return value
        } else {
            return ((object[CONFLICTS] as! [Key: Any])[key] as! [String: Any])[opId] as! [String: Any]
        }
    }

    /**
     * Builds the values structure describing a single property in a patch. Finds all the values of
     * property `key` of `object` (there might be multiple values in the case of a conflict), and
     * returns an object that maps operation IDs to descriptions of values.
     */
    func getValuesDescriptions(path: [KeyPathElement], object: [String: Any], key: Key) -> [String: Diff] {
        if object[TABLE_VALUES] != nil {
            // Table objects don't have conflicts, since rows are identified by their unique objectId
            if case .string(let stringKey) = key, let entries = object[TABLE_VALUES] as? [String: [String: Any]], let value = entries[stringKey] {
                return [stringKey: getValueDescription(value: value)]
            } else {
                return [:]
            }
        } else {
            guard let conflicts = (object[CONFLICTS] as?[Key: Any])?[key] else {
                fatalError("No children at key \(key) of path \(path)")
            }
            let typedConflicts = conflicts as! [String: Any]
            var values = [String: Diff]()
            for opId in typedConflicts.keys {
                values[opId] = getValueDescription(value: typedConflicts[opId]!)
            }

            return values
        }
    }

    /**
     * Updates the list object at path `path`, replacing the current value at
     * position `index` with the new value `value`.
     */
    func setListIndex<T>(path: [KeyPathElement], index: Int, value: T) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        let list = object[LIST_VALUES] as! [Any]
        if index == list.count {
            splice(path: path, start: index, deletions: 0, insertions: [value])
            return
        }
        precondition(!(list[index] is Counter), "Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        applyAt(path: path) { subpatch in
            let valuePatch = setValue(objectId: objectId, key: .index(index), value: value, insert: false)
            subpatch.props?[.index(index)] = [actorId.actorId: valuePatch]
        }

    }

    /**
     * Updates the table object at path `path`, adding a new entry `row`.
     * Returns the objectId of the new row.
     */
    func addTableRow(path: [KeyPathElement], row: [String: Any]) -> String {
        precondition(row[OBJECT_ID] == nil, "Cannot reuse an existing object as table row")
        precondition(row["id"] == nil, "A table row must not have an id property; it is generated automatically")

        let valuePatch = setValue(objectId: path[path.count - 1].objectId, key: nil, value: row, insert: false)
        applyAt(path: path) { subpatch in
            subpatch.props?[.string(valuePatch.objectId!)] = [valuePatch.objectId!: valuePatch]
        }

        return valuePatch.objectId!
    }

    /**
     * Updates the table object at path `path`, deleting the row with ID `rowId`.
     */
    func deleteTableRow(path: [KeyPathElement], rowId: String) {
        let objectId =  path[path.count - 1].objectId
        let table = getObject(objectId: objectId)
        guard let entries = table[TABLE_VALUES] as? [String: Any] else {
            fatalError()
        }
        if entries[rowId] != nil {
            ops.append(Op(action: .del, obj: objectId, key: .string(rowId)))
            applyAt(path: path, callback: { subpatch in
                subpatch.props?[.string(rowId)] = [:]
            })
        }
    }

    /**
     * Adds the integer `delta` to the value of the counter located at property
     * `key` in the object at path `path`.
     */
    func increment(path: [KeyPathElement], key: Key, delta: Int) {
        let objectId = path.count == 0 ? ROOT_ID : path[path.count - 1].objectId
        let object = getObject(objectId: objectId)
        let counterValue: Int
        switch key {
        case .string(let key):
            if case .int(let value) = (object[key] as! [String: Primitive])[COUNTER_VALUE]! {
                counterValue = value
            } else if case .double(let value) = (object[key] as! [String: Primitive])[COUNTER_VALUE]! {
                counterValue = Int(value)
            }else {
                fatalError()
            }
        case .index(let index):
            if let list = object[LIST_VALUES] as? [[String: Primitive]], case .int(let value) = list[index][COUNTER_VALUE]! {
                counterValue = value
            } else if let list = object[LIST_VALUES] as? [[String: Primitive]], case .double(let value) = list[index][COUNTER_VALUE]! {
                counterValue = Int(value)
            } else {
                fatalError()
            }
        }
        // TODO what if there is a conflicting value on the same key as the counter?
        ops.append(Op(action: .inc, obj: objectId, key: key, value: .int(delta)))
        applyAt(path: path, callback: { subpatch in
            subpatch.props?[key] = [actorId.actorId: .value(.init(value: .int(counterValue + delta), datatype: .counter))]
        })
    }

}
