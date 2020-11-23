//
//  Change.swift
//  Automerge
//
//  Created by Lukas Schmidt on 05.06.20.
//

import Foundation

public struct Change: Codable {
    let time: Double
    public let seq: Int
    public var timestamp: Date {
        return Date(timeIntervalSince1970: time)
    }
    public let message: String?
    public let actor: Actor
    public let deps: [String]

    public init(change: [UInt8]) {
        let automerge = automerge_init()
        let length = automerge_decode_change(automerge, UInt(change.count), change)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(automerge, &buffer)
        let newString = String(cString: buffer)
        self = try! JSONDecoder().decode(Change.self, from: newString.data(using: .utf8)!)
    }
}
