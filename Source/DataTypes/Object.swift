//
//  File 2.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

public struct ObjectId: Equatable, Hashable, Codable, ExpressibleByStringLiteral {

    init(objectId: String = UUID().uuidString) {
        self.objectId = objectId
    }

    let objectId: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.objectId = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(objectId)
    }

    static let root = ObjectId(objectId: ROOT_ID)

    public init(stringLiteral value: StringLiteralType) {
        self.objectId = value
    }
}

enum Object: Equatable, ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByArrayLiteral, Codable {

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

    init(arrayLiteral elements: Object...) {
        self = .list(List(objectId: ObjectId(objectId: ""), listValues: elements))
    }

    public init(floatLiteral value: Float) {
        self = .primitive(.number(Double(value)))
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