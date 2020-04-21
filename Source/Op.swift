//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

enum Primitives: Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
}

enum DataType: Equatable {
    case counter
    case timestamp
}

public struct Op: Equatable {

    enum Key: Equatable {
        case string(String)
        case index(Int)
    }

    init(action: OpAction, obj: UUID, key: Op.Key, insert: Bool? = nil, child: UUID? = nil, value: Primitives? = nil, datatype: DataType? = nil) {
        self.action = action
        self.obj = obj
        self.key = key
        self.insert = insert
        self.child = child
        self.value = value
        self.datatype = datatype
    }

    var action: OpAction
    var obj: UUID
    var key: Key
    var insert: Bool?
    var child: UUID?
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
