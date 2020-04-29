//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 23.04.20.
//

import Foundation

public enum Key: Equatable, Hashable {

    case string(String)
    case index(Int)
}

extension Key: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .string(value)
    }

}

extension Key: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .index(value)
    }
}
