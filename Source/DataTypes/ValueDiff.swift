//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 08.03.21.
//

import Foundation

struct ValueDiff: Equatable, Codable {

    init(value: Primitive, datatype: DataType? = nil) {
        self.type = "value"
        self.value = value
        self.datatype = datatype
    }

    init(date: Date) {
        let miliseconds: Primitive = .float64(Double(Int(date.timeIntervalSince1970 * 1000)))
        self.init(value: miliseconds, datatype: .timestamp)
    }

    let type: String
    let value: Primitive
    let datatype: DataType?


    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try values.decode(String.self, forKey: .type)
        if type != "value" {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
        self.datatype = try values.decodeIfPresent(DataType.self, forKey: .datatype)
        switch datatype {
        case .counter, .int:
            self.value = .int(try values.decode(Int.self, forKey: .value))
        case .float64, .timestamp:
            self.value = .float64(try values.decode(Double.self, forKey: .value))
        case .uint:
            self.value = .uint(try values.decode(UInt.self, forKey: .value))
        case .none:
            if let string = try? values.decode(String.self, forKey: .value) {
                self.value = .string(string)
            } else if let bool = try? values.decode(Bool.self, forKey: .value) {
                self.value = .bool(bool)
            } else {
                self.value = .null
            }
        }
    }
}
