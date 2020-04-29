//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

protocol Backend {

    func applyLocalChange(request: Request) -> (Backend, Patch)
    
}




