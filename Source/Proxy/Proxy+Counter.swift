//
//  Proxy+Counter.swift
//  Automerge
//
//  Created by Lukas Schmidt on 26.05.20.
//

import Foundation

public extension Proxy where Wrapped == Counter {

    func increment(_ delta: Int = 1) {
        var path = self.path
        let pathComponent = path.popLast()
        context.increment(path: path, key: pathComponent!.key, delta: delta)
    }

    func decrement(_ delta: Int = -1) {
       increment(delta)
    }

}

