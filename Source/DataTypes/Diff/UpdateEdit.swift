//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

struct UpdateEdit: Codable, Equatable {
    
    init(index: Int, opId: ObjectId, value: Diff) {
        self.action = .update
        self.index = index
        self.opId = opId
        self.value = value
    }

    let action: Edit.Action
    let index: Int
    let opId: ObjectId
    let value: Diff
}
