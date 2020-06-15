//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 21.04.20.
//

import Foundation

public struct Text: Codable, Equatable {

    public init() {
        self.elms = []
    }

    public init(_ content: String) {
        self.elms = [Character](content).map { String($0) }
    }

    var elms: [String]
    let isTextElement: Bool = true

    enum CodingKeys: String, CodingKey {
        case elms = "_am_list_values_"
        case isTextElement = "_am_is_Text_Element_"
    }

    public init(from decoder: Decoder) throws {
        let contaier = try decoder.singleValueContainer()
        let elems = try contaier.decode([[String: String]].self)

        self.elms = elems.map({ $0["value"]! })
    }

    public mutating func insert(_ character: String, at index: Int) {
        precondition(character.count == 1)
        elms.insert(character, at: index)
    }

    public mutating func insert(contentsOf characters: [String], at index: Int) {
        elms.insert(contentsOf: characters, at: index)
    }

    public mutating func delete(_ characterCount: Int, charactersAtIndex index: Int) {
        elms.removeSubrange(index..<index + characterCount)
    }

    public mutating func delete(at index: Int) {
        delete(1, charactersAtIndex: index)
    }
}

extension Text: Collection {
    public func index(after i: Int) -> Int {
        elms.index(after: i)
    }

    public var startIndex: Int {
        return elms.startIndex
    }

    public var endIndex: Int {
        return elms.endIndex
    }

    public subscript(index: Int) -> String {
        return elms[index]
    }
}

extension Text: CustomStringConvertible {
    
    public var description: String {
        return elms.joined()
    }

}

extension Text: ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

}
