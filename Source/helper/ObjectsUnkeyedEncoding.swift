//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 20.05.21.
//

import Foundation

struct ObjectsUnkeyedEncoding: UnkeyedEncodingContainer {

    private let data: ObjectEncoding.Data

    init(data: ObjectEncoding.Data, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath
        if codingPath.map({ $0.stringValue }).last == "_am_tabel_values_" {
            data.root.set(value: .table(Table(tableValues: [:])), at: codingPath.map({ $0.stringValue }).dropLast())
        }
        data.root.set(value: .list([]), at: codingPath.map({ $0.stringValue }))
    }

    let codingPath: [CodingKey]
    private(set) var count: Int = 0

    private mutating func nextIndexedKey() -> CodingKey {
        let nextCodingKey = IndexedCodingKey(intValue: count)!
        count += 1
        return nextCodingKey
    }

    private struct IndexedCodingKey: CodingKey {
        let intValue: Int?
        let stringValue: String

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = intValue.description
        }

        init?(stringValue: String) {
            return nil
        }
    }

    mutating func encodeNil() throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.null))
    }

    mutating func encode(_ value: Bool) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.bool(value)))
    }

    mutating func encode(_ value: String) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.string(value)))
    }

    mutating func encode(_ value: Double) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(value)))
    }

    mutating func encode(_ value: Float) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int8) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int16) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int32) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int64) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt8) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt16) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt32) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt64) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: .primitive(.number(Double(value))))
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let codingPath = codingPath + [nextIndexedKey()]
        if let date = value as? Date {
            data.encode(key: codingPath, value: .date(date))
            return
        }
        if let counter = value as? Counter {
            data.encode(key: codingPath, value: .counter(counter))
            return
        }
        if let text = value as? Text {
            data.encode(key: codingPath, value: .text(text))
            return
        }
        let stringsEncoding = ObjectEncoding(encodedData: data, codingPath: codingPath)

        try value.encode(to: stringsEncoding)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let container = ObjectsKeyedEncoding<NestedKey>(data: data, codingPath: codingPath + [nextIndexedKey()])
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return ObjectsUnkeyedEncoding(data: data, codingPath: codingPath + [nextIndexedKey()])
    }

    mutating func superEncoder() -> Encoder {
        return ObjectEncoding(encodedData: data, codingPath: [nextIndexedKey()])
    }
}
