//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

class MapDiff: Codable, Equatable {
    static func == (lhs: MapDiff, rhs: MapDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
            lhs.type == rhs.type &&
            lhs.props == rhs.props
    }


    init(objectId: ObjectId, type: ObjectType, props: Props = [:]) {
        self.objectId = objectId
        self.type = type
        self.props = props
    }

    enum ObjectType: String, Codable, Equatable {
        case map
        case table
    }

    let objectId: ObjectId
    let type: ObjectType
    var props: Props

    static let empty = MapDiff(objectId: ObjectId("_EMPTY"), type: .map, props: [:])
}
