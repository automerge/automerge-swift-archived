//
//  DictionaryEncoder.swift
//  Automerge
//
//  Created by Lukas Schmidt on 15.06.20.
//

import Foundation

final class EncoderDateFormatter: DateFormatter {

    override init() {
        super.init()
        self.dateFormat = "'_am_date:'yyyy-MM-dd'T'HH:mm:SSSZZZZZ"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

final class DictionaryEncoder {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(EncoderDateFormatter())

        return encoder
    }()

    func encode<T>(_ value: T) throws -> [String: Any] where T : Encodable {
        let data = try encoder.encode(value)
        guard let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
        return obj
    }

    func encode<T>(_ value: [T]) throws -> [[String: Any]] where T : Encodable {
        let data = try encoder.encode(value)
        guard let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: Any]] else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
        return obj
    }
}
