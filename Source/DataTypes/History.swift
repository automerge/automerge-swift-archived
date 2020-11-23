//
//  History.swift
//  Automerge
//
//  Created by Lukas Schmidt on 08.06.20.
//

import Foundation

public struct History<T: Codable> {

    public init(document: Document<T>) {
        self.init(actor: document.actor, binaryChanges: document.allChanges())
    }

    public init(actor: Actor, binaryChanges: [[UInt8]]) {
        self.actor = actor
        self.binaryChanges = binaryChanges
    }

    private let actor: Actor
    private let binaryChanges: [[UInt8]]
}

extension History: Collection, Sequence, BidirectionalCollection {

    public var startIndex: Int { binaryChanges.startIndex }
    public var endIndex: Int { binaryChanges.endIndex }

    public subscript(position: Int) -> Commit<T> {
        get {
            let binaryChange = binaryChanges[position]
            let change = Change(change: binaryChange)

            return Commit(snapshot: Document(changes: Array(binaryChanges[0...position]), actor: actor).content, change: change)
        }
    }

    // Method that returns the next index when iterating
    public func index(after i: Int) -> Index {
        return binaryChanges.index(after: i)
    }

    public func index(before i: Int) -> Int {
        return binaryChanges.index(before: i)
    }

}
