//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

typealias Props = ReferenceDictionary<String, ReferenceDictionary<String, Diff>>
class ObjectDiff: Equatable {
    
    init(objectId: UUID,
         type: CollectionType,
         edits: [Edit]? = nil,
         props: Props? = nil
    ) {
        self.objectId = objectId
        self.type = type
        self.edits = edits
        self.props = props
    }


    var objectId: UUID
    var type: CollectionType
    var edits: [Edit]?
    var props: ReferenceDictionary<String, ReferenceDictionary<String, Diff>>?

    static func ==(lhs: ObjectDiff, rhs: ObjectDiff) -> Bool {
        return lhs.objectId == rhs.objectId &&
                lhs.type == rhs.type &&
            lhs.edits == rhs.edits &&
            lhs.props == rhs.props
    }
}
