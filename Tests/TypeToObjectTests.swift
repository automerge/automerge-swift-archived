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

    // Tranform Double to primitive
    func testMap2() throws {
        let value: Double = 2.0
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .primitive(.double(2.0)))
    }

    // Tranform Double to primitive
    func testMap3() throws {
        let value: Int = 2
        let mapper = TypeToObject()

        let result = try mapper.map(value)

        XCTAssertEqual(result, .primitive(.int(2)))
    }

}


//case double(Double)
//case int(Int)
//case bool(Bool)
