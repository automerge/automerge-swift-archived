//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

struct List: Equatable, Collection, Codable {

    let objectId: String
    var listValues: [Object]
    var conflicts: [[String: Object]]

    init(objectId: String, listValues: [Object] = [], conflicts: [[String: Object]] = []) {
        self.objectId = objectId
        self.listValues = listValues
        self.conflicts = conflicts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(listValues)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.listValues = try container.decode([Object].self)
        self.objectId = ""
        self.conflicts = []
    }

    var startIndex: Int {
        return listValues.startIndex
    }

    var endIndex: Int {
        return listValues.endIndex
    }

    subscript(position: Int) -> Object {
        get {
           return listValues[position]
        }
    }

    // Method that returns the next index when iterating
    func index(after i: Int) -> Int {
        return listValues.index(after: i)
    }
}
