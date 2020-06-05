//
//  Commit.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation

public struct Commit<T> {
    public let snapshot: T
    public let change: Change
}
