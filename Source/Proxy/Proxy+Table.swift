//
//  Proxy+Table.swift
//  Automerge
//
//  Created by Lukas Schmidt on 13.06.20.
//

import Foundation

public extension Proxy {

    @discardableResult
    func add<Row: Codable>(_ row: Row) -> ObjectId where Wrapped == Table<Row>  {
        let row: Object = try! TypeToObject().map(row)

        return context.addTableRow(path: path, row: row)
    }

    func row<Row: Codable>(by rowId: ObjectId) -> Proxy<Row>? where Wrapped == Table<Row> {
        guard case .table(let table) = context.getObject(objectId: objectId!),
              let row = table[rowId],
              let objectId = row.objectId else {
            return nil
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let json = try! encoder.encode(row)
        return Proxy<Row>(context: context, objectId: objectId, path: path + [.init(key: .string(rowId.objectId), objectId: objectId)], value: try! decoder.decode(Row.self, from: json))
    }

    /**
     Removes the row with ID `id` from the table. Throws an exception if the row
     does not exist in the table.
    */
    func removeRow(by rowId: ObjectId) {
//        context.deleteTableRow(path: path, rowId: rowId, pred: )
        fatalError()
    }

}
