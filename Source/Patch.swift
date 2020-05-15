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

  var actor: String?
  var seq: Int?
  var clock: Clock
  var version: Int
  var canUndo: Bool
  var canRedo: Bool
  var diffs: ObjectDiff
}
