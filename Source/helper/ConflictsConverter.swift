//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 29.04.20.
//

import Foundation

extension Array where Element == [String: Any]? {

    init(_ values: [Key: [String: Any]]) {
        var result = Array<[String: Any]?>(repeating: nil, count: values.count)
        for key in values.keys {
            guard case .index(let index) = key else {
                fatalError()
            }
            result[index] = values[key]!
        }

        self = result.compactMap({ $0 })
    }

}

extension Array where Element == [String: Object]? {

    init(_ values: [Int: [String: Object]]) {
        var result = Array<[String: Object]?>(repeating: nil, count: values.count)
        for key in values.keys {
            result[key] = values[key]!
        }

        self = result.compactMap({ $0 })
    }

}

extension Dictionary where Key == Automerge.Key, Value == [String: Any] {

    init(_ values: [[String: Any]?]) {
        var result = [Key: [String: Any]]()
        for (index, value) in values.enumerated() {
            result[.index(index)] = value
        }

        self = result
    }

}

extension Dictionary where Key == Int, Value == [String: Object] {

    init(_ values: [[String: Object]?]) {
        var result = [Int: [String: Object]]()
        for (index, value) in values.enumerated() {
            result[index] = value
        }

        self = result
    }

}
