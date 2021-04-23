//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.20.
//

import Foundation

public struct Table<RowValue: Codable>: Codable {

    public struct Row<T: Codable> {

        init(id: ObjectId, object: Object) {
            self.id = id
            self.object = object
        }

        public let id: ObjectId
        public var value: T {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let json = try! encoder.encode(object)
            return try! decoder.decode(T.self, from: json)
        }
        private let object: Object
    }

    init(tableValues: [ObjectId: Object], objectId: ObjectId = ObjectId(""), opIds: [ObjectId] = []) {
        self.entries = tableValues
        self.objectId = objectId
        self.opIds = opIds
    }

    enum CodingKeys: String, CodingKey {
        case entries = "_am_tabel_values_"
        case objectId
        case opIds
    }

    var entries: [ObjectId: Object]
    let objectId: ObjectId
    let opIds: [ObjectId]

    public func row(by id: ObjectId) -> Row<RowValue>? {
        guard let row = entries[id] else {
            return nil
        }
        return Row(id: id, object: row)
    }

    public var count: Int {
        return entries.count
    }

    public var ids: Set<ObjectId> {
        return Set(entries.keys)
    }


}

extension Table.Row: Equatable where T: Equatable {}

extension Table: Equatable where RowValue: Equatable { }

extension Table: Sequence {
    public func makeIterator() -> AnyIterator<Row<RowValue>> {
        return AnyIterator(entries.keys.map({ Row<RowValue>(id: $0, object: entries[$0]!) }).makeIterator())
    }
}
