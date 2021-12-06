//
//  Commit.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation

/// A data structure that represents an individual commit within a document's change history.
public struct Commit<T> {
    /// The value of the document at this point in time.
    public let snapshot: T
    /// The change associated with this point in time within the change history of a document.
    public let change: Change
}
