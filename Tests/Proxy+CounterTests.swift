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
    func testAdditionAssignmentOperator() {
        struct Schema: Codable, Equatable {
            var counter: Counter = 1
        }
        
        var doc1 = Document(Schema())
        let _ = doc1.change {
            $0.counter += 1
            XCTAssertEqual($0.counter.get(), 2)
        }
        
        XCTAssertEqual(doc1.content, Schema(counter: 2))
    }
    
    func testAdditionAssignmentOperatorOnOptional() {
        struct Schema: Codable, Equatable {
            var counter: Counter?
        }
        
        var doc1 = Document(Schema())
        let _ = doc1.change {
            $0.counter?.set(3)
            XCTAssertEqual($0.counter?.get(), 3)
        }
        
        let _ = doc1.change {
            $0.counter += 2
            XCTAssertEqual($0.counter?.get(), 5)
        }
        
        XCTAssertEqual(doc1.content, Schema(counter: 5))
    }
    
    func testSubstractionAssignmentOperator() {
        struct Schema: Codable, Equatable {
            var counter: Counter = 1
        }
        
        var doc1 = Document(Schema())
        let _ = doc1.change {
            $0.counter -= 1
            XCTAssertEqual($0.counter.get(), 0)
        }
        
        XCTAssertEqual(doc1.content, Schema(counter: 0))
    }
    
    func testSubstractionAssignmentOperatorOnOptional() {
        struct Schema: Codable, Equatable {
            var counter: Counter?
        }
        
        var doc1 = Document(Schema())
        let _ = doc1.change {
            $0.counter?.set(3)
            XCTAssertEqual($0.counter?.get(), 3)
        }
        
        let _ = doc1.change {
            $0.counter -= 2
            XCTAssertEqual($0.counter?.get(), 1)
        }
        
        XCTAssertEqual(doc1.content, Schema(counter: 1))
    }
}
