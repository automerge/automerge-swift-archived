//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 08.03.21.
//

import Foundation

struct ValueDiff: Equatable, Codable {

    init(value: Primitive, datatype: DataType? = nil) {
        self.value = value
        self.datatype = datatype
    }

    let value: Primitive
    let datatype: DataType?
}
