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

    // should allow unsafe access for map key
    func testProxyUnsafe1() {
        struct Scheme: Codable, Equatable {
            var key1: String?
        }
        // GIVEN
        var document = Document(Scheme(key1: nil))

        // WHEN
        document.change({ doc in
            doc.unsafe().key1.set("value1")
            XCTAssertEqual(doc.key1?.get(), "value1")
        })
    }

    // should allow unsafe access for collection index
    func testProxyUnsafe2() {
        struct Scheme: Codable, Equatable {
            var key1: [String]
        }
        // GIVEN
        var document = Document(Scheme(key1: ["1"]))

        // WHEN
        document.change({ doc in
            doc.unsafe().key1[1].set("2")
            XCTAssertEqual(doc.key1.get(), ["1", "2"])
        })
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

//    // should reflect coding key
//    func testProxiesSwift3() {
//        struct Scheme: Codable, Equatable {
//            var foo: String?
//            enum CodingKeys: String, CodingKey {
//                case foo = "fooo"
//            }
//        }
//        let s1 = Document(Scheme(foo: nil))
//        var s2 = s1
//        s2.change { $0.foo?.set("bar") }
//        XCTAssertEqual(s1.content.foo, nil)
//        XCTAssertEqual(s2.content.foo, "bar")
//    }
//    
//    // should reflect class
//    func testProxiesSwift4() {
//        final class Scheme: Codable {
//            init(foo: String?) {
//                self.foo = foo
//            }
//            var foo: String?
//        }
//        let s1 = Document(Scheme(foo: nil))
//        var s2 = s1
//        s2.change { $0.foo?.set("bar") }
//        XCTAssertEqual(s1.content.foo, nil)
//        XCTAssertEqual(s2.content.foo, "bar")
//    }
//    
//    // should reflect protocol types
//    func testProxiesSwift5() {
//        struct Scheme: Codable, Foo {
//            init(foo: String?) {
//                self.foo = foo
//            }
//            var foo: String?
//        }
//        let s1 = Document(Scheme(foo: nil))
//        var s2 = s1
//        s2.change { $0.foo?.set("bar") }
//        XCTAssertEqual(s1.content.foo, nil)
//        XCTAssertEqual(s2.content.foo, "bar")
//    }

    }

    fileprivate protocol Foo { var foo: String? { get } }
