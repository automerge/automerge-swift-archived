//
//  Proxy+UnsafeAccess.swift
//  Automerge
//
//  Created by Lukas Schmidt on 08.06.20.
//

import Foundation

extension Proxy {
    public func toAny() -> AnyProxy {
        return AnyProxy(context: context, objectId: objectId, path: path)
    }
}

@dynamicMemberLookup
public final class AnyProxy {

    init(
        context: Context,
        objectId: ObjectId?,
        path: [Context.KeyPathElement]
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
    }

    public let objectId: ObjectId?
    let context: Context
    let path: [Context.KeyPathElement]

    public subscript(dynamicMember dynamicMember: String) -> AnyProxy {
        guard case .map(let map)? = objectId.map({ context.getObject(objectId: $0) }) else {
            fatalError()
        }
        let objectId = map[dynamicMember]?.objectId
        return AnyProxy(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(dynamicMember), objectId: objectId)]
        )
    }

    public func `as`<T: Codable>(_ type: T.Type) -> MutableProxy<T> {
        let decoder = ObjectDecoder()
        return MutableProxy<T>(
            context: context,
            objectId: objectId,
            path: path,
            value: { [objectId, context] in
                objectId.map { [context] in try! decoder.decode(context.getObject(objectId: $0)) }
            }
        )
    }

}

