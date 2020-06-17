//
//  ActorId.swift
//  Automerge
//
//  Created by Lukas Schmidt on 15.05.20.
//

import Foundation

public struct Actor: Equatable, Hashable, Codable {

    public init(actorId: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()) {
        self.actorId = actorId
    }

    public let actorId: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.actorId = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(actorId)
    }
}

extension Actor: Comparable {

    public static func < (lhs: Actor, rhs: Actor) -> Bool {
        lhs.actorId < rhs.actorId
    }

}

extension Actor: CustomStringConvertible {

    public var description: String {
        return actorId
    }

}

extension Actor: ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self.init(actorId: value)
    }
}

extension Actor: ExpressibleByStringInterpolation {}
