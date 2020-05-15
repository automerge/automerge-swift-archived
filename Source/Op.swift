//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

enum Primitive: Equatable, Codable {
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

enum DataType: String, Equatable, Codable {
    case counter
    case timestamp
}

public struct Op: Equatable, Codable {

    init(action: OpAction, obj: String, key: Key, insert: Bool = false, child: String? = nil, value: Primitive? = nil, datatype: DataType? = nil) {
        self.action = action
        self.obj = obj
        self.key = key
        self.insert = insert
        self.child = child
        self.value = value
        self.datatype = datatype
    }

    var action: OpAction
    var obj: String
    var key: Key
    var insert: Bool
    var child: String?
    var value: Primitive?
    var datatype: DataType?
}

enum OpAction: String, Codable {
    case del
    case inc
    case set
    case link
    case makeText
    case makeTable
    case makeList
    case makeMap
}
