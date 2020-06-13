//
//  ActorId.swift
//  Automerge
//
//  Created by Lukas Schmidt on 15.05.20.
//

import Foundation

public struct Actor: Equatable {

    public init(actorId: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()) {
        self.actorId = actorId
    }

    public let actorId: String
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
