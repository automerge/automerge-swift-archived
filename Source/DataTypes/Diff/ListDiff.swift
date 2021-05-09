//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

class ListDiff: Codable, Equatable {
    static func == (lhs: ListDiff, rhs: ListDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
            lhs.type == rhs.type &&
            lhs.edits == rhs.edits
    }


    init(objectId: ObjectId, type: ListType, edits: [Edit2] = []) {
        self.objectId = objectId
        self.type = type
        self.edits = edits
    }

    enum ListType: String, Codable {
        case list
        case text
    }

    let objectId: ObjectId
    let type: ListType
    var edits: [Edit2]
}
