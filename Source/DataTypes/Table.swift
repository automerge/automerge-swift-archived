//
//  Table.swift
//  
//
//  Created by Lukas Schmidt on 19.04.20.
//

import Foundation

/// A data structure that represents a table of rows.
public struct Table<RowValue: Codable>: Codable {
    
    /// A data structure that represents a row within a table.
    public struct Row<T: Codable> {

        init(id: ObjectId, object: Object) {
            self.id = id
            self.object = object
        }
        
        /// The ID of the row.
        public let id: ObjectId
        /// The value of the row.
        public var value: T {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let json = try! encoder.encode(object)
            return try! decoder.decode(T.self, from: json)
        }
        private let object: Object
    }
    
    /// Creates a new, empty row.
    public init () {
        self.entries = [:]
        self.objectId = ""
        self.opIds = [:]
    }

    init(tableValues: [ObjectId: Object], objectId: ObjectId = ObjectId(""), opIds: [ObjectId: ObjectId] = [:]) {
        self.entries = tableValues
        self.objectId = objectId
        self.opIds = opIds
    }

    enum CodingKeys: String, CodingKey {
        case entries = "_am_tabel_values_"
        case objectId
        case opIds
    }

    private var entries: [ObjectId: Object]
    let objectId: ObjectId
    var opIds: [ObjectId: ObjectId]
    
    /// Returns a row for a table with the object ID you provide.
    /// - Parameter id: The ObjectId of the row.
    /// - Returns: Returns the row, or nil if the ObjectId you provided doesn't exist.
    public func row(by id: ObjectId) -> Row<RowValue>? {
        guard let row = entries[id] else {
            return nil
        }
        return Row(id: id, object: row)
    }
    
    /// The number of entries in the row.
    public var count: Int {
        return entries.count
    }
    
    /// A set of the objectIds contained within the row.
    public var ids: Set<ObjectId> {
        return Set(entries.keys)
    }

    subscript(_ objectId: ObjectId) -> Object? {
        get {
            return entries[objectId]
        }
        set {
            entries[objectId] = newValue
        }
    }

}

extension Table.Row: Equatable where T: Equatable {}

extension Table: Equatable where RowValue: Equatable { }

extension Table: Sequence {
    public func makeIterator() -> AnyIterator<Row<RowValue>> {
        return AnyIterator(entries.map({ Row<RowValue>(id: $0.key, object: $0.value) }).makeIterator())
    }
}
