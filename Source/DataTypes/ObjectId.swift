//
//  ObjectId.swift
//  Automerge
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

/// An objectId uniquely identifies an object in an Automerge document.
///
/// It's the identifier of the operation that created the object in Automerge.
/// An object can be a map, a list, text, or table.
/// Like any opId within Automerge, an objectId consists of a counter and the actorId of the actor that generated the operation.
/// The string representation has the form `counter@actorId`.
public struct ObjectId: Equatable, Hashable, Codable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {

    init(_ objectId: String = UUID().uuidString) {
        self.objectId = objectId
    }
    // NOTE(heckj): based on conversation with Martin, I'm not sure if it's legit to have an ObjectID that
    // can't decompose into `counter@ActorID`, so I'm uncertain if this initializer is correct or not.

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

    /// Returns a Boolean value that indicates whether the value of the first objectId is less than that of the second.
    public static func < (lhs: ObjectId, rhs: ObjectId) -> Bool {
        return lhs.objectId < rhs.objectId
    }

}

