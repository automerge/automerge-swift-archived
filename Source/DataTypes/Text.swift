//
//  Text.swift
//  
//
//  Created by Lukas Schmidt on 21.04.20.
//

import Foundation

/// A model that represents text.
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

    public init() {
        self.content = []
        self.objectId = ObjectId("")
        self.conflicts = []
    }

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

    public mutating func insert(_ character: String, at index: Int) {
        precondition(character.count == 1)
        content.insert(Character(value: .primitive(.string(character)), pred: [], elmId: ""), at: index)
    }

    public mutating func insert(contentsOf characters: [String], at index: Int) {
        content.insert(contentsOf: characters.map({ Character(value: .primitive(.string(String($0))), pred: [], elmId: "") }), at: index)
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
        self.objectId = ObjectId("")
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
        if case .primitive(.string(let character)) = content[index].value {
            return character
        }
        fatalError("unsupported")
    }
}

extension Text: CustomStringConvertible {
    
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

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

}
