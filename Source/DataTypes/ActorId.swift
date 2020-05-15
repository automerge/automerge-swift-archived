//
//  ActorId.swift
//  Automerge
//
//  Created by Lukas Schmidt on 15.05.20.
//

import Foundation

public struct ActorId {

    public init() {
        self.actorId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    let actorId: String
}
