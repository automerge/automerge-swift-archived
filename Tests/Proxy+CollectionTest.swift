//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.05.20.
//

import Foundation
import XCTest
@testable import Automerge

struct DocWithList: Codable, Equatable {
    var list: [Double]
    var empty: [Double]
    var nested: [[Double]]

    var deepObj: DeepObj
}

class ProxyCollectionTest: XCTestCase {

    // should have a length property
    func testListObject1() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]
            doc[\.empty, "empty"] = []
        })

        // WHEN
        document.change({ doc in
            XCTAssertEqual(doc[\.list, "list"].count, 3)
            XCTAssertEqual(doc[\.empty, "empty"].count, 0)

            let proxy: Proxy<[Double]> = doc[\.list, "list"]
            let emptyProxy: Proxy<[Double]> = doc[\.empty, "empty"]
            XCTAssertEqual(proxy.count, 3)
            XCTAssertEqual(emptyProxy.count, 0)
        })
    }

    // should allow entries to be fetched by index
    func testListObject2() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]
            doc[\.empty, "empty"] = []
        })

        // WHEN
        document.change({ doc in
            let proxy: Proxy<[Double]> = doc[\.list, "list"]

            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 2)
            XCTAssertEqual(proxy[2], 3)
        })
    }

    // should support iteration
    func testListObject3() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]
            doc[\.empty, "empty"] = []
        })

        // WHEN
        document.change({ doc in
            let proxy: Proxy<[Double]> = doc[\.list, "list"]
            var copy = [Double]()

            for value in proxy {
                copy.append(value)
            }

            XCTAssertEqual(copy, [1, 2, 3])
        })
    }

    // splice()
    func testListObject4() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]

            let proxy: Proxy<[Double]> = doc[\.list, "list"]
            proxy.replaceSubrange(1...1, with: [])
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 3)
            XCTAssertEqual(proxy.count, 2)

            let proxy2: Proxy<[Double]> = doc[\.list, "list"]
            XCTAssertEqual(doc[\.list, "list"], [1, 3])
            XCTAssertEqual(proxy2[0], 1)
            XCTAssertEqual(proxy2[1], 3)
            XCTAssertEqual(proxy2.count, 2)

        })

        // WHEN
        document.change({ doc in
            let proxy: Proxy<[Double]> = doc[\.list, "list"]
            XCTAssertEqual(doc[\.list, "list"], [1, 3])
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 3)
            XCTAssertEqual(proxy.count, 2)
        })
    }

    // append()
    func testListObject5() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]
        })

        // WHEN
        document.change({ doc in
            doc[\.list, "list"].append(4)
            doc[\.list, "list"].append(contentsOf: [5, 6])
            let proxy: Proxy = doc[\.list, "list"]
            XCTAssertEqual(proxy.count, 6)
            XCTAssertEqual(doc[\.list, "list"], [1, 2, 3, 4, 5, 6])
        })
    }

    // setAtIndex()
    func testListObject6() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]
        })

        document.change({ doc in
            let proxy: Proxy<[Double]> = doc[\.list, "list"]
            proxy[1] = 1
            XCTAssertEqual(proxy[1], 1)
            XCTAssertEqual(doc[\.list, "list"], [1, 1, 3])

        })
    }

    // setAtIndex2()
    func testListObject7() {
        let backend = BackendMock()
        var document = Document<DocWithList>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.list, "list"] = [1, 2, 3]
        })

        document.change({ doc in
             doc[\.list[1], "list[1]"] = 1
            XCTAssertEqual(doc[\.list, "list"], [1, 1, 3])
            XCTAssertEqual(doc[\.list[1], "list[1]"], 1)
        })
    }

    // setAtIndex3()
    func testListObject8() {
        let backend = BackendMock()
        var document = Document<TestStruct>(options: .init(backend: backend))
        document.change({ doc in
            doc[\.deepObjList, "deepObjList"] = [DeepObj(list: [])]
        })

        document.change({ doc in
            let proxy: Proxy = doc[\.deepObjList, "deepObjList"]
            proxy[0] = DeepObj(list: [1])
            XCTAssertEqual(proxy[0], DeepObj(list: [1]))
            XCTAssertEqual(doc[\.deepObjList, "deepObjList"], [DeepObj(list: [1])])
        })
    }

    // setAtIndex4()
//    func testListObject9() {
//        struct DocWithList: Codable, Equatable {
//            var nested: [[Double]]
//        }
//        let backend = BackendMock()
//        var document = Document(DocWithList(nested: [[0], [2]]),
//                           options: .init(backend: backend))
//
//        XCTAssertEqual(document.content, DocWithList(nested: [[0], [2]]))
//        document.change({ doc in
//            let proxy: Proxy<[Double]> = doc[\.nested[0], "nested[0]"]
//            proxy[0] = 1
//            XCTAssertEqual(proxy[0], 1)
//            XCTAssertEqual(doc[\.nested[0], "nested[0]"], [1])
//        })
//    }

}
