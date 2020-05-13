//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public protocol Backend {

    func applyLocalChange(request: Request) -> (Backend, Patch)
    
}

public struct DefaultBackend: Backend {

    public init() {}

    public func applyLocalChange(request: Request) -> (Backend, Patch) {
        return (self, Patch(clock: [:], version: 0, canUndo: false, canRedo: false, diffs: ObjectDiff(objectId: UUID().uuidString, type: .map)))
    }

}




