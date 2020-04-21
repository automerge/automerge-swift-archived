//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 20.04.20.
//

import Foundation

struct Conflicts {

    struct Conflict {
        init(_ store: NSMutableDictionary) {
            self.store = store
        }

        fileprivate let store: NSMutableDictionary

        subscript(_ key: String) -> Diff? {
            get {
                store[key] as? Diff
            }

            set {
                store[key] = newValue
            }

        }
    }

    init(_ store: NSMutableDictionary) {
        self.store = store
    }

    fileprivate let store: NSMutableDictionary

    var keys: [String] {
        return store.allKeys as! [String]
    }

    subscript(_ key: String) -> Conflict? {
        get {
            Conflict(store[key] as! NSMutableDictionary)
        }

        set {
            store[key] = newValue?.store
        }

    }
}
