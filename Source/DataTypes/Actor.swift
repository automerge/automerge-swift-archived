//
//  Actor.swift
//  Automerge
//
//  Created by Lukas Schmidt on 15.05.20.
//

import Foundation

/// Represents a collaborator that makes changes to a document.
///
/// All changes to an automerge ``Document`` are identified by an Actor.
/// Use the default constructor to craete a random collaborator identity.
///
/// ## Topics
///
/// ### Creating an Actor
///
/// - ``Actor/init(actorId:)``
/// - ``Actor/init(stringLiteral:)``
///
/// ### Inspecting Actors
///
/// - ``Actor/actorId``
/// - ``Actor/description``
///
/// ### Encoding and Decoding Actors
///
/// - ``Actor/encode(to:)``
/// - ``Actor/init(from:)``
///
public struct Actor: Equatable, Hashable, Codable {
    
    /// Creates a new Actor.
    /// - Parameter actorId: A string representation of the Actor
    public init(actorId: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()) {
        precondition(actorId.allSatisfy { $0.isHexDigit }, "An actorId must be represented with only hexadecimal characters.")
        self.actorId = actorId
    }
    
    /// A string that represents the Actor
    public let actorId: String
    
    /// Creates a new Actor by decoding from the provided decoder.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.actorId = try container.decode(String.self)
    }
    
    /// Encodes this Actor into the provided encoder.
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(actorId)
    }
}

extension Actor: Comparable {
    
    /// Returns a Boolean value that indicates whether the value of the first actor's Id is less than that of the second actor's Id.
    public static func < (lhs: Actor, rhs: Actor) -> Bool {
        lhs.actorId < rhs.actorId
    }

}

extension Actor: CustomStringConvertible {
    
    /// A string that represents the Actor.
    public var description: String {
        return actorId
    }

}

extension Actor: ExpressibleByStringLiteral {
    
    /// Creates a new Actor from the provided string literal description.
    /// - Parameter value: The string that represents the actor.
    public init(stringLiteral value: StringLiteralType) {
        precondition(value.allSatisfy { $0.isHexDigit }, "An actorId must be represented with only hexadecimal characters.")
        self.init(actorId: value)
    }
}

extension Actor: ExpressibleByStringInterpolation {}
