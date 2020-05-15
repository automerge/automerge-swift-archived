//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 26.04.20.
//

import Foundation
@testable import Automerge

final class BackendMock: Backend {

    private let applyLocalChange: (Request) -> Patch

    init(applyLocalChange: @escaping (Request) -> Patch = { _ in return Patch(clock: [:], version: 0, canUndo: false, canRedo: false, diffs: ObjectDiff(objectId: UUID().uuidString, type: .map)) }) {
        self.applyLocalChange = applyLocalChange
    }

    func applyLocalChange(request: Request) -> (Backend, Patch) {
        return (self, applyLocalChange(request))
    }
    func save() -> [UInt8] {
        return []
    }

}
