//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

final class Patch {
    init(actor: String? = nil, seq: Int? = nil, clock: Clock, version: Int, canUndo: Bool? = nil, canRedo: Bool? = nil, diffs: ObjectDiff) {
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
  var canUndo: Bool?
  var canRedo: Bool?
  var diffs: ObjectDiff
}
