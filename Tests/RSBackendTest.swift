//
//  RSBackendTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 10.05.20.
//

import Foundation
@testable import Automerge
import XCTest

final class RSBackendTest: XCTestCase {

    func testInit() {
        let backend = RSBackend()
         XCTAssertEqual(backend.save(), [])
    }

//    func testloadDocument() {
//        let initialDocumentState: [UInt8] = [133,111,74,131,67,87,31,164,0,162,1,1,16,216,174,219,98,163,198,72,226,186,232,37,141,162,111,106,34,1,66,129,104,19,111,146,163,48,114,216,197,112,88,253,81,69,231,3,107,17,68,57,99,190,132,215,172,44,149,155,164,1,6,1,2,127,0,3,2,127,1,11,2,127,2,19,7,127,155,170,164,139,163,46,29,16,127,14,73,110,105,116,105,97,108,105,122,97,116,105,111,110,32,2,127,0,1,4,0,1,127,0,2,4,0,1,127,1,9,4,0,1,127,0,11,4,0,1,127,0,13,9,127,5,98,105,114,100,115,0,1,17,2,2,0,19,2,2,1,28,2,1,1,34,3,126,5,0,46,3,126,0,70,47,4,84,101,115,116,64,2,2,0]
//        let backend = RSBackend(data: initialDocumentState)
//
//        let abc = backend.save()
//        XCTAssertEqual(backend.save(), initialDocumentState)
//    }

    func testApplayLocal() {
        let backend = RSBackend()
        let request = Request(requestType: .change, message: "Test", time: Date(), actor: "111111", seq: 1, version: 0, ops: [Op(action: .set, obj: .root, key: "bird", value: .string("magpie"))], undoable: false)
        _ = backend.applyLocalChange(request: request)
    }

    func testInsertPerformance() throws {
        try XCTSkipIf(true)
        struct TravelList: Codable, Equatable {
            var trips: [Trip]
            let categories: [Category]

            static var initialScheme: TravelList = TravelList(trips: [], categories: [Category(id: "bar", customName: nil)])
        }

        struct Trip: Codable, Equatable {
            public let name: String
            public let startDate: Date
            public var optional: String?

            init(name: String, startDate: Date = Date(), optional: String? = nil) {
                self.name = name
                self.startDate = startDate
                self.optional = optional
            }
        }
        struct Category: Codable, Equatable {
            let id: String
            let customName: String?
        }


        measure() {
            var automerge = Document(TravelList.initialScheme)
            let trip = Trip(name: "Italien 2019", startDate: Date())
            for _ in 0...100  {
                automerge.change {
                    $0.trips.append(trip)
                }
            }
            XCTAssertEqual(automerge.content.trips.count, 101)
        }
    }

    func testLoadPerformance() throws {
        try XCTSkipIf(true)
        struct Object: Codable, Equatable {
            let date: Date
            let name: String
        }
        struct Schema: Codable, Equatable {
            var birds: [Object]
        }
        var automerge = Document(Schema(birds: [Object(date: Date(), name: "Test")]))
        (0...1000).forEach({ i in
            automerge.change({
                $0.birds.append(Object(date: Date(), name: "\(i)"))
            })
        })


        let document = automerge.save()

        measure() {
            let newDocument = Document<Schema>(data: document, actor: Actor())
            XCTAssertEqual(newDocument.content, automerge.content)
        }
    }

}
