//
//  Change.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation
import AutomergeBackend

/// A struct that represents a change to an Automerge document.
public struct Change: Codable {
    let time: Double
    /// The sequence number of this change within the Automerge document.
    public let seq: Int
    /// The wall clock timestamp of when this change was created.
    public var timestamp: Date {
        return Date(timeIntervalSince1970: time)
    }
    /// An optional message associated with the change.
    public let message: String?
    /// The actor that created the change.
    public let actor: Actor
    /// A list of the dependencies that this change builds upon within the Automerge document.
    public let deps: [String]
    
    /// Creates a change from the byte-buffer you provide.
    /// - Parameter change: An array of bytes that represents the change to be decoded.
    public init(change: [UInt8]) {
        let automerge = automerge_init()
        let length = automerge_decode_change(automerge, UInt(change.count), change)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(automerge, &buffer)
        let newString = String(cString: buffer)
        self = try! JSONDecoder().decode(Change.self, from: newString.data(using: .utf8)!)
    }
}
