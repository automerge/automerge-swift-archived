//
//  History.swift
//  Automerge
//
//  Created by Lukas Schmidt on 08.06.20.
//

import Foundation

public struct History<T: Codable> {

    init(actor: ActorId, backend: RSBackend, binaryChanges: [[UInt8]]) {
        self.actor = actor
        self.backend = backend
        self.binaryChanges = binaryChanges
    }

    private let actor: ActorId
    private let backend: RSBackend
    private let binaryChanges: [[UInt8]]
}

extension History: Collection, Sequence, BidirectionalCollection {

    public var startIndex: Int { binaryChanges.startIndex }
    public var endIndex: Int { binaryChanges.endIndex }

    public subscript(position: Int) -> Commit<T> {
        get {
            let binaryChange = binaryChanges[position]
            let change = backend.decode(change: binaryChange)

            return Commit(snapshot: Document(changes: Array(binaryChanges[0...position]), actorId: actor).content, change: change)
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
