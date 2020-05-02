//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

enum Primitives: Equatable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case null

    var value: Any? {
        switch self {
        case .string(let stringValue):
            return stringValue
        case .double(let doubleValue):
            return doubleValue
        case .int(let intValue):
            return intValue
        case .bool(let boolValue):
            return boolValue
        case .null:
            return nil
        }
    }
}

enum DataType: Equatable {
    case counter
    case timestamp
}

public struct Op: Equatable {

    init(action: OpAction, obj: String, key: Key, insert: Bool? = nil, child: String? = nil, value: Primitives? = nil, datatype: DataType? = nil) {
        self.action = action
        self.obj = obj
        self.key = key
        self.insert = insert
        self.child = child
        self.value = value
        self.datatype = datatype
    }

    var action: OpAction
    var obj: String
    var key: Key
    var insert: Bool?
    var child: String?
    var value: Primitives?
    var datatype: DataType?
}

enum OpAction {
    case del
    case inc
    case set
    case link
    case makeText
    case makeTable
    case makeList
    case makeMap
}
