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
func interpretPatch(patch: MapDiff, obj: Object?, updated: inout [ObjectId: Object]) -> Object? {
    if updated[patch.objectId] != nil {
        return obj
    }
    switch (patch.type, obj) {
    case (.map, .map(let map)):
        let newMap = updateMap(patch: patch, map: map, updated: &updated)
        return .map(newMap)
    case (.map, .none):
        let newMap = updateMap(patch: patch, map: nil, updated: &updated)
        return .map(newMap)
    case (.table, .table(let table)):
        let newTable = updateTable(patch: patch, table: table, updated: &updated)
        return .table(newTable)
    case (.table, .none):
        let newTable = updateTable(patch: patch, table: nil, updated: &updated)
        return .table(newTable)
    default:
        fatalError()
    }
}

func interpretPatch(patch: ListDiff, obj: Object?, updated: inout [ObjectId: Object]) -> Object? {
    if !patch.edits.isEmpty && updated[patch.objectId] != nil {
        return obj
    }
    switch (patch.type, obj) {
    case (.list, .list(let list)):
        let newList = updateList(patch: patch, list: list, updated: &updated)
        return .list(newList)
    case (.list, .none):
        let newList = updateList(patch: patch, list: nil, updated: &updated)
        return .list(newList)
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
func updateTable(patch: MapDiff, table: Table<Map>?, updated: inout [ObjectId: Object]) -> Table<Map> {
    let objectId = patch.objectId
    var table = table ?? Table<Map>(tableValues: [:], objectId: objectId)

    patch.props.keys.strings.forEach({ key in
        let key = ObjectId(key)
        let opIds = Array(patch.props[key.objectId]!.keys)
        if opIds.isEmpty {
            table[key] = nil
        } else if opIds.count == 1 {
            let subpatch = patch.props[key.objectId]![opIds[0]]
            table[key] = getValue(patch: subpatch!, object: table[key], updated: &updated)
            table.opIds[key] = opIds[0]
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
func updateText(patch: ListDiff, text: Text?, updated: inout [ObjectId: Object]) -> Text {
    fatalError()
//    let objectId = patch.objectId
//    var elems: [Text.Character]
//    if case .text(let text) = updated[objectId] {
//        elems = text.content
//    } else if let text = text {
//        elems = text.content
//    } else {
//        elems = []
//    }
//    patch.edits?.iterate(insertCallback: { (index, newElems) in
//        let blanks: [Text.Character] = newElems.map({ Text.Character(value: "", pred: [], elmId: $0) })
//        elems.replaceSubrange(index..<index, with: blanks)
//    }, removeCallback: { (index, deletions) in
//        elems.removeSubrange(index..<index + deletions)
//    })
//    let keys = patch.props.keys.indicies
//    keys?.forEach { index in
//        let pred = patch.props![index]!.keys
//        let opId = pred.sorted(by: lamportCompare)[0]
//
//        if case .primitive(.string(let character)) = getValue(patch: patch.props![index]![opId]!, object: nil, updated: &updated) {
//            elems[index] = Text.Character(value: character, pred: Array(pred), elmId: elems[index].elmId)
//        } else {
//            fatalError()
//        }
//    }
//    let text = Text(objectId: objectId, content: elems)
//    updated[objectId] = .text(text)
//
//    return text
}

/**
 * Updates the list object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateList(patch: ListDiff, list: List?, updated: inout [ObjectId: Object]) -> List {
    let objectId = patch.objectId
    var list = list ?? List(objectId: objectId, listValues: [])
    var i = 0
    while i < patch.edits.count {
        defer {
            i += 1
        }
        let edit = patch.edits[i]
        if edit.action == .insert || edit.action == .update {
            let oldValue = list.conflicts[safe: edit.index]?[edit.opId!]
            var lastValue = getValue(patch: edit.value!, object: oldValue, updated: &updated)
            var values = [edit.opId!: lastValue!]

            while i < patch.edits.count - 1 &&
                    patch.edits[i + 1].index == edit.index &&
                    patch.edits[i + 1].action == .update
            {
                i += 1
                let conflict = patch.edits[i]
                let oldValue = list.conflicts[conflict.index][conflict.opId!]
                lastValue = getValue(patch: conflict.value!, object: oldValue, updated: &updated)
                values[conflict.opId!] = lastValue
            }

            if case .singleInsert(let insert) = edit {
                list.insert(lastValue!, at: edit.index)
                list.conflicts.insert(values, at: edit.index)
                list.elemIds.insert(insert.elemId, at: edit.index)
            } else {
                list[edit.index] = lastValue!
                list.conflicts[edit.index] = values
            }
        } else if case .multiInsert(let multiInsert) = edit {
            let startElemId = multiInsert.elemId.parseOpId()!
            var newElems = [ObjectId]()
            var newValues = [Object]()
            var newConflicts = [[ObjectId : Object]]()
            for (i, value) in multiInsert.values.enumerated() {
                let elemId: ObjectId = "\(startElemId.counter + i)@\(startElemId.actorId)"
                newValues.append(.primitive(value))
                newConflicts.append([elemId: .primitive(value)])
                newElems.append(elemId)
            }
            list.insert(contentsOf: newValues, at: edit.index)
            list.conflicts.insert(contentsOf: newConflicts, at: edit.index)
            list.elemIds.insert(contentsOf: newElems, at: edit.index)
        } else if case .remove(let remove) = edit {
            list.removeSubrange((remove.index..<remove.index + remove.count))
            list.conflicts.removeSubrange((remove.index..<remove.index + remove.count))
            list.elemIds.removeSubrange((remove.index..<remove.index + remove.count))
        }
    }
    updated[objectId] = .list(list)
    return list
}


//function updateListObject(patch, obj, updated) {
//  const objectId = patch.objectId
//  if (!updated[objectId]) {
//    updated[objectId] = cloneListObject(obj, objectId)
//  }
//
//  const list = updated[objectId], conflicts = list[CONFLICTS], elemIds = list[ELEM_IDS]
//  for (let i = 0; i < patch.edits.length; i++) {
//    const edit = patch.edits[i]
//
//    if (edit.action === 'insert' || edit.action === 'update') {
//      const oldValue = conflicts[edit.index] && conflicts[edit.index][edit.opId]
//      let lastValue = getValue(edit.value, oldValue, updated)
//      let values = {[edit.opId]: lastValue}
//
//      // Successive updates for the same index are an indication of a conflict on that list element.
//      // Edits are sorted in increasing order by Lamport timestamp, so the last value (with the
//      // greatest timestamp) is the default resolution of the conflict.
//      while (i < patch.edits.length - 1 && patch.edits[i + 1].index === edit.index &&
//             patch.edits[i + 1].action === 'update') {
//        i++
//        const conflict = patch.edits[i]
//        const oldValue2 = conflicts[conflict.index] && conflicts[conflict.index][conflict.opId]
//        lastValue = getValue(conflict.value, oldValue2, updated)
//        values[conflict.opId] = lastValue
//      }
//
//      if (edit.action === 'insert') {
//        list.splice(edit.index, 0, lastValue)
//        conflicts.splice(edit.index, 0, values)
//        elemIds.splice(edit.index, 0, edit.elemId)
//      } else {
//        list[edit.index] = lastValue
//        conflicts[edit.index] = values
//      }
//
//    } else if (edit.action === 'multi-insert') {
//      const startElemId = parseOpId(edit.elemId), newElems = [], newValues = [], newConflicts = []
//      edit.values.forEach((value, index) => {
//        const elemId = `${startElemId.counter + index}@${startElemId.actorId}`
//        newValues.push(value)
//        newConflicts.push({[elemId]: {value, type: 'value'}})
//        newElems.push(elemId)
//      })
//      list.splice(edit.index, 0, ...newValues)
//      conflicts.splice(edit.index, 0, ...newConflicts)
//      elemIds.splice(edit.index, 0, ...newElems)
//
//    } else if (edit.action === 'remove') {
//      list.splice(edit.index, edit.count)
//      conflicts.splice(edit.index, edit.count)
//      elemIds.splice(edit.index, edit.count)
//    }
//  }
//  return list
//}

/**
 * Updates the map object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateMap(patch: MapDiff, map: Map?, updated: inout [ObjectId: Object]) -> Map {
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
        let opIds = props[index]?.keys.sorted(by: lamportCompare) ?? []
        for opId in opIds {
            let subPatch = props[index]![opId]
            let object = conflicts[index]?[opId]
            values[opId] = getValue(patch: subPatch!, object: object, updated: &updated)
        }
        if list.count > index {
            list[index] = values[opIds[0]]!
        } else if index == list.count {
            list.append(values[opIds[0]]!)
        } else {
            fatalError()
        }
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
        let opIds = props[key]?.keys.sorted(by: lamportCompare) ?? []
        for opId in opIds {
            let subPatch = props[key]![opId]
            let object = map.conflicts[key]?[opId]
            values[opId] = getValue(patch: subPatch!, object: object, updated: &updated)
        }
        if opIds.count == 0 {
            map[key] = nil
            map.conflicts[key] = nil
        } else {
            map[key] = values[opIds[0]]
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
        return time1.actorId > time2.actorId
    }
    return time1.counter > time2.counter
}

/**
 * Reconstructs the value from the patch object `patch`.
 */
func getValue(patch: Diff, object: Object?, updated: inout [ObjectId: Object]) -> Object? {
    switch patch {
    case .map(let mapDiff) where object?.objectId != patch.objectId:
        return interpretPatch(patch: mapDiff, obj: nil, updated: &updated)
    case .map(let mapDiff):
        return interpretPatch(patch: mapDiff, obj: object, updated: &updated)
    case .list(let listDiff) where object?.objectId != patch.objectId:
        return interpretPatch(patch: listDiff, obj: nil, updated: &updated)
    case .list(let listDiff):
        return interpretPatch(patch: listDiff, obj: object, updated: &updated)
    case .value(let valueDiff) where valueDiff.datatype == .counter:
        if case .number(let counterValue) = valueDiff.value {
            return .counter(Counter(Int(counterValue)))
        }
        fatalError()
    case .value(let valueDiff) where valueDiff.datatype == .timestamp:
        if case .number(let timeIntervalSince1970) = valueDiff.value {
            return .date(Date(timeIntervalSince1970: timeIntervalSince1970 / 1000))
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
