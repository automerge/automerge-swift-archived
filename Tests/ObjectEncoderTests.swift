//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation
import XCTest
@testable import Automerge

final class ObjectEncoderTests: XCTestCase {

    func testString() throws {
        let value = "Hello"
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .primitive("Hello"))
    }

    func testArrayOfString() throws {
        let value = ["Hallo"]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list(["Hallo"]))
    }

    func testArrayOfStrings() throws {
        let value = ["Hallo", "world"]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list(["Hallo", "world"]))
    }

    func testTable() throws {
        struct Object: Codable {}
        let value = Table<Object>()
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .table(Table<Map>()))
    }

    func testTableInArray() throws {
        struct Object: Codable {}
        let value = [Table<Object>()]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list([.table(Table<Map>())]))
    }

    func testText() throws {
        let value = Text()
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .text(value))
    }

    func testDouble() throws {
        let value: Double = 2.0
        let encoder = ObjectEncoder()
        
        let result = try encoder.encode(value)
        
        XCTAssertEqual(result, .primitive(.number(2.0)))
    }


    func testInt() throws {
        let value: Int = 2
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .primitive(.number(2)))
    }

    func testIntInArray() throws {
        let value = [2.0]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, [2.0])
    }

    func testIntsInArray() throws {
        let value = [2.0, 3.0]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, [2.0, 3.0])
    }

    func testBool() throws {
        let value: Bool = true
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .primitive(true))
    }

    func testDate() throws {
        let value = Date()
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .date(value))
    }

    func testDateInArray() throws {
        let date = Date()
        let value = [date]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list([.date(date)]))
    }

    func testDatesInArray() throws {
        let date = Date()
        let date2 = Date()
        let value = [date, date2]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list([.date(date), .date(date2)]))
    }

    func testCounter() throws {
        let value = Counter(0)
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .counter(value))
    }

    func testCounterInArray() throws {
        let counter = Counter(0)
        let value = [counter]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list([.counter(counter)]))
    }

    func testCountersInArray() throws {
        let counter = Counter(0)
        let counter2 = Counter(10)
        let value = [counter, counter2]
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .list([.counter(counter), .counter(counter2)]))
    }

    func testObjectInObjectWithStrings() throws {
        struct Scheme: Codable, Equatable {
            struct Birds: Codable, Equatable {
                let wrens: Int; let magpies: Int
            }
            let birds: Birds
        }
        let value = Scheme(birds: .init(wrens: 1, magpies: 1))
        let encoder = ObjectEncoder()

        let result: Object = try encoder.encode(value)

        XCTAssertEqual(result, .map(["birds": .map(Map(objectId: "", mapValues: ["wrens": 1.0, "magpies": 1.0]))]))
    }

    func testObjectInObjectWithEmptyList() throws {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObjList: [DeepObj]
        }
        let value = Scheme(deepObjList: [])
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .map(["deepObjList": .list([])]))
    }

    func testObjectInObjectWithList() throws {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObjList: [DeepObj]
        }
        let value = Scheme(deepObjList: [.init(list: [1, 2, 4])])
        let encoder = ObjectEncoder()

        let result = try encoder.encode(value)

        XCTAssertEqual(result, .map(["deepObjList": .list([.map(["list": .list([1, 2, 4])])])]))
    }

    func testListInObject() throws {
        struct Scheme: Codable, Equatable {
            var deepObjList: [Int]
        }
        let value = Scheme(deepObjList: [1])
        let encoder = ObjectEncoder()

        let result: Object = try encoder.encode(value)

        XCTAssertEqual(result, .map(["deepObjList": .list([1.0])]))
    }

    func testListInListInObject() throws {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObjList: [DeepObj]
        }
        let value = Scheme(deepObjList: [.init(list: [])])
        let encoder = ObjectEncoder()

        let result: Object = try encoder.encode(value)

        XCTAssertEqual(result, .map(["deepObjList": .list([.map(["list": .list([])])])]))
    }

    func testDeepMapAndList() throws {
        struct Scheme: Codable, Equatable {
            struct Animals: Codable, Equatable {
                struct Birds: Codable, Equatable {
                    let pink: String
                    let black: String
                    var brown: String?
                }
                var birds: Birds?
                var mammals: [String]
            }
            var animals: Animals
        }

        let value = Scheme(animals: .init(birds: .init(pink: "flamingo", black: "starling", brown: nil), mammals: ["badger"]))
        let encoder = ObjectEncoder()

        let result: Object = try encoder.encode(value)

        XCTAssertEqual(result, .map(["animals":.map(["mammals": .list(["badger"]), "birds": .map(["pink": "flamingo", "black": "starling"])])]))
    }

}
