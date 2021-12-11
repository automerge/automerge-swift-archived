//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

extension MutableProxy where Wrapped == Date {
    
    /// Sets an updated Date into your model.
    /// - Parameter newValue: The updated value for the Date.
    public func set(_ newValue: Wrapped) {
        set(newValue: .date(newValue))
    }

}

extension MutableProxy where Wrapped == Date? {
    
    /// Sets an updated Date into your model.
    /// - Parameter newValue: The updated value for the Date.
    public func set(_ newValue: Wrapped) {
        if let newValue = newValue {
            set(newValue: .date(newValue))
        } else {
            set(newValue: .primitive(.null))
        }
    }

}
