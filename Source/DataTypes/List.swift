//
//  List.swift
//  Automerge
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

/// A representation of a List object within Automerge.
struct List: Equatable, Codable {

    let objectId: ObjectId
    private var listValues: [Object]
    var conflicts: [[ObjectId: Object]]
    var elemIds: [ObjectId]

    init(objectId: ObjectId = "", listValues: [Object] = [], conflicts: [[ObjectId: Object]] = [], elemIds: [ObjectId] = []) {
        self.objectId = objectId
        self.listValues = listValues
        self.conflicts = conflicts
        self.elemIds = elemIds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(listValues)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.listValues = try container.decode([Object].self)
        self.objectId = ObjectId("")
        self.conflicts = []
        self.elemIds = []
    }

}

extension List: Collection, MutableCollection, RangeReplaceableCollection {
    init() {
        self.objectId = ""
        self.listValues = []
        self.conflicts = []
        self.elemIds = []
    }


    var startIndex: Int {
        return listValues.startIndex
    }

    var endIndex: Int {
        return listValues.endIndex
    }

    subscript(position: Int) -> Object {
        get {
           return listValues[position]
        }
        set {
            listValues[position] = newValue
        }
    }

    // Method that returns the next index when iterating
    func index(after i: Int) -> Int {
        return listValues.index(after: i)
    }

    public mutating func replaceSubrange<C, R>(_ subrange: R, with proxyElements: C) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
        listValues.replaceSubrange(subrange, with: proxyElements)
    }

    public func reserveCapacity(_ n: Int) {}

}

extension List: ExpressibleByArrayLiteral {

    init(arrayLiteral elements: Object...) {
        self.objectId = ""
        self.listValues = elements
        self.conflicts = []
        self.elemIds = []
    }
}
