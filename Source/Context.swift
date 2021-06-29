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
        let objectId: ObjectId?
    }

    convenience init(cache: [ObjectId: Object], actorId: Actor, maxOp: Int) {
        self.init(
            actorId: actorId,
            applyPatch: interpretPatch,
            updated: [:],
            cache: cache,
            ops: [],
            maxOp: maxOp
        )
    }

    init(
        actorId: Actor,
        applyPatch: @escaping (MapDiff, Object?, inout [ObjectId: Object]) -> Object?,
        updated: [ObjectId: Object],
        cache: [ObjectId: Object],
        ops: [Op] = [],
        maxOp: Int
    ) {
        self.actorId = actorId
        self.applyPatch = applyPatch
        self.updated = updated
        self.cache = cache
        self.ops = ops
        self.maxOp = maxOp
    }

    private let actorId: Actor
    private let maxOp: Int
    private let applyPatch: (MapDiff, Object?, inout [ObjectId: Object]) -> Object?
    private (set) var updated: [ObjectId: Object]
    private var cache: [ObjectId: Object]

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
    func setValue(objectId: ObjectId, key: Key?, value: Object, insert: Bool, pred: [ObjectId]?, elmId: ObjectId?) -> Diff {
        switch value {
        case .primitive(let primitive):
            let operation: Op
            if case .null = primitive {
                operation = Op(action: .del, obj: objectId, key: key, insert: insert, pred: pred)
            } else {
                if let elmId = elmId {
                    operation = Op(action: .set, obj: objectId, elemId: elmId, insert: insert, value: primitive, datatype: primitive.datatype, pred: pred)
                } else {
                    operation = Op(action: .set, obj: objectId, key: key, insert: insert, value: primitive, datatype: primitive.datatype, pred: pred)
                }
            }
            ops.append(operation)
            return .value(ValueDiff(value: primitive, datatype: primitive.datatype))
        case .map(let map):
            return .map(createNestedMap(obj: objectId, key: key, map: map, insert: insert, pred: pred, elmId: elmId))
        case .list(let list):
            return .list(createNestedList(obj: objectId, key: key, list: list, insert: insert, pred: pred, elemId: elmId))
        case .text(let text):
            return .list(createNestedText(obj: objectId, key: key, text: text, insert: insert, pred: pred, elemId: elmId))
        case .table:
            return .map(createNestedTable(obj: objectId, key: key, insert: insert, pred: pred, elemId: elmId))
        case .date(let date):
            let value = ValueDiff(date: date)
            if let elmId = elmId {
                ops.append(Op(action: .set, obj: objectId, elemId: elmId, insert: insert, value: value.value, datatype: .timestamp, pred: pred))
            } else {
                ops.append(Op(action: .set, obj: objectId, key: key, insert: insert, value: value.value, datatype: .timestamp, pred: pred))
            }
            return .value(value)
        case .counter(let counter):
            let value: Primitive = .int(counter.value)
            if let elmId = elmId {
                ops.append(Op(action: .set, obj: objectId, elemId: elmId, insert: insert, value: value, datatype: .counter, pred: pred))
            } else {
                ops.append(Op(action: .set, obj: objectId, key: key, insert: insert, value: value, datatype: .counter, pred: pred))
            }

            return .value(.init(value: value, datatype: .counter))
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
    private func createNestedMap(obj: ObjectId, key: Key?, map: Map, insert: Bool, pred: [ObjectId]?, elmId: ObjectId?) -> MapDiff {
        let objectId = nextOpId()
        if let elmId = elmId {
            ops.append(Op(action: .makeMap, obj: obj, elemId: elmId, insert: insert, pred: pred))
        } else {
            ops.append(Op(action: .makeMap, obj: obj, key: key, insert: insert, pred: pred))
        }


        var props = Props()
        for (nestedKey, value) in map {
            let opId = nextOpId()
            let valuePatch = setValue(objectId: objectId, key: .string(nestedKey), value: value, insert: false, pred: [], elmId: nil)
            props[nestedKey] = [opId: valuePatch]
        }

        return MapDiff(objectId: objectId, type: .map, props: props)
    }

    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    private func createNestedTable(obj: ObjectId, key: Key?, insert: Bool, pred: [ObjectId]?, elemId: ObjectId?) -> MapDiff {
        let objectId = nextOpId()
        if let elemId = elemId {
            ops.append(Op(action: .makeTable, obj: obj, elemId: elemId, insert: insert, pred: pred))
        } else {
            ops.append(Op(action: .makeTable, obj: obj, key: key, insert: insert, pred: pred))
        }

        return MapDiff(objectId: objectId, type: .table, props: [:])
    }

    /**
     * Recursively creates Automerge versions of all the objects and nested objects in `value`,
     * constructing a patch and operations that describe the object tree. The new object is
     * assigned to the property `key` in the object with ID `obj`. If `insert` is true, a new
     * list element is created at index `key`, and the new object is assigned to that list
     * element. If `key` is null, the ID of the new object is used as key (this construction
     * is used by Automerge.Table).
     */
    private func createNestedList(obj: ObjectId, key: Key?, list: List, insert: Bool, pred: [ObjectId]?, elemId: ObjectId?) -> ListDiff {
        let objectId = nextOpId()
        if let elemId = elemId {
            let operation = Op(action: .makeList, obj: obj, elemId: elemId, insert: insert, pred: pred)
            ops.append(operation)
        } else {
            let operation = Op(action: .makeList, obj: obj, key: key, insert: insert, pred: pred)
            ops.append(operation)
        }

        let subpatch = ListDiff(objectId: objectId, type: .list, edits: [])
        insertListItems(subPatch: subpatch, index: 0, values: list, newObject: true)

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
    private func createNestedText(obj: ObjectId, key: Key?, text: Text, insert: Bool, pred: [ObjectId]?, elemId: ObjectId?) -> ListDiff {
        let objectId = nextOpId()
        if let elemId = elemId {
            ops.append(Op(action: .makeText, obj: obj, elemId: elemId, insert: insert, pred: pred))
        } else {
            ops.append(Op(action: .makeText, obj: obj, key: key, insert: insert, pred: pred))
        }
        let elems: [Object] = text.content.map { $0.value }

        let subpatch = ListDiff(objectId: objectId, type: .text, edits: [])
        insertListItems(subPatch: subpatch, index: 0, values: elems, newObject: true)

        return subpatch
    }

    /// Returns the operation ID of the next operation to be added to the context.
    private func nextOpId() -> ObjectId {
        var numberOfOps = maxOp + 1
        for op in ops {
            if let values = op.values, op.action == .set {
                numberOfOps += values.count
            } else if let multiOp = op.multiOp, op.action == .del {
                numberOfOps += multiOp
            } else {
                numberOfOps += 1
            }

        }
        return "\(numberOfOps)@\(actorId.actorId)"
    }

    /**
     * Inserts a sequence of new list elements `values` into a list, starting at position `index`.
     * `newObject` is true if we are creating a new list object, and false if we are updating an
     * existing one. `subpatch` is the patch for the list object being modified. Mutates
     * `subpatch` to reflect the sequence of values.
     */
    func insertListItems<C: Collection>(subPatch: ListDiff, index: Int, values: C, newObject: Bool) where C.Element == Object {
        let list = newObject ? [] : getList(objectId: subPatch.objectId)
        precondition(index >= 0 && index <= list.count, "List index \(index) is out of bounds for list of length \(list.count)")

        var elmId = getElmId(list: getSaveObject(objectId: subPatch.objectId), index: index, insert: true)
        let primitives: [Primitive] = values.compactMap { value in
            if case .primitive(let primitive) = value {
                return primitive
            }
            return nil
        }

        if primitives.count == values.count && values.count > 1 {
            let nextElmId = nextOpId()
            ops.append(Op(action: .set, obj: subPatch.objectId, elemId: elmId, insert: true, values: primitives, pred: []))
            subPatch.edits.append(.multiInsert(MultiInsertEdit(index: index, elemId: nextElmId, values: primitives)))
        } else {
            for (offset, value) in values.enumerated() {
                let nextElemId = nextOpId()
                let valuePatch = setValue(objectId: subPatch.objectId, key: .index(index + offset), value: value, insert: true, pred: [], elmId: elmId)
                elmId = nextElemId
                subPatch.edits.append(.singleInsert(SingleInsertEdit(index: index + offset, elemId: elmId, opId: elmId, value: valuePatch)))
            }
        }
    }

    func getElmId(list: Object?, index: Int, insert: Bool = false) -> ObjectId {
        var index = index
        if insert {
            if (index == 0) {
                return .head
            }
            index -= 1
        }
        if case .list(let list)? = list {
            return list.elemIds[index]
        }
        if case .text(let text)? = list {
            return text.elemIds[index]
        }

        fatalError()
    }

    /**
     * Updates the list object at path `path`, deleting `deletions` list elements starting from
     * list index `start`, and inserting the list of new elements `insertions` at that position.
     */
    func splice(path: [KeyPathElement], start: Int, deletions: Int, insertions: [Object]) {
        guard let objectId = path.isEmpty ? .root : path[path.count - 1].objectId else {
            fatalError("objectId must exist")
        }

        let numberOfElements: Int
        let object = getObject(objectId: objectId)
        if case .list(let list) = object {
            numberOfElements = list.count
        } else if case .text(let text) = object {
            numberOfElements = text.content.count
        } else {
            fatalError("Must be a list or text")
        }
        if (start < 0 || deletions < 0 || start > numberOfElements - deletions) {
            fatalError("\(deletions) deletions starting at index \(start) are out of bounds for list of length \(numberOfElements)")
        }
        if deletions == 0 && insertions.count == 0 {
            return
        }
        let diff = MapDiff(objectId: .root, type: .map)
        var subPatch = getSubpatch(diff: diff, path: path)

        if deletions > 0 {
            var op: Op?
            var lastElemParsed: (counter: Int, actorId: String)?
            var lastPredParsed: (counter: Int, actorId: String)?
            (0..<deletions).forEach { i in
                #warning("Detect counter deletion and throw error ")

                // Any sequences of deletions with consecutive elemId and pred values get combined into a
                // single multiOp; any others become individual deletion operations. This optimisation only
                // kicks in if the user deletes a sequence of elements at once (in a single call to splice);
                // it might be nice to also detect such runs of deletions in the case where the user deletes
                // a sequence of list elements one by one.
                let thisElem = getElmId(list: object, index: start + i)
                let thisElemParsed = thisElem.parseOpId()
                let thisPred = getPred(object: object, key: .index(start + i))
                let thisPredParsed = (thisPred.count == 1 ? thisPred.first?.parseOpId() : nil)

                if op != nil,
                   let lastElemParsed = lastElemParsed,
                   let lastPredParsed = lastPredParsed,
                   let thisPredParsed = thisPredParsed,
                   lastElemParsed.actorId == thisElemParsed?.actorId &&
                    lastElemParsed.counter + 1 == thisElemParsed?.counter &&
                    lastPredParsed.actorId == thisPredParsed.actorId &&
                    lastPredParsed.counter + 1 == thisPredParsed.counter {
                    let multiOp = op?.multiOp ?? 1
                    op?.multiOp = (multiOp) + 1
                } else {
                    if let op = op {
                        ops.append(op)
                    }
                    op = Op(action: .del, obj: objectId, elemId: thisElem, insert: false, pred: thisPred)
                }
                lastElemParsed = thisElemParsed
                lastPredParsed = thisPredParsed
            }
            ops.append(op!)
            subPatch.edits.append(.remove(RemoveEdit(index: start, count: deletions)))
        }
        if case .list(let subPatch) = subPatch, insertions.count > 0 {
            insertListItems(subPatch: subPatch, index: start, values: insertions, newObject: false)
        }
        cache[.root] = applyPatch(diff, cache[.root], &updated)
    }

    /**
     * Updates the map object at path `path`, setting the property with name
     * `key` to `value`.
     */
    func setMapKey(path: [KeyPathElement], key: String, value: Object) {
        if case .primitive(.null) = value {
            deleteMapKey(path: path, key: key)
            return
        }
        guard let objectId = path.isEmpty ? .root : path[path.count - 1].objectId else {
            fatalError("objectId must exist")
        }
        let object = getObject(objectId: objectId)
        guard case .map(let map) = object else {
            fatalError("Must be Map")
        }
        if case .counter = map[key] {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        // If the assigned field value is the same as the existing value, and
        // the assignment does not resolve a conflict, do nothing

        if map[key] != value || map.conflicts[key]?.keys.count ?? 0 > 1 {
            applyAt(path: path, callback: { subpatch in
                let pred = getPred(object: object, key: .string(key))
                let opId = nextOpId()
                let valuePatch = setValue(objectId: objectId, key: .string(key), value: value, insert: false, pred: pred, elmId: nil)
                subpatch.props[key] = [opId: valuePatch]
            })
        } else if map.conflicts[key]?.count ?? 0 > 1 {
            fatalError()
        }
    }

    func getPred(object: Object, key: Key) -> [ObjectId] {
        switch (object, key) {
        case (.map(let map), .string(let key)):
            if let conflicts = map.conflicts[key]?.keys.sorted() {
                return Array(conflicts)
            } else {
                return []
            }
        case (.list(let list), .index(let index)):
            return list.conflicts[index].keys.sorted()
        case (.text(let text), .index(let index)):
            return text.content[index].pred
        default:
            fatalError()
        }
    }


    /// Updates the map object at path `path`, deleting the property `key`.
    private func deleteMapKey(path: [KeyPathElement], key: String) {
        guard let objectId = path.isEmpty ? .root : path[path.count - 1].objectId else {
            fatalError("objectId must exist")
        }
        let object = getObject(objectId: objectId)
        guard case .map(let map) = object else {
            fatalError("Must be Map")
        }

        if map[key] != nil {
            let pred = getPred(object: object, key: .string(key))
            ops.append(Op(action: .del, obj: objectId, key: .string(key), insert: false, pred: pred))
            applyAt(path: path, callback: { subpatch in
                subpatch.props[key] = [:]
            })
        }
      }

    /**
     * Takes a value and returns an object describing the value (in the format used by patches).
     */
    private func getValueDescription(value: Object) -> Diff {
        switch value {
        case .map(let map):
            return .map(MapDiff(objectId: map.objectId, type: .map))
        case .list(let list):
            return .list(ListDiff(objectId: list.objectId, type: .list))
        case .table(let table):
            return .map(MapDiff(objectId: table.objectId, type: .table))
        case .primitive(let primitive):
            return .value(ValueDiff(value: primitive, datatype: primitive.datatype))
        case .counter(let counter):
            return .value(.init(value: .int(counter.value), datatype: .counter))
        case .date(let date):
            return .value(ValueDiff(date: date))
        case .text(let text):
            return .list(ListDiff(objectId: text.objectId, type: .text))
        }
    }

    /**
     * Returns a string that is either 'map', 'table', 'list', or 'text', indicating
     * the type of the object with ID `objectId`.
     */
    private func getObjectType(objectId: ObjectId) -> CollectionType {
        if objectId == .root {
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
    private func getList(objectId: ObjectId) -> [Any] {
        let object = getObject(objectId: objectId)
        if case .list(let list) = object {
            return Array(list)
        } else if case .text(let text) = object {
            return text.content
        } else {
            fatalError("Target object does not exist: \(objectId)")
        }
    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    func getObject(objectId: ObjectId) -> Object {
        let updatedObject = updated[objectId]
        let cachedObject = cache[objectId]
        guard let object = updatedObject ?? cachedObject else {
            fatalError("Target object does not exist: \(objectId)")
        }
        return object
    }

    /**
     * Returns an object (not proxied) from the cache or updated set, as appropriate.
     */
    func getSaveObject(objectId: ObjectId) -> Object? {
        let updatedObject = updated[objectId]
        let cachedObject = cache[objectId]

        return updatedObject ?? cachedObject
    }

    /**
     * Constructs a new patch, calls `callback` with the subpatch at the location `path`,
     * and then immediately applies the patch to the document.
     */
    func applyAt(path: [KeyPathElement], callback: (inout Diff) -> Void) {
        let diff = MapDiff(objectId: .root, type: .map)
        var subPatch = getSubpatch(diff: diff, path: path)
        callback(&subPatch)
        cache[.root] = applyPatch(diff, cache[.root], &updated)
    }

    /**
     * Recurses along `path` into the patch object `patch`, creating nodes along the way as needed
     * by mutating the patch object. Returns the subpatch at the given path.
     */
    func getSubpatch(diff: MapDiff, path: [KeyPathElement]) -> Diff {
        if path.isEmpty {
            return .map(diff)
        }
        var subPatch: Diff = .map(diff)
        var object = getObject(objectId: .root)
        for pathComponent in path {
            let values = getValuesDescriptions(path: path, object: object, key: pathComponent.key)
            if case .map(let mapDiff) = subPatch {
                if mapDiff.props[pathComponent.key] == nil {
                    mapDiff.props[pathComponent.key] = values
                }
            } else if case .list(let listDiff) = subPatch, case .index(let index) = pathComponent.key {
                for (opId, value) in values {
                    listDiff.edits.append(.update(UpdateEdit(index: index, opId: opId, value: value)))
                }
            }

            var nextOpId: ObjectId!
            for (opId, value) in values {
                if value.objectId == pathComponent.objectId {
                    nextOpId = opId
                }
            }
            subPatch = values[nextOpId!]!
            object = getPropertyValue(object: object, key: pathComponent.key, opId: nextOpId!)
        }

        return subPatch
    }

    /**
     * Returns the value at property `key` of object `object`. In the case of a conflict, returns
     * the value whose assignment operation has the ID `opId`.
     */
    func getPropertyValue(object: Object, key: Key, opId: ObjectId) -> Object {
        switch (object, key) {
        case (.table(let table), .string(let key)):
            return table[ObjectId(key)]!
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
    func getValuesDescriptions(path: [KeyPathElement], object: Object, key: Key) -> [ObjectId: Diff] {
        switch (object, key) {
        case (.table(let table), .string(let key)):
            let objectId = ObjectId(key)
            if let value = table[objectId]  {
                return [objectId: getValueDescription(value: value)]
            } else {
                return [:]
            }
        case (.map(let map), .string(let key)):
            let conflict = map.conflicts[key]!
            var values = [ObjectId: Diff]()
            for opId in conflict.keys {
                values[opId] = getValueDescription(value: conflict[opId]!)
            }

            return values
        case (.list(let list), .index(let index)):
            let conflict = list.conflicts[index]
            var values = [ObjectId: Diff]()
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
        guard let objectId = path.isEmpty ? .root : path[path.count - 1].objectId else {
            fatalError("objectId must exist")
        }
        let object = getObject(objectId: objectId)
        guard case .list(let list) = object else {
            fatalError("Must be a list")
        }
        if index == list.count {
            splice(path: path, start: index, deletions: 0, insertions: [value])
            return
        }
        if case .counter = list[index] {
            fatalError("Cannot overwrite a Counter object; use .increment() or .decrement() to change its value.")
        }
        if list[index] != value || list.conflicts[index].keys.count > 1 {
            applyAt(path: path) { subpatch in
                let pred = getPred(object: object, key: .index(index))
                let opId = nextOpId()
                let valuePatch = setValue(objectId: objectId, key: .index(index), value: value, insert: false, pred: pred, elmId: getElmId(list: object, index: index))
                subpatch.edits.append(.update(UpdateEdit(index: index, opId: opId, value: valuePatch)))
            }
        }
    }

    /**
     * Updates the table object at path `path`, adding a new entry `row`.
     * Returns the objectId of the new row.
     */
    func addTableRow(path: [KeyPathElement], row: Object) -> ObjectId {
        precondition(row.objectId == ObjectId("") || row.objectId == nil, "Cannot reuse an existing object as table row")

        let id = ObjectId()
        let valuePatch = setValue(objectId: path[path.count - 1].objectId!, key: .string(id.objectId), value: row, insert: false, pred: [], elmId: nil)

        applyAt(path: path) { subpatch in
            subpatch.props[id.objectId] = [valuePatch.objectId!: valuePatch]
        }

        return id
    }

    /**
     * Updates the table object at path `path`, deleting the row with ID `rowId`.
     */
    func deleteTableRow(path: [KeyPathElement], rowId: ObjectId, pred: ObjectId) {
        let objectId =  path[path.count - 1].objectId!
        guard case .table(let table) = getObject(objectId: objectId) else {
            fatalError()
        }
        if table[rowId] != nil {
            ops.append(Op(action: .del, obj: objectId, key: .string(rowId.objectId), pred: [pred]))
            applyAt(path: path, callback: { subpatch in
                subpatch.props[rowId.objectId] = [:]
            })
        }
    }

    /**
     * Adds the integer `delta` to the value of the counter located at property
     * `key` in the object at path `path`.
     */
    func increment(path: [KeyPathElement], key: Key, delta: Int) {
        guard let objectId = path.isEmpty ? .root : path[path.count - 1].objectId else {
            fatalError("objectId must exist")
        }
        let object = getObject(objectId: objectId)
        let counterValue: Int
        switch key {
        case .string(let key):
            if  case .map(let map) = object,
                case .counter(let counter) = map[key] {
                counterValue = counter.value
            } else {
                fatalError("Only counter values can be incremented")
            }
        case .index(let index):
            if case .list(let list) = object,
               case .counter(let counter) = list[index] {
                counterValue = counter.value
            } else {
                fatalError("Only counter values can be incremented")
            }
        }

        let opId = nextOpId()
        let pred = getPred(object: object, key: key)
        // TODO what if there is a conflicting value on the same key as the counter?

        if case .list = object, case .index(let index) = key {
            let elemId = getElmId(list: object, index: index, insert: false)
            ops.append(Op(action: .inc, obj: objectId, elemId: elemId, insert: false, value: .int(delta), pred: pred))
        } else if  case .text = object, case .index(let index) = key {
            let elemId = getElmId(list: object, index: index, insert: false)
            ops.append(Op(action: .inc, obj: objectId, elemId: elemId, insert: false, value: .int(delta), pred: pred))
        } else {
            ops.append(Op(action: .inc, obj: objectId, key: key, insert: false, value: .int(delta), pred: pred))
        }

        applyAt(path: path, callback: { subpatch in
            if case .list(let listDiff) = subpatch, case .index(let index) = key {
                listDiff.edits.append(.update(UpdateEdit(index: index, opId: opId, value: .value(.init(value: .int(counterValue + delta), datatype: .counter)))))
            } else if case .map = subpatch {
                subpatch.props[key] = [opId: .value(.init(value: .int(counterValue + delta), datatype: .counter))]
            }

        })
    }

}

