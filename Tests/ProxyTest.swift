//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.05.20.
//

import Foundation
import XCTest
@testable import Automerge

class ProxyTest: XCTestCase {

    // should have a fixed object ID
    func testProxie1() {
        struct Scheme: Codable, Equatable {}
        // GIVEN
        var document = Document(Scheme())

        // WHEN
        document.change({ doc in
            XCTAssertEqual(doc.objectId, "00000000-0000-0000-0000-000000000000")
        })
    }

    // should expose keys as object properties
    func testProxie3() {
        struct Scheme: Codable, Equatable {
            var key1: String?
        }
        // GIVEN
        var document = Document(Scheme(key1: nil))

        // WHEN
        document.change({ doc in
            doc.key1?.set("value1")
            XCTAssertEqual(doc.key1?.get(), "value1")
        })
    }

    // should return undefined for unknown properties
    func testProxies4() {
        struct Scheme: Codable, Equatable {
            var key1: String?
        }
        // GIVEN
        var document = Document(Scheme(key1: nil))

        // WHEN
        document.change { doc in
            XCTAssertNil(doc.key1.get())
        }
    }

    // should allow deep object assigment
    func testProxiesSwift1() {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                let list: [Int]
            }
            var deepObj: DeepObj?
        }
        var document = Document(Scheme(deepObj: nil))

        // WHEN
        document.change({ doc in
            doc.deepObj?.set(.init(list: [1]))
            XCTAssertEqual(doc.deepObj?.get(), Scheme.DeepObj(list: [1]))
        })
    }

    // should allow list assignment inside deep object
    func testProxiesSwift2() {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObj: DeepObj?
        }
        var document = Document(Scheme(deepObj: nil))

        // WHEN
        document.change({ doc in
            doc.deepObj?.set(.init(list: []))
            doc.deepObj?.list.set([1])
            XCTAssertEqual(doc.deepObj?.list.get(), [1])
        })
    }

}
