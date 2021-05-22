//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 30.04.20.
//

import Foundation

extension Proxy: Collection, Sequence where Wrapped: Collection, Wrapped.Element: Codable, Wrapped.Index == Int {

    public typealias Index = Int
    public typealias Element = Proxy<Wrapped.Element>
    
    public var startIndex: Index { list.startIndex }
    public var endIndex: Index { list.endIndex }

    public subscript(position: Int) -> Proxy<Wrapped.Element> {
        get {
            let objectId = list[position].objectId
            return Proxy<Wrapped.Element>(
                context: context,
                objectId: objectId,
                path: path + [.init(key: .index(position), objectId: objectId)],
                value: self.get()[position]
            )
        }
    }

    // Method that returns the next index when iterating
    public func index(after i: Index) -> Index {
        return list.index(after: i)
    }

    fileprivate var list: List {
        guard case .list(let list) = objectId.map({ context.getObject(objectId: $0) }) else {
            fatalError("Must contain list")
        }

        return list
    }

}

extension Proxy: MutableCollection where Wrapped: MutableCollection, Wrapped.Element: Codable, Wrapped.Index == Int {

    public subscript(position: Int) -> Proxy<Wrapped.Element> {
        get {
            let objectId = list[position].objectId
            return Proxy<Wrapped.Element>(
                context: context,
                objectId: objectId,
                path: path + [.init(key: .index(position), objectId: objectId)]
                , value: self.get()[position]
            )
        }
        set {
            fatalError()
//            let encoded: Any = (try? DictionaryEncoder().encode(newValue)) ?? newValue
//            context.setListIndex(path: path, index: position, value: encoded)
        }
    }

}

extension Proxy: RangeReplaceableCollection where Wrapped: RangeReplaceableCollection, Wrapped.Index == Int, Wrapped.Element: Codable {

    public convenience init() {
        let void: (ObjectDiff, Object?, inout [ObjectId: Object]) -> Object? = { _, _, _ in
            fatalError()
        }
        self.init(context: Context(actorId: Actor(), applyPatch: void, updated: [:], cache: [:], ops: [], maxOp: 0), objectId: nil, path: [], value: nil)
    }

    public func replaceSubrange<C, R>(_ subrange: R, with proxyElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        let newElements = proxyElements.map { $0.get() }
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        guard case .list(let list) = try! objectEncoder.encode(Array(newElements)) else {
            fatalError()
        }
        context.splice(path: path, start: start, deletions: deleteCount, insertions: Array(list))
    }

    public func reserveCapacity(_ n: Int) {}

}

extension Proxy where Wrapped: RangeReplaceableCollection, Wrapped.Index == Int, Wrapped.Element: Codable {

    public func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, C.Element == Wrapped.Element, Index == R.Bound {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        guard case .list(let list) = try! objectEncoder.encode(Array(newElements)) else {
            fatalError()
        }
        context.splice(path: path, start: start, deletions: deleteCount, insertions: Array(list))
    }

    public func append(_ newElement: __owned Wrapped.Element) {
        insert(newElement, at: endIndex)
    }

    public func insert(_ newElement: __owned Wrapped.Element, at i: Index) {
        replaceSubrange(i..<i, with: CollectionOfOne(newElement))
    }

    public func append<S: Sequence>(contentsOf newElements: S)
        where S.Element == Wrapped.Element {
            let approximateCapacity = self.count + newElements.underestimatedCount
            self.reserveCapacity(approximateCapacity)
            for element in newElements {
                append(element)
            }
    }


    @discardableResult
    public func remove(at position: Index) -> Wrapped.Element {
        precondition(!isEmpty, "Can't remove from an empty collection")
        let result: Wrapped.Element = self[position].get()
        replaceSubrange(position..<index(after: position), with: EmptyCollection())
        return result
    }

    public func insert<C: Collection>(
      contentsOf newElements: __owned C, at i: Index
    ) where C.Element == Wrapped.Element {
      replaceSubrange(i..<i, with: newElements)
    }
}


