//
//  Primitive.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation

public enum Primitive: Equatable, Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {

    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case null

    var value: Any? {
        switch self {
        case .string(let stringValue):
            return stringValue
        case .double(let doubleValue):
            return doubleValue
        case .int(let intValue):
            return intValue
        case .bool(let boolValue):
            return boolValue
        case .null:
            return nil
        }
    }

    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }

    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .double(let double):
            try container.encode(double)
        case .int(let int):
            try container.encode(int)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            return
        }
    }
}
