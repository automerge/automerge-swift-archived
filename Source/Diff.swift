//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

enum Diff: Equatable {
    case object(ObjectDiff)
    case value(ValueDiff)

    var link: Bool {
        fatalError()
    }

    var objectId: UUID? {
        if case .object(let object) = self {
            return object.objectId
        }
        return nil
    }
}
