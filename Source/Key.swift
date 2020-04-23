//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 23.04.20.
//

import Foundation

enum Key: Equatable, Hashable {

    case string(String)
    case index(Int)
}

extension Key: ExpressibleByStringLiteral {

    init(stringLiteral value: String) {
        self = .string(value)
    }

}

extension Key: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .index(value)
    }
}
