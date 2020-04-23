//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 18.04.20.
//

import Foundation

extension Dictionary where Key == String {
    subscript(_ key: UUID) -> Value? {
        get {
            return self[key.uuidString]
        }
        set(newValue) {
            self[key.uuidString] = newValue
        }
    }
}
