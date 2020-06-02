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

}
