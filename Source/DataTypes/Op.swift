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

    init(
        action: OpAction,
        obj: ObjectId,
        key: Key? = nil,
        elemId: ObjectId? = nil,
        insert: Bool = false,
        value: Primitive? = nil,
        datatype: DataType? = nil,
        pred: [ObjectId]?
    ) {
        self.action = action
        self.obj = obj
        self.key = key
        self.elemId = elemId
        self.insert = insert
        self.value = value
        self.datatype = datatype
        self.pred = pred
    }

    public let action: OpAction
    public let obj: ObjectId
    public let key: Key?
    public let elemId: ObjectId?
    public let insert: Bool
    public let value: Primitive?
    public let datatype: DataType?
    public let pred: [ObjectId]?
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
