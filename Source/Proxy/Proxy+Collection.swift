//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 30.04.20.
//

import Foundation

extension Proxy where T: Collection, T.Index == Int, T.Element: Codable {

    public subscript(index: Int) -> Proxy<T.Element> {
        get {
            let object = self.objectId.map { context.getObject(objectId: $0) }
            let listValues = object?[LIST_VALUES] as? [[String: Any]]
            let objectId = listValues?[index][OBJECT_ID] as? String
            return Proxy<T.Element>(context: context, objectId: objectId, path: path + [.init(key: .index(index), objectId: objectId ?? "")], value: self.get()[index])
        }
    }

    public func conflicts(index: Int) -> [String: T.Element]? {
        guard let objectId = objectId else {
            return nil
        }
        let object = context.getObject(objectId: objectId)
        guard let conflicts = object[CONFLICTS] as? [Key: Any], let realConflicts = conflicts[.index(index)] as? [String: Any], realConflicts.count > 1 else {
            return nil
        }
        let decoder = DictionaryDecoder()
        return try? decoder.decode([String: T.Element].self, from: realConflicts)
    }
}

extension Proxy: Collection, Sequence where T: Collection {

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

extension Proxy: MutableCollection where T: MutableCollection, T.Element: Codable, T.Index == Int {

    public subscript(position: Index) -> T.Element {
        get { return self.get()[position] }
        set {
            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
            context.setListIndex(path: path, index: position, value: encoded)
        }
    }

}

extension Proxy: RangeReplaceableCollection where T: RangeReplaceableCollection, T.Index == Int, T.Element: Codable {
    public convenience init() {
        let void: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]? = { _, _, _ in
            fatalError()
        }
        self.init(context: Context(actorId: ActorId(), applyPatch: void, updated: [:], cache: [:], ops: []), objectId: "", path: [], value: nil)
    }

    public func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        let encoded: [Any] = (try? DictionaryEncoder().encode(Array(newElements)) as [[String: Any]]) ?? Array(newElements)
        context.splice(path: path, start: start, deletions: deleteCount, insertions: encoded)
    }

    public func append(_ newElement: __owned Element) {
        insert(newElement, at: endIndex)
    }

    public func insert(
        _ newElement: __owned Element, at i: Index
    ) {
        replaceSubrange(i..<i, with: CollectionOfOne(newElement))
    }

    public func append<S: Sequence>(contentsOf newElements: __owned S)
        where S.Element == Element {

            let approximateCapacity = self.count + newElements.underestimatedCount
            self.reserveCapacity(approximateCapacity)
            for element in newElements {
                append(element)
            }
    }

    public func reserveCapacity(_ n: Int) {}

    @discardableResult
    public func remove(at position: Index) -> Element {
        precondition(!isEmpty, "Can't remove from an empty collection")
        let result: Element = self[position]
        replaceSubrange(position..<index(after: position), with: EmptyCollection())
        return result
    }

}
