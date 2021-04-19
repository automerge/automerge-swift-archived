//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 16.04.21.
//

import Foundation

struct Map: Equatable, Codable {

    init(objectId: String, mapValues: [String: Object] = [:], conflicts: [String: [String: Object]] = [:]) {
        self.objectId = objectId
        self.mapValues = mapValues
        self.conflicts = conflicts
    }

    let objectId: String
    var mapValues: [String: Object]
    var conflicts: [String: [String: Object]]

    subscript(_ key: String) -> Object? {
        return mapValues[key]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(mapValues)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.mapValues = try container.decode([String: Object].self)
        self.objectId = ""
        self.conflicts = [:]
    }
}

struct List: Equatable, Collection, Codable {

    let objectId: String
    var listValues: [Object]
    var conflicts: [Int: [String: Object]]

    init(objectId: String, listValues: [Object] = [], conflicts: [Int: [String: Object]] = [:]) {
        self.objectId = objectId
        self.listValues = listValues
        self.conflicts = conflicts
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(listValues)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.listValues = try container.decode([Object].self)
        self.objectId = ""
        self.conflicts = [:]
    }

    var startIndex: Int {
        return listValues.startIndex
    }

    var endIndex: Int {
        return listValues.endIndex
    }

    public subscript(position: Int) -> Object {
        get {
           return listValues[position]
        }
    }

    // Method that returns the next index when iterating
    public func index(after i: Int) -> Int {
        return listValues.index(after: i)
    }
}

struct TableObj: Equatable, Codable {
    let objectId: String
    var tableValues: [String: Object]
    var conflicts: [String: Object]

    init(objectId: String, tableValues: [String: Object] = [:], conflicts: [String: Object] = [:]) {
        self.objectId = objectId
        self.tableValues = tableValues
        self.conflicts = conflicts
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(tableValues)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.tableValues = try container.decode([String: Object].self)
        self.objectId = ""
        self.conflicts = [:]
    }

}

struct TextObj: Equatable, Codable {
    let objectId: String
    var characters: [Character]
    var conflicts: [Int: [String: Object]]

    init(objectId: String, characters: [Character] = [], conflicts: [Int: [String: Object]] = [:]) {
        self.objectId = objectId
        self.characters = characters
        self.conflicts = conflicts
    }

    struct Character: Equatable, ExpressibleByStringLiteral {
        let value: String
        var conflicts: [String: [String: Object]]
        let opId: String

        init(
            value: String,
            conflicts: [String: [String: Object]],
            opId: String
        ) {
            self.value = value
            self.conflicts = conflicts
            self.opId = opId
        }

        init(stringLiteral value: StringLiteralType) {
            self.value = value
            self.conflicts = [:]
            self.opId = ""
        }

        static let blank = Character(value: "", conflicts: [:], opId: "")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(characters.map({ $0.value }))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let characters = try container.decode([String].self)
        self.characters = characters.map({ Character(value: $0, conflicts: [:], opId: "") })
        self.conflicts = [:]
        self.objectId = ""
    }

}

enum Object: Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, Codable {

    case text(TextObj)
    case map(Map)
    case table(TableObj)
    case list(List)
    case counter(Counter)
    case date(Date)
    case primitive(Primitive)

    var objectId: String? {
        switch self {
        case .text(let obj):
            return obj.objectId
        case .map(let obj):
            return obj.objectId
        case .table(let obj):
            return obj.objectId
        case .list(let obj):
            return obj.objectId
        case .primitive, .counter, .date:
            return nil
        }
    }

    init(integerLiteral value: IntegerLiteralType) {
        self = .primitive(.int(value))
    }

    init(stringLiteral value: StringLiteralType) {
        self = .primitive(.string(value))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .map(let map):
            try container.encode(map)
        case .table(let table):
            try container.encode(table)
        case .counter(let counter):
            try container.encode(counter)
        case .date(let date):
            try container.encode(date)
        case .primitive(let primitive):
            try container.encode(primitive)
        case .text(let text):
            try container.encode(text)
        case .list(let list):
            try container.encode(list)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let map = try? container.decode(Map.self) {
            self = .map(map)
        } else if let table = try? container.decode(TableObj.self) {
            self = .table(table)
        } else if let list = try? container.decode(List.self) {
            self = .list(list)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let primitive = try? container.decode(Primitive.self) {
            self = .primitive(primitive)
        } else if let counter = try? container.decode(Counter.self) {
            self = .counter(counter)
        } else if let text = try? container.decode(TextObj.self) {
            self = .text(text)
        } else {
            fatalError()
        }
    }


}

/**
 * Applies the patch object `patch` to the read-only document object `obj`.
 * Clones a writable copy of `obj` and places it in `updated` (indexed by
 * objectId), if that has not already been done. Returns the updated object.
 */
func interpretPatch2(patch: ObjectDiff, obj: Object?, updated: inout [String: Object]) -> Object? {
    if patch.props != nil && patch.edits != nil && patch == .empty && updated[patch.objectId] != nil {
        return obj
    }
    switch (patch.type, obj) {
    case (.map, .map(let map)):
        let newMap = updateMapObject2(patch: patch, map: map, updated: &updated)
        return .map(newMap)
    case (.map, .none):
        let newMap = updateMapObject2(patch: patch, map: nil, updated: &updated)
        return .map(newMap)
    case (.list, .list(let list)):
        let newList = updateListObject2(patch: patch, list: list, updated: &updated)
        return .list(newList)
    case (.list, .none):
        let newList = updateListObject2(patch: patch, list: nil, updated: &updated)
        return .list(newList)
    case (.table, .table(let table)):
        let newTable = updateTableObject2(patch: patch, table: table, updated: &updated)
        return .table(newTable)
    case (.table, .none):
        let newTable = updateTableObject2(patch: patch, table: nil, updated: &updated)
        return .table(newTable)
    case (.text, .text(let text)):
        let newText = updateTextObject2(patch: patch, text: text, updated: &updated)
        return .text(newText)
    case (.text, .none):
        let newText = updateTextObject2(patch: patch, text: nil, updated: &updated)
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
func updateTableObject2(patch: ObjectDiff, table: TableObj?, updated: inout [String: Object]) -> TableObj {
    let objectId = patch.objectId
    var table = table ?? TableObj(objectId: objectId, tableValues: [:], conflicts: [:])

    let keys = patch.props?.keys.strings
    keys?.forEach({ (key) in
        let opIds = Array(patch.props![.string(key)]!.keys)
        let subpatch = patch.props![.string(key)]![opIds[0]]

        let newValue = opIds.isEmpty ? nil : getValue2(patch: subpatch!, object: table.tableValues[key], updated: &updated)
        table.tableValues[key] = newValue
    })
    updated[objectId] = .table(table)

    return table
}

/**
 * Updates the text object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateTextObject2(patch: ObjectDiff, text: TextObj?, updated: inout [String: Object]) -> TextObj {
    let objectId = patch.objectId
    var elems: [TextObj.Character]
    if case .text(let text) = updated[objectId] {
        elems = text.characters
    } else if let text = text {
        elems = text.characters
    } else {
        elems = []
    }
    patch.edits?.iterate(insertCallback: { (index, insertions) in
        let blanks: [TextObj.Character] = Array(repeating: .blank, count: insertions)
        elems.insert(contentsOf: blanks, at: index)
    }, removeCallback: { (index, deletions) in
        elems.removeSubrange(index..<index + deletions)
    })
    let keys = patch.props?.keys.indicies
    keys?.forEach { index in
        let opId = patch.props![.index(index)]?.keys.sorted(by: lamportCompare2)[0]
        if let value = getValue2(patch: patch.props![.index(index)]![opId!]!, object: nil, updated: &updated) {
//            elems[index].value = value
//            elems
            //            elems[index] = value
            //            elems[index]["opId"] = opId
            fatalError("Fix this")
        } else if case .primitive(let value) = getValue2(patch: patch.props![.index(index)]![opId!]!, object: nil, updated: &updated),
                  case .string(let character) = value {
            elems[index] = TextObj.Character(value: character, conflicts: [:], opId: opId!)
        } else {
            fatalError()
        }
    }
    let text = TextObj(objectId: objectId, characters: elems, conflicts: [:])
    updated[objectId] = .text(text)

    return text
}

/**
 * Updates the list object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateListObject2(patch: ObjectDiff, list: List?, updated: inout [String: Object]) -> List {
    let objectId = patch.objectId
    var list = list ?? List(objectId: objectId, listValues: [], conflicts: [:])
    var listValues = list.listValues
    var conflicts = Array(list.conflicts)
    patch.edits?.iterate(
        insertCallback: { index, insertions in
            let blanksValues = Array<Object>(repeating: .primitive(1), count: insertions)
            listValues.replaceSubrange(index..<index, with: blanksValues)
            let blanksConflicts = Array<[String : Object]?>(repeating: nil, count: insertions)
            conflicts.replaceSubrange(index..<index, with: blanksConflicts)
        },
        removeCallback: { index, deletions in
            listValues.removeSubrange(index..<index + deletions)
            conflicts.removeSubrange(index..<index + deletions)
        })
    var dictConflicts = [Int: [String: Object]](conflicts)
    list.listValues = listValues
    applyProperties2(props: patch.props, list: &list, conflicts: &dictConflicts, updated: &updated)
    list.conflicts = dictConflicts
    updated[objectId] = .list(list)

    return list
}

/**
 * Updates the map object `obj` according to the modifications described in
 * `patch`, or creates a new object if `obj` is undefined. Mutates `updated`
 * to map the objectId to the new object, and returns the new object.
 */
func updateMapObject2(patch: ObjectDiff, map: Map?, updated: inout [String: Object]) -> Map {
    let objectId = patch.objectId
    var map = map ?? Map(objectId: objectId, mapValues: [:], conflicts: [:])

    applyProperties2(props: patch.props, objectId: objectId, map: &map, updated: &updated)
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
func applyProperties2(
    props: Props?,
    list: inout List,
    conflicts: inout [Int: [String: Object]],
    updated: inout [String: Object]
) {
    guard let props = props else {
        return
    }
    for index in props.keys.indicies {
        var values = [String: Object]()
        let opIds = props[.index(index)]?.keys.sorted(by: lamportCompare2) ?? []
        for opId in opIds {
            let subPatch = props[.index(index)]![opId]
            let object = conflicts[index]?[opId]
            values[opId] = getValue2(patch: subPatch!, object: object ?? nil, updated: &updated)
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
func applyProperties2(
    props: Props?,
    objectId: String,
    map: inout Map,
    updated: inout [String: Object]
) {
    guard let props = props else {
        return
    }
    for key in props.keys.strings {
        var values = [String: Object]()
        let opIds = props[.string(key)]?.keys.sorted(by: lamportCompare2) ?? []
        for opId in opIds {
            let subPatch = props[.string(key)]![opId]
            let object = map.conflicts[key]?[opId]
            values[opId] = getValue2(patch: subPatch!, object: object ?? nil, updated: &updated)
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
func  lamportCompare2(ts1: String, ts2: String) -> Bool {
    let time1 = ts1.contains("@") ? parseOpId2(opId: ts1) : (counter: 0, actorId: ts1)
    let time2 = ts2.contains("@") ? parseOpId2(opId: ts2) : (counter: 0, actorId: ts2)
    if time1.counter == time2.counter {
        return time1.actorId > time2.actorId
    }
    return time1.counter > time2.counter
}

/**
 * Takes a string in the form that is used to identify operations (a counter concatenated
 * with an actor ID, separated by an `@` sign) and returns an object `{counter, actorId}`.
 */
func parseOpId2(opId: String) -> (counter: Int, actorId: String) {
    let splitted = opId.split(separator: "@")
    return (counter: Int(String(splitted[0]))!, actorId: String(splitted[1]))
}

/**
 * Reconstructs the value from the patch object `patch`.
 */
func getValue2(patch: Diff, object: Object?, updated: inout [String: Object]) -> Object? {
    switch patch {
    case .object(let objectDiff) where object?.objectId != patch.objectId:
        return interpretPatch2(patch: objectDiff, obj: nil, updated: &updated)
    case .object(let objectDiff):
        return interpretPatch2(patch: objectDiff, obj: object, updated: &updated)
    case .value(let valueDiff) where valueDiff.datatype == .counter:
        if case .int(let counterValue) = valueDiff.value {
            return .counter(Counter(counterValue))
        }
        fatalError()
    case .value(let valueDiff) where valueDiff.datatype == .timestamp:
        if case .double(let timeIntervalSince1970) = valueDiff.value {
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
