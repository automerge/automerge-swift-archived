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
        objectId: ObjectId?,
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
        objectId: ObjectId?,
        path: [Context.KeyPathElement],
        value: @autoclosure @escaping () -> Wrapped?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.valueResolver = value
    }

    public let objectId: ObjectId?
    let context: Context
    let path: [Context.KeyPathElement]
    private let valueResolver: () -> Wrapped?

    public func get() -> Wrapped {
        return valueResolver()!
    }


    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y>) -> Proxy<Y> {
        let fieldName = dynamicMember.fieldName!
        var map: Map?
        if self.objectId != ObjectId(objectId: ""), case .map(let map2)? = self.objectId.map({ context.getObject(objectId: $0) })  {
            map = map2
        }

        let objectId = map?.mapValues[fieldName]?.objectId
        return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? ObjectId(objectId: ""))], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y?>) -> Proxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        guard case .map(let map)? = self.objectId.map({ context.getObject(objectId: $0) }) else {
            fatalError()
        }
        let objectId = map.mapValues[fieldName]?.objectId
        return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? ObjectId(objectId: ""))], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    private func set(rootObject: Map) {
        for (key, value) in rootObject.mapValues {
            context.setMapKey(path: path, key: key, value: value)
        }
    }

    func set(newValue: Object) {
        guard let lastPathKey = path.last?.key else {
            if case .map(let root) = newValue {
                self.set(rootObject: root)
            }
            return
        }
        switch lastPathKey {
        case .string(let key):
            let path = Array(self.path.dropLast())
            context.setMapKey(path: path, key: key, value: newValue)
        case .index(let index):
            let path = Array(self.path.dropLast())
            context.setListIndex(path: path, index: index, value: newValue)
        }
    }

    public func set(_ newValue: Wrapped) {
        let mapper = TypeToObject()
        let object = try! mapper.map(newValue)

        set(newValue: object)
    }
    
}
