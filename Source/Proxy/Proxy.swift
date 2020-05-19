//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

public final class Proxy<T: Codable> {

    convenience init(
        contex: Context,
        objectId: String,
        path: [Context.KeyPathElement]
    ) {
        let object = contex.getObject(objectId: objectId)
        let value: T?
        if let listValues = object[LIST_VALUES] as? [Primitive], let primitiveValues = listValues.map({ $0.value }) as? T {
            value = primitiveValues
        } else if let listObjects = object[LIST_VALUES] as? [[String: Any]], let objects = try? DictionaryDecoder().decodeList(from: listObjects) as T {
            value = objects
        } else {
             value = try? DictionaryDecoder().decode(T.self, from: object)
        }

        self.init(contex: contex, objectId: objectId, path: path, value: value)
    }

    init(
        contex: Context,
        objectId: String,
        path: [Context.KeyPathElement],
        value: T?
    ) {
        self.contex = contex
        self.objectId = objectId
        self.path = path
        self.value = value
    }

    let objectId: String
    let contex: Context
    let path: [Context.KeyPathElement]
    var value: T!

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y>, keyPathString: String) -> Y {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)!
        }
        set {
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y?>, keyPathString: String) -> Y? {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)
        }
        set {
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, keyPathString: String) -> [Y] {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)!
        }
        set {
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]?>, keyPathString: String) -> [Y]? {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)
        }
        set {
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, keyPathString: String) -> Proxy<[Y]> {
        get {
            getCollectionProxy(keyPathString.keyPath)
        }
    }

    subscript<Y: Codable>(keyPath: KeyPath<T, Y>, keyPathString: String) -> Proxy<Y>? {
        get {
            return getProxyByKeyPath(keyPathString.keyPath)
        }
    }

    func set(object: T) {
        let dictionary = try! DictionaryEncoder().encode(object)
        for key in dictionary.keys {
            contex.setMapKey(path: path, key: key, value: dictionary[key])
        }
    }

    private func getCollectionProxy<Y: Codable>(_ keyPath: [Key]) -> Proxy<[Y]> {
        let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch contex.getObject(objectId: taregtObjectId)[key] {
            case let objectType as [String: Any]:
                let listId = objectType[OBJECT_ID] as! String
                return Proxy<[Y]>(contex: contex, objectId: listId, path: path + [.init(key: .string(key), objectId: listId)])
            default:
                fatalError()
            }
        case .index(let index):
            switch contex.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case let listObjects as [[String: Any]]:
                let objectType = listObjects[index]
                let listId = objectType[OBJECT_ID] as! String
                return Proxy<[Y]>(contex: contex, objectId: listId, path: path + [.init(key: .index(index), objectId: listId)])
            default:
                fatalError("Unsupported proxy at \(index), implement later")
            }
        }
    }

    private func getObjectByKeyPath<Y: Codable>(_ keyPath: [Key]) -> Y? {
        let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch contex.getObject(objectId: taregtObjectId)[key] {
            case let primitives as Primitive:
                return primitives.value as? Y
            case let objectType as [String: Any]:
                let objectId = objectType[OBJECT_ID] as! String
                return Proxy<Y?>(contex: contex, objectId: objectId, path: path + [.init(key: .string(key), objectId: objectId)]).value
            case .none:
                return nil
            default:
                fatalError()
            }
        case .index(let index):
            switch contex.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case let primitives as [Primitive]:
                return primitives[index].value as? Y
            case let listObjects as [[String: Any]]:
                let objectId = listObjects[index][OBJECT_ID] as! String
                return Proxy<Y?>(contex: contex, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId)]).value
            default:
                fatalError()
            }
        }
    }

    private func getProxyByKeyPath<Y: Codable>(_ keyPath: [Key]) -> Proxy<Y>? {
        let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch contex.getObject(objectId: taregtObjectId)[key] {
            case is Primitive:
                return nil
            case let objectType as [String: Any]:
                let objectId = objectType[OBJECT_ID] as! String
                return Proxy<Y>(contex: contex, objectId: objectId, path: path + [.init(key: .string(key), objectId: objectId)])
            case .none:
                return nil
            default:
                fatalError()
            }
        case .index(let index):
            switch contex.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case is [Primitive]:
                return nil
            case let listObjects as [[String: Any]]:
                let objectId = listObjects[index][OBJECT_ID] as! String
                return Proxy<Y>(contex: contex, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId)])
            default:
                fatalError()
            }
        }
    }


    static func rootProxy<T>(contex: Context) -> Proxy<T> {
        return Proxy<T>(contex: contex, objectId: ROOT_ID, path: [])
    }

    private func setMapKey<Y: Codable>(_ keyPath: [Key], newValue: [Y]) {
        let (path, _) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
            contex.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            contex.setListIndex(path: path, index: index, value: newValue)
        }
    }

    private func setMapKey<Y: Codable>(_ keyPath: [Key], newValue: Y) {
        let (path, _) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
            contex.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            contex.setListIndex(path: path, index: index, value: newValue)
        }
    }

    private func getPathFrom(keyPath: [Key], path: [Context.KeyPathElement], objectId: String) -> (path: [Context.KeyPathElement], objectId: String) {
        if keyPath.count == 1 {
            return (path, objectId)
        } else {
            let object = contex.getObject(objectId: objectId)
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

extension Proxy where T: NSObject {

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y>) -> Y {
        get {
            return getObjectByKeyPath(NSExpression(forKeyPath: keyPath).keyPath.keyPath)!
        }
        set {
            return setMapKey(NSExpression(forKeyPath: keyPath).keyPath.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Optional<Y>>) -> Y? {
        get {
            return getObjectByKeyPath(NSExpression(forKeyPath: keyPath).keyPath.keyPath)
        }
        set {
            return setMapKey(NSExpression(forKeyPath: keyPath).keyPath.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>) -> [Y] {
        get {
            return getObjectByKeyPath(NSExpression(forKeyPath: keyPath).keyPath.keyPath)!
        }
        set {
            return setMapKey(NSExpression(forKeyPath: keyPath).keyPath.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Optional<[Y]>>) -> [Y]? {
        get {
            return getObjectByKeyPath(NSExpression(forKeyPath: keyPath).keyPath.keyPath)
        }
        set {
            return setMapKey(NSExpression(forKeyPath: keyPath).keyPath.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Array<Y>>) -> Proxy<[Y]> {
        get {
            getCollectionProxy(NSExpression(forKeyPath: keyPath).keyPath.keyPath)
        }
    }
}
