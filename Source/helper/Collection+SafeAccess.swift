//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 25.05.21.
//

import Foundation

extension Collection {

    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
}
