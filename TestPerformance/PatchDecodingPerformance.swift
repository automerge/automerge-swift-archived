//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 29.05.21.
//

import XCTest
import Automerge

final class DocumentPerformanceTest: XCTestCase {

    func testInsertPerformance() throws {
        struct TravelList: Codable, Equatable {
            var trips: [Trip]
            let categories: [Category]

            static var initialScheme: TravelList = TravelList(trips: [], categories: [Category(id: "bar", customName: nil)])
        }

        struct Trip: Codable, Equatable {
            public let name: String
            public var optional: String?

            init(name: String, optional: String? = nil) {
                self.name = name
                self.optional = optional
            }
        }
        struct Category: Codable, Equatable {
            let id: String
            let customName: String?
        }


        measure() {
            var automerge = Document(TravelList.initialScheme)
            let trip = Trip(name: "Italien 2019")
            automerge.change {
                $0.trips.append(trip)
            }
            XCTAssertEqual(automerge.content.trips.count, 1)
        }
    }

    func testInsertPerformance3() throws {
        struct TravelList: Codable, Equatable {
            var trips: [Trip]
            let categories: [Category]

            static var initialScheme: TravelList = TravelList(trips: [], categories: [Category(id: "bar", customName: nil)])
        }

        struct Trip: Codable, Equatable {
            public let name: String
            public var optional: String?

            init(name: String, optional: String? = nil) {
                self.name = name
                self.optional = optional
            }
        }
        struct Category: Codable, Equatable {
            let id: String
            let customName: String?
        }


        measure() {
            var automerge = Document(TravelList.initialScheme)
            let trip = Trip(name: "Italien 2019")
            for _ in 0...100  {
                automerge.change {
                    $0.trips.append(trip)
                }
            }
            XCTAssertEqual(automerge.content.trips.count, 101)
        }
    }

    func testLoadPerformance() throws {
        struct Object: Codable, Equatable {
            let name: String
        }
        struct Schema: Codable, Equatable {
            var birds: [Object]
        }
        var automerge = Document(Schema(birds: [Object(name: "Test")]))
        (0...1000).forEach({ i in
            automerge.change({
                $0.birds.append(Object(name: "\(i)"))
            })
        })


        let document = automerge.save()

        measure() {
            let newDocument = Document<Schema>(data: document, actor: Actor())
            XCTAssertEqual(newDocument.content, automerge.content)
        }
    }

}
