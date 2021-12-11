//
//  Key.swift
//  Automerge
//
//  Created by Lukas Schmidt on 23.04.20.
//

import Foundation

public enum Key: Equatable, Hashable, Codable {

    case string(String)
    case index(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            if let index = Int(string) {
                self = .index(index)
            } else {
                self = .string(string)
            }
        } else {
            self = .index(try container.decode(Int.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .index(let index):
            try container.encode(index)
        }
    }
}

extension Key: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .string(value)
    }

}

extension Key: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: Int) {
        self = .index(value)
    }
}

extension Key: CustomStringConvertible {
    public var description: String {
        switch self {
        case .index(let index):
            return "\(index)"
        case .string(let string):
            return string
        }
    }

}
