//
//  File.swift
//  
//
//  Created by Konstantin Kostov on 23/06/2022.
//

import Foundation
import XCTest
@testable import Automerge

class ProxyCounterTests: XCTestCase {
    func testAssignmentExpressions() {
        struct Schema: Codable, Equatable {
            var counter: Counter?
            var notOptionalCounter: Counter = 3
        }
        
        var doc1 = Document(Schema())
        let _ = doc1.change {
            $0.counter?.set(3)
            XCTAssertEqual($0.counter?.get(), 3)
        }
        
        let _ = doc1.change {
            $0.counter -= 1
            $0.notOptionalCounter -= 1
            XCTAssertEqual($0.counter?.get(), 2)
            XCTAssertEqual($0.notOptionalCounter.get(), 2)
        }
        
        let _ = doc1.change {
            $0.counter += 2
            $0.notOptionalCounter += 2
            XCTAssertEqual($0.counter?.get(), 4)
            XCTAssertEqual($0.notOptionalCounter.get(), 4)
        }
        
        let _ = doc1.change {
            $0.counter += -2
            $0.notOptionalCounter -= 2
            XCTAssertEqual($0.counter?.get(), 2)
            XCTAssertEqual($0.notOptionalCounter.get(), 2)
        }
        
        XCTAssertEqual(doc1.content, Schema(counter: 2, notOptionalCounter: 2))
    }
}
