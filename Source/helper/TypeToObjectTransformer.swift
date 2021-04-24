//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

final class EncoderDateFormatter: DateFormatter {

    override init() {
        super.init()
        self.dateFormat = "'_am_date:'yyyy-MM-dd'T'HH:mm:ss:SSSZZZZZ"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

final class TypeToObject {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let formatter = EncoderDateFormatter()

    func map<T: Codable>(_ value: T) throws -> Object {
        encoder.dateEncodingStrategy = .formatted(formatter)
        decoder.dateDecodingStrategy = .formatted(formatter)
        let encoded = try encoder.encode(value)
        return try decoder.decode(Object.self, from: encoded)
    }

    func map<T: Codable>(_ value: Array<T>) throws -> [Object] {
        encoder.dateEncodingStrategy = .formatted(formatter)
        decoder.dateDecodingStrategy = .formatted(formatter)
        let encoded = try encoder.encode(value)
        return try decoder.decode([Object].self, from: encoded)
    }

    func map<T: Codable>(_ value: [String: T]) throws -> [String: Object] {
        encoder.dateEncodingStrategy = .formatted(formatter)
        decoder.dateDecodingStrategy = .formatted(formatter)
        let encoded = try encoder.encode(value)
        return try decoder.decode([String: Object].self, from: encoded)
    }
}
