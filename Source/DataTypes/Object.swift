//
//  File 2.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

enum Object: Equatable, Codable {

    case text(Text)
    case map(Map)
    case table(Table<Map>)
    case list(List)
    case counter(Counter)
    case date(Date)
    case primitive(Primitive)

    var objectId: ObjectId? {
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

    var isPrimitive: Bool {
        return objectId == nil
    }

    init(arrayLiteral elements: Object...) {
        self = .list(List(objectId: ObjectId(""), listValues: elements))
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
        if let list = try? container.decode(List.self) {
            self = .list(list)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let counter = try? container.decode(Counter.self) {
            self = .counter(counter)
        } else if let table = try? container.decode(Table<Map>.self) {
            self = .table(table)
        } else if let text = try? container.decode(Text.self) {
            self = .text(text)
        } else if let map = try? container.decode(Map.self) {
            self = .map(map)
        } else if let primitive = try? container.decode(Primitive.self) {
            self = .primitive(primitive)
        } else {
            self = .primitive(.null)
        }
    }
}


extension Object: ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {

    init(stringLiteral value: StringLiteralType) {
        self = .primitive(.string(value))
    }

    init(floatLiteral value: Float) {
        self = .primitive(.number(Double(value)))
    }

    init(integerLiteral value: IntegerLiteralType) {
        self = .primitive(.number(Double(value)))
    }

    init(dictionaryLiteral elements: (String, Object)...) {
        self = .map(Map(mapValues: Dictionary(uniqueKeysWithValues: elements)))
    }
}
