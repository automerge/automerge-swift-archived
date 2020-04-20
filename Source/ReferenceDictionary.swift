//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 18.04.20.
//

import Foundation

@dynamicMemberLookup
final class ReferenceDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral {
    var store: Dictionary<Key, Value>

    init(dictionaryLiteral elements: (Key, Value)...) {
        store = Dictionary(uniqueKeysWithValues: elements)
    }

    init(_ dictionary: Dictionary<Key, Value> = [:]) {
        store = dictionary
    }

    subscript<T>(dynamicMember keyPath: KeyPath<Dictionary<Key, Value>, T>) -> T {
        return store[keyPath: keyPath]
    }

    subscript(_ key: Key) -> Value? {
        get {
            return store[key]
        }
        set(newValue) {
            store[key] = newValue
        }
    }
}

extension ReferenceDictionary: Equatable where Value: Equatable {

    static func ==(lhs: ReferenceDictionary<Key, Value>, rhs: ReferenceDictionary<Key, Value>) -> Bool {
        return lhs.store == rhs.store
    }

}

extension ReferenceDictionary where Key == String {
    subscript(_ key: UUID) -> Value? {
        get {
            return store[key.uuidString]
        }
        set(newValue) {
            store[key.uuidString] = newValue
        }
    }
}
