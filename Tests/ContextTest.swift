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

    var observerDiff: (T, [String: Any]?, inout [String: [String: Any]]) -> [String: Any]? {
        return { diff, _, _ in
            self.observer(diff)
            return [:]
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
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )

        // WHEN
        context.setMapKey(path: [], key: "sparrows", value: 5)

        // THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: ROOT_ID, key: "sparrows", value: .int(5))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "sparrows": [actor.actorId: .value(.init(value: .int(5),
                                                            datatype: nil))]])
        )
    }

    // should do nothing if the value was not changed
    func testContextSetMapKey2() {
        //Given
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID: [
                    "goldfinches": 3,
                    OBJECT_ID: ROOT_ID,
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
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID: [
                    "goldfinches": 5,
                    OBJECT_ID: ROOT_ID,
                    CONFLICTS: ["goldfinches": ["actor1": 3, "actor2": 5]]
                ]
            ],
            ops: [])
        // WHEN
        context.setMapKey(path: [], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: ROOT_ID, key: "goldfinches", value: .int(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(objectId: ROOT_ID,
                                                    type: .map,
                                                    props: [
                                                        "goldfinches": [actor.actorId: 3]]))
    }

    //should create nested maps
    func testContextSetMapKey4() {
        // GIVEN
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )

        // WHEN
        context.setMapKey(path: [], key: "birds", value: ["goldfinches": 3])

        let objectId = applyPatch.value!.props!["birds"]![actor.actorId]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: ROOT_ID, key: "birds", child: objectId),
            Op(action: .set, obj: objectId, key: "goldfinches", value: .int(3))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [actor.actorId: .object(.init(
                    objectId: objectId,
                    type: .map,
                    props: [
                        "goldfinches": [actor.actorId: 3]]
                    ))
                ]
            ]
            )
        )
    }

    // should perform assignment inside nested maps
    func testContextSetMapKey5() {
        let actor = ActorId()
        let objectId = UUID().uuidString
        let child = [OBJECT_ID: objectId]
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId: child,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    CONFLICTS: [
                        Key.string("birds"): ["actor1": child]
                    ],
                    "birds": child
                ]
        ])

        // WHEN
        context.setMapKey(path: [.init(key: "birds", objectId: objectId)], key: "goldfinches", value: 3)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId, key: "goldfinches", value: .int(3))])
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
                        "goldfinches": [actor.actorId: 3]]
                    ))
                ]
            ]
            )
        )
    }

    // should perform assignment inside conflicted maps
    func testContextSetMapKey6() {
        //Given
        let actor = ActorId()
        let objectId1 = UUID().uuidString
        let child1 = [OBJECT_ID: objectId1]
        let objectId2 = UUID().uuidString
        let child2 = [OBJECT_ID: objectId2]
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId1: child1,
                objectId2: child2,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": child2,
                    CONFLICTS: [
                        Key.string("birds"): [
                            "actor1": child1,
                            "actor2": child2
                        ]
                    ]
                ]
        ])

        //When
        context.setMapKey(path: [.init(key: "birds", objectId: objectId2)], key: "goldfinches", value: 3)

        //Then
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId2, key: "goldfinches", value: .int(3))])
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
                            "goldfinches": [actor.actorId: 3]
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
        let actor = ActorId()
        let objectId = UUID().uuidString
        let child = [OBJECT_ID: objectId]
        let dateValue = Date()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId: child,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    CONFLICTS: [
                        Key.string("values"): [
                            "actor1": dateValue,
                            "actor2": Counter(0),
                            "actor3": 42,
                            "actor4": NSNull(),
                            "actor5": child
                        ]
                    ],
                    "values": child
                ]
        ])
        //When
        context.setMapKey(path: [.init(key: "values", objectId: objectId)], key: "goldfinches", value: 3)

        //Then
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId, key: "goldfinches", value: .int(3))])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            edits: nil,
            props: [
                "values": [
                    "actor1": .value(.init(value: .double(dateValue.timeIntervalSince1970), datatype: .timestamp)),
                    "actor2": .value(.init(value: .int(0), datatype: .counter)),
                    "actor3": 42,
                    "actor4": .value(.init(value: .null)),
                    "actor5": .object(.init(objectId: objectId, type: .map, props: ["goldfinches": [actor.actorId: 3]]))
                ]
            ]
            )
        )
    }

    // should create nested lists
    func testContextSetMapKey8() {
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "birds", value: ["sparrow", "goldfinch"])

        // Then
        let objectId = applyPatch.value!.props!["birds"]![actor.actorId]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeList, obj: ROOT_ID, key: "birds", child: objectId),
            Op(action: .set, obj: objectId, key: .index(0), insert: true, value: .string("sparrow")),
            Op(action: .set, obj: objectId, key: .index(1), insert: true, value: .string("goldfinch"))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    actor.actorId: .object(.init(objectId: objectId,
                                                    type: .list,
                                                    edits: [Edit(action: .insert, index: 0), Edit(action: .insert, index: 1)],
                                                    props: [
                                                        0: [actor.actorId: "sparrow"],
                                                        1: [actor.actorId: "goldfinch"]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested Text objects
    func testContextSetMapKey9() {
        //Given
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "text", value: try! DictionaryEncoder().encode(Text("hi")))

        //THEN
        let objectId = applyPatch.value!.props!["text"]![actor.actorId]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeText, obj: ROOT_ID, key: "text", child: objectId),
            Op(action: .set, obj: objectId, key: .index(0), insert: true, value: .string("h")),
            Op(action: .set, obj: objectId, key: .index(1), insert: true, value: .string("i"))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "text": [
                    actor.actorId: .object(.init(objectId: objectId,
                                                    type: .text,
                                                    edits: [Edit(action: .insert, index: 0), Edit(action: .insert, index: 1)],
                                                    props: [
                                                        0: [actor.actorId: "h"],
                                                        1: [actor.actorId: "i"]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested Table objects
    func testContextSetMapKey10() {
        //Given
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "books", value: try! DictionaryEncoder().encode(Table<String>()))

        //Then
        let objectId = applyPatch.value!.props!["books"]![actor.actorId]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeTable, obj: ROOT_ID, key: "books", child: objectId)
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "books": [
                    actor.actorId: .object(.init(objectId: objectId, type: .table, props: [:]))
                ]
            ]
            )
        )
    }

    // should allow assignment of Date values
    func testContextSetMapKey11() {
        //Given
        let now = Date()
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "now", value: now)

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: ROOT_ID, key: "now", value: .double(now.timeIntervalSince1970), datatype: .timestamp)
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "now": [
                    actor.actorId: .value(.init(value: .double(now.timeIntervalSince1970), datatype: .timestamp))
                ]
            ]
            )
        )
    }

    // should allow assignment of Counter values
    func testContextSetMapKey12() {
        //Given
        let counter = Counter(3)
        let encoder = DictionaryEncoder()
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "counter", value: try! encoder.encode(counter))

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: ROOT_ID, key: "counter", value: .int(3), datatype: .counter)
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "counter": [
                    actor.actorId: .value(.init(value: .int(3), datatype: .counter))
                ]
            ]
            )
        )
    }

    // should allow assignment of UUID values
    func testContextSetMapKey13() {
        //Given
        let uuid = UUID()
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [ROOT_ID: [:]],
            ops: []
        )
        // WHEN
        context.setMapKey(path: [], key: "uuid", value: uuid)

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: ROOT_ID, key: "uuid", value: .string(uuid.uuidString))
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "uuid": [
                    actor.actorId: .value(.init(value: .string(uuid.uuidString)))
                ]
            ]
            )
        )
    }


    // should overwrite an existing list element
    func testListManupulation1() {
        // Given
        let listId = UUID().uuidString
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": list,

                    CONFLICTS: [
                        Key.string("birds"): ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.setListIndex(path: [.init(key: "birds", objectId: listId)], index: 0, value: "starling")

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
                                                0: [actor.actorId: "starling"]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested objects on assignment
    func testListManupulation2() {
        // Given
        let listId = UUID().uuidString
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": list,

                    CONFLICTS: [
                        Key.string("birds"): ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.setListIndex(path: [.init(key: "birds", objectId: listId)], index: 1, value: ["english": "goldfinch", "latin": "carduelis"])

        // Then
        let nestedId = applyPatch.value!.props!["birds"]!["actor1"]!.props![1]![actor.actorId]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: listId, key: .index(1), child: nestedId),
            Op(action: .set, obj: nestedId, key: "english", value: .string("goldfinch")),
            Op(action: .set, obj: nestedId, key: "latin", value: .string("carduelis"))
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
                                                1: [actor.actorId: .object(.init(objectId: nestedId, type: .map, props: [
                                                    "english": [actor.actorId: "goldfinch"],
                                                    "latin": [actor.actorId: "carduelis"]
                                                ]))]
                    ]))
                ]
            ]
            )
        )
    }

    // should create nested objects on insertion
    func testListManupulation3() {
        // Given
        let listId = UUID().uuidString
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId,
            CONFLICTS:  [Key.string("actor1"): "swallow", "actor2": "swallow"]
        ]

        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": list,

                    CONFLICTS: [
                        Key.string("birds"): ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.splice(path: [.init(key: "birds", objectId: listId)], start: 2, deletions: 0, insertions: [["english": "goldfinch", "latin": "carduelis"]])

        // Then
        let nestedId = applyPatch.value!.props!["birds"]!["actor1"]!.props![2]![actor.actorId]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: listId, key: 2, insert: true, child: nestedId),
            Op(action: .set, obj: nestedId, key: "english", value: .string("goldfinch")),
            Op(action: .set, obj: nestedId, key: "latin", value: .string("carduelis"))
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    "actor1": .object(.init(objectId: listId,
                                            type: .list,
                                            edits: [Edit(action: .insert, index: 2)],
                                            props: [
                                                2: [actor.actorId: .object(.init(objectId: nestedId, type: .map, props: [
                                                    "english": [actor.actorId: "goldfinch"],
                                                    "latin": [actor.actorId: "carduelis"]
                                                ]))]
                    ]))
                ]
            ]
            )
        )
    }

    // should support deleting list elements
    func testListManupulation4() {
        // Given
        let listId = UUID().uuidString
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": list,

                    CONFLICTS: [
                        Key.string("birds"): ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.splice(path: [.init(key: "birds", objectId: listId)], start: 0, deletions: 2, insertions: [String]())

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .del, obj: listId, key: 0),
            Op(action: .del, obj: listId, key: 0)
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    "actor1": .object(
                        .init(objectId: listId,
                              type: .list,
                              edits: [
                                Edit(action: .remove, index: 0),
                                Edit(action: .remove, index: 0)
                            ],
                              props: [:]
                        ))
                ]
            ]
            )
        )
    }

    // should support deleting list elements
    func testListManupulation5() {
        // Given
        let listId = UUID().uuidString
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": list,

                    CONFLICTS: [
                        Key.string("birds"): ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.splice(path: [.init(key: "birds", objectId: listId)], start: 0, deletions: 2, insertions: [String]())

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .del, obj: listId, key: 0),
            Op(action: .del, obj: listId, key: 0)
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    "actor1": .object(
                        .init(objectId: listId,
                              type: .list,
                              edits: [
                                Edit(action: .remove, index: 0),
                                Edit(action: .remove, index: 0)
                            ],
                              props: [:]
                        ))
                ]
            ]
            )
        )
    }

    // should support list splicing
    func testListManupulation6() {
        // Given
        let listId = UUID().uuidString
        let list: [String: Any] = [
            LIST_VALUES : ["swallow", "magpie"],
            OBJECT_ID: listId,
            CONFLICTS:  ["actor1": "swallow", "actor2": "swallow"]
        ]

        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "birds": list,

                    CONFLICTS: [
                        Key.string("birds"): ["actor1": list]
                    ]
                ]
            ]
        )

        // When
        context.splice(path: [.init(key: "birds", objectId: listId)], start: 0, deletions: 1, insertions: ["starling", "goldfinch"])

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .del, obj: listId, key: 0),
            Op(action: .set, obj: listId, key: 0, insert: true, value: .string("starling")),
            Op(action: .set, obj: listId, key: 1, insert: true, value: .string("goldfinch")),
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "birds": [
                    "actor1": .object(
                        .init(objectId: listId,
                              type: .list,
                              edits: [
                                Edit(action: .remove, index: 0),
                                Edit(action: .insert, index: 0),
                                Edit(action: .insert, index: 1)
                            ],
                              props: [
                                0: [actor.actorId: "starling"],
                                1: [actor.actorId: "goldfinch"]
                        ]))
                ]
            ]
        ))

    }

    func testTableManipulation1() {
        let tableId = UUID().uuidString
        let table: [String: Any] = [
            OBJECT_ID: tableId,
            CONFLICTS: [String: Any](),
            "entries": [String: Any]()
        ]
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                tableId: table,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "books": table,
                    CONFLICTS: [
                        Key.string("books"): ["actor1": table]
                    ]
                ]
            ]
        )

        //When
        let rowId = context.addTableRow(path: [.init(key: "books", objectId: tableId)], row: ["author": "Mary Shelley", "title": "Frankenstein"])

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: tableId, key: .string(rowId), child: rowId),
            Op(action: .set, obj: rowId, key: "author", value: .string("Mary Shelley")),
            Op(action: .set, obj: rowId, key: "title", value: .string("Frankenstein"))
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "books": [
                    "actor1": .object(
                        .init(objectId: tableId,
                              type: .table,
                              props: [
                                .string(rowId): [
                                    rowId: .object(.init(
                                        objectId: rowId,
                                        type: .map,
                                        props: [
                                            "author": [actor.actorId: "Mary Shelley"],
                                            "title": [actor.actorId: "Frankenstein"]
                                    ]))
                                ]
                        ]))
                ]
            ]
        ))
    }

    // should delete a table row
    func testTableManipulation2() {
        let rowId = UUID()
        let row: [String: Any] = [
            "author": "Mary Shelley",
            "title": "Frankenstein",
            OBJECT_ID: rowId
        ]
        let tableId = UUID().uuidString
        let table: [String: Any] = [
            OBJECT_ID: tableId,
            CONFLICTS: [String: Any](),
            "entries": [rowId.uuidString: row]
        ]
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                tableId: table,
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "books": table,
                    CONFLICTS: [
                        Key.string("books"): ["actor1": table]
                    ]
                ]
            ]
        )

        //When
        context.deleteTableRow(path: [.init(key: "books", objectId: tableId)], rowId: rowId)

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .del, obj: tableId, key: .string(rowId.uuidString))
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "books": [
                    "actor1": .object(
                        .init(objectId: tableId,
                              type: .table,
                              props: [
                                .string(rowId.uuidString): [:]
                        ]))
                ]
            ]
        ))
    }

    //should increment a counter
    func testCounter1() {
        let counter = [COUNTER_VALUE: Primitive.int(0)]
        let actor = ActorId()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                ROOT_ID: [
                    OBJECT_ID: ROOT_ID,
                    "counter": counter,
                    CONFLICTS: [
                        Key.string("counter"): ["actor1": counter]
                    ]
                ]
            ]
        )

        //When
        context.increment(path: [], key: "counter", delta: 1)

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .inc, obj: ROOT_ID, key: .string("counter"), value: .int(1))
        ])

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: ROOT_ID,
            type: .map,
            props: [
                "counter": [
                    actor.actorId: .value(.init(value: .int(1), datatype: .counter))
                ]
            ]
        ))
    }

//    it('should increment a counter', () => {
//      const counter = new Counter()
//      context.cache[ROOT_ID] = {[OBJECT_ID]: ROOT_ID, counter, [CONFLICTS]: {counter: {actor1: counter}}}
//      context.increment([], 'counter', 1)
//      assert(applyPatch.calledOnce)
//      assert.deepStrictEqual(applyPatch.firstCall.args[0], {objectId: ROOT_ID, type: 'map', props: {
//        counter: {[context.actorId]: {value: 1, datatype: 'counter'}}
//      }})
//      assert.deepStrictEqual(context.ops, [{obj: ROOT_ID, action: 'inc', key: 'counter', value: 1}])
//    })

}
