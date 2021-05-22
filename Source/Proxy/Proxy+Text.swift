//
//  Proxy+Text.swift
//  Automerge
//
//  Created by Lukas Schmidt on 04.06.20.
//

import Foundation

public extension Proxy where Wrapped == Text {

    func insert(_ character: Character, at index: Int) {
        context.splice(path: path, start: index, deletions: 0, insertions: [.primitive(.string(String(character)))])
    }

    func insert(_ string: String, at index: Int) {
        insert(contentsOf: Array(string), at: index)
    }

    func insert(contentsOf characters: [Character], at index: Int) {
        context.splice(path: path, start: index, deletions: 0, insertions: characters.map({ character in
            return .primitive(.string(String(character)))
        }))
    }

    func replaceSubrange(_ subrange: Range<Int>, with newElements: [Character]) {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        let encoded: [Object] = newElements.map({ .primitive(.string(String($0))) })
        context.splice(path: path, start: start, deletions: deleteCount, insertions: encoded)
    }

    func replaceSubrange(_ subrange: Range<Int>, with string: String) {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        let encoded: [Object] = Array(string).map({ .primitive(.string(String($0))) })
        context.splice(path: path, start: start, deletions: deleteCount, insertions: encoded)
    }

    func delete(_ characterCount: Int, charactersAtIndex index: Int) {
        context.splice(path: path, start: index, deletions: characterCount, insertions: [])
    }

    func delete(at index: Int) {
        context.splice(path: path, start: index, deletions: 1, insertions: [])
    }

}
