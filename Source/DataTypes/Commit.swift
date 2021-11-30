//
//  Commit.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation

/// A data structure that represents an individual commit within a document's change history.
public struct Commit<T> {
    public let snapshot: T
    public let change: Change
}
