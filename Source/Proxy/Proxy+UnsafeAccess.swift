//
//  Proxy+UnsafeAccess.swift
//  Automerge
//
//  Created by Lukas Schmidt on 08.06.20.
//

import Foundation

extension Proxy {
    public func unsafe() -> UnsafeProxy {
        return UnsafeProxy(context: context, objectId: objectId, path: path)
    }
}

@dynamicMemberLookup
public final class UnsafeProxy {

    init(
        context: Context,
        objectId: String?,
        path: [Context.KeyPathElement]
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
    }

    public let objectId: String?
    let context: Context
    let path: [Context.KeyPathElement]

    public subscript(dynamicMember dynamicMember: String) -> UnsafeProxy {
        guard case .map(let map)? = self.objectId.map({ context.getObject(objectId: $0) }) else {
            fatalError()
        }
        let objectId = map.mapValues[dynamicMember]?.objectId
        return UnsafeProxy(context: context, objectId: objectId, path: path + [.init(key: .string(dynamicMember), objectId: objectId ?? "")])
    }

//    private func set<T: Codable>(rootObject: T) {
//        let dictionary = try! DictionaryEncoder().encode(rootObject) as [String: Any]
//        for key in dictionary.keys {
//            context.setMapKey(path: path, key: key, value: dictionary[key])
//        }
//    }

    public func set<T: Codable>(_ newValue: T) {
        guard let lastPathKey = path.last?.key else {
//            self.set(rootObject: newValue)
            #warning("fix me")
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

    public subscript(index: Int) -> UnsafeProxy {
        get {
            guard case .list(let list)? = self.objectId.map({ context.getObject(objectId: $0) }) else {
                fatalError()
            }
            if index >= list.listValues.count {
                return UnsafeProxy(context: context, objectId: nil, path: path + [.init(key: .index(index), objectId: "")])
            }
            let objectId = list[index].objectId
            return UnsafeProxy(context: context, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId ?? "")])
        }
    }

}

