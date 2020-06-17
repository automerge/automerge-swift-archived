//
//  Proxy+Conflicts.swift
//  Automerge
//
//  Created by Lukas Schmidt on 16.06.20.
//

import Foundation

extension Proxy {

    public func conflicts<Y: Codable>(dynamicMember: KeyPath<Wrapped, Y>) -> [Actor: Y]? {
        guard let objectId = objectId else {
            return nil
        }
        let object = context.getObject(objectId: objectId)
        guard let conflicts = object[CONFLICTS] as? [Key: Any] else {
            return nil
        }
        guard let fieldName = dynamicMember.fieldName, let realConflicts = conflicts[.string(fieldName)] as? [String: Any], realConflicts.count > 1 else {
            return nil
        }
        let decoder = DictionaryDecoder()
        return (try? decoder.decode([String: Y].self, from: realConflicts))?.compactMapKeys({ Actor(actorId: $0) })
    }

}

extension Proxy where Wrapped: Collection, Wrapped.Index == Int, Wrapped.Element: Codable {

    public func conflicts(index: Int) -> [Actor: Wrapped.Element]? {
        guard let objectId = objectId else {
            return nil
        }
        let object = context.getObject(objectId: objectId)
        guard let conflicts = object[CONFLICTS] as? [Key: Any], let realConflicts = conflicts[.index(index)] as? [String: Any], realConflicts.count > 1 else {
            return nil
        }
        let decoder = DictionaryDecoder()
        return (try? decoder.decode([String: Wrapped.Element].self, from: realConflicts))?.compactMapKeys({ Actor(actorId: $0) })
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
