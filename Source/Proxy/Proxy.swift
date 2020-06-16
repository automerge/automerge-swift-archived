//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

@dynamicMemberLookup
public final class Proxy<T: Codable> {

    init(
        context: Context,
        objectId: String?,
        path: [Context.KeyPathElement],
        value: @escaping () -> T?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.valueResolver = value
    }

    init(
        context: Context,
        objectId: String?,
        path: [Context.KeyPathElement],
        value: @autoclosure @escaping () -> T?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.valueResolver = value
    }

    public let objectId: String?
    let context: Context
    let path: [Context.KeyPathElement]
    private let valueResolver: () -> T?

    public func get() -> T {
        return valueResolver()!
    }

    public func conflicts<Y: Codable>(dynamicMember: KeyPath<T, Y>) -> [String: Y]? {
        guard let objectId = objectId else {
            return nil
        }
        let object = context.getObject(objectId: objectId)
        guard let conflicts = object[CONFLICTS] as? [Key: Any] else {
            return nil
        }
        guard let fieldName = dynamicMember.fieldName, let realConflicts = conflicts[.string(fieldName)] as? [String: Any], realConflicts.count > 1 else {
            return nil
        }
        let decoder = DictionaryDecoder()
        return try? decoder.decode([String: Y].self, from: realConflicts)
    }


    public subscript<Y>(dynamicMember dynamicMember: KeyPath<T, Y>) -> Proxy<Y> {
        let fieldName = dynamicMember.fieldName!
        let object = self.objectId.map { context.getObject(objectId: $0) }
        let objectId = (object?[fieldName] as? [String: Any])?[OBJECT_ID] as? String
        return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    public subscript<Y>(dynamicMember dynamicMember: KeyPath<T, Y?>) -> Proxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        let object = self.objectId.map { context.getObject(objectId: $0) }
        let objectId = (object?[fieldName] as? [String: Any])?[OBJECT_ID] as? String
        return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    private func set(rootObject: T) {
        let dictionary = try! DictionaryEncoder().encode(rootObject) as [String: Any]
        for key in dictionary.keys {
            context.setMapKey(path: path, key: key, value: dictionary[key])
        }
    }

    public func set(_ newValue: T) {
        guard let lastPathKey = path.last?.key else {
            self.set(rootObject: newValue)
            return
        }
        let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
        switch lastPathKey {
        case .string(let key):
            let path = Array(self.path.dropLast())
            context.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            let path = Array(self.path.dropLast())
            context.setListIndex(path: path, index: index, value: encoded)
        }
    }
}

extension Proxy where T: RawRepresentable {

    public func set(_ newValue: T) {
        guard let lastPathKey = path.last?.key else {
            self.set(rootObject: newValue)
            return
        }
        let encoded: Any = newValue.rawValue
        switch lastPathKey {
        case .string(let key):
            let path = Array(self.path.dropLast())
            context.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            let path = Array(self.path.dropLast())
            context.setListIndex(path: path, index: index, value: encoded)
        }
    }

}
