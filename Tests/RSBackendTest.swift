//
//  RSBackendTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 10.05.20.
//

import Foundation
@testable import Automerge
import XCTest

final class RSBackendTest: XCTestCase {

    func testInit() {
        let backend = RSBackend()
         XCTAssertEqual(backend.save(), [])
    }

//    func testloadDocument() {
//        let initialDocumentState: [UInt8] = [133, 111, 74, 131, 31, 191, 200, 9, 0, 150, 1, 1, 16, 215, 202, 121, 173, 249, 60, 66, 186, 135, 225, 16, 161, 85, 162, 112, 99, 1, 134, 37, 223, 236, 30, 174, 126, 157, 190, 175, 242, 188, 108, 88, 110, 150, 81, 218, 234, 100, 85, 222, 197, 241, 27, 82, 177, 54, 11, 88, 9, 49, 6, 1, 2, 127, 0, 3, 2, 127, 1, 11, 2, 127, 2, 19, 6, 127, 217, 207, 243, 245, 5, 29, 18, 127, 16, 73, 110, 105, 116, 32, 119, 105, 116, 104, 32, 115, 99, 104, 101, 109, 101, 32, 2, 127, 0, 1, 4, 0, 1, 127, 0, 2, 4, 0, 1, 127, 1, 13, 12, 126, 6, 115, 99, 104, 101, 109, 97, 3, 105, 110, 116, 17, 2, 2, 0, 19, 2, 2, 1, 28, 1, 2, 34, 3, 126, 4, 0, 46, 3, 126, 0, 19, 47, 1, 1, 64, 2, 2, 0]
//        let backend = RSBackend(document: initialDocumentState)
//
//        let abc = backend.save()
//        XCTAssertEqual(backend.save(), initialDocumentState)
//    }

    func testApplayLocal() {
        let backend = RSBackend()
        let request = Request(requestType: .change, message: "Test", time: Date(), actor: "111111", seq: 1, version: 0, ops: [Op(action: .set, obj: ROOT_ID, key: "bird", value: .string("magpie"))], undoable: false)
        backend.applyLocalChange(request: request)
    }

}
