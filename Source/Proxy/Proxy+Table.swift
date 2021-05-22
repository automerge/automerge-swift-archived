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
        let row: Object = try! objectEncoder.encode(row)

        return context.addTableRow(path: path, row: row)
    }

    func row<Row: Codable>(by rowId: ObjectId) -> Proxy<Row>? where Wrapped == Table<Row> {
        guard case .table(let table) = context.getObject(objectId: objectId!),
              let row = table[rowId],
              let objectId = row.objectId else {
            return nil
        }

        return Proxy<Row>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(rowId.objectId), objectId: objectId)],
            value: try! ObjectToTypeTransformer().map(row))
    }

    /**
     Removes the row with ID `id` from the table. Throws an exception if the row
     does not exist in the table.
    */
    func removeRow(by rowId: ObjectId) {
        guard case .table(let table) = context.getObject(objectId: objectId!) else {
            return
        }
        context.deleteTableRow(path: path, rowId: rowId, pred: table.opIds[rowId]!)

    }

}
