//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

/**
 * Applies the patch object `patch` to the read-only document object `obj`.
 * Clones a writable copy of `obj` and places it in `updated` (indexed by
 * objectId), if that has not already been done. Returns the updated object.
 */
func interpretPatch(patch: ObjectDiff, obj: [String: Any]?, updated: inout [String: [String: Any]]) -> [String: Any]? {
    if patch.props != nil && patch.edits != nil && patch == .empty && updated[patch.objectId] != nil && obj?[LIST_VALUES] == nil {
        return obj
    }
    switch patch.type {
    case .map:
        return updateMapObject(patch: patch, obj: obj, updated: &updated)
    case .table:
        return updateTableObject(patch: patch, obj: obj, updated: &updated)
    case .list:
        return updateListObject(patch: patch, obj: obj, updated: &updated)
    case .text:
        return updateTextObject(patch: patch, obj: obj, updated: &updated)
    }
}

/**
 * Updates the table object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateTableObject(patch: ObjectDiff, obj: [String: Any]?, updated: inout [String: [String: Any]]) -> [String: Any]? {
    let objectId = patch.objectId
    if updated[objectId] == nil {
        updated[objectId] = obj ?? instantiateTable(objectId: objectId, entries: nil)
    }
    var object = updated[objectId]

    let keys = patch.props?.keys
    keys?.forEach({ (key) in
        guard case .string(let stringKey) = key else {
            return
        }
        let opIds = Array(patch.props![key]!.keys)
        if opIds.isEmpty {
             var entries = object![TABLE_VALUES] as! [String: Any]
            entries[stringKey] = nil
            object![TABLE_VALUES] = entries
        } else if opIds.count == 1 {
            let subpatch = patch.props![key]![opIds[0]]
            var entries = object![TABLE_VALUES] as! [String: Any]
            entries[stringKey] = getValue(patch: subpatch!, object: entries[stringKey] as? [String: Any], updated: &updated)
            object![TABLE_VALUES] = entries
        }
    })
    updated[objectId] = object
    
    return object
}

private func instantiateTable(objectId: String, entries: [String: Any]?) -> [String: Any] {
    return [
        OBJECT_ID: objectId,
        CONFLICTS: [String: Any](),
        TABLE_VALUES: entries ?? [String: Any]()
    ]
}

/**
 * Updates the text object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateTextObject(patch: ObjectDiff, obj: [String: Any]?, updated: inout [String: [String: Any]]) -> [String: Any]? {
    let objectId = patch.objectId
    var elems: [[String: Any]]
    if let stored = updated[objectId], let storedElems = stored[LIST_VALUES] as? [[String: Any]] {
        elems = storedElems
    } else if let obj = obj, let storedElems = obj[LIST_VALUES] as? [[String: Any]] {
        elems = storedElems
    } else {
        elems = []
    }
    patch.edits?.iterate(insertCallback: { (index, insertions) in
        let blanks: [[String: Any]] = Array(repeating: [String: Any](), count: insertions)
        elems.insert(contentsOf: blanks, at: index)
    }, removeCallback: { (index, deletions) in
        elems.removeSubrange(index..<index + deletions)
    })
    let keys = patch.props?.keys
    keys?.forEach({ (key) in
        guard case .index(let index) = key else {
            fatalError()
        }
        let opId = patch.props![key]?.keys.sorted(by: lamportCompare)[0]
        if let value = getValue(patch: patch.props![key]![opId!]!, object: nil, updated: &updated) as? [String: Any] {
            elems[index] = value
            elems[index]["opId"] = opId
        } else if let value = getValue(patch: patch.props![key]![opId!]!, object: nil, updated: &updated) as? Primitive {
            elems[index] = ["value": value, "opId": opId!]
        } else {
            fatalError()
        }
    })
    updated[objectId] = [OBJECT_ID: objectId, LIST_VALUES: elems, ISTEXT: true]

    return updated[objectId]
}

/**
 * Updates the list object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateListObject(patch: ObjectDiff, obj: [String: Any]?, updated: inout [String: [String: Any]]) -> [String: Any]? {
    let objectId = patch.objectId
    if updated[objectId] == nil {
        updated[objectId] = cloneListObject(originalList: obj, objectId: objectId)
    }
    var object = updated[objectId]
    var list = object![LIST_VALUES] as! [Any?]
    var conflicts = Array(object![CONFLICTS] as! [Key: [String: Any]])
    patch.edits?.iterate(
        insertCallback: { index, insertions in
            let blanks = Array<[String: Any]?>(repeating: nil, count: insertions)
            list.replaceSubrange(index..<index, with: blanks)
            conflicts.replaceSubrange(index..<index, with: blanks)
    },
        removeCallback: { index, deletions in
            list.removeSubrange(index..<index + deletions)
            conflicts.removeSubrange(index..<index + deletions)
    })
    var dictConflicts = [Key: [String: Any]?](conflicts)
    object?[LIST_VALUES] = list
    applyProperties(props: patch.props, objectId: objectId, object: &object, conflicts: &dictConflicts, updated: &updated)
    object![CONFLICTS] = dictConflicts
    updated[objectId] = object

    return object
}

/**
 * Creates a writable copy of an immutable list object. If `originalList` is
 * undefined, creates an empty list with ID `objectId`.
 */
func cloneListObject(originalList: [String: Any]?, objectId: String) -> [String: Any] {
    var originalList = originalList ?? [:]
    originalList[CONFLICTS] = originalList[CONFLICTS] ?? [Key: [String: Any]]()
    originalList[OBJECT_ID] = objectId
    originalList[LIST_VALUES] = originalList[LIST_VALUES] ?? [Any]()

    return originalList
}

/**
 * Updates the map object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateMapObject(patch: ObjectDiff, obj: [String: Any]?, updated: inout [String: [String: Any]]) -> [String: Any]? {
    let objectId = patch.objectId
    if updated[objectId] == nil {
        updated[objectId]  = clone(originalObject: obj, objectId: objectId)
    }

    var object = updated[objectId]
    var conflicts = object?[CONFLICTS] as! [Key: [String: Any]?]
    applyProperties(props: patch.props, objectId: objectId, object: &object, conflicts: &conflicts, updated: &updated)
    object?[CONFLICTS] = conflicts
    updated[objectId] = object

    return object
}

/**
 * Creates a writable copy of an immutable map object. If `originalObject`
 * is undefined, creates an empty object with ID `objectId`.
 */
func clone(originalObject: [String: Any]?, objectId: String) -> [String: Any] {
    var originalObject = originalObject ?? [:]
    originalObject[CONFLICTS] = originalObject[CONFLICTS] ??  [String: [String: Any]]()
    originalObject[OBJECT_ID] = objectId

    return originalObject
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
func applyProperties(props: Props?,
                     objectId: String,
                     object: inout [String: Any]?,
                     conflicts: inout [Key: [String: Any]?],
                     updated: inout [String: [String: Any]]) {
    guard let props = props else {
        return
    }
    for key in props.keys {
        var values = [String: Any]()
        let opIds = props[key]?.keys.sorted(by: lamportCompare) ?? []
        for opId in opIds {
            let subPatch = props[key]![opId]
            let object = conflicts[key]??[opId] as? [String: Any]?
            values[opId] = getValue(patch: subPatch!, object: object ?? nil, updated: &updated)
        }
        if opIds.count == 0 {
            switch key {
            case .string(let string):
                object?[string] = nil
            case .index:
                fatalError()
            }

            conflicts[key] = nil
        } else {
            switch key {
            case .string(let string):
                object?[string] = values[opIds[0]]
                updated[objectId]?[string] = values[opIds[0]]
            case .index(let index):
                var list = object?[LIST_VALUES] as! [Any]
                if list.count > index {
                    list[index] = values[opIds[0]]!
                } else if index == list.count {
                    list.append(values[opIds[0]]!)
                } else {
                    fatalError()
                }
                object?[LIST_VALUES] = list
            }

            conflicts[key] = values
        }
    }
}
/**
 * Compares two strings, interpreted as Lamport timestamps of the form
 * 'counter@actorId'. Returns 1 if ts1 is greater, or -1 if ts2 is greater.
 */
func  lamportCompare(ts1: String, ts2: String) -> Bool {
    let time1 = ts1.contains("@") ? parseOpId(opId: ts1) : (counter: 0, actorId: ts1)
    let time2 = ts2.contains("@") ? parseOpId(opId: ts2) : (counter: 0, actorId: ts2)
    if time1.counter == time2.counter {
        return time1.actorId > time2.actorId
    }
    return time1.counter > time2.counter
}

/**
 * Takes a string in the form that is used to identify operations (a counter concatenated
 * with an actor ID, separated by an `@` sign) and returns an object `{counter, actorId}`.
 */
func parseOpId(opId: String) -> (counter: Int, actorId: String) {
    let splitted = opId.split(separator: "@")
    return (counter: Int(String(splitted[0]))!, actorId: String(splitted[1]))
}

/**
 * Reconstructs the value from the patch object `patch`.
 */
func getValue(patch: Diff, object: [String: Any]?, updated: inout [String: [String: Any]]) -> Any? {
    switch patch {
    case .object(let objectDiff) where (object?[OBJECT_ID] as? String) != patch.objectId:
        return interpretPatch(patch: objectDiff, obj: nil, updated: &updated)
    case .object(let objectDiff):
        return interpretPatch(patch: objectDiff, obj: object, updated: &updated)
    case .value(let valueDiff) where valueDiff.datatype == .counter:
        return [COUNTER_VALUE: valueDiff.value]
    case .value(let valueDiff):
        return valueDiff.value
    }
}
