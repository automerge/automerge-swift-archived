//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 30.04.20.
//

import Foundation

public final class ArrayProxy<T> {

    init(
        elements: [T],
        contex: Context,
        listId: String,
        path: [Context.KeyPathElement]
    ) {
        self.elements = elements
        self.contex = contex
        self.listId = listId
        self.path = path
    }

    private var elements: [T]
    private let contex: Context
    private let path: [Context.KeyPathElement]
    let listId: String
    var change: Context {
        return contex
    }

}

extension ArrayProxy: Collection {

    public typealias Index = Int
    public typealias Element = T

    public var startIndex: Int { elements.startIndex }
    public var endIndex: Int { elements.endIndex }

    public subscript(position: Index) -> T {
        get { return elements[position] }
        set {
            elements[position] = newValue
            contex.setListIndex(path: path, index: position, value: newValue)
        }
    }

    // Method that returns the next index when iterating
    public func index(after i: Int) -> Int {
        return elements.index(after: i)
    }

}

extension ArrayProxy: RangeReplaceableCollection {
    public convenience init() {
        let void: (ObjectDiff, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]? = { _, _, _ in
            fatalError()
        }
        self.init(elements: [], contex: Context(actorId: UUID(), applyPatch: void, updated: [:], cache: [:], ops: []), listId: "", path: [])
    }

    public func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        contex.spice(path: path, start: start, deletions: deleteCount, insertions: Array(newElements))
        elements.replaceSubrange(subrange, with: newElements)
    }

}
