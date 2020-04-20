//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import XCTest
@testable import Automerge

class LukasTests: XCTestCase {

//    func testGIVEN_emptyDocument_WHEN_setKeyOnRootObject_THEN_ShouldBeSet() {
//        // GIVEN
//        let actor = UUID()
//        let frontend = Document<Any>(actorId: actor)
//
//        // WHEN
//        let (doc, req) = frontend.change(execute: { context in
//            context.set(value: "bird", keyPath: "magpie")
//        })
//
//        // THEN
//        XCTAssertEqual(req, Request(requestType: .change,
//                                    message: nil,
//                                    actor: actor,
//                                    seq: 1,
//                                    version: 0,
//                                    ops: [
//                                        Op(action: .set,
//                                           obj: ROOT_ID,
//                                           key: .string("bird"),
//                                           insert: nil,
//                                           child: nil,
//                                           value: .string("magpie"),
//                                           datatype: nil
//                                        )],
//                                    undoable: true)
//        )
////        XCTAssertEqual(doc.root as? [String: String], ["bird": "magpie"])
//    }

}

//it('should set root object properties', () => {
//  const actor = uuid()
//  const [doc, req] = Frontend.change(Frontend.init(actor), doc => doc.bird = 'magpie')
//  assert.deepStrictEqual(doc, {bird: 'magpie'})
//  assert.deepStrictEqual(req, {requestType: 'change', actor, seq: 1, version: 0, ops: [
//    {obj: ROOT_ID, action: 'set', key: 'bird', value: 'magpie'}
//  ]})
//})
