//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 26.04.20.
//

import Foundation

@dynamicMemberLookup
class DictionaryEncoder {

    private let encoder = JSONEncoder()

    subscript<T>(dynamicMember keyPath: WritableKeyPath<JSONEncoder, T>) -> T {
        return encoder[keyPath: keyPath]
    }

    func encode<T>(_ value: T) throws -> [String: Any] where T : Encodable {
        let data = try encoder.encode(value)
        guard let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
        return obj
    }

    func encode<T>(_ value: [T]) throws -> [[String: Any]] where T : Encodable {
        let data = try encoder.encode(value)
        guard let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: Any]] else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
        return obj
    }
}

@dynamicMemberLookup
class DictionaryDecoder {

    private let decoder = JSONDecoder()

    subscript<T>(dynamicMember keyPath: WritableKeyPath<JSONDecoder, T>) -> T {
        return decoder[keyPath: keyPath]
    }

    func decode<T>(_ type: T.Type, from dictionary: [String: Any]) throws -> T where T : Decodable {
        let clearDict = removeConflicts(dictionary)
        let data = try JSONSerialization.data(withJSONObject: clearDict, options: [])
        return try decoder.decode(type, from: data)
    }

    func decodeList<T>(from array: [[String: Any]]) throws -> T where T : Decodable {
        let clearArray = array.map { removeConflicts($0) }
        let data = try JSONSerialization.data(withJSONObject: clearArray, options: [.fragmentsAllowed])
        return try decoder.decode(T.self, from: data)
    }
}

private func removeConflicts(_ dict: [String: Any]) -> Any {
    var dict = dict
    dict[CONFLICTS] = nil
    for key in dict.keys {
        if let childDict = dict[key] as? [String: Any] {
            dict[key] = removeConflicts(childDict)
        }
        if let childDict = dict[key] as? [String: Any], let list = childDict[LIST_VALUES] as? [Any] {
            dict[key] = removeListValues(list: list)
        }

        if let list = dict[LIST_VALUES] as? [Any] {
            dict[key] = removeListValues(list: list)
        }

        if let value = dict[key] as? Primitive {
            dict[key] = value.value
        }
    }

    return dict
}

private func removeListValues(list: [Any]) -> [Any?] {
    if let objects = list as? [[String: Any]] {
        return objects.map(removeConflicts)
    }
    if let primitives = list as? [Primitive] {
        return primitives.map(\.value)
    }
    if let nested = list as? [[Any]] {
        return nested.map(removeListValues)
    }
    return list
}
