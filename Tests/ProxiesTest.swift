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

    // should allow list (conatining objects) assignment inside deep object
    func testProxiesSwift4() {
        let backend = BackendMock()
        let document = Document<TestStruct>(options: .init(actorId: UUID(), backend: backend))

        // WHEN
        _ = document.change(execute: { doc in
            doc[\.deepObjList, "deepObjList"] = [DeepObj(list: [1])]
            XCTAssertEqual(doc[\.deepObjList, "deepObjList"], [DeepObj(list: [1])])
        })
    }
}
