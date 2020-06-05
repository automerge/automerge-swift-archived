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
}
