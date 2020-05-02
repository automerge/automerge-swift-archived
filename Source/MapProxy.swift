//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

public final class MapProxy<T> {

    init(
        contex: Context,
        objectId: String,
        path: [Context.KeyPathElement]
    ) {
        self.contex = contex
        self.objectId = objectId
        self.path = path
    }

    let objectId: String
    var change: Context {
        return contex
    }

    private let contex: Context
    private let path: [Context.KeyPathElement]

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y>, key: String) -> Y {
        get {
            return getObjectByKeyPath(key.keyPath, objectId: objectId)!
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Optional<Y>>, key: String) -> Y? {
        get {
            return getObjectByKeyPath(key.keyPath, objectId: objectId)
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, key: String) -> [Y] {
        get {
            return getObjectByKeyPath(key.keyPath, objectId: objectId)!
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable>(keyPath: KeyPath<T, Y>, key: String) -> Y {
        get {
            let object = contex.getObject(objectId: objectId)
            return (object[key] as? Primitives)?.value as! Y
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Array<Y>>, key: String) -> ArrayProxy<Y> {
        get {
            getCollectionProxy(key.keyPath, objectId: objectId)
        }
    }

    private func getCollectionProxy<Y: Codable>(_ keyPath: [Key], objectId: String) -> ArrayProxy<Y> {
        if case .string(let key) = keyPath.first, keyPath.count == 1 {
            switch contex.getObject(objectId: objectId)[key] {
            case let objectType as [String: Any]:
                if let listValues = objectType[LIST_VALUES] as? [Primitives] {
                    let values = (listValues.map { $0.value! })
                    let listId = objectType[OBJECT_ID] as! String
                    return ArrayProxy(elements: values as! [Y], contex: contex, listId: listId, path: path + [.init(key: .string(key), objectId: listId)])

                }
            default:
                fatalError()
            }
        } else if case .string(let key) = keyPath.first {
            let object = contex.getObject(objectId: objectId)
            let objectId = (object[key] as! [String: Any])[OBJECT_ID] as! String
            let proxy = MapProxy<Any>(contex: contex, objectId: objectId, path: path + [.init(key: .string(key), objectId: objectId)])
            return proxy.getCollectionProxy(Array(keyPath.suffix(from: 1)), objectId: objectId)
        }
        fatalError()
    }


    static func rootProxy<T>(contex: Context) -> MapProxy<T> {
        return MapProxy<T>(contex: contex, objectId: ROOT_ID, path: [])
    }

    private func setMapKey<Y: Codable>(_ keyPath: [Key], newValue: [Y]) {
        if case .string(let key) = keyPath.first, keyPath.count == 1 {
            let encoded = try? DictionaryEncoder().encode(newValue)
            if let encoded2 = encoded {
                contex.setMapKey(path: path, key: key, value: encoded2)
            } else {
                contex.setMapKey(path: path, key: key, value: newValue)
            }
        } else if case .string(let key) = keyPath.first {
            let object = contex.getObject(objectId: objectId)
            let objectId = (object[key] as! [String: Any])[OBJECT_ID] as! String
            let proxy = MapProxy<Any>(contex: contex, objectId: objectId, path: [.init(key: .string(key), objectId: objectId)])
            return proxy.setMapKey(Array(keyPath.suffix(from: 1)), newValue: newValue)
        }
    }

    private func setMapKey<Y: Codable>(_ keyPath: [Key], newValue: Y) {
        if keyPath.count == 1 {
            switch keyPath[0] {
            case .string(let key):
                let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
                contex.setMapKey(path: path, key: key, value: encoded)
            case .index(let index):
                contex.setListIndex(path: path, index: index, value: newValue)
            }
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

            let proxy = MapProxy<Any>(contex: contex, objectId: objectId, path: [.init(key: keyPath[0], objectId: objectId)])
            return proxy.setMapKey(Array(keyPath.suffix(from: 1)), newValue: newValue)
        }
    }

    private func getObjectByKeyPath<Y: Codable>(_ keyPath: [Key], objectId: String) -> Y? {
        if case .string(let key) = keyPath.first, keyPath.count == 1 {
            switch contex.getObject(objectId: objectId)[key] {
            case let primitives as Primitives:
                return primitives.value as? Y
            case let objectType as [String: Any]:
                if let listValues = objectType[LIST_VALUES] as? [Primitives] {
                    let values = (listValues.map { $0.value! })
                    return values as? Y
                } else if let listValues = objectType[LIST_VALUES] as? [[String: Any]] {
                    return try! DictionaryDecoder().decodeList(from: listValues)
                } else {
                    return try! DictionaryDecoder().decode(Y.self, from: objectType)
                }
            case .none:
                return nil
            default:
                fatalError()
            }
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
            let proxy = MapProxy<Any>(contex: contex, objectId: objectId, path: [.init(key: keyPath[0], objectId: self.objectId)])
            return proxy.getObjectByKeyPath(Array(keyPath.suffix(from: 1)), objectId: objectId)
        }
    }

    private func getObjectByKeyPath2<Y: Codable>(_ keyPath: [Key], objectId: String) -> Y? {
        let (key, objectId) = getPathFor(keyPath: keyPath, objectId: self.objectId)

        switch contex.getObject(objectId: objectId)[key] {
        case let primitives as Primitives:
            return primitives.value as? Y
        case let objectType as [String: Any]:
            if let listValues = objectType[LIST_VALUES] as? [Primitives] {
                let values = (listValues.map { $0.value! })
                return values as? Y
            } else if let listValues = objectType[LIST_VALUES] as? [[String: Any]] {
                return try! DictionaryDecoder().decodeList(from: listValues)
            } else {
                return try! DictionaryDecoder().decode(Y.self, from: objectType)
            }
        case .none:
            return nil
        default:
            fatalError()
        }
    }

    func getPathFor(keyPath: [Key], objectId: String) -> (key: String, objectId: String) {
        if case .string(let key) = keyPath.first, keyPath.count == 1 {
            return (objectId, key)
        } else if case .string(let key) = keyPath.first {
            let object = contex.getObject(objectId: objectId)
            let objectId = (object[key] as! [String: Any])[OBJECT_ID] as! String
            return getPathFor(keyPath: Array(keyPath.suffix(from: 1)), objectId: objectId)
        } else {
            fatalError()
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

