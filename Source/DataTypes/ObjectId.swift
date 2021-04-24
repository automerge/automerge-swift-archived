//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

public struct ObjectId: Equatable, Hashable, Codable, ExpressibleByStringLiteral {

    init(objectId: String = UUID().uuidString) {
        self.objectId = objectId
    }

    let objectId: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.objectId = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(objectId)
    }

    static let root = ObjectId(objectId: "00000000-0000-0000-0000-000000000000")

    public init(stringLiteral value: StringLiteralType) {
        self.objectId = value
    }
}
