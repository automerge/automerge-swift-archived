//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation
import XCTest
@testable import Automerge

struct DeepObj: Codable, Equatable {
    var list: [Double]
}

struct TestStruct: Codable {
    var key1: String?
    let key2: String
    var deepObj: DeepObj

    var deepObjList: [DeepObj]
}

struct DocWithList: Codable {
    var list: [Double]
    var empty: [Double]

    var deepObj: DeepObj
}

class ProxiesTest: XCTestCase {

    // should have a fixed object ID
    func testProxie1() {
        // GIVEN
        let backend = BackendMock()
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            XCTAssertEqual(doc.objectId, ROOT_ID)
        })
    }

    // should expose keys as object properties
    func testProxie3() {
        // GIVEN
        let backend = BackendMock()
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.key1, "key1"] = "value1"
            XCTAssertEqual(doc[\.key1, "key1"], "value1")
        })
    }

    // should return undefined for unknown properties
    func testProxies4() {
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: BackendMock()))

        // WHEN
        _ = document.change(execute: { doc in
            let nilValue = doc[\.key1, "key1"]
            XCTAssertNil(nilValue)
        })
    }

    // should allow deep object assigment
    func testProxiesSwift1() {
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: BackendMock()))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [1])
            XCTAssertEqual(doc[\.deepObj, "deepObj"], DeepObj(list: [1]))
        })
    }

    // should allow list assignment inside deep object
    func testProxiesSwift2() {
        let backend = BackendMock()
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [])
            doc[\.deepObj.list, "deepObj.list"] = [1]
            XCTAssertEqual(doc[\.deepObj.list, "deepObj.list"], [1])
        })
    }

    // should allow empty list assignment inside deep object
    func testProxiesSwift3() {
        let backend = BackendMock()
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [])
            XCTAssertEqual(doc[\.deepObj.list, "deepObj.list"], [])
        })
    }

    // should have a length property
    func testListObject1() {
        let backend = BackendMock()
        let document = Document<DocWithList>(options: .init(actorId: UUID(), backend: backend)).change(execute: { doc in
            doc[\.list, "list"] = [1, 2, 3]
            doc[\.empty, "empty"] = []
        }).0

        // WHEN
        _ = document.change(execute: { doc in
            XCTAssertEqual(doc[\.list, "list"].count, 3)
            XCTAssertEqual(doc[\.empty, "empty"].count, 0)

            let proxy: ArrayProxy<Double> = doc[\.list, "list"]
            let emptyProxy: ArrayProxy<Double> = doc[\.empty, "empty"]
            XCTAssertEqual(proxy.count, 3)
            XCTAssertEqual(emptyProxy.count, 0)
        })
    }

    // should allow entries to be fetched by index
    func testListObject2() {
        let backend = BackendMock()
        let document = Document<DocWithList>(options: .init(actorId: UUID(), backend: backend)).change(execute: { doc in
            doc[\.list, "list"] = [1, 2, 3]
            doc[\.empty, "empty"] = []
        }).0

        // WHEN
        _ = document.change(execute: { doc in
            let proxy: ArrayProxy<Double> = doc[\.list, "list"]

            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 2)
            XCTAssertEqual(proxy[2], 3)
        })
    }

    // should support iteration
    func testListObject3() {
        let backend = BackendMock()
        let document = Document<DocWithList>(options: .init(actorId: UUID(), backend: backend)).change(execute: { doc in
            doc[\.list, "list"] = [1, 2, 3]
            doc[\.empty, "empty"] = []
        }).0

        // WHEN
        _ = document.change(execute: { doc in
            let proxy: ArrayProxy<Double> = doc[\.list, "list"]
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
        let document = Document<DocWithList>(options: .init(actorId: UUID(), backend: backend)).change(execute: { doc in
            doc[\.list, "list"] = [1, 2, 3]

            let proxy: ArrayProxy<Double> = doc[\.list, "list"]
            proxy.replaceSubrange(1...1, with: [])
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 3)
            XCTAssertEqual(proxy.count, 2)

            let proxy2: ArrayProxy<Double> = doc[\.list, "list"]
            XCTAssertEqual(doc[\.list, "list"], [1, 3])
            XCTAssertEqual(proxy2[0], 1)
            XCTAssertEqual(proxy2[1], 3)
            XCTAssertEqual(proxy2.count, 2)

        }).0

        // WHEN
        _ = document.change(execute: { doc in
           let proxy: ArrayProxy<Double> = doc[\.list, "list"]
            XCTAssertEqual(doc[\.list, "list"], [1, 3])
            XCTAssertEqual(proxy[0], 1)
            XCTAssertEqual(proxy[1], 3)
            XCTAssertEqual(proxy.count, 2)
        })
    }

    // append()
    func testListObject5() {
        let backend = BackendMock()
        let document = Document<DocWithList>(options: .init(actorId: UUID(), backend: backend)).change(execute: { doc in
            doc[\.list, "list"] = [1, 2, 3]

            var proxy: ArrayProxy<Double> = doc[\.list, "list"]
            proxy.append(4)
            proxy.append(contentsOf: [5, 6])
            XCTAssertEqual(proxy.count, 6)
            XCTAssertEqual(doc[\.list, "list"], [1, 2, 3, 4, 5, 6])
        }).0
    }

}
