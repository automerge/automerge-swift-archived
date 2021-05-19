//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 19.04.21.
//

import Foundation
import XCTest
@testable import Automerge

final class TypeToObjectTests: XCTestCase {

    // Tranform String to primitive
    func testMap1() throws {
        let value = "Hello"
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .primitive("Hello"))
    }

    // Tranform String to primitive
    func testMap1Perfo() throws {
        let value = "Hello"
        let mapper = TypeToObject()

        measure {
            try! (0...100).forEach { _ in
                let result = try mapper.map(value)
            }

        }


//        XCTAssertEqual(result, .primitive("Hello"))
    }

    // Tranform Double to primitive
    func testMap2() throws {
        let value: Double = 2.0
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .primitive(.number(2.0)))
    }

    // Tranform Double to primitive
    func testMap3() throws {
        let value: Int = 2
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .primitive(.number(2)))
    }

    // Tranform Bool to primitive
    func testMap4() throws {
        let value: Bool = true
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .primitive(true))
    }

    // Tranform Date to date
    func testMap5() throws {
        let value = Date()
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        if case .date(let date) = result {
            XCTAssertEqual(date.timeIntervalSince1970, value.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail()
        }
    }

    // Transform Array<String> to List.string
    func testMap6() throws {
        let value = ["Hallo", "world"]
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, ["Hallo", "world"])
    }

    // Transform Array<Double> to List.number
    func testMap7() throws {
        let value = [2.0, 2.0]
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, [2.0, 2.0])
    }

    // Transform Counter to Counter
    func testMap8() throws {
        let value = Counter(0)
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .counter(value))
    }

    // Transform Counter to Counter
    func testMap9() throws {
        struct Scheme: Codable, Equatable {
            struct Birds: Codable, Equatable {
                let wrens: Int; let magpies: Int
            }
            let birds: Birds
        }
        let value = Scheme(birds: .init(wrens: 1, magpies: 1))
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .map(["birds": .map(Map(objectId: "", mapValues: ["wrens": 1.0, "magpies": 1.0]))]))
    }

    // Transform Counter to Counter
    func testMap10() throws {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObjList: [DeepObj]
        }
        let value = Scheme(deepObjList: [])
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .map(["deepObjList": .list([])]))
    }

    // Transform Counter to Counter
    func testMap11() throws {
        struct Scheme: Codable, Equatable {
            var deepObjList: [Int]
        }
        let value = Scheme(deepObjList: [1])
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .map(["deepObjList": .list([1.0])]))
    }

    // Transform Counter to Counter
    func testMap12() throws {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObjList: [DeepObj]
        }
        let value = Scheme(deepObjList: [.init(list: [])])
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .map(Map(objectId: "", mapValues: ["deepObjList": .list(List(objectId: "", listValues: [.map(Map(objectId: "", mapValues: ["list": .list(List(objectId: "", listValues: []))]))]))])))
    }

    // Transform Counter to Counter
    func testMap13() throws {
        struct Scheme: Codable, Equatable {
            var list: [Int]
        }
        let value = Scheme(list: [1, 2])
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .map(Map(objectId: "", mapValues: ["list": .list(List(objectId: "", listValues: [1.0, 2.0], conflicts: []))])))
    }

    // Transform Text to .text
    func testMap14() throws {
        let value = Text()
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .text(value))
    }

}
