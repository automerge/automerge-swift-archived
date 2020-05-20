//
//  DocumentTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 16.05.20.
//

import Foundation
import XCTest
@testable import Automerge

struct DocumentState: Codable, Equatable {
    struct Birds: Codable, Equatable {
        let wrens: Int
        let magpies: Int
    }
    var birds: Birds?
}

struct DocumentT2: Codable, Equatable {
    var bird: String?
}

// Refers to test/frontend_test.js
class DocumentTest: XCTestCase {

    // should allow instantiating from an existing object
    func testInitializing1() {
        let initialState = DocumentState(birds: .init(wrens: 3, magpies: 4))
        let document = Document(initialState)
        XCTAssertEqual(document.content, initialState)
    }

    // should return the unmodified document if nothing changed
    func testPerformingChanges1() {
        let initialState = DocumentState(birds: .init(wrens: 3, magpies: 4))
        var document = Document(initialState)
        document.change({ _ in

        })
        XCTAssertEqual(document.content, initialState)
    }

    // should set root object properties
    func testPerformingChanges2() {
        struct Schema: Codable, Equatable {
            var bird: String?
        }
        let actor = ActorId()
        var doc = Document(Schema(bird: nil), options: .init(actorId: actor))
        let req = doc.change({ $0[\.bird, "bird"] = "magpie" })

        XCTAssertEqual(doc.content, Schema(bird: "magpie"))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: actor.actorId, seq: 1, version: 0, ops: [
            Op(action: .set, obj: ROOT_ID, key: "bird", insert: false, value: .string("magpie"))
        ], undoable: true))
    }

    // should create nested maps
    func testPerformingChanges3() {
        struct Schema: Codable, Equatable {
            struct Birds: Codable, Equatable { let wrens: Int }
            var birds: Birds?
        }
        var doc = Document(Schema(birds: nil))
        let req = doc.change({ $0[\.birds, "birds"] = .init(wrens: 3) })
        XCTAssertEqual(doc.content, Schema(birds: .init(wrens: 3)))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: doc.actor.actorId, seq: 1, version: 0, ops: [
            Op(action: .makeMap, obj: ROOT_ID, key: "birds", insert: false, child: req!.ops[1].obj),
            Op(action: .set, obj: req!.ops[1].obj, key: "wrens", insert: false, value: .int(3))
        ], undoable: true))
    }

    // should apply updates inside nested maps
    func testPerformingChanges4() {
        struct Schema: Codable, Equatable {
            struct Birds: Codable, Equatable { let wrens: Int; var sparrows: Int? }
            var birds: Birds?
        }
        var doc1 = Document(Schema(birds: nil))
        doc1.change({ $0[\.birds, "birds"] = .init(wrens: 3, sparrows: nil) })
        var doc2 = doc1
        let req = doc2.change({ $0[\.birds!.sparrows, "birds.sparrows"] = 15 })
        let birds = doc2.getObjectId(\.birds, "birds")
        XCTAssertEqual(doc1.content, Schema(birds: .init(wrens: 3, sparrows: nil)))
        XCTAssertEqual(doc2.content, Schema(birds: .init(wrens: 3, sparrows: 15)))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: doc1.actor.actorId, seq: 2, version: 1, ops: [
            Op(action: .set, obj: birds!, key: "sparrows", insert: false, value: .int(15))
        ], undoable: true))
    }

    // should delete keys in maps
    func testPerformingChanges5() {
        struct Schema: Codable, Equatable {
            var magpies: Int?; let sparrows: Int?
        }
        let actor = ActorId()
        let doc1 = Document(Schema(magpies: 2, sparrows: 15), options: .init(actorId: actor))
        var doc2 = doc1
        let req = doc2.change { $0[\.magpies, "magpies"] = nil }
        XCTAssertEqual(doc1.content, Schema(magpies: 2, sparrows: 15))
        XCTAssertEqual(doc2.content, Schema(magpies: nil, sparrows: 15))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: actor.actorId, seq: 2, version: 1, ops: [
            Op(action: .del, obj: ROOT_ID, key: "magpies", insert: false, value: nil)
        ], undoable: true))
    }

    // should create lists
    func testPerformingChanges6() {
        struct Schema: Codable, Equatable {
            var birds: [String]?
        }
        var doc1 = Document(Schema(birds: nil))
        let req = doc1.change { $0[\.birds, "birds"] = ["chaffinch"] }
        XCTAssertEqual(doc1.content, Schema(birds: ["chaffinch"]))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: doc1.actor.actorId, seq: 1, version: 0, ops: [
            Op(action: .makeList, obj: ROOT_ID, key: "birds", insert: false, child: req!.ops[1].obj),
            Op(action: .set, obj: req!.ops[1].obj, key: 0, insert: true, value: .string("chaffinch"))
        ], undoable: true))
    }

    // should apply updates inside lists
    func testPerformingChanges7() {
        struct Schema: Codable, Equatable {
            var birds: [String]?
        }
        var doc1 = Document(Schema(birds: nil))
        doc1.change { $0[\.birds, "birds"] = ["chaffinch"] }
        var doc2 = doc1
        let req = doc2.change { $0[\.birds![0], "birds[0]"] = "greenfinch" }
        let birds = doc2.getObjectId(\.birds, "birds")
        XCTAssertEqual(doc1.content, Schema(birds: ["chaffinch"]))
        XCTAssertEqual(doc2.content, Schema(birds: ["greenfinch"]))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: doc1.actor.actorId, seq: 2, version: 1, ops: [
            Op(action: .set, obj: birds!, key: 0, value: .string("greenfinch"))
        ], undoable: true))
    }

    // should delete list elements
    func testPerformingChanges8() {
        struct Schema: Codable, Equatable {
            var birds: [String]
        }
        var doc1 = Document(Schema(birds: []))
        doc1.change { $0[\.birds, "birds"] = ["chaffinch", "goldfinch"] }
        var doc2 = doc1
        let req = doc2.change {
            var proxy: Proxy<[String]> = $0[\.birds, "birds"]
            proxy.remove(at: 0) }
        let birds = doc2.getObjectId(\.birds, "birds")
        XCTAssertEqual(doc1.content, Schema(birds: ["chaffinch", "goldfinch"]))
        XCTAssertEqual(doc2.content, Schema(birds: ["goldfinch"]))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: doc2.actor.actorId, seq: 3, version: 2, ops: [
            Op(action: .del, obj: birds!, key: 0)
        ], undoable: true))
    }

    // should store Date objects as timestamps
    func testPerformingChanges9() {
        struct Schema: Codable, Equatable {
            var now: Date?
        }
        let now = Date(timeIntervalSince1970: 0)
        var doc1 = Document(Schema(now: nil))
        let req = doc1.change { $0[\.now, "now"] = now }
        XCTAssertEqual(doc1.content, Schema(now: now))
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: doc1.actor.actorId, seq: 1, version: 0, ops: [
            Op(action: .set, obj: ROOT_ID, key: "now", insert: false, value: .double(now.timeIntervalSince1970), datatype: .timestamp)
        ], undoable: true))
    }

    #warning("missing Counter tests")
//
//    // should use version and sequence number from the backend
//    func testBackendConcurrency1() {
//        struct Schema: Codable, Equatable {
//            var blackbirds: Int?
//            var partridges: Int?
//        }
//        let local = ActorId(), remtote1 = ActorId(), remtote2 = ActorId()
//        let patch1 = Patch(
//            clock: [local.actorId: 4, remtote1.actorId: 11, remtote2.actorId: 41],
//            version: 3,
//            canUndo: false,
//            canRedo: false,
//            diffs: .init(objectId: ROOT_ID, type: .map, props: ["blackbirds": [local.actorId: 24]]))
//        var doc1 = Document(Schema(blackbirds: nil, partridges: nil), options: .init(actorId: local))
//        doc1.applyPatch(patch: patch1)
//        doc1.change { $0[\.partridges, "partridges"] = 1 }
//        let requests = doc1.state.requests.map { $0.request }
//        XCTAssertEqual(requests, [
//           Request(requestType: .change, message: "", time: requests[0].time, actor: doc1.actor.actorId, seq: 5, version: 3, ops: [
//            Op(action: .set, obj: ROOT_ID, key: "partridges", insert: false, value: .int(1))
//            ], undoable: true)
//        ])
//    }

//    it('should use version and sequence number from the backend', () => {
//      const local = uuid(), remote1 = uuid(), remote2 = uuid()
//      const patch1 = {
//        version: 3, canUndo: false, canRedo: false,
//        clock: {[local]: 4, [remote1]: 11, [remote2]: 41},
//        diffs: {objectId: ROOT_ID, type: 'map', props: {blackbirds: {[local]: {value: 24}}}}
//      }
//      let doc1 = Frontend.applyPatch(Frontend.init(local), patch1)
//      let [doc2, req] = Frontend.change(doc1, doc => doc.partridges = 1)
//      let requests = getRequests(doc2)
//      assert.deepStrictEqual(requests, [
//        {requestType: 'change', actor: local, seq: 5, time: requests[0].time, message: '', version: 3, ops: [
//          {obj: ROOT_ID, action: 'set', key: 'partridges', insert: false, value: 1}
//        ]}
//      ])
//    })


//    // should remove pending requests once handled
//    func testBackendConcurrency2() {
//        struct Schema: Codable, Equatable {
//            var blackbirds: Int?
//            var partridges: Int?
//        }
//        let actor = ActorId()
//        var doc =  Document(Schema(blackbirds: nil, partridges: nil), options: .init(actorId: actor))
//        doc.change({ $0[\.blackbirds, "blackbirds"] = 24 })
//        doc.change({ $0[\.partridges, "partridges"] = 1 })
//        let requests = doc.state.requests.map { $0.request }
//        XCTAssertEqual(requests, [
//           Request(requestType: .change, message: "", time: requests[0].time, actor: actor.actorId, seq: 1, version: 0, ops: [
//            Op(action: .set, obj: ROOT_ID, key: "blackbirds", insert: false, value: .int(24))
//            ], undoable: true),
//           Request(requestType: .change, message: "", time: requests[1].time, actor: actor.actorId, seq: 2, version: 0, ops: [
//           Op(action: .set, obj: ROOT_ID, key: "partridges", insert: false, value: .int(1))
//           ], undoable: true)
//        ])
//        doc.applyPatch(patch: Patch(actor: actor.actorId,
//                                    seq: 1,
//                                    clock: [actor.actorId: 1],
//                                    version: 1,
//                                    canUndo: true,
//                                    canRedo: false,
//                                    diffs: ObjectDiff(objectId: ROOT_ID, type: .map, props: ["blackbirds": [actor.actorId: 24]])
//            )
//        )
//
//        let requests2 = doc.state.requests.map { $0.request }
//        XCTAssertEqual(doc.content, Schema(blackbirds: 24, partridges: 1))
//        XCTAssertEqual(requests2, [
//           Request(requestType: .change, message: "", time: requests2[0].time, actor: actor.actorId, seq: 2, version: 0, ops: [
//            Op(action: .set, obj: ROOT_ID, key: "partridges", insert: false, value: .int(1))
//            ], undoable: true)
//        ])
//
//        doc.applyPatch(patch: Patch(actor: actor.actorId,
//                                    seq: 2,
//                                    clock: [actor.actorId: 2],
//                                    version: 2,
//                                    canUndo: true,
//                                    canRedo: false,
//                                    diffs: ObjectDiff(objectId: ROOT_ID, type: .map, props: ["partridges": [actor.actorId: 1]])
//            )
//        )
//
//        XCTAssertEqual(doc.content, Schema(blackbirds: 24, partridges: 1))
//        XCTAssertEqual(doc.state.requests.map { $0.request }, [])
//    }
}
