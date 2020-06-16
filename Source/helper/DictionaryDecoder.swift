//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 26.04.20.
//

import Foundation

final class DictionaryDecoder {

    private let decoder: JSONDecoder = {
        let deocder = JSONDecoder()
        deocder.dateDecodingStrategy = .secondsSince1970
        return deocder
    }()

    func decode<T>(_ type: T.Type, from dictionary: [String: Any]) throws -> T where T : Decodable {
        let clearDict = removeConflicts(dictionary, removeObjectId: true)
        let data = try JSONSerialization.data(withJSONObject: clearDict, options: [])
        return try decoder.decode(type, from: data)
    }

    private func removeConflicts(_ dict: [String: Any], removeObjectId: Bool) -> Any {
        var dict = dict
        dict[CONFLICTS] = nil
        dict[CACHE] = nil
        if removeObjectId {
            dict[OBJECT_ID] = nil
        }
        for key in dict.keys where key != OBJECT_ID {
            if let childDict = dict[key] as? [String: Any] {
                if childDict[TABLE_VALUES] != nil {
                    dict[key] = removeTableRow(childDict)
                    continue
                } else {
                    dict[key] = removeConflicts(childDict, removeObjectId: true)
                }
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

    private func removeTableRow(_ dict: [String: Any]) -> Any {
        var dict = dict
        dict[CONFLICTS] = nil
        dict[CACHE] = nil
        dict[OBJECT_ID] = nil
        guard var entries = dict[TABLE_VALUES] as? [String: Any] else {
            fatalError()
        }
        for key in entries.keys where key != OBJECT_ID {
            if let childDict = entries[key] as? [String: Any] {
                entries[key] = removeConflicts(childDict, removeObjectId: false)
            }
            if let childDict = entries[key] as? [String: Any], let list = childDict[LIST_VALUES] as? [Any] {
                entries[key] = removeListValues(list: list)
            }

            if let list = entries[LIST_VALUES] as? [Any] {
                entries[key] = removeListValues(list: list)
            }

            if let value = entries[key] as? Primitive {
                entries[key] = value.value
            }
        }
        dict[TABLE_VALUES] = entries
        return dict
    }

    private func removeListValues(list: [Any]) -> [Any?] {
        if let objects = list as? [[String: Any]] {
            let mapped = objects.map({ removeConflicts($0, removeObjectId: true) }).map { any -> Any in
                if let dict = any as? [String: Any], let list = dict[LIST_VALUES] as? [Any] {
                    return list
                }
                return any
            }
            return mapped
        }
        if let primitives = list as? [Primitive] {
            return primitives.map(\.value)
        }
        if let nested = list as? [[Any]] {
            return nested.map(removeListValues)
        }
        return list
    }

}
