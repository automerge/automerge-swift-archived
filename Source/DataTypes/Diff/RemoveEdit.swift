//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

struct RemoveEdit: Codable, Equatable {

    init(index: Int, count: Int) {
        self.action = .remove
        self.index = index
        self.count = count
    }

    let action: Edit2.Action
    let index: Int
    let count: Int
}
