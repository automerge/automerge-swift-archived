//
//  Proxy+Text.swift
//  Automerge
//
//  Created by Lukas Schmidt on 04.06.20.
//

import Foundation

public extension Proxy where Wrapped == Text {
    
    /// Inserts a character at the index location you provide for the text model.
    /// - Parameters:
    ///   - character: The character to insert.
    ///   - index: The location to insert the character.
    func insert(_ character: Character, at index: Int) {
        context.splice(path: path, start: index, deletions: 0, insertions: [.primitive(.string(String(character)))])
    }
    
    /// Inserts a string at the index location you provide for the text model.
    /// - Parameters:
    ///   - string: The string to insert.
    ///   - index: The location to insert the string.
    func insert(_ string: String, at index: Int) {
        insert(contentsOf: Array(string), at: index)
    }
    
    /// Inserts a list of characters at the location you provide for the text model.
    /// - Parameters:
    ///   - characters: The list of characters to insert.
    ///   - index: The location to insert the list of characters.
    func insert(contentsOf characters: [Character], at index: Int) {
        context.splice(path: path, start: index, deletions: 0, insertions: characters.map({ character in
            return .primitive(.string(String(character)))
        }))
    }
    
    /// Replaces a set of characters at the index positions you provide with a new set of characters.
    /// - Parameters:
    ///   - subrange: The range of the characters to replace.
    ///   - newElements: The characters to insert within the range provided.
    func replaceSubrange(_ subrange: Range<Int>, with newElements: [Character]) {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        let encoded: [Object] = newElements.map({ .primitive(.string(String($0))) })
        context.splice(path: path, start: start, deletions: deleteCount, insertions: encoded)
    }
    
    /// Replaces a string at the index positions you provide with a new set of characters.
    /// - Parameters:
    ///   - subrange: The range of the characters to replace.
    ///   - string: The string to insert within the range provided.
    func replaceSubrange(_ subrange: Range<Int>, with string: String) {
        let start = subrange.relative(to: self).startIndex
        let deleteCount = subrange.relative(to: self).endIndex - subrange.relative(to: self).startIndex
        let encoded: [Object] = Array(string).map({ .primitive(.string(String($0))) })
        context.splice(path: path, start: start, deletions: deleteCount, insertions: encoded)
    }
    
    /// Deletes the the number of characters you specify at the location you provide.
    /// - Parameters:
    ///   - characterCount: The number of characters to delete.
    ///   - index: The location to start removing the characters.
    func delete(_ characterCount: Int, charactersAtIndex index: Int) {
        context.splice(path: path, start: index, deletions: characterCount, insertions: [])
    }
    
    /// Deletes a character at the location you provide.
    /// - Parameter index: The location of the character to remove.
    func delete(at index: Int) {
        context.splice(path: path, start: index, deletions: 1, insertions: [])
    }

}
