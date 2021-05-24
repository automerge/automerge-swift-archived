//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 20.05.21.
//

import Foundation

struct ObjectEncoding: Encoder {

    final class Data {
        var root: Object = .map([:])

        func encode(key codingKey: [CodingKey], value: Object) {
            root.set(value: value, at: codingKey)
        }
    }

    let data: Data

    init(encodedData: Data, codingPath: [CodingKey] = []) {
        self.data = encodedData
        self.codingPath = codingPath
    }

    let codingPath: [CodingKey]

    let userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = ObjectsKeyedEncoding<Key>(data: data, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return ObjectsUnkeyedEncoding(data: data, codingPath: codingPath)
   }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return ObjectsSingleValueEncoding(data: data, codingPath: codingPath)
    }
}
