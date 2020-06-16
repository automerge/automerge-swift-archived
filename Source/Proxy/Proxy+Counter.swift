//
//  Proxy+Counter.swift
//  Automerge
//
//  Created by Lukas Schmidt on 26.05.20.
//

import Foundation

public extension Proxy where Wrapped == Counter {

    func increment(_ value: Int = 1) {
        var path = self.path
        let pathComponent = path.popLast()
        context.increment(path: path, key: pathComponent!.key, delta: value)
    }

    func decrement(_ value: Int = -1) {
       increment(value)
    }

}

