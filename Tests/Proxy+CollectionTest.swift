//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.05.20.
//

import Foundation
import XCTest
@testable import Automerge

class ProxyCollectionTest: XCTestCase {

    // should have a length property
    func testListObject1() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
            var empty: [Int]
        }
        var document = Document(Scheme(list: [], empty: []))
        document.change { $0.list.set([1, 2, 3]) }

        // WHEN
        document.change({ doc in
            XCTAssertEqual(doc.list.count, 3)
            XCTAssertEqual(doc.empty.count, 0)
        })
    }

    // should allow entries to be fetched by index
    func testListObject2() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
        }
        var document = Document(Scheme(list: []))
        document.change { $0.list.set([1, 2, 3]) }

        // WHEN
        document.change({ doc in
            XCTAssertEqual(doc.list[0], 1)
            XCTAssertEqual(doc.list[1], 2)
            XCTAssertEqual(doc.list[2], 3)
        })
    }

    // should support iteration
    func testListObject3() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
            var empty: [Int]
        }
        var document = Document(Scheme(list: [], empty: []))
        document.change { $0.list.set([1, 2, 3]) }

        // WHEN
        document.change({ doc in
            var copy = [Int]()

            for value in doc.list {
                copy.append(value)
            }
            XCTAssertEqual(copy, [1, 2, 3])
        })
    }

    // splice()
    func testListObject4() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
        }
        var document = Document(Scheme(list: []))
        document.change({ doc in
            doc.list.set([1, 2, 3])

            var proxy: Proxy<[Int]> = doc.list
            proxy.replaceSubrange(1...1, with: [])
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 3)
            XCTAssertEqual(proxy.count, 2)

            let proxy2: Proxy<[Int]> = doc.list
            XCTAssertEqual(doc.list.get(), [1, 3])
            XCTAssertEqual(proxy2[0], 1)
            XCTAssertEqual(proxy2[1], 3)
            XCTAssertEqual(proxy2.count, 2)

        })

        // WHEN
        document.change({ doc in
            let proxy: Proxy<[Int]> = doc.list
            XCTAssertEqual(doc.list.get(), [1, 3])
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 3)
            XCTAssertEqual(proxy.count, 2)
        })
    }

    // append()
    func testListObject5() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
        }
        var document = Document(Scheme(list: []))
        document.change({ doc in
            doc.list.set([1, 2, 3])
        })

        // WHEN
        document.change({ doc in
            var proxy: Proxy<[Int]> = doc.list
            proxy.append(4)
            proxy.append(contentsOf: [5, 6])
            XCTAssertEqual(doc.list.count, 6)
            XCTAssertEqual(doc.list.get(), [1, 2, 3, 4, 5, 6])
        })
    }

    // setAtIndex()
    func testListObject6() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
        }
        var document = Document(Scheme(list: []))
        document.change({ doc in
            doc.list.set([1, 2, 3])
        })

        document.change({ doc in
            var proxy: Proxy<[Int]> = doc.list
            proxy[1] = 1
            XCTAssertEqual(proxy[1], 1)
            XCTAssertEqual(doc.list.get(), [1, 1, 3])
        })
    }

    // setAtIndex2()
    func testListObject7() {
        struct Scheme: Codable, Equatable {
            var list: [Int]
        }
        var document = Document(Scheme(list: []))
        document.change({ doc in
            doc.list.set([1, 2, 3])
        })

        document.change({ doc in
            doc.list[1].set(1)
            XCTAssertEqual(doc.list.get(), [1, 1, 3])
            XCTAssertEqual(doc.list[1].get(), 1)
        })
    }

    // setAtIndex3()
    func testListObject8() {
        struct Scheme: Codable, Equatable {
            struct DeepObj: Codable, Equatable {
                var list: [Int]
            }
            var deepObjList: [DeepObj]
        }
        var document = Document(Scheme(deepObjList: []))
        document.change({ doc in
            doc.deepObjList.set([.init(list: [])])
        })

        document.change({ doc in
            var proxy: Proxy = doc.deepObjList
            proxy.append(.init(list: [1]))
            XCTAssertEqual(doc.deepObjList[0], .init(list: [1]))
            XCTAssertEqual(doc.deepObjList.get(), [.init(list: [1])])
        })
    }
    
    // setAtIndex4()
    func testListObject9() {
        struct Scheme: Codable, Equatable {
            var nested: [[Double]]
        }
        var document = Document(Scheme(nested: [[0], [2]]))

        XCTAssertEqual(document.content, Scheme(nested: [[0], [2]]))
        document.change({ doc in
            let proxy: Proxy = doc.nested[0]
            proxy[0].set(1)
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(doc.nested[0], [1])
        })
    }

}
