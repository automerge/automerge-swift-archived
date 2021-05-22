//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 20.05.21.
//

import Foundation

struct ObjectsKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {

    private let data: ObjectEncoding.Data

    init(data: ObjectEncoding.Data, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath

        data.root.set(value: .map([:]), at: codingPath)
    }

    let codingPath: [CodingKey]

    mutating func encodeNil(forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.null))
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.bool(value)))
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.string(value)))
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(value)))
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: .primitive(.number(Double(value))))
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let codingPath = self.codingPath + [key]
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

    mutating func encode<T: Encodable>(_ value: Table<T>, forKey key: Key) throws {
        fatalError()
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let container = ObjectsKeyedEncoding<NestedKey>(data: data, codingPath: codingPath + [key])
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return ObjectsUnkeyedEncoding(data: data, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        let superKey = Key(stringValue: "super")!
        return superEncoder(forKey: superKey)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return ObjectEncoding(encodedData: data, codingPath: codingPath + [key])
    }
}
