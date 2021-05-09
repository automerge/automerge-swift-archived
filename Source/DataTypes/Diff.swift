//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation



enum Diff: Equatable, Codable {
    case map(MapDiff)
    case list(ListDiff)
    case value(ValueDiff)

    var objectId: ObjectId? {
        if case .map(let map) = self {
            return map.objectId
        }
        if case .list(let list) = self {
            return list.objectId
        }
        return nil
    }

    var props: Props {
        get {
            if case .map(let map) = self {
                return map.props
            }
            fatalError()
        }
        set {
            if case .map(let map) = self {
                map.props = newValue
            }
        }
    }

    var edits: [Edit2] {
        get {
            if case .list(let list) = self {
                return list.edits
            }
            fatalError()
        }
        set {
            if case .list(let list) = self {
                list.edits = newValue
            }
        }
    }

    static func value(_ value: Primitive) -> Diff {
        return Diff.value(.init(value: value))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(ValueDiff.self) {
            self = .value(value)
        } else if let map = try? container.decode(MapDiff.self) {
            self = .map(map)
        } else {
            self = .list(try container.decode(ListDiff.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let value):
            try container.encode(value)
        case .map(let map):
            try container.encode(map)
        case .list(let list):
            try container.encode(list)
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
