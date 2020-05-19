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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(ValueDiff.self) {
            self = .value(value)
        } else {
            self = .object(try container.decode(ObjectDiff.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let value):
            try container.encode(value)
        case .object(let object):
            try container.encode(object)
        }
    }
}

extension Diff: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: Int) {
        self = .value(.int(value))
    }

}

extension Diff: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .value(.string(value))
    }

}

struct ValueDiff: Equatable, Codable {

    init(value: Primitive, datatype: DataType? = nil) {
        self.value = value
        self.datatype = datatype
    }

    var value: Primitive
    var datatype: DataType?
}

typealias Props = [Key: [String: Diff]]

final class ObjectDiff: Equatable, Codable {

    init(objectId: String,
         type: CollectionType,
         edits: [Edit]? = nil,
         props: Props? = nil
    ) {
        self.objectId = objectId
        self.type = type
        self.edits = edits
        self.props = props
    }

    var objectId: String
    var type: CollectionType
    var edits: [Edit]?
    var props: Props?

    static func ==(lhs: ObjectDiff, rhs: ObjectDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
                lhs.type == rhs.type &&
            lhs.edits == rhs.edits &&
            lhs.props == rhs.props
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try values.decode(String.self, forKey: .objectId)
        self.type = try values.decode(CollectionType.self, forKey: .type)
        self.edits = try values.decodeIfPresent([Edit].self, forKey: .edits)
        var props = Props()

        let stringProps = try? values.decodeIfPresent([String: [String: Diff]].self, forKey: .props)
        if let keys = stringProps?.keys {
            for key in keys {
                if let index = Int(key) {
                     props[.index(index)] = stringProps![key]
                } else {
                    props[.string(key)] = stringProps![key]
                }

            }
        }

        self.props = props
    }
}

enum CollectionType: String, Equatable, Codable {
    case list
    case map
    case table
    case text
}
