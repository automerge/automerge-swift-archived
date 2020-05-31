//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 30.04.20.
//

import Foundation

extension Proxy {

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, keyPathString: String) -> [Y] {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)!
        }
        set {
            value?[keyPath: keyPath] = newValue
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]?>, keyPathString: String) -> [Y]? {
        get {
            return getObjectByKeyPath(keyPathString.keyPath)
        }
        set {
            value?[keyPath: keyPath] = newValue
            return setMapKey(keyPathString.keyPath, newValue: newValue)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]>, keyPathString: String) -> Proxy<[Y]> {
        get {
            getCollectionProxy(keyPathString.keyPath)
        }
    }

    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]?>, keyPathString: String) -> Proxy<[Y]>? {
        get {
            getCollectionProxy(keyPathString.keyPath)
        }
    }

    func getCollectionProxy<Y: Codable>(_ keyPath: [Key]) -> Proxy<[Y]> {
           let (path, taregtObjectId) = getPathFrom(keyPath: keyPath, path: self.path, objectId: objectId)
           switch keyPath.last! {
           case .string(let key):
               switch context.getObject(objectId: taregtObjectId)[key] {
               case let objectType as [String: Any]:
                   let listId = objectType[OBJECT_ID] as! String
                   return Proxy<[Y]>(context: context, objectId: listId, path: path + [.init(key: .string(key), objectId: listId)])
               default:
                   fatalError()
               }
           case .index(let index):
               switch context.getObject(objectId: taregtObjectId)[LIST_VALUES] {
               case let listObjects as [[String: Any]]:
                   let objectType = listObjects[index]
                   let listId = objectType[OBJECT_ID] as! String
                   return Proxy<[Y]>(context: context, objectId: listId, path: path + [.init(key: .index(index), objectId: listId)])
               default:
                   fatalError("Unsupported proxy at \(index), implement later")
               }
           }
       }

}


extension Proxy: Collection, Sequence where T: Collection {

    public typealias Index = T.Index
    public typealias Element = T.Element

    public var startIndex: Index { value.startIndex }
    public var endIndex: Index { value.endIndex }

    public subscript(position: Index) -> T.Element {
        get { return value[position] }
    }

    // Method that returns the next index when iterating
    public func index(after i: Index) -> Index {
        return value.index(after: i)
    }

}



extension Proxy: MutableCollection where T: MutableCollection, T.Element: Encodable, T.Index == Int {

    public subscript(position: Index) -> T.Element {
        get { return value[position] }
        set {
            value[position] = newValue
            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
            context.setListIndex(path: path, index: position, value: encoded)
        }
    }

}

extension Proxy: RangeReplaceableCollection where T: RangeReplaceableCollection, T.Index == Int {
    public convenience init() {
        let void: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]? = { _, _, _ in
            fatalError()
        }
        self.init(context: Context(actorId: ActorId(), applyPatch: void, updated: [:], cache: [:], ops: []), objectId: "", path: [])
    }

    public func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        context.splice(path: path, start: start, deletions: deleteCount, insertions: Array(newElements))
        value.replaceSubrange(subrange, with: newElements)
    }

}

extension Proxy2 where T: Collection, T.Index == Int, T.Element: Codable {

    public subscript(index: Int) -> Proxy2<T.Element> {
        get {
            let object = self.objectId.map { context.getObject(objectId: $0) }
            let listValues = object?[LIST_VALUES] as? [[String: Any]]
            let objectId = listValues?[index][OBJECT_ID] as? String
            return Proxy2<T.Element>(context: context, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId ?? "")], value: self.get()[index])
        }
    }

//    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<T, [Y]>) -> Proxy2<[Y]> {
//        get {
//            let fieldName = dynamicMember.fieldName!
//            let object = self.objectId.map { context.getObject(objectId: $0) }
//            let objectId = (object?[fieldName] as? [String: Any])?[OBJECT_ID] as? String
//            return Proxy2<Y>(context: context, objectId: objectId, path: path + [.init(key: .string(fieldName), objectId: objectId ?? "")], value: self.valueResolver()?[keyPath: dynamicMember])
//        }
//    }

//    public subscript<Y: Equatable & Codable>(keyPath: WritableKeyPath<T, [Y]?>, keyPathString: String) -> [Y]? {
//        get {
//            return getObjectByKeyPath(keyPathString.keyPath)
//        }
//    }
}

extension Proxy2: Collection, Sequence where T: Collection {

    public typealias Index = T.Index
    public typealias Element = T.Element

    public var startIndex: Index { self.get().startIndex }
    public var endIndex: Index { self.get().endIndex }

    public subscript(position: Index) -> T.Element {
        get { return self.get()[position] }
    }

    // Method that returns the next index when iterating
    public func index(after i: Index) -> Index {
        return self.get().index(after: i)
    }

}

extension Proxy2: MutableCollection where T: MutableCollection, T.Element: Codable, T.Index == Int {

    public subscript(position: Index) -> T.Element {
        get { return self.get()[position] }
        set {
            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
            context.setListIndex(path: path, index: position, value: encoded)
        }
    }

}

extension Proxy2: RangeReplaceableCollection where T: RangeReplaceableCollection, T.Index == Int {
    public init() {
        let void: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]? = { _, _, _ in
            fatalError()
        }
        self.init(context: Context(actorId: ActorId(), applyPatch: void, updated: [:], cache: [:], ops: []), objectId: "", path: [], value: nil)
    }

    public mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        context.splice(path: path, start: start, deletions: deleteCount, insertions: Array(newElements))
    }

}
