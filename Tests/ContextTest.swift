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
    func testContextSetMapKey1() {
        // GIVEN
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID.uuidString: [:]],
            ops: []
        )

        // WHEN
        context.setMapKey(path: [], key: "sparrows", value: 5)

        // THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: ROOT_ID, key: .string("sparrows"), value: .number(5))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "sparrows": [actor.uuidString: .value(.init(value: .number(5),
                                                            datatype: nil))]])
        )
    }

    // should do nothing if the value was not changed
    func testContextSetMapKey2() {
        //Given
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID.uuidString: [
                    "goldfinches": 3,
                    OBJECT_ID: ROOT_ID.uuidString,
                    CONFLICTS: ["goldfinches": ["actor1": 3]]
                ]
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
    func testContextSetMapKey3() {
        //Given
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID.uuidString: [
                    "goldfinches": 5,
                    OBJECT_ID: ROOT_ID.uuidString,
                    CONFLICTS: ["goldfinches": ["actor1": 3, "actor2": 5]]
                ]
            ],
            ops: [])
        // WHEN
        context.setMapKey(path: [], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: ROOT_ID, key: .string("goldfinches"), value: .number(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(objectId: ROOT_ID,
                                                    type: .map,
                                                    props: [
                                                        "goldfinches": [actor.uuidString: .value(.init(value: .number(3),
                                                                                                       datatype: nil))]]))
    }

    //should create nested maps
    func testContextSetMapKey4() {
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
            props: [
                "birds": [actor.uuidString: .object(.init(
                    objectId: objectId,
                    type: .map,
                    props: [
                        "goldfinches": [actor.uuidString: .value(.init(value: .number(3), datatype: nil))]]
                    ))
                ]
            ]
            )
        )
    }

    // should perform assignment inside nested maps
    func testContextSetMapKey5() {
        let actor = UUID()
        let objectId = UUID()
        let child = [OBJECT_ID: objectId.uuidString]
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
        context.setMapKey(path: [.init(key: .string("birds"), objectId: objectId)], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId, key: .string("goldfinches"), value: .number(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "birds": ["actor1": .object(.init(
                    objectId: objectId,
                    type: .map,
                    props: [
                        "goldfinches": [actor.uuidString: .value(.init(value: .number(3), datatype: nil))]]
                    ))
                ]
            ]
            )
        )
    }

    // should perform assignment inside conflicted maps
    func testContextSetMapKey6() {
        //Given
        let actor = UUID()
        let objectId1 = UUID()
        let child1 = [OBJECT_ID: objectId1.uuidString]
        let objectId2 = UUID()
        let child2 = [OBJECT_ID: objectId2.uuidString]
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId1.uuidString: child1,
                objectId2.uuidString: child2,
                ROOT_ID.uuidString: [
                    OBJECT_ID: ROOT_ID,
                    "birds": child2,
                    CONFLICTS: [
                        "birds": [
                            "actor1": child1,
                            "actor2": child2
                        ]
                    ]
                ]
        ])

        //When
        context.setMapKey(path: [.init(key: .string("birds"), objectId: objectId2)], key: "goldfinches", value: 3)

        //Then
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId2, key: .string("goldfinches"), value: .number(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "birds": [
                    "actor1": .object(.init(objectId: objectId1, type: .map)),
                    "actor2": .object(.init(
                        objectId: objectId2,
                        type: .map,
                        props: [
                            "goldfinches": [actor.uuidString: .value(.init(value: .number(3), datatype: nil))]
                        ]
                        ))
                ]
            ]
            )
        )
    }

    // should handle conflict values of various types
    func testContextSetMapKey7() {
        // Given
        let actor = UUID()
        let objectId = UUID()
        let child = [OBJECT_ID: objectId.uuidString]
        let dateValue = Date()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId.uuidString: child,
                ROOT_ID.uuidString: [
                    OBJECT_ID: ROOT_ID,
                    CONFLICTS: [
                        "values": [
                            "actor1": dateValue,
                            "actor2": Counter(value: 0),
                            "actor3": 42,
                            "actor4": NSNull(),
                            "actor5": child
                        ]
                    ],
                    "values": child
                ]
        ])
        //When
        context.setMapKey(path: [.init(key: .string("values"), objectId: objectId)], key: "goldfinches", value: 3)

        //Then
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId, key: .string("goldfinches"), value: .number(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "values": [
                    "actor1": .value(.init(value: .number(dateValue.timeIntervalSince1970), datatype: .timestamp)),
                    "actor2": .value(.init(value: .number(0), datatype: .counter)),
                    "actor3": .value(.init(value: .number(42))),
                    "actor4": .value(.init(value: .null)),
                    "actor5": .object(.init(objectId: objectId, type: .map, props: ["goldfinches": [actor.uuidString: .value(.init(value: .number(3)))]]))
                ]
            ]
            )
        )
    }

    // should create nested lists
    func testContextSetMapKey8() {
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID.uuidString: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "birds", value: ["sparrow", "goldfinch"])

        // Then
        let objectId = applyPatch.value!.props!["birds"]![actor]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeList, obj: ROOT_ID, key: .string("birds"), child: objectId),
            Op(action: .set, obj: objectId, key: .index(0), insert: true, value: .string("sparrow")),
            Op(action: .set, obj: objectId, key: .index(1), insert: true, value: .string("goldfinch"))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    actor.uuidString: .object(.init(objectId: objectId,
                                                    type: .list,
                                                    edits: [Edit(action: .insert, index: 0), Edit(action: .insert, index: 1)],
                                                    props: [
                                                        "0": [actor.uuidString: .value(.init(value: .string("sparrow")))],
                                                        "1":  [actor.uuidString: .value(.init(value: .string("goldfinch")))]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested Text objects
    func testContextSetMapKey9() {
        //Given
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID.uuidString: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "text", value: Text("hi"))

        //THEN
        let objectId = applyPatch.value!.props!["text"]![actor]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeText, obj: ROOT_ID, key: .string("text"), child: objectId),
            Op(action: .set, obj: objectId, key: .index(0), insert: true, value: .string("h")),
            Op(action: .set, obj: objectId, key: .index(1), insert: true, value: .string("i"))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "text": [
                    actor.uuidString: .object(.init(objectId: objectId,
                                                    type: .text,
                                                    edits: [Edit(action: .insert, index: 0), Edit(action: .insert, index: 1)],
                                                    props: [
                                                        "0": [actor.uuidString: .value(.init(value: .string("h")))],
                                                        "1":  [actor.uuidString: .value(.init(value: .string("i")))]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested Table objects
    func testContextSetMapKey10() {
        //Given
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID.uuidString: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "books", value: Table(columns: ["auther", "book"]))

        //Then
        let objectId = applyPatch.value!.props!["books"]![actor]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeTable, obj: ROOT_ID, key: .string("books"), child: objectId)
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "books": [
                    actor.uuidString: .object(.init(objectId: objectId, type: .table, props: [:]))
                ]
            ]
            )
        )
    }

    // should allow assignment of Date values
    func testContextSetMapKey11() {
        //Given
        let now = Date()
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID.uuidString: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "now", value: now)

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: ROOT_ID, key: .string("now"), value: .number(now.timeIntervalSince1970), datatype: .timestamp)
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "now": [
                    actor.uuidString: .value(.init(value: .number(now.timeIntervalSince1970), datatype: .timestamp))
                ]
            ]
            )
        )
    }

    // should allow assignment of Counter values
    func testContextSetMapKey12() {
        //Given
        let counter = Counter(value: 3)
        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID.uuidString: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "counter", value: counter)

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: ROOT_ID, key: .string("counter"), value: .number(3), datatype: .counter)
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "counter": [
                    actor.uuidString: .value(.init(value: .number(3), datatype: .counter))
                ]
            ]
            )
        )
    }

    // should overwrite an existing list element
    func testListManupulation1() {
        // Given
        let listId = UUID()
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId.uuidString,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId.uuidString: list,
                ROOT_ID.uuidString: [
                    OBJECT_ID: ROOT_ID.uuidString,
                    "birds": list,

                    CONFLICTS: [
                        "birds": ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.setListIndexpath(path: [.init(key: .string("birds"), objectId: listId)], index: 0, value: "starling")

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: listId, key: .index(0), value: .string("starling"))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    "actor1": .object(.init(objectId: listId,
                                                    type: .list,
                                                    props: [
                                                        "0": [actor.uuidString: .value(.string("starling"))]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested objects on assignment
    func testListManupulation2() {
        // Given
        let listId = UUID()
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId.uuidString,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = UUID()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId.uuidString: list,
                ROOT_ID.uuidString: [
                    OBJECT_ID: ROOT_ID.uuidString,
                    "birds": list,

                    CONFLICTS: [
                        "birds": ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.setListIndexpath(path: [.init(key: .string("birds"), objectId: listId)], index: 1, value: ["english": "goldfinch", "latin": "carduelis"])

        // Then
        let nestedId = applyPatch.value!.props!["birds"]!["actor1"]!.props!["1"]![actor]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: listId, key: .index(1), child: nestedId),
            Op(action: .set, obj: nestedId, key: .string("english"), value: .string("goldfinch")),
            Op(action: .set, obj: nestedId, key: .string("latin"), value: .string("carduelis"))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    "actor1": .object(.init(objectId: listId,
                                                    type: .list,
                                                    props: [
                                                        "1": [actor.uuidString: .object(.init(objectId: nestedId, type: .map, props: [
                                                            "english": [actor.uuidString: .value(.string("goldfinch"))],
                                                            "latin": [actor.uuidString: .value(.string("carduelis"))]
                                                        ]))]
                    ]))
                ]
            ]
            )
        )
    }

}
