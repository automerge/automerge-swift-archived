//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 21.04.20.
//

import Foundation

public struct Text: Equatable {

    struct Character: Codable, Equatable {
        init(value: String, opId: String) {
            self.value = value
            self.opId = opId
        }
        let value: String
        let opId: String
    }

    public init() {
        self.content = []
        self.objectId = ""
        self.conflicts = []
    }

    public init(_ content: String) {
        self.content = [Swift.Character](content).map { Character(value: String($0), opId: "") }
        self.objectId = ""
        self.conflicts = []
    }

    init(objectId: String, content: [Character], conflicts: [[String: Character]] = []) {
        self.objectId = objectId
        self.content = content
        self.conflicts = conflicts
    }

    let objectId: String
    var content: [Character]
    var conflicts: [[String: Character]]

    public mutating func insert(_ character: String, at index: Int) {
        precondition(character.count == 1)
        content.insert(Character(value: character, opId: ""), at: index)
    }

    public mutating func insert(contentsOf characters: [String], at index: Int) {
        content.insert(contentsOf: characters.map({ Character(value: $0, opId: "") }), at: index)
    }

    public mutating func delete(_ characterCount: Int, charactersAtIndex index: Int) {
        content.removeSubrange(index..<index + characterCount)
    }

    public mutating func delete(at index: Int) {
        delete(1, charactersAtIndex: index)
    }
}

extension Text: Codable {
    enum CodingKeys: String, CodingKey {
        case content = "_am_text_content_"
    }

    public init(from decoder: Decoder) throws {
        let contaier = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try contaier.decode([Character].self, forKey: .content)
        self.objectId = ""
        self.conflicts = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
    }
}

extension Text: Collection {
    public func index(after i: Int) -> Int {
        content.index(after: i)
    }

    public var startIndex: Int {
        return content.startIndex
    }

    public var endIndex: Int {
        return content.endIndex
    }

    public subscript(index: Int) -> String {
        return content[index].value
    }
}

extension Text: CustomStringConvertible {
    
    public var description: String {
        return content.map({ $0.value }).joined()
    }

}

extension Text: ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

}
