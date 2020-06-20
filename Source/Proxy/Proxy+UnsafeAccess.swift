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
        let object = self.objectId.map { context.getObject(objectId: $0) }
        let objectId = (object?[dynamicMember] as? [String: Any])?[OBJECT_ID] as? String
        return UnsafeProxy(context: context, objectId: objectId, path: path + [.init(key: .string(dynamicMember), objectId: objectId ?? "")])
    }

    private func set<T: Codable>(rootObject: T) {
        let dictionary = try! DictionaryEncoder().encode(rootObject) as [String: Any]
        for key in dictionary.keys {
            context.setMapKey(path: path, key: key, value: dictionary[key])
        }
    }

    public func set<T: Codable>(_ newValue: T) {
        guard let lastPathKey = path.last?.key else {
            self.set(rootObject: newValue)
            return
        }
        let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
        switch lastPathKey {
        case .string(let key):
            let path = Array(self.path.dropLast())
            context.setMapKey(path: path, key: key, value: encoded)
        case .index(let index):
            let path = Array(self.path.dropLast())
            context.setListIndex(path: path, index: index, value: encoded)
        }
    }

    public subscript(index: Int) -> UnsafeProxy {
        get {
            let object = self.objectId.map { context.getObject(objectId: $0) }
            let listValues = object?[LIST_VALUES] as? [[String: Any]]
            if index >= listValues?.count ?? 0 {
                return UnsafeProxy(context: context, objectId: nil, path: path + [.init(key: .index(index), objectId: "")])
            }
            let objectId = listValues?[index][OBJECT_ID] as? String
            return UnsafeProxy(context: context, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId ?? "")])
        }
    }

}

