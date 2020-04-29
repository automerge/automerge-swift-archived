//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

typealias Props = [Key: [String: Diff]]

class ObjectDiff: Equatable {

    init(objectId: String,
         type: CollectionType,
         edits: [Edit]? = nil,
         props: Props? = nil
    ) {
        self.objectId = objectId
        self.type = type
        self.edits = edits
        self.props = props
    }

    var objectId: String
    var type: CollectionType
    var edits: [Edit]?
    var props: Props?

    static func ==(lhs: ObjectDiff, rhs: ObjectDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
                lhs.type == rhs.type &&
            lhs.edits == rhs.edits &&
            lhs.props == rhs.props
    }
}
