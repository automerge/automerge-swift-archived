//
//  Counter.swift
//  Automerge
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

/// A data structure that represents a counter.
public struct Counter: Codable, Equatable {
    /// The value of the counter.
    public let value: Int
    
    /// Creates a new counter with the value you provide.
    /// - Parameter value: The value for the counter.
    public init(_ value: Int) {
        self.value = value
    }

}

extension Counter: ExpressibleByIntegerLiteral {
    
    /// Creates a counter from the string representation provided.
    /// - Parameter value: The string representation of the counter.
    public init(integerLiteral value: Int) {
        self = Counter(value)
    }

}
