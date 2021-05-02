//
//  File.swift
//  
//
//  Created by Adam Wulf on 5/1/21.
//

import Foundation
import XCTest
@testable import Automerge

final class PerformanceTest: XCTestCase {

    struct Model: Codable {
        let id: String
        var fumble: CGPoint?
        init(fumble: CGPoint) {
            self.id = UUID().uuidString
            self.fumble = fumble
        }
    }

    func testFirst1kEdits() {
        measure {
            var doc = Automerge.Document(Model(fumble: .zero))
            var p = CGPoint(x: 0, y: 0)
            for _ in 0..<1000 {
                doc.change { (proxy) in
                    proxy.fumble.set(p)
                }
                p = doc.content.fumble ?? .zero
                p.x += CGFloat.random(in: 0..<10) - 5
                p.y += CGFloat.random(in: 0..<10) - 5
            }
        }
    }


    func testSubsequent1kEdits() {
        var doc = Automerge.Document(Model(fumble: .zero))
        var p = CGPoint(x: 0, y: 0)

        measure {
            for _ in 0..<1000 {
                doc.change { (proxy) in
                    proxy.fumble.set(p)
                }
                p = doc.content.fumble ?? .zero
                p.x += CGFloat.random(in: 0..<10) - 5
                p.y += CGFloat.random(in: 0..<10) - 5
            }
        }
    }
}
