//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

struct MultiInsertEdit: Codable, Equatable {

    init(index: Int, elemId: ObjectId, values: [Primitive]) {
        self.action = "multi-insert"
        self.index = index
        self.elemId = elemId
        self.values = values
    }

    let action: String
    let index: Int
    let elemId: ObjectId
    let values: [Primitive]
}
