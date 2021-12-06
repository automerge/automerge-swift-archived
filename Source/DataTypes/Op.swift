//
//  Op.swift
//  Automerge
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

// The data type associated with the operation.
public enum DataType: String, Equatable, Codable {
    case counter
    case timestamp
    case int
    case uint
    case float64
}

/// A struct that represents a unique operation that makes up the change history of an Automerge document.
public struct Op: Equatable, Codable {
    
    /// Creates a new operation with the values you provide.
    /// - Parameters:
    ///   - action: The action that the operation represents.
    ///   - obj: The object ID that the operation creates.
    ///   - key:
    ///   - elemId:
    ///   - insert: A Boolean value that indicates whether the operation is an insertion.
    ///   - value: An optional primitive that represents the value of the operation.
    ///   - values: An optional list of primitives that represent the value of the operation.
    ///   - datatype: The type of data associated with the operation.
    ///   - pred:
    ///   - multiOp:
    init(
        action: OpAction,
        obj: ObjectId,
        key: Key? = nil,
        elemId: ObjectId? = nil,
        insert: Bool = false,
        value: Primitive? = nil,
        values: [Primitive]? = nil,
        datatype: DataType? = nil,
        pred: [ObjectId]?,
        multiOp: Int? = nil
    ) {
        self.action = action
        self.obj = obj
        self.key = key
        self.elemId = elemId
        self.insert = insert
        self.value = value
        self.values = values
        self.datatype = datatype
        self.pred = pred
        self.multiOp = multiOp
    }

    public let action: OpAction
    public let obj: ObjectId
    public let key: Key?
    public let elemId: ObjectId?
    public let insert: Bool
    public let value: Primitive?
    public let values: [Primitive]?
    public let datatype: DataType?
    public let pred: [ObjectId]?
    public var multiOp: Int?
}

/// The kind of operation that Automerge performs to maintain the state of a Document.
public enum OpAction: String, Codable {
    /// A operation that deletes a value.
    case del
    /// An operation that increments a value.
    case inc
    /// An operation that sets a value.
    case set
    /// An operation that links to a value.
    case link
    /// An operation that creates a Text object.
    case makeText
    /// An operation that creates a Table object.
    case makeTable
    /// An operation that creates a List object.
    case makeList
    /// An operation that creates a Map object.
    case makeMap
}
