//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

@dynamicMemberLookup
public final class Proxy<Wrapped: Codable> {

    init(
        context: Context,
        objectId: String?,
        path: [Context.KeyPathElement],
        value: @escaping () -> Wrapped?
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
        value: @autoclosure @escaping () -> Wrapped?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.valueResolver = value
    }

    public let objectId: String?
    let context: Context
    let path: [Context.KeyPathElement]
    private let valueResolver: () -> Wrapped?

    public func get() -> Wrapped {
        return valueResolver()!
    }


    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y>) -> Proxy<Y> {
        let fieldName = dynamicMember.fieldName!
        guard case .map(let map)? = self.objectId.map({ context.getObject(objectId: $0) }) else {
            fatalError()
        }
        let objectId = map.mapValues[fieldName]?.objectId
        return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y?>) -> Proxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        guard case .map(let map)? = self.objectId.map({ context.getObject(objectId: $0) }) else {
            fatalError()
        }
        let objectId = map.mapValues[fieldName]?.objectId
        return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    private func set<T: Codable>(rootObject: T) {
        let dictionary = try! DictionaryEncoder().encode(rootObject) as [String: Any]
        for key in dictionary.keys {
//            context.setMapKey(path: path, key: key, value: dictionary[key])
            #warning("fix me")
        }
    }

    private func set<T: Codable>(newValue: T) {
        guard let lastPathKey = path.last?.key else {
            self.set(rootObject: newValue)
            return
        }
        let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
        switch lastPathKey {
        case .string(let key):
            let path = Array(self.path.dropLast())
//            context.setMapKey(path: path, key: key, value: encoded)
            #warning("fix me")
        case .index(let index):
            let path = Array(self.path.dropLast())
//            context.setListIndex(path: path, index: index, value: encoded)
        }
    }

    public func set(_ newValue: Wrapped) {
        set(newValue: newValue)
    }
}

extension Proxy where Wrapped: RawRepresentable, Wrapped.RawValue: Codable {

    public func set(_ newValue: Wrapped) {
        set(newValue: newValue.rawValue)
    }

}
