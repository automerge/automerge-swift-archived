//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

struct Edit: Equatable {
    enum Action: Equatable {
        case insert
        case remove
    }

  let action: Action
  let index: Int
}
