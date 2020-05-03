//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

public final class MapProxy<T: Codable> {

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
    private let contex: Context
    private let path: [Context.KeyPathElement]

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Y>, key: String) -> Y {
        get {
            return getObjectByKeyPath(key.keyPath)!
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Optional<Y>>, key: String) -> Y? {
        get {
            return getObjectByKeyPath(key.keyPath)
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, key: String) -> [Y] {
        get {
            return getObjectByKeyPath(key.keyPath)!
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, Array<Y>>, key: String) -> ArrayProxy<Y> {
        get {
            getCollectionProxy(key.keyPath)
        }
    }

    func set(object: T) {
        let dictionary = try! DictionaryEncoder().encode(object)
        for key in dictionary.keys {
            contex.setMapKey(path: path, key: key, value: dictionary[key])
        }
    }

    private func getCollectionProxy<Y: Codable>(_ keyPath: [Key]) -> ArrayProxy<Y> {
        let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch contex.getObject(objectId: taregtObjectId)[key] {
            case let objectType as [String: Any]:
                let listId = objectType[OBJECT_ID] as! String
                if let listValues = objectType[LIST_VALUES] as? [Primitive] {
                    let values = (listValues.map { $0.value! })
                    return ArrayProxy(elements: values as! [Y], contex: contex, listId: listId, path: path + [.init(key: .string(key), objectId: listId)])
                }
                if let listValues = objectType[LIST_VALUES] as? [[String: Any]] {
                    let objects = try! DictionaryDecoder().decodeList(from: listValues) as [Y]
                    return ArrayProxy(elements: objects, contex: contex, listId: listId, path: path + [.init(key: .string(key), objectId: listId)])
                }
                fatalError()
            default:
                fatalError()
            }
        case .index(let index):
            switch contex.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case let listObjects as [[String: Any]]:
                let objectType = listObjects[index]
                let listId = objectType[OBJECT_ID] as! String
                if let listValues = objectType[LIST_VALUES] as? [Primitive] {
                    let values = (listValues.map { $0.value! })
                    return ArrayProxy(elements: values as! [Y], contex: contex, listId: listId, path: path + [.init(key: .index(index), objectId: listId)])
                }
                if let listValues = objectType[LIST_VALUES] as? [[String: Any]] {
                    let objects = try! DictionaryDecoder().decodeList(from: listValues) as [Y]
                    return ArrayProxy(elements: objects, contex: contex, listId: listId, path: path + [.init(key: .index(index), objectId: listId)])
                }
                fatalError()
            default:
                fatalError()
            }
            fatalError("Unsupported proxy at \(index), implement later")
        }
    }

    private func getObjectByKeyPath<Y: Codable>(_ keyPath: [Key]) -> Y? {
        let (_, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
        switch keyPath.last! {
        case .string(let key):
            switch contex.getObject(objectId: taregtObjectId)[key] {
            case let primitives as Primitive:
                return primitives.value as? Y
            case let objectType as [String: Any]:
                if let listValues = objectType[LIST_VALUES] as? [Primitive] {
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
        case .index(let index):
            switch contex.getObject(objectId: taregtObjectId)[LIST_VALUES] {
            case let primitives as [Primitive]:
                return primitives[index].value as? Y
            case let listObjects as [[String: Any]]:
                switch listObjects[index][LIST_VALUES] {
                case let primitives as [Primitive]:
                    let values = (primitives.map { $0.value! })
                    return values as? Y
                case let objects as [[String: Any]]:
                    return try! DictionaryDecoder().decodeList(from: objects)
                case .none:
                    return try! DictionaryDecoder().decode(Y.self, from: listObjects[index])
                default:
                    fatalError()
                }
            default:
                fatalError()
            }
        }
    }


    static func rootProxy<T>(contex: Context) -> MapProxy<T> {
        return MapProxy<T>(contex: contex, objectId: ROOT_ID, path: [])
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

