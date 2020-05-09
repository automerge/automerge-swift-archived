//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

struct Counter: Codable, Equatable {
    let value: Double

    enum CodingKeys: String, CodingKey  {
        case value = "_Counter_Value"
    }
}
