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
    if patch.props != nil && patch.edits != nil && updated[patch.objectId] != nil && obj?[LIST_VALUES] == nil {
        return obj
    }
    switch patch.type {
    case .map:
        return updateMapObject(patch: patch, obj: obj, updated: &updated)
    case .table:
        fatalError()
    case .list:
        return updateListObject(patch: patch, obj: obj, updated: &updated)
    case .text:
        fatalError()
    }
}

//function interpretPatch(patch, obj, updated) {
//  // Return original object if it already exists and isn't being modified
//  if (isObject(obj) && !patch.props && !patch.edits && !updated[patch.objectId]) {
//    return obj
//  }
//
//  if (patch.type === 'map') {
//    return updateMapObject(patch, obj, updated)
//  } else if (patch.type === 'table') {
//    return updateTableObject(patch, obj, updated)
//  } else if (patch.type === 'list') {
//    return updateListObject(patch, obj, updated)
//  } else if (patch.type === 'text') {
//    return updateTextObject(patch, obj, updated)
//  } else {
//    throw new TypeError(`Unknown object type: ${patch.type}`)
//  }
//}

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

//function updateListObject(patch, obj, updated) {
//  const objectId = patch.objectId
//  if (!updated[objectId]) {
//    updated[objectId] = cloneListObject(obj, objectId)
//  }
//
//  const list = updated[objectId], conflicts = list[CONFLICTS]
//
//  iterateEdits(patch.edits,
//    (index, insertions) => { // insertion
//      const blanks = new Array(insertions)
//      list     .splice(index, 0, ...blanks)
//      conflicts.splice(index, 0, ...blanks)
//    },
//    (index, count) => { // deletion
//      list     .splice(index, count)
//      conflicts.splice(index, count)
//    }
//  )
//
//  applyProperties(patch.props, list, conflicts, updated)
//  return list
//}

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
//function cloneListObject(originalList, objectId) {
//  const list = originalList ? originalList.slice() : [] // slice() makes a shallow clone
//  const conflicts = (originalList && originalList[CONFLICTS]) ? originalList[CONFLICTS].slice() : []
//  Object.defineProperty(list, OBJECT_ID, {value: objectId})
//  Object.defineProperty(list, CONFLICTS, {value: conflicts})
//  return list
//}

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

//function updateMapObject(patch, obj, updated) {
//  const objectId = patch.objectId
//  if (!updated[objectId]) {
//    updated[objectId] = cloneMapObject(obj, objectId)
//  }
//
//  const object = updated[objectId]
//  applyProperties(patch.props, object, object[CONFLICTS], updated)
//  return object
//}

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
//function cloneMapObject(originalObject, objectId) {
//  const object    = copyObject(originalObject)
//  const conflicts = copyObject(originalObject ? originalObject[CONFLICTS] : undefined)
//  Object.defineProperty(object, OBJECT_ID, {value: objectId})
//  Object.defineProperty(object, CONFLICTS, {value: conflicts})
//  return object
//}

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

//function applyProperties(props, object, conflicts, updated) {
//  if (!props) return
//
//  for (let key of Object.keys(props)) {
//    const values = {}, opIds = Object.keys(props[key]).sort(lamportCompare).reverse()
//    for (let opId of opIds) {
//      const subpatch = props[key][opId]
//      if (conflicts[key] && conflicts[key][opId]) {
//        values[opId] = getValue(subpatch, conflicts[key][opId], updated)
//      } else {
//        values[opId] = getValue(subpatch, undefined, updated)
//      }
//    }
//
//    if (opIds.length === 0) {
//      delete object[key]
//      delete conflicts[key]
//    } else {
//      object[key] = values[opIds[0]]
//      conflicts[key] = values
//    }
//  }
//}

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
//function parseOpId(opId) {
//  const match = /^(\d+)@(.*)$/.exec(opId || '')
//  if (!match) {
//    throw new RangeError(`Not a valid opId: ${opId}`)
//  }
//  return {counter: parseInt(match[1]), actorId: match[2]}
//}

//function lamportCompare(ts1, ts2) {
//  const regex = /^(\d+)@(.*)$/
//  const time1 = regex.test(ts1) ? parseOpId(ts1) : {counter: 0, actorId: ts1}
//  const time2 = regex.test(ts2) ? parseOpId(ts2) : {counter: 0, actorId: ts2}
//  if (time1.counter < time2.counter) return -1
//  if (time1.counter > time2.counter) return  1
//  if (time1.actorId < time2.actorId) return -1
//  if (time1.actorId > time2.actorId) return  1
//  return 0
//}

/**
 * Reconstructs the value from the patch object `patch`.
 */

func getValue(patch: Diff, object: [String: Any]?, updated: inout [String: [String: Any]]) -> Any? {
    switch patch {
    case .object(let objectDiff):
        if let object = object, (object[OBJECT_ID] as? String) != patch.objectId {
            return interpretPatch(patch: objectDiff, obj: nil, updated: &updated)
        } else {
            return interpretPatch(patch: objectDiff, obj: object, updated: &updated)
        }
    case .value(let valueDiff):
        if valueDiff.datatype == .counter {
            return [COUNTER_VALUE: valueDiff.value]
        } else {
            return valueDiff.value
        }
    }
}

//function getValue(patch, object, updated) {
//  if (patch.objectId) {
//    // If the objectId of the existing object does not match the objectId in the patch,
//    // that means the patch is replacing the object with a new one made from scratch
//    if (object && object[OBJECT_ID] !== patch.objectId) {
//      object = undefined
//    }
//    return interpretPatch(patch, object, updated)
//  } else if (patch.datatype === 'timestamp') {
//    // Timestamp: value is milliseconds since 1970 epoch
//    return new Date(patch.value)
//  } else if (patch.datatype === 'counter') {
//    return new Counter(patch.value)
//  } else if (patch.datatype !== undefined) {
//    throw new TypeError(`Unknown datatype: ${patch.datatype}`)
//  } else {
//    // Primitive value (number, string, boolean, or null)
//    return patch.value
//  }
//}

