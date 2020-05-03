//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

enum Diff: Equatable {
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

struct ValueDiff: Equatable {

    init(value: Primitive, datatype: DataType? = nil) {
        self.value = value
        self.datatype = datatype
    }

    var value: Primitive
    var datatype: DataType?
}

typealias Props = [Key: [String: Diff]]

class ObjectDiff: Equatable {

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
}

enum CollectionType: Equatable {
    case list
    case map
    case table
    case text
}
