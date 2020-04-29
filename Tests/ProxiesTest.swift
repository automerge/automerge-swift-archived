//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation
import XCTest
@testable import Automerge

struct DeepObj: Codable, Equatable {
    var list: [Int]
}

struct TestStruct: Codable {
    var key1: String?
    let key2: String
    var deepObj: DeepObj
}

class ProxiesTest: XCTestCase {

    // should have a fixed object ID
    func testProxie1() {
        // GIVEN
        let backend = BackendMock()
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            XCTAssertEqual(doc.objectId, ROOT_ID)
        })
    }

    // should expose keys as object properties
    func testProxie3() {
        // GIVEN
        let backend = BackendMock { req in
            return Patch(
                actor: req.actor.uuidString,
                seq: 1,
                clock: [req.actor: 1],
                version: 1,
                canUndo: true,
                canRedo: false,
                diffs: ObjectDiff(
                    objectId: ROOT_ID,
                    type: .map,
                    props: [
                        "key1": ["1@\(req.actor.uuidString)": .value(.string("value1"))]
                    ])
            )
        }
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.key1, "key1"] = "value1"
            XCTAssertEqual(doc[\.key1, "key1"], "value1")
        })
    }

    // should return undefined for unknown properties
    func testProxies4() {
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: BackendMock()))

        // WHEN
        _ = document.change(execute: { doc in
            XCTAssertNil(doc[\.key1, "key1"])
        })
    }

    // should allow access to an object by id
    func testProxies5() {
        let backend = BackendMock { req in
            return Patch(
                actor: req.actor.uuidString,
                seq: 1,
                clock: [req.actor: 1],
                version: 1,
                canUndo: true,
                canRedo: false,
                diffs: ObjectDiff(
                    objectId: ROOT_ID,
                    type: .map,
                    props: [
                        "deepObj": [
                            "1@\(req.actor.uuidString)": .object(.init(objectId: "1@\(req.actor.uuidString)", type: .map,
                                                                       props: [
                                                                        "deepList": ["2@\(req.actor.uuidString)": .object(.init(objectId: "2@\(req.actor.uuidString)", type: .list))]
                                                                        ]))
                        ]
                    ])
            )
        }
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [])

            XCTAssertEqual(doc[\.deepObj.list, "deepObj.list"], [])

            doc[\.deepObj, "deepObj"] = DeepObj(list: [1])

            XCTAssertEqual(doc[\.deepObj.list, "deepObj.list"], [1])
        })
    }
}



//  it('should allow access to an object by id', () => {
//    const doc = Automerge.change(Automerge.init(), doc => {
//      doc.deepObj = {}
//      doc.deepObj.deepList = []
//      const listId = Automerge.getObjectId(doc.deepObj.deepList)
//      assert.throws(() => { Automerge.getObjectById(doc, listId) }, /Cannot use getObjectById in a change callback/)
//    })
//
//    const objId = Automerge.getObjectId(doc.deepObj)
//    assert.strictEqual(Automerge.getObjectById(doc, objId), doc.deepObj)
//    const listId = Automerge.getObjectId(doc.deepObj.deepList)
//    assert.strictEqual(Automerge.getObjectById(doc, listId), doc.deepObj.deepList)
//  })
//})
