//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public struct Counter: Codable, Equatable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    enum CodingKeys: String, CodingKey  {
        case value = "_am_counter_value_"
    }
}

extension Counter: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: Int) {
        self = Counter(value)
    }

}
