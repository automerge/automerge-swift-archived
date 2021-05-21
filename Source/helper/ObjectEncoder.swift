//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

/// An object that encodes instances of a data type
/// as strings following the simple strings file format.
final class ObjectEncoder {

    /// Returns a strings file-encoded representation of the specified value.
    func encode<T: Encodable>(_ value: T) throws -> Object {
        let stringsEncoding = ObjectEncoding(encodedData: ObjectEncoding.Data())
        if let date = value as? Date {
            return .date(date)
        }
        if let counter = value as? Counter {
            return .counter(counter)
        }
        if let text = value as? Text {
            return .text(text)
        }
        try value.encode(to: stringsEncoding)
        let object = stringsEncoding.data.root
        return object
    }

    func encode<T: Encodable>(_ value: Table<T>) throws -> Object {
        var entries: [ObjectId: Object] = [:]
        for id in value.ids {
            entries[id] = try encode(value[id])
        }
        return .table(Table(tableValues: entries))
    }
}


