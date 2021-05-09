//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 16.04.21.
//

import Foundation
import XCTest
@testable import Automerge

final class ApplyPatchTest: XCTestCase {

    // Set map key
//    func testApplyPatch1() {
//        // GIVEN
//        let patch = ObjectDiff(objectId: "00000000-0000-0000-0000-000000000000", type: .map, props: ["key1": ["f788794f7f0f48fbb44289b2a06d4d5b": "value1"]])
//        let obj: Object = .map(Map(objectId: "00000000-0000-0000-0000-000000000000", mapValues: [:], conflicts: [:]))
//        var updated = [ObjectId: Object]()
//
//        // WHEN
//        guard case .map(let newMap)? = interpretPatch(patch: patch, obj: obj, updated: &updated) else {
//            XCTFail()
//            return
//        }
//
//        XCTAssertEqual(newMap["key1"], .primitive("value1"))
//        XCTAssertEqual(newMap.objectId, "00000000-0000-0000-0000-000000000000")
//        XCTAssertEqual(newMap.conflicts, [
//            "key1": ["f788794f7f0f48fbb44289b2a06d4d5b": .primitive("value1")]
//        ])
//    }

//    // Set map list
//    func testApplyPatch2() {
//        // GIVEN
//        let patch = ObjectDiff(
//            objectId: "E10E9F4C-721D-4925-A580-C667DD538A02",
//            type: .list,
//            edits: [Edit(action: .insert, index: 0)],
//            props: [0: ["595663f742244778981c54fbe0ee6bd7": "chaffinch"]]
//        )
//        var updated: [ObjectId: Object] = [
//            "00000000-0000-0000-0000-000000000000": .map(Map(objectId: "00000000-0000-0000-0000-000000000000", mapValues: [:], conflicts: [:]))
//        ]
//
//        // WHEN
//        guard case .list(let newList)? = interpretPatch(patch: patch, obj: nil, updated: &updated) else {
//            XCTFail()
//            return
//        }
//
//        XCTAssertEqual(newList.listValues, [.primitive(.string("chaffinch"))])
//        XCTAssertEqual(newList.objectId, "E10E9F4C-721D-4925-A580-C667DD538A02")
//        XCTAssertEqual(newList.conflicts.count, 1)
//        XCTAssertEqual(newList.conflicts, [
//            ["595663f742244778981c54fbe0ee6bd7": .primitive("chaffinch")]
//        ])
//    }



}
