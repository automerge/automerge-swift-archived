//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public enum DataType: String, Equatable, Codable {
    case counter
    case timestamp
}

public struct Op: Equatable, Codable {

    init(action: OpAction, obj: ObjectId, key: Key, insert: Bool = false, child: ObjectId? = nil, value: Primitive? = nil, datatype: DataType? = nil) {
        self.action = action
        self.obj = obj
        self.key = key
        self.insert = insert
        self.child = child
        self.value = value
        self.datatype = datatype
    }

    public let action: OpAction
    public let obj: ObjectId
    public let key: Key
    public let insert: Bool
    public let child: ObjectId?
    public let value: Primitive?
    public let datatype: DataType?
}

public enum OpAction: String, Codable {
    case del
    case inc
    case set
    case link
    case makeText
    case makeTable
    case makeList
    case makeMap
}
