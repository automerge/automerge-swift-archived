//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 26.04.21.
//

import Foundation

typealias Props = [Key: [ObjectId: Diff]]

extension Props {

    subscript(_ key: String) -> [ObjectId: Diff]? {
        get {
            return self[.string(key)]
        }
        set {
            self[.string(key)] = newValue
        }
    }

    subscript(_ index: Int) -> [ObjectId: Diff]? {
        get {
            return self[.index(index)]
        }
        set {
            self[.index(index)] = newValue
        }
    }
}
