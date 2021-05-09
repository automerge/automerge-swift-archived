//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public final class Patch: Codable {

    init(
        actor: Actor? = nil,
        seq: Int? = nil,
        clock: Clock,
        deps: [ObjectId],
        maxOp: Int,
        diffs: MapDiff
    ) {
        self.actor = actor
        self.seq = seq
        self.clock = clock
        self.deps = deps
        self.maxOp = maxOp
        self.diffs = diffs
    }

    let actor: Actor?
    let seq: Int?
    let clock: Clock
    let deps: [ObjectId]
    let maxOp: Int
    let diffs: MapDiff

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.actor = try container.decodeIfPresent(Actor.self, forKey: .actor)
        self.seq = try container.decodeIfPresent(Int.self, forKey: .seq)
        self.clock = try container.decode(Clock.self, forKey: .clock)
        self.deps = try container.decode([ObjectId].self, forKey: .deps)
        self.maxOp = try container.decode(Int.self, forKey: .maxOp)

        self.diffs = (try? container.decode(MapDiff.self, forKey: .diffs)) ?? .empty
    }

}
