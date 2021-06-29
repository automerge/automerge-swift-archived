//
//  Primitive.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation

public enum Primitive: Equatable, Codable {

    case string(String)
    case float64(Double)
    case int(Int)
    case uint(UInt)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let double = try? container.decode(Double.self) {
            self = .float64(double)
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
        case .float64(let number):
            try container.encode(number)
        case .int(let number):
            try container.encode(number)
        case .uint(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            return
        }
    }

    var datatype: DataType? {
        switch self {
        case .float64:
            return .float64
        case .int:
            return .int
        case .uint:
            return .uint
        case .bool, .string, .null:
            return nil
        }
    }
}

extension Primitive: ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral, ExpressibleByIntegerLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }

    public init(floatLiteral value: Float) {
        self = .float64(Double(value))
    }

    public init(integerLiteral value: Int) {
        self = .int(value)
    }

    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }

    public init(nilLiteral: Void) {
        self = .null
    }

}
