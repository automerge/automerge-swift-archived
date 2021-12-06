//
//  Text.swift
//  
//
//  Created by Lukas Schmidt on 21.04.20.
//

import Foundation

/// A data structure that represents text.
public struct Text: Equatable {

    struct Character: Codable, Equatable {
        init(value: Object, pred: [ObjectId], elmId: ObjectId) {
            self.value = value
            self.pred = pred
            self.elmId = elmId
        }
        let value: Object
        let pred: [ObjectId]
        let elmId: ObjectId
    }
    
    /// Creates a new Text data structure.
    public init() {
        self.content = []
        self.objectId = ObjectId("")
        self.conflicts = []
    }
    
    /// Creates a new Text data structure with the content you provide.
    /// - Parameter content: The initial text contents.
    public init(_ content: String) {
        self.content = [Swift.Character](content).map { Character(value: .primitive(.string(String($0))), pred: [], elmId: "") }
        self.objectId = ObjectId("")
        self.conflicts = []
    }

    init(objectId: ObjectId, content: [Character], conflicts: [[String: Character]] = []) {
        self.objectId = objectId
        self.content = content
        self.conflicts = conflicts
    }

    let objectId: ObjectId
    var content: [Character]
    var conflicts: [[String: Character]]
    var elemIds: [ObjectId] {
        return content.map { $0.elmId }
    }
    
    /// Inserts a string at the index location you provide.
    /// - Parameters:
    ///   - character: The string to add.
    ///   - index: The index location of where to add the string.
    public mutating func insert(_ character: String, at index: Int) {
        precondition(character.count == 1)
        content.insert(Character(value: .primitive(.string(character)), pred: [], elmId: ""), at: index)
    }
    
    /// Inserts a list of characters at the index location you provide.
    /// - Parameters:
    ///   - characters: The characters to add.
    ///   - index: The index location of where to add the characters.
    public mutating func insert(contentsOf characters: [String], at index: Int) {
        content.insert(contentsOf: characters.map({ Character(value: .primitive(.string(String($0))), pred: [], elmId: "") }), at: index)
    }
    
    /// Removes a number of characters starting at the location you provide.
    /// - Parameters:
    ///   - characterCount: The number of characters to remove.
    ///   - index: The index location of where to start removing the characters.
    public mutating func delete(_ characterCount: Int, charactersAtIndex index: Int) {
        content.removeSubrange(index..<index + characterCount)
    }
    
    /// Removes a character at the location you provide.
    /// - Parameter index: The index location of the character to remove.
    public mutating func delete(at index: Int) {
        delete(1, charactersAtIndex: index)
    }
}

extension Text: Codable {
    enum CodingKeys: String, CodingKey {
        case content = "_am_text_content_"
    }

    /// Creates a new Text data structure by decoding from the provided decoder.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let contaier = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try contaier.decode([Character].self, forKey: .content)
        self.objectId = ObjectId("")
        self.conflicts = []
    }

    /// Encodes this Text data structure into the provided encoder.
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
    }
}

extension Text: Collection {
    /// Returns the index location following the index location you provide.
    /// - Parameter i: An index location.
    public func index(after i: Int) -> Int {
        content.index(after: i)
    }
    
    /// The index location of the start of the Text data structure.
    public var startIndex: Int {
        return content.startIndex
    }
    
    /// The index location of the end of the Text data structure.
    public var endIndex: Int {
        return content.endIndex
    }

    /// Returns the character at the index location you provide.
    public subscript(index: Int) -> String {
        if case .primitive(.string(let character)) = content[index].value {
            return character
        }
        fatalError("unsupported")
    }
}

extension Text: CustomStringConvertible {
    
    /// A string representation of the Text data structure.
    public var description: String {
        return content.compactMap({ element in
            if case .primitive(.string(let character)) = element.value {
                return character
            }
            return nil
        }).joined()
    }

}

extension Text: ExpressibleByStringLiteral {
    
    /// Creates a new Text data stucture from the string representation you provide.
    /// - Parameter value: The string representation of the Text data structure.
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

}
