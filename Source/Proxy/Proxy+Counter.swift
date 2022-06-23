//
//  Proxy+Counter.swift
//  Automerge
//
//  Created by Lukas Schmidt on 26.05.20.
//

import Foundation

public extension Proxy where Wrapped == Counter {
    
    /// Increments the counter by the value you provide.
    /// - Parameter delta: The amount to increment the counter, defaults to `1`.
    func increment(_ delta: Int = 1) {
        var path = self.path
        let pathComponent = path.popLast()
        context.increment(path: path, key: pathComponent!.key, delta: delta)
    }
    
    /// Decrements the counter by the value you provide.
    /// - Parameter delta: The amount to decrement the counter, defaults to `1`.
    func decrement(_ delta: Int = -1) {
        increment(delta)
    }
    
    /// Subtracts the second value from the counter by performing a `decrement`.
    ///
    /// - Parameters:
    ///   - lhs: A Counter
    ///   - rhs: The value to subtract from `lhs`.
    static func -=(lhs: Proxy, rhs: Int) {
        lhs.decrement(-rhs)
    }
    
    /// Adds the second value to the counter by performing an `increment`.
    ///
    /// - Parameters:
    ///   - lhs: A Counter
    ///   - rhs: The value to add to `lhs`.
    static func +=(lhs: Proxy, rhs: Int) {
        lhs.increment(rhs)
    }
}

public extension Proxy where Wrapped == Optional<Counter> {
    /// Increments the counter by the value you provide.
    /// - Parameter delta: The amount to increment the counter, defaults to `1`.
    func increment(_ delta: Int = 1) {
        var path = self.path
        let pathComponent = path.popLast()
        context.increment(path: path, key: pathComponent!.key, delta: delta)
    }
    
    /// Decrements the counter by the value you provide.
    /// - Parameter delta: The amount to decrement the counter, defaults to `1`.
    func decrement(_ delta: Int = -1) {
        increment(delta)
    }
    
    /// Subtracts the second value from the counter by performing a `decrement`.
    ///
    /// - Parameters:
    ///   - lhs: A Counter
    ///   - rhs: The value to subtract from `lhs`.
    static func -=(lhs: Proxy, rhs: Int) {
        lhs.decrement(-rhs)
    }
    
    /// Adds the second value to the counter by performing an `increment`.
    ///
    /// - Parameters:
    ///   - lhs: A Counter
    ///   - rhs: The value to add to `lhs`.
    static func +=(lhs: Proxy, rhs: Int) {
        lhs.increment(rhs)
    }
}

