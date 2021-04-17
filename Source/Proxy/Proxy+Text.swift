//
//  Proxy+Text.swift
//  Automerge
//
//  Created by Lukas Schmidt on 04.06.20.
//

import Foundation

public extension Proxy where Wrapped == Text {

    func insert(_ character: String, at index: Int) {
        precondition(character.count == 1)
//        context.splice(path: path, start: index, deletions: 0, insertions: [["value": character]])
    }

    func insert(contentsOf characters: [String], at index: Int) {
//        context.splice(path: path, start: index, deletions: 0, insertions: characters.map { ["value": $0] })
    }

    func delete(_ characterCount: Int, charactersAtIndex index: Int) {
        context.splice(path: path, start: index, deletions: characterCount, insertions: [])
    }

    func delete(at index: Int) {
        context.splice(path: path, start: index, deletions: 1, insertions: [])
    }

}
