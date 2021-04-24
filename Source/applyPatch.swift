//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 16.04.21.
//

import Foundation

/**
 * Applies the patch object `patch` to the read-only document object `obj`.
 * Clones a writable copy of `obj` and places it in `updated` (indexed by
 * objectId), if that has not already been done. Returns the updated object.
 */
func interpretPatch(patch: ObjectDiff, obj: Object?, updated: inout [ObjectId: Object]) -> Object? {
    if patch.props != nil && patch.edits != nil && patch == .empty && updated[patch.objectId] != nil {
        return obj
    }
    switch (patch.type, obj) {
    case (.map, .map(let map)):
        let newMap = updateMap(patch: patch, map: map, updated: &updated)
        return .map(newMap)
    case (.map, .none):
        let newMap = updateMap(patch: patch, map: nil, updated: &updated)
        return .map(newMap)
    case (.list, .list(let list)):
        let newList = updateList(patch: patch, list: list, updated: &updated)
        return .list(newList)
    case (.list, .none):
        let newList = updateList(patch: patch, list: nil, updated: &updated)
        return .list(newList)
    case (.table, .table(let table)):
        let newTable = updateTable(patch: patch, table: table, updated: &updated)
        return .table(newTable)
    case (.table, .none):
        let newTable = updateTable(patch: patch, table: nil, updated: &updated)
        return .table(newTable)
    case (.text, .text(let text)):
        let newText = updateText(patch: patch, text: text, updated: &updated)
        return .text(newText)
    case (.text, .none):
        let newText = updateText(patch: patch, text: nil, updated: &updated)
        return .text(newText)
    default:
        fatalError()

    }
}

/**
 * Updates the table object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateTable(patch: ObjectDiff, table: Table<Map>?, updated: inout [ObjectId: Object]) -> Table<Map> {
    let objectId = patch.objectId
    var table = table ?? Table<Map>(tableValues: [:], objectId: objectId)

    let keys = patch.props?.keys.strings
    keys?.forEach({ (key) in
        let key = ObjectId(key)
        let opIds = Array(patch.props![.string(key.objectId)]!.keys)
        if opIds.isEmpty {
            table.entries[key] = nil
        } else if opIds.count == 1 {
            let subpatch = patch.props![.string(key.objectId)]![opIds[0]]
            let row = getValue(patch: subpatch!, object: table.entries[key], updated: &updated)
            table.entries[key] = row
        }
    })
    updated[objectId] = .table(table)

    return table
}

/**
 * Updates the text object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateText(patch: ObjectDiff, text: Text?, updated: inout [ObjectId: Object]) -> Text {
    let objectId = patch.objectId
    var elems: [Text.Character]
    if case .text(let text) = updated[objectId] {
        elems = text.content
    } else if let text = text {
        elems = text.content
    } else {
        elems = []
    }
    patch.edits?.iterate(insertCallback: { (index, newElems) in
        let blanks: [Text.Character] = newElems.map({ Text.Character(value: "", pred: [], elmId: $0) })
        elems.replaceSubrange(index..<index, with: blanks)
    }, removeCallback: { (index, deletions) in
        elems.removeSubrange(index..<index + deletions)
    })
    let keys = patch.props?.keys.indicies
    keys?.forEach { index in
        let pred = patch.props![.index(index)]!.keys
        let opId = pred.sorted(by: lamportCompare).reversed()[0]

        if case .primitive(.string(let character)) = getValue(patch: patch.props![.index(index)]![opId]!, object: nil, updated: &updated) {
            elems[index] = Text.Character(value: character, pred: Array(pred), elmId: elems[index].elmId)
        } else {
            fatalError()
        }
    }
    let text = Text(objectId: objectId, content: elems)
    updated[objectId] = .text(text)

    return text
}

/**
 * Updates the list object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateList(patch: ObjectDiff, list: List?, updated: inout [ObjectId: Object]) -> List {
    let objectId = patch.objectId
    var list = list ?? List(objectId: objectId, listValues: [])
    var conflicts: [[ObjectId: Object]?] = list.conflicts
    patch.edits?.iterate(
        insertCallback: { index, newElems in
            let blanksValues = Array<Object>(repeating: .primitive(1.0), count: newElems.count)
            list.listValues.replaceSubrange(index..<index, with: blanksValues)
            let blanksConflicts = Array<[ObjectId : Object]?>(repeating: nil, count: newElems.count)
            conflicts.replaceSubrange(index..<index, with: blanksConflicts)
            list.elemIds.replaceSubrange(index..<index, with: newElems)
        },
        removeCallback: { index, deletions in
            let range = index..<index + deletions
            list.listValues.removeSubrange(range)
            conflicts.removeSubrange(range)
            list.elemIds.removeSubrange(range)
        })
    applyProperties(props: patch.props, list: &list, conflicts: &conflicts, updated: &updated)
    list.conflicts = conflicts.compactMap({ $0 })
    updated[objectId] = .list(list)

    return list
}

/**
 * Updates the map object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateMap(patch: ObjectDiff, map: Map?, updated: inout [ObjectId: Object]) -> Map {
    let objectId = patch.objectId
    var map = map ?? Map(objectId: objectId, mapValues: [:], conflicts: [:])

    applyProperties(props: patch.props, objectId: objectId, map: &map, updated: &updated)
    updated[objectId] = .map(map)

    return map
}

/**
 * `props` is an object of the form:
 * `{key1: {opId1: {...}, opId2: {...}}, key2: {opId3: {...}}}`
 * where the outer object is a mapping from property names to inner objects,
 * and the inner objects are a mapping from operation ID to sub-patch.
 * This function interprets that structure and updates the objects `object` and
 * `conflicts` to reflect it. For each key, the greatest opId (by Lamport TS
 * order) is chosen as the default resolution; that op's value is assigned
 * to `object[key]`. Moreover, all the opIds and values are packed into a
 * conflicts object of the form `{opId1: value1, opId2: value2}` and assigned
 * to `conflicts[key]`. If there is no conflict, the conflicts object contains
 * just a single opId-value mapping.
 */
func applyProperties(
    props: Props?,
    list: inout List,
    conflicts: inout [[ObjectId: Object]?],
    updated: inout [ObjectId: Object]
) {
    guard let props = props else {
        return
    }
    for index in props.keys.indicies {
        var values = [ObjectId: Object]()
        let opIds = props[.index(index)]?.keys.sorted(by: lamportCompare).reversed() ?? []
        for opId in opIds {
            let subPatch = props[.index(index)]![opId]
            let object = conflicts[index]?[opId]
            values[opId] = getValue(patch: subPatch!, object: object, updated: &updated)
        }
        var listValues = list.listValues
        if listValues.count > index {
            listValues[index] = values[opIds[0]]!
        } else if index == listValues.count {
            listValues.append(values[opIds[0]]!)
        } else {
            fatalError()
        }
        list.listValues = listValues
        conflicts[index] = values
    }
}

/**
 * `props` is an object of the form:
 * `{key1: {opId1: {...}, opId2: {...}}, key2: {opId3: {...}}}`
 * where the outer object is a mapping from property names to inner objects,
 * and the inner objects are a mapping from operation ID to sub-patch.
 * This function interprets that structure and updates the objects `object` and
 * `conflicts` to reflect it. For each key, the greatest opId (by Lamport TS
 * order) is chosen as the default resolution; that op's value is assigned
 * to `object[key]`. Moreover, all the opIds and values are packed into a
 * conflicts object of the form `{opId1: value1, opId2: value2}` and assigned
 * to `conflicts[key]`. If there is no conflict, the conflicts object contains
 * just a single opId-value mapping.
 */
func applyProperties(
    props: Props?,
    objectId: ObjectId,
    map: inout Map,
    updated: inout [ObjectId: Object]
) {
    guard let props = props else {
        return
    }
    for key in props.keys.strings {
        var values = [ObjectId: Object]()
        let opIds = props[.string(key)]?.keys.sorted(by: lamportCompare).reversed() ?? []
        for opId in opIds {
            let subPatch = props[.string(key)]![opId]
            let object = map.conflicts[key]?[opId]
            values[opId] = getValue(patch: subPatch!, object: object, updated: &updated)
        }
        if opIds.count == 0 {
            map.mapValues[key] = nil
            map.conflicts[key] = nil
        } else {
            map.mapValues[key] = values[opIds[0]]
            map.conflicts[key] = values
        }
    }
}
/**
 * Compares two strings, interpreted as Lamport timestamps of the form
 * 'counter@actorId'. Returns 1 if ts1 is greater, or -1 if ts2 is greater.
 */
func lamportCompare(ts1: ObjectId, ts2: ObjectId) -> Bool {
    let time1 = ts1.parseOpId() ?? (counter: 0, actorId: ts1.objectId)
    let time2 = ts2.parseOpId() ?? (counter: 0, actorId: ts2.objectId)
    if time1.counter == time2.counter {
        return time1.actorId < time2.actorId
    }
    return time1.counter < time2.counter
}

/**
 * Reconstructs the value from the patch object `patch`.
 */
func getValue(patch: Diff, object: Object?, updated: inout [ObjectId: Object]) -> Object? {
    switch patch {
    case .object(let objectDiff) where object?.objectId != patch.objectId:
        return interpretPatch(patch: objectDiff, obj: nil, updated: &updated)
    case .object(let objectDiff):
        return interpretPatch(patch: objectDiff, obj: object, updated: &updated)
    case .value(let valueDiff) where valueDiff.datatype == .counter:
        if case .number(let counterValue) = valueDiff.value {
            return .counter(Counter(Int(counterValue)))
        }
        fatalError()
    case .value(let valueDiff) where valueDiff.datatype == .timestamp:
        if case .number(let timeIntervalSince1970) = valueDiff.value {
            return .date(Date(timeIntervalSince1970: timeIntervalSince1970))
        }
        fatalError()
    case .value(let valueDiff):
        return .primitive(valueDiff.value)
    }
}

extension Collection where Element == Key {
    
    var strings: [String] {
        self.compactMap({
            switch $0 {
            case .string(let string):
                return string
            case .index:
                return nil
            }
        })
    }
}

extension Collection where Element == Key {

    var indicies: [Int] {
        self.compactMap({
            switch $0 {
            case .index(let index):
                return index
            case .string:
                return nil
            }
        })
    }
}
