//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 21.05.21.
//

import Foundation

extension Proxy where Wrapped: Codable {
    
    /// Updates your document's model object with a new instance of the model.
    /// - Parameter newValue: The updated state for your model.
    public func set(_ newValue: Wrapped) {
        let object = try! objectEncoder.encode(newValue)

        set(newValue: object)
    }
    
}

extension MutableProxy where Wrapped: Codable {

    /// Updates your document's model object with a new instance of the model.
    /// - Parameter newValue: The updated state for your model.
    public func set(_ newValue: Wrapped) {
        let object = try! objectEncoder.encode(newValue)

        set(newValue: object)
    }

}
