//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 21.05.21.
//

import Foundation

public final class MutableProxy<Wrapped> {

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

    lazy var objectToType = ObjectToTypeTransformer()
    lazy var typeToObject = ObjectToTypeTransformer()

    public func get() -> Wrapped {
        return valueResolver()!
    }

    private var map: Map {
        guard case .map(let map)? = objectId.map({ context.getObject(objectId: $0) }) else {
           fatalError("Must be map")
        }

        return map
    }

    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y>) -> Proxy<Y> {
        let fieldName = dynamicMember.fieldName!

        let objectId = map[fieldName]?.objectId
        return Proxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }

    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y?>) -> Proxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        let objectId = map[fieldName]?.objectId
        return Proxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }

    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<Wrapped, Y>) -> MutableProxy<Y> {
        let fieldName = dynamicMember.fieldName!

        let objectId = map[fieldName]?.objectId
        return MutableProxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }

    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<Wrapped, Y?>) -> MutableProxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        let objectId = map[fieldName]?.objectId
        return MutableProxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }

    func set(newValue: Object) {
        guard let lastPathKey = path.last?.key else {
            if case .map(let root) = newValue {
                set(rootObject: root)
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

    func set(rootObject: Map) {
        for (key, value) in rootObject {
            context.setMapKey(path: path, key: key, value: value)
        }
    }

}
