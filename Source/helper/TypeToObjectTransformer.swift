//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

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
}
