//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 21.04.20.
//

import Foundation

struct Text: Equatable {
    init(_ content: String) {
        self.elms = Array(content)
    }
    var elms: [Character]
}
