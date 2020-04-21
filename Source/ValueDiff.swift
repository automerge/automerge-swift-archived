//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

struct ValueDiff: Equatable {

    init(value: Primitives, datatype: DataType? = nil) {
        self.value = value
        self.datatype = datatype
    }

    var value: Primitives
    var datatype: DataType?
}
