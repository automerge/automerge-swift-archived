//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation

extension Proxy where Wrapped == Date {

    public func set(_ newValue: Wrapped) {
        set(newValue: .date(newValue))
    }

}

extension Proxy where Wrapped == Date? {

    public func set(_ newValue: Wrapped) {
        if let newValue = newValue {
            set(newValue: .date(newValue))
        } else {
            set(newValue: .primitive(.null))
        }
    }

}

