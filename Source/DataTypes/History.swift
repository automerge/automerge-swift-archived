//
//  History.swift
//  Automerge
//
//  Created by Lukas Schmidt on 08.06.20.
//

import Foundation

/// A struct that wraps a document to represent it as a collection of changes.
///
/// Each indexed position of the history collection provides a ``Commit`` that encapsulates a snapshot of your model at that change and a ``Change`` to represent the differences included within the commit.
public struct History<T: Codable> {
    
    /// Creates a history of the provided Automerge document.
    /// - Parameter document: The document to inspect for the change history.
    public init(document: Document<T>) {
        self.init(actor: document.actor, binaryChanges: document.allChanges())
    }
    
    /// Creates a history of an Automerge document from the list binary changes that you provide.
    /// - Parameters:
    ///   - actor: An actor that represents the current collaborator viewing the changes.
    ///   - binaryChanges: An array of byte buffers that represent the changes.
    public init(actor: Actor, binaryChanges: [[UInt8]]) {
        self.actor = actor
        self.binaryChanges = binaryChanges
    }

    private let actor: Actor
    private let binaryChanges: [[UInt8]]
}

extension History: Collection, Sequence, BidirectionalCollection {
    
    /// The index at the start of the collection of changes.
    public var startIndex: Int { binaryChanges.startIndex }
    /// The index at the end of the collection of changes.
    public var endIndex: Int { binaryChanges.endIndex }

    /// Returns the commit at the index position of the change collection.
    public subscript(position: Int) -> Commit<T> {
        get {
            let binaryChange = binaryChanges[position]
            let change = Change(change: binaryChange)

            return Commit(snapshot: Document(changes: Array(binaryChanges[0...position]), actor: actor).content, change: change)
        }
    }

    /// Returns the index following the index provided.
    public func index(after i: Int) -> Index {
        return binaryChanges.index(after: i)
    }

    /// Returns the index position prior to the index provided.
    public func index(before i: Int) -> Int {
        return binaryChanges.index(before: i)
    }

}
