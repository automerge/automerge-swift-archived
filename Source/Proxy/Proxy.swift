//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

@dynamicMemberLookup
public struct Proxy2<T: Codable> {

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

    var conflicts: [Key: Any]? {
        guard let objectId = objectId else {
            return nil
        }
        let object = context.getObject(objectId: objectId)

        return object[CONFLICTS] as? [Key: Any]
    }


    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<T, Y>) -> Proxy2<Y> {
        let fieldName = dynamicMember.fieldName!
        let object = self.objectId.map { context.getObject(objectId: $0) }
        let objectId = (object?[fieldName] as? [String: Any])?[OBJECT_ID] as? String
        return Proxy2<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
    }

    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<T, Y?>) -> Proxy2<Y>? {
        let fieldName = dynamicMember.fieldName!
        let object = self.objectId.map { context.getObject(objectId: $0) }
        let objectId = (object?[fieldName] as? [String: Any])?[OBJECT_ID] as? String
        return Proxy2<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
    }


    static func rootProxy<T>(context: Context) -> Proxy2<T> {
        return Proxy2<T>(context: context, objectId: ROOT_ID, path: [], value: {
            let object = context.getObject(objectId: ROOT_ID)
           return try? DictionaryDecoder().decode(T.self, from: object)
        })
    }

    public func set(_ newValue: T) {
        let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
        let path = Array(self.path.dropLast())
        switch path.last!.key {
        case .string(let key):
            context.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            context.setListIndex(path: path, index: index, value: encoded)
        }
    }

}


public final class Proxy<T: Codable> {

    convenience init(
        context: Context,
        objectId: String,
        path: [Context.KeyPathElement]
    ) {
        let object = context.getObject(objectId: objectId)
        let value: T?
        if let listValues = object[LIST_VALUES] as? [Primitive], let primitiveValues = listValues.map({ $0.value }) as? T {
            value = primitiveValues
        } else if let listObjects = object[LIST_VALUES] as? [[String: Any]], let objects = try? DictionaryDecoder().decodeList(from: listObjects) as T {
            value = objects
        } else {
             value = try? DictionaryDecoder().decode(T.self, from: object)
        }

        self.init(context: context, objectId: objectId, path: path, value: value)
    }

    init(
        context: Context,
        objectId: String,
        path: [Context.KeyPathElement],
        value: T?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.value = value
    }

    let objectId: String
    let context: Context
    let path: [Context.KeyPathElement]
    public internal(set) var value: T!

    var conflicts: [Key: Any]? {
        let object = context.getObject(objectId: objectId)
        return object[CONFLICTS] as? [Key: Any]
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y>, keyPathString: String) -> Y {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)!
        }
        set {
            value?[keyPath: keyPath] = newValue
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y?>, keyPathString: String) -> Y? {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)
        }
        set {
            value?[keyPath: keyPath] = newValue
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    subscript<Y: Codable>(keyPath: KeyPath<T, Y>, keyPathString: String) -> Proxy<Y>? {
        get {
            return getProxyByKeyPath(keyPathString.keyPath)
        }
    }

    func set(object: T) {
        let dictionary = try! DictionaryEncoder().encode(object) as! [String: Any]
        for key in dictionary.keys {
            context.setMapKey(path: path, key: key, value: dictionary[key])
        }
    }

    func getObjectByKeyPath<Y: Codable>(_ keyPath: [Key]) -> Y? {
        let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch context.getObject(objectId: taregtObjectId)[key] {
            case let primitives as Primitive:
                return primitives.value as? Y
            case let objectType as [String: Any]:
                let objectId = objectType[OBJECT_ID] as! String
                return Proxy<Y?>(context: context, objectId: objectId, path: path + [.init(key: .string(key), objectId: objectId)]).value
            case .none:
                return nil
            default:
                fatalError()
            }
        case .index(let index):
            switch context.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case let primitives as [Primitive]:
                return primitives[index].value as? Y
            case let listObjects as [[String: Any]]:
                let objectId = listObjects[index][OBJECT_ID] as! String
                return Proxy<Y?>(context: context, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId)]).value
            default:
                fatalError()
            }
        }
    }

    func getProxyByKeyPath<Y: Codable>(_ keyPath: [Key]) -> Proxy<Y>? {
        let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch context.getObject(objectId: taregtObjectId)[key] {
            case let primitive as Primitive:
                return Proxy<Y>(context: context, objectId: taregtObjectId, path: path + [.init(key: .string(key), objectId: objectId)], value: primitive.value as! Y)
            case let objectType as [String: Any]:
                if objectType[COUNTER_VALUE] != nil {
                    return Proxy<Y>(context: context, objectId: taregtObjectId, path: path + [.init(key: .string(key), objectId: objectId)], value: try! DictionaryDecoder().decode(Y.self, from: objectType))
                }
                let objectId = objectType[OBJECT_ID] as! String
                return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(key), objectId: objectId)])
            case .none:
                return nil
            default:
                fatalError()
            }
        case .index(let index):
            switch context.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case let primitives as [Primitive]:
                return Proxy<Y>(context: context, objectId: taregtObjectId, path: path + [.init(key: .index(index), objectId: objectId)], value: primitives[index].value as! Y)
            case let listObjects as [[String: Any]]:
                let objectId = listObjects[index][OBJECT_ID] as! String
                return Proxy<Y>(context: context, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId)])
            default:
                fatalError()
            }
        }
    }


    static func rootProxy<T>(context: Context) -> Proxy<T> {
        return Proxy<T>(context: context, objectId: ROOT_ID, path: [])
    }

    func setMapKey<Y: Codable>(_ keyPath: [Key], newValue: [Y]) {
        let (path, _) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
            context.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            context.setListIndex(path: path, index: index, value: newValue)
        }
    }

    func setMapKey<Y: Codable>(_ keyPath: [Key], newValue: Y) {
        let (path, _) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
        switch keyPath.last! {
        case .string(let key):
            context.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            context.setListIndex(path: path, index: index, value: encoded)
        }
    }

    func getPathFrom(keyPath: [Key], path: [Context.KeyPathElement], objectId: String) -> (path: [Context.KeyPathElement], objectId: String) {
        if keyPath.count == 1 {
            return (path, objectId)
        } else {
            let object = context.getObject(objectId: objectId)
            let objectId: String
            switch keyPath[0] {
            case .string(let key):
                objectId = (object[key] as! [String: Any])[OBJECT_ID] as! String
            case .index(let index):
                let listValues = object[LIST_VALUES] as! [[String: Any]]
                objectId = listValues[index][OBJECT_ID] as! String
            }

            return getPathFrom(keyPath: Array(keyPath.suffix(from: 1)), path: path + [.init(key: keyPath[0], objectId: objectId)], objectId: objectId)
        }
    }

}

extension String {
    var keyPath: [Key] {
        return self.split(whereSeparator: { $0 == "." || $0 == "["  || $0 == "]"}).map({
            let string = String($0)
            if let index = Int(string) {
                return Key.index(index)
            } else {
                return Key.string(string)
            }
        })


    }
}
