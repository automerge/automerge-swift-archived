//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 17.04.20.
//

import Foundation
import XCTest
@testable import Automerge

final class Spion<T> {
    private (set) var value: T?
    private (set) var callCount = 0

    var observer: (T) -> Void {
        return {
            self.value = $0
            self.callCount += 1
        }
    }
}

extension Spion where T == ObjectDiff {

    var observerDiff: (T, Any, ReferenceDictionary<String, Any>) -> Void {
        return { diff, _, _ in
            self.observer(diff)
        }
    }

}

class ContextTest: XCTestCase {

    var applyPatch: Spion<ObjectDiff>!

    override func setUp() {
        super.setUp()
        applyPatch = Spion()
    }

    // should assign a primitive value to a map key
    func testContext1() {
        // GIVEN
        let actor = UUID()
        let document = Document<Int>(options: .init(actorId: actor))
        let context = Context(doc: document, actorId: actor, applyPatch: applyPatch.observerDiff)

        // WHEN
        context.setMapKey(path: [], key: "sparrows", value: 5)

        // THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: ROOT_ID, key: .string("sparrows"), value: .number(5))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "sparrows": [actor.uuidString: .value(.init(value: .number(5),
                                                            datatype: nil))]])
        )
    }

    // should do nothing if the value was not changed
    func testContext2() {
        //Given
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID.uuidString: ReferenceDictionary([
                    "goldfinches": 3,
                    OBJECT_ID: ROOT_ID.uuidString,
                    CONFLICTS: ["goldfinches": ["actor1": 3]]
                ])
            ],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [])
        XCTAssertNil(applyPatch.value)
        XCTAssertEqual(applyPatch.callCount, 0)
    }

    // should allow a conflict to be resolved
    func testContext3() {
        //Given
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID.uuidString: ReferenceDictionary([
                    "goldfinches": 5,
                    OBJECT_ID: ROOT_ID.uuidString,
                    CONFLICTS: ["goldfinches": ["actor1": 3, "actor2": 5]]
                ])
            ],
            ops: [])
        // WHEN
        context.setMapKey(path: [], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: ROOT_ID, key: .string("goldfinches"), value: .number(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(objectId: ROOT_ID,
                                              type: .map,
                                              edits: nil,
                                              props: [
                                                "goldfinches": [actor.uuidString: .value(.init(value: .number(3),
                                                                                               datatype: nil))]]))
    }

    //should create nested maps
    func testContext4() {
        // GIVEN
        let actor = UUID()
        let document = Document<Int>(options: .init(actorId: actor))
        let context = Context(doc: document, actorId: actor, applyPatch: applyPatch.observerDiff)

        // WHEN
        context.setMapKey(path: [], key: "birds", value: ["goldfinches": 3])

        let objectId = applyPatch.value!.props!["birds"]![actor]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: ROOT_ID, key: .string("birds"), child: objectId),
            Op(action: .set, obj: objectId, key: .string("goldfinches"), value: .number(3))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "birds": [actor.uuidString: .object(.init(
                    objectId: objectId,
                    type: .map,
                    edits: nil,
                    props: [
                    "goldfinches": [actor.uuidString: .value(.init(value: .number(3), datatype: nil))]]
                    ))
                ]
            ]
            )
        )
    }

    // should perform assignment inside nested maps
    func testContext5() {
        let actor = UUID()
        let objectId = UUID()
        let child = ReferenceDictionary([OBJECT_ID: objectId.uuidString])
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId.uuidString: child,
                ROOT_ID.uuidString: [
                    OBJECT_ID: ROOT_ID,
                    CONFLICTS: [
                        "birds": ["actor1": child]
                    ],
                    "birds": child
                ]
            ])

        // WHEN
        context.setMapKey(path: [Context.KeyPathElement.init(key: .string("birds"), objectId: objectId)], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [
                   Op(action: .set, obj: objectId, key: .string("goldfinches"), value: .number(3))
               ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "birds": ["actor1": .object(.init(
                    objectId: objectId,
                    type: .map,
                    edits: nil,
                    props: [
                        "goldfinches": [actor.uuidString: .value(.init(value: .number(3), datatype: nil))]]
                    ))
                ]
            ]
            )
        )
    }
    //    it('should perform assignment inside nested maps', () => {
    //      const objectId = uuid(), child = {[OBJECT_ID]: objectId}
    //      context.cache[objectId] = child
    //      context.cache[ROOT_ID] = {[OBJECT_ID]: ROOT_ID, [CONFLICTS]: {birds: {actor1: child}}, birds: child}
    //      context.setMapKey([{key: 'birds', objectId}], 'goldfinches', 3)
    //      assert(applyPatch.calledOnce)
    //      assert.deepStrictEqual(applyPatch.firstCall.args[0], {objectId: ROOT_ID, type: 'map', props: {
    //        birds: {actor1: {objectId, type: 'map', props: {
    //          goldfinches: {[context.actorId]: {value: 3}}
    //        }}}
    //      }})
    //      assert.deepStrictEqual(context.ops, [{obj: objectId, action: 'set', key: 'goldfinches', value: 3}])
    //    })

}

