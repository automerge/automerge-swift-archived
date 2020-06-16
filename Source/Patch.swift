//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public final class Patch: Codable {

    init(actor: String? = nil, seq: Int? = nil, clock: Clock, version: Int, canUndo: Bool, canRedo: Bool, diffs: ObjectDiff) {
        self.actor = actor
        self.seq = seq
        self.clock = clock
        self.version = version
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.diffs = diffs
    }

    let actor: String?
    let seq: Int?
    let clock: Clock
    let version: Int
    let canUndo: Bool
    let canRedo: Bool
    let diffs: ObjectDiff

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.actor = try container.decodeIfPresent(String.self, forKey: .actor)
        self.seq = try container.decodeIfPresent(Int.self, forKey: .seq)
        self.clock = try container.decode(Clock.self, forKey: .clock)
        self.version = try container.decode(Int.self, forKey: .version)
        self.canUndo = try container.decode(Bool.self, forKey: .canUndo)
        self.canRedo = try container.decode(Bool.self, forKey: .canRedo)

        self.diffs = (try? container.decode(ObjectDiff.self, forKey: .diffs)) ?? .empty
    }

}
