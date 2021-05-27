//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

final class MapDiff: Codable {

    init(objectId: ObjectId, type: ObjectType, props: Props = [:]) {
        self.objectId = objectId
        self.type = type
        self.props = props
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try values.decode(ObjectId.self, forKey: .objectId)
        self.type = try values.decode(ObjectType.self, forKey: .type)
        
        var props = Props()
        let stringProps = try? values.decodeIfPresent([String: [String: Diff]].self, forKey: .props)
        if let keys = stringProps?.keys {
            for key in keys {
                if let index = Int(key) {
                    props[index] = stringProps![key]?.compactMapKeys({ ObjectId($0) })
                } else {
                    props[key] = stringProps![key]?.compactMapKeys({ ObjectId($0) })
                }
                
            }
        }
        
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

extension MapDiff: Equatable {

    static func == (lhs: MapDiff, rhs: MapDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
            lhs.type == rhs.type &&
            lhs.props == rhs.props
    }

}
