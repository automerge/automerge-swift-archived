//
//  Proxy+Table.swift
//  Automerge
//
//  Created by Lukas Schmidt on 13.06.20.
//

import Foundation

public extension Proxy {

    @discardableResult
    func add<Row: Codable>(_ row: Row) -> String where T == Table<Row>  {
        guard let encoded = (try? DictionaryEncoder().encode(row)) else {
            fatalError()
        }
        return context.addTableRow(path: path, row: encoded)
    }

    func row<Row: Codable>(by rowId: String) -> Proxy<Row>? where T == Table<Row> {
        guard let container = get().row(by: rowId) else {
            return nil
        }
        let objectId = container.objectId
        return Proxy<Row>(context: context, objectId: objectId, path: path + [.init(key: .string(rowId), objectId: objectId)], value: container.value)
    }

    /**
     Removes the row with ID `id` from the table. Throws an exception if the row
     does not exist in the table.
    */
    func removeRow(by rowId: String) {
        context.deleteTableRow(path: path, rowId: rowId)
    }

}
