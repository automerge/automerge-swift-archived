//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

final class ObjectEncoder {

    func encode<T: Encodable>(_ value: T) throws -> Object {
        let objectEncoding = ObjectEncoding(encodedData: ObjectEncoding.Data())
        if let date = value as? Date {
            return .date(date)
        }
        if let counter = value as? Counter {
            return .counter(counter)
        }
        if let text = value as? Text {
            return .text(text)
        }
        try value.encode(to: objectEncoding)
        let object = objectEncoding.data.root
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

extension Object {

    mutating func set(value: Object, at keyPath: [CodingKey]) {
        guard keyPath.count != 0 else {
            self = value
            return
        }
        var keyPath = keyPath
        if case .map(var map) = self {
            let key = keyPath.removeFirst().stringValue
            if var valueAtKey = map[key] {
                valueAtKey.set(value: value, at: keyPath)
                map[key] = valueAtKey
            } else {
                map[key] = value
            }
            self = .map(map)
        } else if let key = keyPath.removeFirst().intValue,
                  case .list(var list) = self {
            if list.count <= key {
                list.append(value)
            } else {
                var valueAtKey = list[key]
                valueAtKey.set(value: value, at: keyPath)
                list[key] = valueAtKey
            }
            self = .list(list)
        }
    }
    
}


