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

func interpretPatch<T>(patch: ObjectDiff, obj: Document<T>, updated: inout [String: Any]) -> Document<T> {
    if patch.props != nil && patch.edits != nil && updated[patch.objectId.uuidString] != nil {
        return obj
    }
    switch patch.type {
    case .map:
        return updateMapObject(patch: patch, obj: obj, updated: &updated)
    case .table:
        fatalError()
    case .list:
        fatalError()
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
 * Updates the map object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */

func updateMapObject<T>(patch: ObjectDiff, obj: Document<T>, updated: inout [String: Any]) -> Document<T> {
    let objectId = patch.objectId.uuidString
    if updated[objectId] == nil {
        updated[objectId] = obj
    }

    let object = updated[objectId] as! Document<T>
    guard let props = patch.props else {
        return object
    }

    return applyProperties(props: props, object: object, conflicts: object._conflicts, updated: &updated)
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

func applyProperties<T>(props: Props, object: Document<T>, conflicts: [String: [String: Diff]], updated: inout [String: Any]) -> Document<T> {
    fatalError()

    for key in props.keys {
        var values = [String: Any]()
        let opIds = props[key]?.keys.sorted(by: lamportCompare)
        for opId in opIds ?? [] {
            let subPatch = props[key]![opId]
            if let conflict = conflicts[key]?[opId] {
                values[opId] = getValue(diff: subPatch!, cache: conflict, updated: &updated)
            } else {
                values[opId] = getValue(diff: subPatch!, cache: nil, updated: &updated)
            }
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
    fatalError()
}

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
 * Reconstructs the value from the diff object `diff`.
 */
func getValue(diff: Diff, cache: Diff?, updated: inout [String: Any]) -> Any? {
    if case .value(let valueDiff) = diff, case .string(let stringValue) = valueDiff.value, diff.link {
        fatalError()
//        return updated[stringValue] ?? cache?[stringValue]!
    } else if case .value(let valueDiff) = diff, case .number(let seconds) = valueDiff.value, valueDiff.datatype == .timestamp {
        return Date(timeIntervalSince1970: seconds)
    } else if case .value(let valueDiff) = diff, case .number(let count) = valueDiff.value, valueDiff.datatype == .counter {
        return Counter(value: count)
    } else if case .value(let valueDiff) = diff, case .number(let number) = valueDiff.value {
        return number
    } else if case .value(let valueDiff) = diff, case .string(let string) = valueDiff.value {
        return string
    } else if case .value(let valueDiff) = diff, case .bool(let bool) = valueDiff.value {
        return bool
    } else if case .value(let valueDiff) = diff, case .null = valueDiff.value {
        return nil
    }

    fatalError()
}
//function getValue(diff, cache, updated) {
//  if (diff.link) {
//    // Reference to another object; fetch it from the cache
//    return updated[diff.value] || cache[diff.value]
//  } else if (diff.datatype === 'timestamp') {
//    // Timestamp: value is milliseconds since 1970 epoch
//    return new Date(diff.value)
//  } else if (diff.datatype === 'counter') {
//    return new Counter(diff.value)
//  } else if (diff.datatype !== undefined) {
//    throw new TypeError(`Unknown datatype: ${diff.datatype}`)
//  } else {
//    // Primitive value (number, string, boolean, or null)
//    return diff.value
//  }
//}
