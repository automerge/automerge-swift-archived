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
            return getObjectByKeyPath(key.keyPath, objectId: objectId)
        }
        set {
            if let encoded = try? DictionaryEncoder().encode(newValue) {
                contex.setMapKey(path: path, key: key, value: encoded)
            } else {
                contex.setMapKey(path: path, key: key, value: newValue)
            }

        }
    }

    public subscript<Y: Equatable>(keyPath: KeyPath<T, Y>, key: String) -> Y {
        get {
            switch contex.getObject(objectId: objectId) {
            case let object as [String: Any]:
                return (object[key] as? Primitives)?.value as! Y
            default:
                fatalError()
            }
        }
    }

    static func rootProxy<T>(contex: Context) -> MapProxy<T> {
        return MapProxy<T>(contex: contex, objectId: ROOT_ID, path: [])
    }

    private func getObjectByKeyPath<Y: Codable>(_ keyPath: [Key], objectId: String) -> Y {
        if case .string(let key) = keyPath.first, keyPath.count == 1 {
            switch contex.getObject(objectId: objectId) {
            case let object as [String: Any]:
                switch object[key] {
                case let primitives as Primitives:
                    return primitives.value as! Y
                case let object as [String: Any]:
                    if let listValues = object[LIST_VALUES] {
                        return listValues as! Y
                    } else {
                        return try! DictionaryDecoder().decode(Y.self, from: object)
                    }
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

