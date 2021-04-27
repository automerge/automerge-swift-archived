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

    var observerDiff: (T, Object?, inout [ObjectId: Object]) -> Object? {
        return { diff, _, _ in
            self.observer(diff)
            return nil
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
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(Map(objectId: "", mapValues: [:], conflicts: [:]))],
            ops: [],
            maxOp: 0
        )

        // WHEN
        context.setMapKey(path: [], key: "sparrows", value: 5.0)

        // THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: .root, key: "sparrows", value: 5.0, pred: [])])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
                        objectId: .root,
                        type: .map,
                        props: [
                            "sparrows": ["1@\(actor)": .value(.init(value: 5.0,
                                                                     datatype: nil))]])
        )
    }

    // should do nothing if the value was not changed
    func testContextSetMapKey2() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                .root: .map(Map(
                                objectId: .root,
                                mapValues: ["goldfinches": 3.0],
                                conflicts: ["goldfinches": ["actor1": 3.0]])
                )
            ],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "goldfinches", value: 3.0)

        //THEN
        XCTAssertEqual(context.ops, [])
        XCTAssertNil(applyPatch.value)
        XCTAssertEqual(applyPatch.callCount, 0)
    }

    // should allow a conflict to be resolved
    func testContextSetMapKey3() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                .root: .map(Map(
                    objectId: .root,
                    mapValues: ["goldfinches": 5.0],
                    conflicts: ["goldfinches": ["1@actor1": 3.0, "2@actor2": 5.0]]

                ))
            ],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "goldfinches", value: 3.0)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: .root, key: "goldfinches", value: 3.0, pred: ["1@actor1", "2@actor2"])])
        XCTAssertEqual(context.ops[0].pred, ["1@actor1", "2@actor2"])
        XCTAssertEqual(context.ops.count, 1)

        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(objectId: .root,
                                                    type: .map,
                                                    props: [
                                                        "goldfinches": ["1@\(actor)": 3.0]]))
    }

    //should create nested maps
    func testContextSetMapKey4() {
        // GIVEN
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(Map(objectId: ""))],
            ops: [],
            maxOp: 0
        )

        // WHEN
        context.setMapKey(path: [], key: "birds", value: .map(Map(mapValues: ["goldfinches": 3.0])))

        let objectId = applyPatch.value!.props!["birds"]!["1@\(actor)"]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: .root, key: "birds", pred: []),
            Op(action: .set, obj: objectId, key: "goldfinches", value: 3.0, pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "birds": ["1@\(actor)": .object(.init(
                    objectId: objectId,
                    type: .map,
                    props: [
                        "goldfinches": ["2@\(actor)": 3.0]]
                ))
                ]
            ]
        )
        )
    }

    // should perform assignment inside nested maps
    func testContextSetMapKey5() {
        let actor = Actor()
        let objectId = ObjectId()
        let child: Object = .map(Map(objectId: objectId))
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId: child,
                .root: .map(Map(objectId: .root, mapValues: ["birds": child], conflicts: ["birds": ["actor1": child]]))
            ], maxOp: 0)

        // WHEN
        context.setMapKey(path: [.init(key: "birds", objectId: objectId)], key: "goldfinches", value: 3.0)

        //THEN
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId, key: "goldfinches", value: 3.0, pred: [])])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            edits: nil,
            props: [
                "birds": ["actor1": .object(.init(
                    objectId: objectId,
                    type: .map,
                    props: [
                        "goldfinches": ["1@\(actor)": 3.0]]
                ))
                ]
            ]
        )
        )
    }

    // should perform assignment inside conflicted maps
    func testContextSetMapKey6() {
        //Given
        let actor = Actor()
        let objectId1 = ObjectId()
        let child1: Object = .map(Map(objectId: objectId1))
        let objectId2 = ObjectId()
        let child2: Object = .map(Map(objectId: objectId2))
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId1: child1,
                objectId2: child2,
                .root: .map(Map(
                                objectId: .root,
                                mapValues: ["birds": child2],
                                conflicts: ["birds": [
                                    "actor1": child1,
                                    "actor2": child2
                                ]])
                )
            ],
            maxOp: 0)

        //When
        context.setMapKey(path: [.init(key: "birds", objectId: objectId2)], key: "goldfinches", value: 3.0)

        //Then
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId2, key: "goldfinches", value: 3.0, pred: [])])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            edits: nil,
            props: [
                "birds": [
                    "actor1": .object(.init(objectId: objectId1, type: .map)),
                    "actor2": .object(.init(
                        objectId: objectId2,
                        type: .map,
                        props: [
                            "goldfinches": ["1@\(actor)": 3.0]
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
        let actor = Actor()
        let objectId = ObjectId()
        let child: Object = .map(Map(objectId: objectId))
        let dateValue = Date()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                objectId: child,
                .root: .map(Map(
                                objectId: .root,
                                mapValues: ["values": child],
                                conflicts: ["values": [
                                    "1@actor1": .date(dateValue),
                                    "1@actor2": .counter(0),
                                    "1@actor3": 42.0,
                                    "1@actor4": .primitive(.null),
                                    "1@actor5": child
                                ]])
                )
            ],
            maxOp: 0)
        //When
        context.setMapKey(path: [.init(key: "values", objectId: objectId)], key: "goldfinches", value: 3.0)

        //Then
        XCTAssertEqual(context.ops, [Op(action: .set, obj: objectId, key: "goldfinches", value: 3.0, pred: [])])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            edits: nil,
            props: [
                "values": [
                    "1@actor1": .value(.init(value: .number(dateValue.timeIntervalSince1970), datatype: .timestamp)),
                    "1@actor2": .value(.init(value: 0.0, datatype: .counter)),
                    "1@actor3": 42.0,
                    "1@actor4": .value(.init(value: .null)),
                    "1@actor5": .object(.init(objectId: objectId, type: .map, props: ["goldfinches": ["1@\(actor)": 3.0]]))
                ]
            ]
        )
        )
    }

    // should create nested lists
    func testContextSetMapKey8() {
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(.init(objectId: ""))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "birds", value: .list(["sparrow", "goldfinch"]))

        // Then
        let objectId = applyPatch.value!.props!["birds"]!["1@\(actor)"]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeList, obj: .root, key: "birds", insert: false, pred: []),
            Op(action: .set, obj: objectId, elemId: .head, insert: true, value: "sparrow", pred: []),
            Op(action: .set, obj: objectId, elemId: "2@\(actor)", insert: true, value: "goldfinch", pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "birds": [
                    "1@\(actor)": .object(.init(
                                            objectId: objectId,
                                            type: .list,
                                            edits: [
                                                Edit(action: .insert, index: 0, elemId: "2@\(actor)"),
                                                Edit(action: .insert, index: 1, elemId: "3@\(actor)")
                                            ],
                                            props: [
                                                0: ["2@\(actor)": "sparrow"],
                                                1: ["3@\(actor)": "goldfinch"]
                                            ]))
                ]
            ]
        ))
    }

    // should create nested Text objects
    func testContextSetMapKey9() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(.init(objectId: ""))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "text", value: .text(Text("hi")))

        //THEN
        let objectId = applyPatch.value!.props!["text"]!["1@\(actor)"]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeText, obj: .root, key: "text", pred: []),
            Op(action: .set, obj: objectId, elemId: .head, insert: true, value: "h", pred: []),
            Op(action: .set, obj: objectId, elemId: "2@\(actor)", insert: true, value: "i", pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "text": [
                    "1@\(actor)": .object(.init(
                                            objectId: objectId,
                                            type: .text,
                                            edits: [
                                                Edit(action: .insert, index: 0, elemId: "2@\(actor)"),
                                                Edit(action: .insert, index: 1, elemId: "3@\(actor)")],
                                            props: [
                                                0: ["2@\(actor)": "h"],
                                                1: ["3@\(actor)": "i"]
                                            ]))
                ]
            ]
        )
        )
    }

    // should create nested Table objects
    func testContextSetMapKey10() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(.init(objectId: ""))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "books", value: .table(Table(tableValues: [:])))

        //Then
        let objectId = applyPatch.value!.props!["books"]!["1@\(actor)"]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeTable, obj: .root, key: "books", insert: false, pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "books": [
                    "1@\(actor)": .object(.init(objectId: objectId, type: .table, props: [:]))
                ]
            ]
        )
        )
    }

    // should allow assignment of Date values
    func testContextSetMapKey11() {
        //Given
        let now = Date()
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(.init(objectId: ""))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "now", value: .date(now))

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: .root, key: "now", value: .number(now.timeIntervalSince1970), datatype: .timestamp, pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "now": [
                    "1@\(actor)": .value(.init(value: .number(now.timeIntervalSince1970), datatype: .timestamp))
                ]
            ]
        )
        )
    }


    // should allow assignment of Counter values
    func testContextSetMapKey12() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(.init(objectId: ""))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "counter", value: .counter(3))

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: .root, key: "counter", value: 3.0, datatype: .counter, pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "counter": [
                    "1@\(actor)": .value(.init(value: 3.0, datatype: .counter))
                ]
            ]
        )
        )
    }

    // should allow assignment of UUID values
    func testContextSetMapKey13() {
        //Given
        let uuid = UUID().uuidString
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(.init(objectId: ""))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.setMapKey(path: [], key: "uuid", value: .primitive(.string(uuid)))

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: .root, key: "uuid", value: .string(uuid), pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "uuid": [
                    "1@\(actor)": .value(.init(value: .string(uuid)))
                ]
            ]
        )
        )
    }

    //should remove an existing key
    func testDeleteMapKey1() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["goldfinches": 3.0],
                                    conflicts: ["goldfinches": ["1@actor1": 3.0]]))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.deleteMapKey(path: [], key: "goldfinches")

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .del, obj: .root, key: "goldfinches", insert: false, pred: ["1@actor1"])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "goldfinches": [:]
            ]
        )
        )
    }

    // should do nothing if the key does not exist
    func testDeleteMapKey2() {
        //Given
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [.root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["goldfinches": 3.0],
                                    conflicts: ["goldfinches": ["1@actor1": 3.0]]))],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.deleteMapKey(path: [], key: "sparrows")

        //Then
        XCTAssertEqual(context.ops, [])
        XCTAssertEqual(applyPatch.callCount, 0)
    }

    // should do nothing if the key does not exist
    func testDeleteMapKey3() {
        //Given
        let objectId = ObjectId()
        let child: Object = .map(Map(objectId: objectId, mapValues: ["goldfinches": 3.0], conflicts: ["goldfinches": ["5@actor1": 3.0]]))
        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                .root: .map(Map(
                                objectId: .root,
                                mapValues: ["birds": child],
                                conflicts: ["birds": ["1@actor1": child]])),
                objectId: child
            ],
            ops: [],
            maxOp: 0
        )
        // WHEN
        context.deleteMapKey(path: [.init(key: "birds", objectId: objectId)], key: "goldfinches")

        //Then
        XCTAssertEqual(context.ops, [
            Op(action: .del, obj: objectId, key: "goldfinches", insert: false, pred: ["5@actor1"])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "birds": [
                    "1@actor1": .object(ObjectDiff(objectId: objectId, type: .map, props: ["goldfinches": [:]]))
                ]
            ]
        )
        )
    }



    // should overwrite an existing list element
    func testListManupulation1() {
        // Given
        let listId = ObjectId()
        let list: Object = .list(List(
                                    objectId: listId,
                                    listValues: ["swallow", "magpie"],
                                    conflicts: [["1@xxx": "swallow"], ["2@xxx": "magpie"]],
                                    elemIds: ["1@xxx", "2@xxx"])
        )

        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                .root: .map(Map(
                                objectId: .root,
                                mapValues: ["birds": list],
                                conflicts: ["birds": ["1@actor1": list]]))
            ],
            maxOp: 0
        )

        // When
        context.setListIndex(path: [.init(key: "birds", objectId: listId)], index: 0, value: "starling")

        // Then
        XCTAssertEqual(context.ops, [
            Op(action: .set, obj: listId, elemId: "1@xxx", insert: false, value: "starling", pred: ["1@xxx"])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "birds": [
                    "1@actor1": .object(.init(
                                            objectId: listId,
                                            type: .list,
                                            props: [
                                                0: ["1@\(actor)": "starling"]
                                            ]))
                ]
            ]
        )
        )
    }


    // should create nested objects on assignment
    func testListManupulation2() {
        // Given
        let listId = ObjectId()
        let list: Object = .list(List(
                                    objectId: listId,
                                    listValues: ["swallow", "magpie"],
                                    conflicts: [["1@xxx": "swallow"], ["2@xxx": "magpie"]],
                                    elemIds: ["1@xxx", "2@xxx"])
        )

        let actor = Actor()
        let context = Context(
            actorId: actor,
            applyPatch: applyPatch.observerDiff,
            updated: [:],
            cache: [
                listId: list,
                .root: .map(Map(
                                objectId: .root,
                                mapValues: ["birds": list],
                                conflicts: ["birds": ["1@actor1": list]]))
            ],
            maxOp: 0
        )

        // When
        context.setListIndex(path: [.init(key: "birds", objectId: listId)], index: 1, value: .map(Map( mapValues: ["english": "goldfinch", "latin": "carduelis"])))

        // Then
        let nestedId = applyPatch.value!.props!["birds"]!["1@actor1"]!.props![1]!["1@\(actor)"]!.objectId!
        XCTAssertEqual(context.ops, [
            Op(action: .makeMap, obj: listId, elemId: "2@xxx", insert: false, pred: ["2@xxx"]),
            Op(action: .set, obj: nestedId, key: "english", insert: false, value: "goldfinch", pred: []),
            Op(action: .set, obj: nestedId, key: "latin", insert: false, value: "carduelis", pred: [])
        ])
        XCTAssertEqual(applyPatch.callCount, 1)
        XCTAssertEqual(applyPatch.value, ObjectDiff(
            objectId: .root,
            type: .map,
            props: [
                "birds": [
                    "1@actor1": .object(.init(objectId: listId,
                                            type: .list,
                                            props: [
                                                1: ["1@\(actor)": .object(.init(
                                                                            objectId: nestedId,
                                                                            type: .map,
                                                                            props: [
                                                    "english": ["2@\(actor)": "goldfinch"],
                                                    "latin": ["3@\(actor)": "carduelis"]
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
            let listId = ObjectId()
            let list: Object = .list(List(
                                        objectId: listId,
                                        listValues: ["swallow", "magpie"],
                                        conflicts: [["1@xxx": "swallow"], ["2@xxx": "magpie"]],
                                        elemIds: ["1@xxx", "2@xxx"])
            )

            let actor = Actor()
            let context = Context(
                actorId: actor,
                applyPatch: applyPatch.observerDiff,
                updated: [:],
                cache: [
                    listId: list,
                    .root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["birds": list],
                                    conflicts: ["birds": ["1@actor1": list]]))
                ],
                maxOp: 0
            )

            // When
            context.splice(path: [.init(key: "birds", objectId: listId)], start: 2, deletions: 0, insertions: [.map(Map(mapValues: ["english": "goldfinch", "latin": "carduelis"]))])

            // Then
            let nestedId = applyPatch.value!.props!["birds"]!["1@actor1"]!.props![2]!["1@\(actor)"]!.objectId!
            XCTAssertEqual(context.ops, [
                Op(action: .makeMap, obj: listId, elemId: "2@xxx", insert: true, pred: []),
                Op(action: .set, obj: nestedId, key: "english", insert: false, value: "goldfinch", pred: []),
                Op(action: .set, obj: nestedId, key: "latin", insert: false, value: "carduelis", pred: [])
            ])

            XCTAssertEqual(applyPatch.callCount, 1)
            XCTAssertEqual(applyPatch.value, ObjectDiff(
                objectId: .root,
                type: .map,
                props: [
                    "birds": [
                        "1@actor1": .object(.init(objectId: listId,
                                                type: .list,
                                                edits: [Edit(action: .insert, index: 2, elemId: "1@\(actor)")],
                                                props: [
                                                    2: ["1@\(actor)": .object(.init(
                                                                                objectId: nestedId,
                                                                                type: .map,
                                                                                props: [
                                                                                    "english": ["2@\(actor)": "goldfinch"],
                                                                                    "latin": ["3@\(actor)": "carduelis"]
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
            let listId = ObjectId()
            let list: Object = .list(List(
                                        objectId: listId,
                                        listValues: ["swallow", "magpie"],
                                        conflicts: [["1@xxx": "swallow"], ["2@xxx": "magpie"]],
                                        elemIds: ["1@xxx", "2@xxx"])
            )

            let actor = Actor()
            let context = Context(
                actorId: actor,
                applyPatch: applyPatch.observerDiff,
                updated: [:],
                cache: [
                    listId: list,
                    .root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["birds": list],
                                    conflicts: ["birds": ["1@actor1": list]]))
                ],
                maxOp: 0
            )

            // When
            context.splice(path: [.init(key: "birds", objectId: listId)], start: 0, deletions: 2, insertions: [])

            // Then
            XCTAssertEqual(context.ops, [
                Op(action: .del, obj: listId, elemId: "1@xxx", insert: false, pred: ["1@xxx"]),
                Op(action: .del, obj: listId, elemId: "2@xxx", insert: false, pred: ["2@xxx"])
            ])

            XCTAssertEqual(applyPatch.callCount, 1)
            XCTAssertEqual(applyPatch.value, ObjectDiff(
                objectId: .root,
                type: .map,
                props: [
                    "birds": [
                        "1@actor1": .object(
                            .init(objectId: listId,
                                  type: .list,
                                  edits: [
                                    Edit(action: .remove, index: 0, elemId: nil),
                                    Edit(action: .remove, index: 0, elemId: nil)
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
            let listId = ObjectId()
            let list: Object = .list(List(
                                        objectId: listId,
                                        listValues: ["swallow", "magpie"],
                                        conflicts: [["1@xxx": "swallow"], ["2@xxx": "magpie"]],
                                        elemIds: ["1@xxx", "2@xxx"])
            )

            let actor = Actor()
            let context = Context(
                actorId: actor,
                applyPatch: applyPatch.observerDiff,
                updated: [:],
                cache: [
                    listId: list,
                    .root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["birds": list],
                                    conflicts: ["birds": ["1@actor1": list]]))
                ],
                maxOp: 0
            )

            // When
            context.splice(path: [.init(key: "birds", objectId: listId)], start: 0, deletions: 1, insertions: ["starling", "goldfinch"])

            // Then
            XCTAssertEqual(context.ops, [
                Op(action: .del, obj: listId, elemId: "1@xxx", insert: false, pred: ["1@xxx"]),
                Op(action: .set, obj: listId, elemId: .head, insert: true, value: "starling", pred: []),
                Op(action: .set, obj: listId, elemId: "2@\(actor)", insert: true, value: "goldfinch", pred: []),
            ])

            XCTAssertEqual(applyPatch.callCount, 1)
            XCTAssertEqual(applyPatch.value, ObjectDiff(
                objectId: .root,
                type: .map,
                props: [
                    "birds": [
                        "1@actor1": .object(
                            .init(objectId: listId,
                                  type: .list,
                                  edits: [
                                    Edit(action: .remove, index: 0, elemId: nil),
                                    Edit(action: .insert, index: 0, elemId: "2@\(actor)"),
                                    Edit(action: .insert, index: 1, elemId: "3@\(actor)")
                                ],
                                  props: [
                                    0: ["2@\(actor)": "starling"],
                                    1: ["3@\(actor)": "goldfinch"]
                            ]))
                    ]
                ]
            ))

        }

        // should add a table row
        func testTableManipulation1() {
            let tableId = ObjectId()
            let table: Object = .table(Table(tableValues: [:], objectId: tableId, opIds: [:]))
            let actor = Actor()
            let context = Context(
                actorId: actor,
                applyPatch: applyPatch.observerDiff,
                updated: [:],
                cache: [
                    tableId: table,
                    .root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["books": table],
                                    conflicts: ["books": ["1@actor1": table]])
                    )
                ],
                maxOp: 0
            )

            //When
            let rowId = context.addTableRow(
                path: [.init(key: "books", objectId: tableId)],
                row: .map(Map(mapValues: ["author": "Mary Shelley", "title": "Frankenstein"]))
            )

            // Then
            XCTAssertEqual(context.ops, [
                Op(action: .makeMap, obj: tableId, key: .string(rowId.objectId), insert: false, pred: []),
                Op(action: .set, obj: "1@\(actor)", key: "author", insert: false, value: "Mary Shelley", pred: []),
                Op(action: .set, obj: "1@\(actor)", key: "title", insert: false, value: "Frankenstein", pred: [])
            ])

            XCTAssertEqual(applyPatch.callCount, 1)
            XCTAssertEqual(applyPatch.value, ObjectDiff(
                objectId: .root,
                type: .map,
                props: [
                    "books": [
                        "1@actor1": .object(
                            .init(
                                objectId: tableId,
                                type: .table,
                                props: [
                                    .string(rowId.objectId): [
                                        "1@\(actor)": .object(.init(
                                                                objectId: "1@\(actor)",
                                                                type: .map,
                                                                props: [
                                                                    "author": ["2@\(actor)": "Mary Shelley"],
                                                                    "title": ["3@\(actor)": "Frankenstein"]
                                                                ]))
                                    ]
                                ]))
                    ]
                ]
            ))
        }

        // should delete a table row
        func testTableManipulation2() {
            let rowId = ObjectId()
            let row: Object = .map(Map(
                objectId: rowId,
                mapValues: [
                    "author": "Mary Shelley",
                    "title": "Frankenstein"],
                conflicts: [:]
            ))
            let tableId = ObjectId()
            let table: Object = .table(Table(tableValues: [rowId: row], objectId: tableId))
            let actor = Actor()
            let context = Context(
                actorId: actor,
                applyPatch: applyPatch.observerDiff,
                updated: [:],
                cache: [
                    tableId: table,
                    .root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["books": table],
                                    conflicts: ["books": ["1@actor1": table]])
                    )
                ],
                maxOp: 0
            )

            //When
            context.deleteTableRow(path: [.init(key: "books", objectId: tableId)], rowId: rowId, pred: "5@actor1")

            // Then
            XCTAssertEqual(context.ops, [
                Op(action: .del, obj: tableId, key: .string(rowId.objectId), insert: false, pred: ["5@actor1"])
            ])

            XCTAssertEqual(applyPatch.callCount, 1)
            XCTAssertEqual(applyPatch.value, ObjectDiff(
                objectId: .root,
                type: .map,
                props: [
                    "books": [
                        "1@actor1": .object(
                            .init(objectId: tableId,
                                  type: .table,
                                  props: [
                                    .string(rowId.objectId): [:]
                            ]))
                    ]
                ]
            ))
        }

        //should increment a counter
        func testCounter1() {
            let counter: Object = .counter(0)
            let actor = Actor()
            let context = Context(
                actorId: actor,
                applyPatch: applyPatch.observerDiff,
                updated: [:],
                cache: [
                    .root: .map(Map(
                                    objectId: .root,
                                    mapValues: ["counter": counter],
                                    conflicts: ["counter": ["1@actor1": counter]])
                    )
                ],
                maxOp: 0
            )

            //When
            context.increment(path: [], key: "counter", delta: 1)

            //Then
            XCTAssertEqual(context.ops, [
                Op(action: .inc, obj: .root, key: "counter", value: 1.0, pred: ["1@actor1"])
            ])

            XCTAssertEqual(applyPatch.callCount, 1)
            XCTAssertEqual(applyPatch.value, ObjectDiff(
                objectId: .root,
                type: .map,
                props: [
                    "counter": [
                        "1@\(actor)": .value(.init(value: 1.0, datatype: .counter))
                    ]
                ]
            ))
        }

}
