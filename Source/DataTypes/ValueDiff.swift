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
        let miliseconds: Primitive = .number(Double(Int(date.timeIntervalSince1970 * 1000)))
        self.value = miliseconds
        self.type = "value"
        self.datatype = .timestamp
    }

    let type: String
    let value: Primitive
    let datatype: DataType?
}
