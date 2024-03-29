//
//  Proxy+Conflicts.swift
//  Automerge
//
//  Created by Lukas Schmidt on 16.06.20.
//

import Foundation

extension Proxy {

    /// Returns the conflicts that Automerge has registered while it applied changes to your model.
    /// - Returns: An optional map keyed by the ``ObjectId`` with the conflicting change and the value that it proposed.
    public func conflicts<Y: Codable>(dynamicMember: KeyPath<Wrapped, Y>) -> [ObjectId: Y]? {
        guard let objectId = objectId else {
            return nil
        }
        let object = context.getObject(objectId: objectId)
        switch object {
        case .primitive:
            return nil
        case .map(let map):
            guard let fieldName = dynamicMember.fieldName,
                  let realConflicts = map.conflicts[fieldName],
                  realConflicts.count > 1 else {
                return nil
            }

            let typedObjects: [String: Y] = try! objectDecoder.decode(realConflicts.compactMapKeys({ $0.objectId }))
            return typedObjects.compactMapKeys({ ObjectId($0) })
        default:
            fatalError()
        }

    }

}

extension Proxy where Wrapped: Collection, Wrapped.Index == Int, Wrapped.Element: Codable {

    /// Returns the conflict at the index location you provide that Automerge has registered while it applied changes to your model.
    /// - Returns: An optional map keyed by the ``ObjectId`` with the conflicting change and the value that it proposed.
    public func conflicts(index: Int) -> [ObjectId: Wrapped.Element]? {
        guard let objectId = objectId else {
            return nil
        }
        guard case .list(let list) = context.getObject(objectId: objectId) else {
            fatalError()
        }
        let realConflicts = list.conflicts[index]
        guard realConflicts.count > 1 else {
            return nil
        }

        let typedObjects: [String: Wrapped.Element] = try! objectDecoder.decode(realConflicts.compactMapKeys({ $0.objectId }))
        return typedObjects.compactMapKeys({ ObjectId($0) })
    }
}

extension Dictionary {
    func compactMapKeys<T>(_ transform: ((Key) throws -> T?)) rethrows -> Dictionary<T, Value> {
        return try self.reduce(into: [T: Value](), { (result, x) in
            if let key = try transform(x.key) {
                result[key] = x.value
            }
        })
    }
}
