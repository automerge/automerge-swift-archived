//
//  XCTAssertEqualOneOf.swift
//  AutomergeTests
//
//  Created by Lukas Schmidt on 02.06.20.
//

import XCTest


public func XCTAssertEqualOneOf<T>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ expression3: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) where T : Equatable {
    XCTAssertTrue(try expression1() == (try expression2()) || (try expression1()) == (try expression3()), message(), file: file, line: line)
}
