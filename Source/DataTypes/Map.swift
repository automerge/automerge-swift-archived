//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

struct Map: Equatable, Codable {

    init(objectId: ObjectId, mapValues: [String: Object] = [:], conflicts: [String: [String: Object]] = [:]) {
        self.objectId = objectId
        self.mapValues = mapValues
        self.conflicts = conflicts
    }

    let objectId: ObjectId
    var mapValues: [String: Object]
    var conflicts: [String: [String: Object]]

    subscript(_ key: String) -> Object? {
        return mapValues[key]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(mapValues)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.mapValues = try container.decode([String: Object].self)
        self.objectId = ObjectId(objectId: "")
        self.conflicts = [:]
    }
}
