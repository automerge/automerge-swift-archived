//
//  ActorId.swift
//  Automerge
//
//  Created by Lukas Schmidt on 15.05.20.
//

import Foundation

public struct ActorId: Equatable {

    public init() {
        self.actorId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    let actorId: String
}

extension ActorId: Comparable {

    public static func < (lhs: ActorId, rhs: ActorId) -> Bool {
        lhs.actorId < rhs.actorId
    }

}

extension ActorId: CustomStringConvertible {

    public var description: String {
        return actorId
    }

}
