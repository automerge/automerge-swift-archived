//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.20.
//

import Foundation

public struct Table<RowValue: Codable>: Codable {

    @dynamicMemberLookup
    public struct Row<T: Codable>: Codable {

        init(id: String, value: T, objectId: String) {
            self.id = id
            self.objectId = objectId
            self.value = value
        }

        public let objectId: String
        public internal(set) var id: String! // Hacky
        public let value: T

        enum CodingKeys: String, CodingKey {
            case objectId = "_am_objectId_"
        }

        public init(from decoder: Decoder) throws {
            let singleKeyContainer = try decoder.singleValueContainer()
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.objectId = try container.decode(String.self, forKey: .objectId)
            self.value = try singleKeyContainer.decode(T.self)
        }

        public subscript<Y>(dynamicMember dynamicMember: KeyPath<T, Y>) -> Y {
            return value[keyPath: dynamicMember]
        }
    }

    public init() {
        self.entries = [:]
    }

    enum CodingKeys: String, CodingKey {
        case entries = "_am_tabel_values_"
    }

    let entries: [String: Row<RowValue>]

    public func row(by id: String) -> Row<RowValue>? {
        guard var row = entries[id] else {
            return nil
        }
        row.id = id
        return row
    }

    public var count: Int {
        return entries.count
    }

    public var ids: Set<String> {
        return Set(entries.keys)
    }


}

extension Table.Row: Equatable where T: Equatable {}

extension Table: Equatable where RowValue: Equatable { }

extension Table: Sequence {
    public func makeIterator() -> AnyIterator<Row<RowValue>> {
        return AnyIterator(entries.values.makeIterator())
    }
}
