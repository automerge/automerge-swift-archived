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

    convenience init(cache: [String: Object], actorId: Actor) {
        self.init(actorId: actorId, applyPatch: interpretPatch2, updated: [String: Object](), cache: cache, ops: [])
    }

    init(actorId: Actor,
         applyPatch: @escaping (ObjectDiff, Object?, inout [String: Object]) -> Object?,
         updated: [String: Object],
         cache: [String: Object],
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
    private let applyPatch: (ObjectDiff, Object?, inout [String:Object]) -> Object?
    private(set) var updated: [String: Object]
    private var cache: [String: Object]
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
    func setValue(objectId: String, key: Key?, value: Object, insert: Bool) -> Diff {
        switch value {
        case .primitive(let primitive):
            let operation: Op
            if case .null = primitive {
                operation = Op(action: .del, obj: objectId, key: key!, insert: insert)
            } else {
                operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: primitive)
            }
            ops.append(operation)
            return .value(primitive)
        case .map(let map):
            return .object(createNestedMap(obj: objectId, key: key, map: map, insert: insert))
        case .list(let list):
            return .object(createNestedList(obj: objectId, key: key, list: list, insert: insert))
        case .text(let text):
            return .object(createNestedText(obj: objectId, key: key, text: text, insert: insert))
        case .table:
            return .object(createNestedTable(obj: objectId, key: key, insert: insert))
        case .date(let date):
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .number(date.timeIntervalSince1970), datatype: .timestamp)
            ops.append(operation)
            return .value(.init(value: .number(date.timeIntervalSince1970), datatype: .timestamp))
        case .counter(let counter):
            let operation = Op(action: .set, obj: objectId, key: key!, insert: insert, value: .number(Double(counter.value)), datatype: .counter)
            ops.append(operation)
            return .value(.init(value: .number(Double(counter.value)), datatype: .counter))
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
    private func createNestedMap(obj: String, key: Key?, map: Map, insert: Bool) -> ObjectDiff {
        let child = UUID().uuidString
        let key = key ?? .string(child)
        let operation = Op(action: .makeMap, obj: obj, key: key, insert: insert, child: child)
        ops.append(operation)

        var props = Props()
        for nested in map.mapValues.keys.sorted() {
            let valuePatch = setValue(objectId: child, key: .string(nested), value: map[nested]!, insert: false)
            props[.string(nested)] = [actorId.actorId: valuePatch]
        }

        return ObjectDiff(objectId: child, type: .map, props: props)
    }

    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    private func createNestedList(obj: String, key: Key?, list: List, insert: Bool) -> ObjectDiff {
        let child = UUID().uuidString
        let key = key ?? .string(child)

        let operation = Op(action: .makeList, obj: obj, key: key, insert: insert, child: child)
        ops.append(operation)
        let subpatch = ObjectDiff(objectId: child, type: .list, edits: [], props: [:])
        insertListItems(subPatch: subpatch, index: 0, values: list.listValues, newObject: true)

        return subpatch
    }

    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    private func createNestedText(obj: String, key: Key?, text: TextObj, insert: Bool) -> ObjectDiff {
        let child = UUID().uuidString
        let key = key ?? .string(child)

        let elems: [Object] = text.characters.map { .primitive(.string($0.value)) }
        let operation = Op(action: .makeText, obj: obj, key: key, insert: insert, child: child)
        ops.append(operation)
        let subpatch = ObjectDiff(objectId: child, type: .text, edits: [], props: [:])
        insertListItems(subPatch: subpatch, index: 0, values: elems, newObject: true)

        return subpatch
    }


    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    private func createNestedTable(obj: String, key: Key?, insert: Bool) -> ObjectDiff {
        let child = UUID().uuidString
        let key = key ?? .string(child)
        let operation = Op(action: .makeTable, obj: obj, key: key, insert: insert, child: child)
        ops.append(operation)
        let subpatch = ObjectDiff(objectId: child, type: .table, props: [:])

        return subpatch
    }

    /**
     * Inserts a sequence of new list elements `values` into a list, starting at position `index`.
     * `newObject` is true if we are creating a new list object, and false if we are updating an
     * existing one. `subpatch` is the patch for the list object being modified. Mutates
     * `subpatch` to reflect the sequence of values.
     */
    func insertListItems(subPatch: ObjectDiff, index: Int, values: [Object], newObject: Bool) {
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
    func splice(path: [KeyPathElement], start: Int, deletions: Int, insertions: [Object]) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        guard case .list(let listObj) = getObject(objectId: objectId) else {
            fatalError("Must be a list")
        }
        let list = listObj.listValues
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
    func setMapKey(path: [KeyPathElement], key: String, value: Object) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        guard case .map(let map) = getObject(objectId: objectId) else {
            fatalError("Must be Map")
        }
        if case .counter = map[key] {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        // If the assigned field value is the same as the existing value, and
        // the assignment does not resolve a conflict, do nothing

        if map[key] != value {
            applyAt(path: path, callback: { subpatch in
                let valuePatch = setValue(objectId: objectId, key: .string(key), value: value, insert: false)
                subpatch.props?[.string(key)] = [actorId.actorId: valuePatch]
            })
        } else if map.conflicts[key]?.count ?? 0 > 1 {
            fatalError()
        }
    }


    /**
     * Takes a value and returns an object describing the value (in the format used by patches).
     */
    private func getValueDescription(value: Object) -> Diff {
        switch value {
        case .map(let map):
            return .object(.init(objectId: map.objectId, type: .map))
        case .list(let list):
            return .object(.init(objectId: list.objectId, type: .list))
        case .table(let table):
            return .object(.init(objectId: table.objectId!, type: .table))
        case .primitive(let primitive):
            return .value(primitive)
        case .counter(let counter):
            return .value(.init(value: .number(Double(counter.value)), datatype: .counter))
        case .date(let date):
            return .value(.init(value: .number(date.timeIntervalSince1970), datatype: .timestamp))
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
        switch object {
        case .list:
            return .list
        case .map:
            return .map
        case .table:
            return .table
        case .text:
            return .text
        case .counter, .primitive, .date:
            fatalError()
        }
    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    private func getList(objectId: String) -> [Any] {
        guard case .list(let list) = (updated[objectId] ?? cache[objectId]) else {
            fatalError("Target object does not exist: \(objectId)")
        }
        return list.listValues
    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    func getObject(objectId: String) -> Object {
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
        let subPatch = getSubpatch(patch: patch, path: path)
        callback(subPatch)
        cache[ROOT_ID] = applyPatch(patch.diffs, cache[ROOT_ID], &updated)
        updated[ROOT_ID] = cache[ROOT_ID]
    }

    /**
     * Recurses along `path` into the patch object `patch`, creating nodes along the way as needed
     * by mutating the patch object. Returns the subpatch at the given path.
     */
    func getSubpatch(patch: Patch, path: [KeyPathElement]) -> ObjectDiff {
        var subPatch = patch.diffs
        var object = getObject(objectId: ROOT_ID)
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
            guard let nextOpId2 = nextOpId, case .object(let objectDiff) = values[nextOpId2]  else {
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
    func getPropertyValue(object: Object, key: Key, opId: String) -> Object {
        switch (object, key) {
        case (.table(let table), .string(let key)):
            return table.entries[key]!
        case (.map(let map), .string(let key)):
            return map.conflicts[key]![opId]!
        case (.list(let list), .index(let index)):
            return list.conflicts[index][opId]!
        default:
        fatalError()
        }
    }

    /**
     * Builds the values structure describing a single property in a patch. Finds all the values of
     * property `key` of `object` (there might be multiple values in the case of a conflict), and
     * returns an object that maps operation IDs to descriptions of values.
     */
    func getValuesDescriptions(path: [KeyPathElement], object: Object, key: Key) -> [String: Diff] {
        switch (object, key) {
        case (.table(let table), .string(let key)):
            if let value = table.entries[key]  {
                return [key: getValueDescription(value: value)]
            } else {
                return [:]
            }
        case (.map(let map), .string(let key)):
            let conflict = map.conflicts[key]!
            var values = [String: Diff]()
            for opId in conflict.keys {
                values[opId] = getValueDescription(value: conflict[opId]!)
            }

            return values
        case (.list(let list), .index(let index)):
            let conflict = list.conflicts[index]
            var values = [String: Diff]()
            for opId in conflict.keys {
                values[opId] = getValueDescription(value: conflict[opId]!)
            }

            return values
        default:
            fatalError()
        }
    }

    /**
     * Updates the list object at path `path`, replacing the current value at
     * position `index` with the new value `value`.
     */
    func setListIndex(path: [KeyPathElement], index: Int, value: Object) {
        let objectId = path.isEmpty ? ROOT_ID : path[path.count - 1].objectId
        guard case .list(let list) = getObject(objectId: objectId) else {
            fatalError("Must be a list")
        }
        if index == list.count {
            splice(path: path, start: index, deletions: 0, insertions: [value])
            return
        }
        if case .counter = list[index] {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        applyAt(path: path) { subpatch in
            let valuePatch = setValue(objectId: objectId, key: .index(index), value: value, insert: false)
            subpatch.props?[.index(index)] = [actorId.actorId: valuePatch]
        }

    }

    /**
     * Updates the table object at path `path`, adding a new entry `row`.
     * Returns the objectId of the new row.
     */
    func addTableRow(path: [KeyPathElement], row: Object) -> String {
        precondition(row.objectId == "", "Cannot reuse an existing object as table row")

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
        guard case .table(let table) = getObject(objectId: objectId) else {
            fatalError()
        }
        if table.entries[rowId] != nil {
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
            if  case .map(let map) = object,
                case .counter(let counter) = map[key] {
                counterValue = counter.value
            } else {
                fatalError()
            }
        case .index(let index):
            if case .list(let list) = object,
               case .counter(let counter) = list.listValues[index] {
                counterValue = counter.value
            } else {
                fatalError()
            }
        }
        // TODO what if there is a conflicting value on the same key as the counter?
        ops.append(Op(action: .inc, obj: objectId, key: key, value: .number(Double(delta))))
        applyAt(path: path, callback: { subpatch in
            subpatch.props?[key] = [actorId.actorId: .value(.init(value: .number(Double(counterValue + delta)), datatype: .counter))]
        })
    }

}
