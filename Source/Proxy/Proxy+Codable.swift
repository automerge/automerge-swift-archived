//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 21.05.21.
//

import Foundation

extension Proxy where Wrapped: Codable {

    public func set(_ newValue: Wrapped) {
        let mapper = TypeToObject()
        let object = try! mapper.map(newValue)

        set(newValue: object)
    }
    
}
