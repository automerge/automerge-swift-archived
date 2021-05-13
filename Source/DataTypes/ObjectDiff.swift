//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 08.03.21.
//

import Foundation

final class ObjectDiff: Equatable, Codable {

    init(
        objectId: ObjectId,
        type: CollectionType,
        edits: [Edit]? = nil,
        props: Props? = nil
    ) {
        self.objectId = objectId
        self.type = type
        self.edits = edits
        self.props = props
    }

    let objectId: ObjectId
    let type: CollectionType
    var edits: [Edit]?
    var props: Props?

    static func ==(lhs: ObjectDiff, rhs: ObjectDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
            lhs.type == rhs.type &&
            lhs.edits == rhs.edits &&
            lhs.props == rhs.props
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try values.decode(ObjectId.self, forKey: .objectId)
        self.type = try values.decode(CollectionType.self, forKey: .type)
        self.edits = try values.decodeIfPresent([Edit].self, forKey: .edits)

        var props = Props()
        // Not sure why [String: [ObjectId: Diff]].self does not work here ???
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

    static let empty = ObjectDiff(objectId: ObjectId("_EMPTY"), type: .map)
}
