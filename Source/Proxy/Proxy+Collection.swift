//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 30.04.20.
//

import Foundation

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
            contex.setListIndex(path: path, index: position, value: encoded)
        }
    }

}

extension Proxy: RangeReplaceableCollection where T: RangeReplaceableCollection, T.Element: Encodable, T.Index == Int {
    public convenience init() {
        let void: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]? = { _, _, _ in
            fatalError()
        }
        self.init(contex: Context(actorId: UUID(), applyPatch: void, updated: [:], cache: [:], ops: []), objectId: "", path: [])
    }

    public func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        contex.splice(path: path, start: start, deletions: deleteCount, insertions: Array(newElements))
        value.replaceSubrange(subrange, with: newElements)
    }

}
