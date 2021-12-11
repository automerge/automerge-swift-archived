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

}

