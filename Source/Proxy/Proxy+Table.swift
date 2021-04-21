//
//  Proxy+Table.swift
//  Automerge
//
//  Created by Lukas Schmidt on 13.06.20.
//

import Foundation

public extension Proxy {

    @discardableResult
    func add<Row: Codable>(_ row: Row) -> String where Wrapped == Table<Row>  {
        let row: Object = try! TypeToObject().map(row)

        return context.addTableRow(path: path, row: row)
    }

    func row<Row: Codable>(by rowId: String) -> Proxy<Row>? where Wrapped == Table<Row> {
        guard let container = get().entries[rowId], let objectId = container.objectId else {
            return nil
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let json = try! encoder.encode(container)
        return Proxy<Row>(context: context, objectId: objectId, path: path + [.init(key: .string(rowId), objectId: objectId)], value: try! decoder.decode(Row.self, from: json))
    }

    /**
     Removes the row with ID `id` from the table. Throws an exception if the row
     does not exist in the table.
    */
    func removeRow(by rowId: String) {
        context.deleteTableRow(path: path, rowId: rowId)
    }

}
