//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

struct SingleInsertEdit: Codable, Equatable {

    init(index: Int, elemId: ObjectId, opId: ObjectId, value: Diff) {
        self.action = .insert
        self.index = index
        self.elemId = elemId
        self.opId = opId
        self.value = value
    }

    let action: Edit.Action
    let index: Int
    let elemId: ObjectId
    let opId: ObjectId
    let value: Diff
}
