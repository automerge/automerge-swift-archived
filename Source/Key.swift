//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 23.04.20.
//

import Foundation

enum Key: Equatable, Hashable, Codable {

    case string(String)
    case index(Int)

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

    init(stringLiteral value: String) {
        self = .string(value)
    }

}

extension Key: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .index(value)
    }
}
