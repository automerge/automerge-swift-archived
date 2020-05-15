//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.05.20.
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

    static let fake = TestStruct(key1: nil, key2: "key2", deepObj: DeepObj(list: []), deepObjList:[ DeepObj(list: [])])
}

class ProxyTest: XCTestCase {

    // should have a fixed object ID
    func testProxie1() {
        // GIVEN
        var document = Document<TestStruct>(.fake, options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            XCTAssertEqual(doc.objectId, "00000000-0000-0000-0000-000000000000")
        })
    }

    // should expose keys as object properties
    func testProxie3() {
        // GIVEN
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            doc[\.key1, "key1"] = "value1"
            XCTAssertEqual(doc[\.key1, "key1"], "value1")
        })
    }

    // should return undefined for unknown properties
    func testProxies4() {
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            let nilValue = doc[\.key1, "key1"]
            XCTAssertNil(nilValue)
        })
    }

    // should allow deep object assigment
    func testProxiesSwift1() {
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [1])
            XCTAssertEqual(doc[\.deepObj, "deepObj"], DeepObj(list: [1]))
        })
    }

    // should allow list assignment inside deep object
    func testProxiesSwift2() {
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [])
            doc[\.deepObj.list, "deepObj.list"] = [1]
            XCTAssertEqual(doc[\.deepObj.list, "deepObj.list"], [1])
        })
    }

    // should allow empty list assignment inside deep object
    func testProxiesSwift3() {
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            doc[\.deepObj, "deepObj"] = DeepObj(list: [])
            XCTAssertEqual(doc[\.deepObj.list, "deepObj.list"], [])
        })
    }

    // should allow empty list assignment inside deep object
    func testProxiesSwift4() {
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            doc[\.deepObjList, "deepObjList"] = [DeepObj(list: [])]
            XCTAssertEqual(doc[\.deepObjList[0].list, "deepObjList[0].list"], [])
        })
    }

    // should allow empty list assignment inside deep object
    func testProxiesSwift5() {
        var document = Document<TestStruct>(options: .init(backend: RSBackend()))

        // WHEN
        document.change({ doc in
            doc[\.deepObjList, "deepObjList"] = [DeepObj(list: [])]
            doc[\.deepObjList[0].list, "deepObjList[0].list"] = [1, 2]
            XCTAssertEqual(doc[\.deepObjList[0].list, "deepObjList[0].list"], [1, 2])
        })
    }

}
