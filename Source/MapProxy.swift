//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

public final class ArrayProxy<T> {

    func append(_ element: T) {}
}

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
            return getObjectByKeyPath(key.keyPath, objectId: objectId)
        }
        set {
            return setMapKey(key.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, key: String) -> [Y] {
        get {
            return getObjectByKeyPath(key.keyPath, objectId: objectId)
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
             fatalError()
        }
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
        if case .string(let key) = keyPath.first, keyPath.count == 1 {
            let encoded = try? DictionaryEncoder().encode(newValue)
            if let encoded2 = encoded {
                contex.setMapKey(path: path, key: key, value: encoded2)
            } else {
                contex.setMapKey(path: path, key: key, value: newValue)
            }
        } else if case .string(let key) = keyPath.first, let object = contex.getObject(objectId: objectId) as? [String: Any] {
            let objectId = (object[key] as! [String: Any])[OBJECT_ID] as! String
            let proxy = MapProxy<Any>(contex: contex, objectId: objectId, path: [.init(key: .string(key), objectId: objectId)])
            return proxy.setMapKey(Array(keyPath.suffix(from: 1)), newValue: newValue)
        }
    }

    private func getObjectByKeyPath<Y: Codable>(_ keyPath: [Key], objectId: String) -> Y {
           if case .string(let key) = keyPath.first, keyPath.count == 1 {
               switch contex.getObject(objectId: objectId) {
               case let object as [String: Any]:
                   switch object[key] {
                   case let primitives as Primitives:
                       return primitives.value as! Y
                   case let objectType as [String: Any]:
                       if let listValues = objectType[LIST_VALUES] as? [Primitives] {
                           return (listValues.map { $0.value! }) as! Y
                       } else if let listValues = objectType[LIST_VALUES] as? [[String: Any]] {
                        return try! DictionaryDecoder().decodeList(from: listValues)
                    }
                   case .none:
                       fatalError()
                   default:
                       fatalError()
                   }
                   return (object[key] as? Primitives)?.value as! Y
               default:
                   fatalError()
               }
           } else if case .string(let key) = keyPath.first, let object = contex.getObject(objectId: objectId) as? [String: Any] {
               let objectId = (object[key] as! [String: Any])[OBJECT_ID] as! String
               let proxy = MapProxy<Any>(contex: contex, objectId: objectId, path: [.init(key: .string(key), objectId: self.objectId)])
               return proxy.getObjectByKeyPath(Array(keyPath.suffix(from: 1)), objectId: objectId)
           }
           fatalError()
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

