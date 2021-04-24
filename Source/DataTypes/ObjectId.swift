//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

public struct ObjectId: Equatable, Hashable, Codable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {

    init(_ objectId: String = UUID().uuidString) {
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

    static let root: ObjectId = "_root"
    static let head: ObjectId = "_head"

    public init(stringLiteral value: StringLiteralType) {
        self.objectId = value
    }

    /**
     * Takes a string in the form that is used to identify operations (a counter concatenated
     * with an actor ID, separated by an `@` sign) and returns an object `{counter, actorId}`.
     */
    func parseOpId() -> (counter: Int, actorId: String)? {
        guard objectId.contains("@") else {
            return nil
        }
        let splitted = objectId.split(separator: "@")
        return (counter: Int(String(splitted[0]))!, actorId: String(splitted[1]))
    }
}

extension ObjectId: Comparable {

    public static func < (lhs: ObjectId, rhs: ObjectId) -> Bool {
        return lhs.objectId < rhs.objectId
    }

}

