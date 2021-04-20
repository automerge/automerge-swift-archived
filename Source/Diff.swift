//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

enum Diff: Equatable, Codable {
    case object(ObjectDiff)
    case value(ValueDiff)

    var objectId: String? {
        if case .object(let object) = self {
            return object.objectId
        }
        return nil
    }

    var props: Props? {
        if case .object(let object) = self {
            return object.props
        }
        return nil
    }

    static func value(_ value: Primitive) -> Diff {
        return Diff.value(.init(value: value))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(ValueDiff.self) {
            self = .value(value)
        } else {
            self = .object(try container.decode(ObjectDiff.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let value):
            try container.encode(value)
        case .object(let object):
            try container.encode(object)
        }
    }
}

extension Diff: ExpressibleByFloatLiteral {
    
    init(floatLiteral value: Float) {
        self = .value(.number(Double(value)))
    }

}

extension Diff: ExpressibleByStringLiteral {

    init(stringLiteral value: String) {
        self = .value(.string(value))
    }

}

enum CollectionType: String, Equatable, Codable {
    case list
    case map
    case table
    case text
}
