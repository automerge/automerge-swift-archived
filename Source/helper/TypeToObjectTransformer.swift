//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

final class EncoderDateFormatter: DateFormatter {

    override init() {
        super.init()
        self.dateFormat = "'_am_date:'yyyy-MM-dd'T'HH:mm:ss:SSSZZZZZ"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

final class TypeToObject {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let formatter = EncoderDateFormatter()
    let abcdEncoder = TypeToObjectEncoder()

    func map<T: Codable>(_ value: T) throws -> Object {
        let encoded = try abcdEncoder.encode(value)
        return encoded
    }

    func map<T: Codable>(_ value: Array<T>) throws -> [Object] {
        return try value.map { try abcdEncoder.encode($0) }
    }

    func map<T: Codable>(_ value: [String: T]) throws -> [String: Object] {
        encoder.dateEncodingStrategy = .formatted(formatter)
        decoder.dateDecodingStrategy = .formatted(formatter)
        let encoded = try encoder.encode(value)
        return try decoder.decode([String: Object].self, from: encoded)
    }
}

/// An object that encodes instances of a data type
/// as strings following the simple strings file format.
final class TypeToObjectEncoder {

    /// Returns a strings file-encoded representation of the specified value.
    func encode<T: Encodable>(_ value: T) throws -> Object {
        let stringsEncoding = StringsEncoding(to: StringsEncoding.Data())
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
        let object = stringsEncoding.data.object
        return object
    }

}

fileprivate struct StringsEncoding: Encoder {

    /// Stores the actual strings file data during encoding.
    fileprivate final class Data {
        var object: Object = .map(Map(objectId: "", mapValues: [:], conflicts: [:]))

        func encode(key codingKey: [CodingKey], value: Object) {
            if codingKey.isEmpty {
                object = value
            } else if case .primitive(.null) = value {

            } else {
                object.set(value: value, at: codingKey.map { $0.stringValue })
            }
        }
    }

    fileprivate var data: Data

    init(to encodedData: Data) {
        self.data = encodedData
    }

    var codingPath: [CodingKey] = []

    let userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        var container = StringsKeyedEncoding<Key>(to: data)
        container.codingPath = codingPath
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: data)
        container.codingPath = codingPath
        return container
   }

    func singleValueContainer() -> SingleValueEncodingContainer {
        var container = StringsSingleValueEncoding(to: data)
        container.codingPath = codingPath
        return container
    }
}

fileprivate struct StringsKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {

    private let data: StringsEncoding.Data

    init(to data: StringsEncoding.Data) {
        self.data = data
    }

    var codingPath: [CodingKey] = []

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
        var stringsEncoding = StringsEncoding(to: data)
        stringsEncoding.codingPath.append(key)
        if let list = value as? Array<Any> {
            data.object.set(value: .list(List(Array(repeating: .primitive(.null), count: list.count))), at: (self.codingPath + stringsEncoding.codingPath).map({ $0.stringValue }))
        } else {
            data.object.set(value: .map([:]), at: (self.codingPath + stringsEncoding.codingPath).map({ $0.stringValue }))
        }
        try value.encode(to: stringsEncoding)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        var container = StringsKeyedEncoding<NestedKey>(to: data)
        container.codingPath = codingPath + [key]
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: data)
        container.codingPath = codingPath + [key]
        return container
    }

    mutating func superEncoder() -> Encoder {
        let superKey = Key(stringValue: "super")!
        return superEncoder(forKey: superKey)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        var stringsEncoding = StringsEncoding(to: data)
        stringsEncoding.codingPath = codingPath + [key]
        return stringsEncoding
    }
}

fileprivate struct StringsUnkeyedEncoding: UnkeyedEncodingContainer {

    private let data: StringsEncoding.Data

    init(to data: StringsEncoding.Data) {
        self.data = data
    }

    var codingPath: [CodingKey] = []

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
        var stringsEncoding = StringsEncoding(to: data)
        stringsEncoding.codingPath = codingPath + [nextIndexedKey()]
        if let list = value as? Array<Any> {
            data.object.set(value: .list(List(Array(repeating: .primitive(.null), count: list.count))), at: stringsEncoding.codingPath.map({ $0.stringValue }))
        } else {
            data.object.set(value: .map([:]), at: stringsEncoding.codingPath.map({ $0.stringValue }))
        }

        try value.encode(to: stringsEncoding)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        var container = StringsKeyedEncoding<NestedKey>(to: data)
        container.codingPath = codingPath + [nextIndexedKey()]
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: data)
        container.codingPath = codingPath + [nextIndexedKey()]
        return container
    }

    mutating func superEncoder() -> Encoder {
        var stringsEncoding = StringsEncoding(to: data)
        stringsEncoding.codingPath.append(nextIndexedKey())
        return stringsEncoding
    }
}

fileprivate struct StringsSingleValueEncoding: SingleValueEncodingContainer {

    private let data: StringsEncoding.Data

    init(to data: StringsEncoding.Data) {
        self.data = data
    }

    var codingPath: [CodingKey] = []

    mutating func encodeNil() throws {
        data.encode(key: codingPath, value: .primitive(.null))
    }

    mutating func encode(_ value: Bool) throws {
        data.encode(key: codingPath, value: .primitive(.bool(value)))
    }

    mutating func encode(_ value: String) throws {
        data.encode(key: codingPath, value: .primitive(.string(value)))
    }

    mutating func encode(_ value: Double) throws {
        data.encode(key: codingPath, value: .primitive(.number(value)))
    }

    mutating func encode(_ value: Float) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int8) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int16) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int32) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: Int64) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt8) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt16) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt32) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode(_ value: UInt64) throws {
        data.encode(key: codingPath, value: .primitive(.number(Double(value))))
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        var stringsEncoding = StringsEncoding(to: data)
        stringsEncoding.codingPath = codingPath
        try value.encode(to: stringsEncoding)
    }
}
