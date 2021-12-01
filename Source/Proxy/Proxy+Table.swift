//
//  Proxy+Table.swift
//  Automerge
//
//  Created by Lukas Schmidt on 13.06.20.
//

import Foundation

public extension Proxy {

    /// Adds a row you provide to the table model in your document.
    /// - Returns: <#description#>
    @discardableResult
    func add<Row: Codable>(_ row: Row) -> ObjectId where Wrapped == Table<Row>  {
        let row = try! objectEncoder.encode(row)

        return context.addTableRow(path: path, row: row)
    }
    
    /// Provides a proxy to the row in your table model associated with the id you provide.
    /// - Returns: An optional proxy to your row, nil if the provided Id isn't associated with a row.
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
            value: { [objectDecoder] in try! objectDecoder.decode(row) }
            )
    }

    /// Removes the row matching the provided id from your table model.
    /// - Parameter rowId: The id of the row to remove.
    ///
    /// Throws an exception if the row does not exist in the table.
    func removeRow(by rowId: ObjectId) {
        guard case .table(let table) = context.getObject(objectId: objectId!) else {
            return
        }
        context.deleteTableRow(path: path, rowId: rowId, pred: table.opIds[rowId]!)

    }

}
