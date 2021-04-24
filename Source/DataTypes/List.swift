//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

struct List: Equatable, Collection, Codable {

    let objectId: ObjectId
    var listValues: [Object]
    var conflicts: [[ObjectId: Object]]
    var elemIds: [ObjectId]

    init(objectId: ObjectId = "", listValues: [Object] = [], conflicts: [[ObjectId: Object]] = [], elemIds: [ObjectId] = []) {
        self.objectId = objectId
        self.listValues = listValues
        self.conflicts = conflicts
        self.elemIds = elemIds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(listValues)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.listValues = try container.decode([Object].self)
        self.objectId = ObjectId("")
        self.conflicts = []
        self.elemIds = []
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

extension List: ExpressibleByArrayLiteral {

    init(arrayLiteral elements: Object...) {
        self.objectId = ""
        self.listValues = elements
        self.conflicts = []
        self.elemIds = []
    }
}
