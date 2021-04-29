//
//  MergeCaseTest.swift
//  
//
//  Created by Adam Wulf on 4/28/21.
//

import Foundation
import XCTest
@testable import Automerge

// MARK: - Automerge Models

struct Tint: Equatable, Codable {
    let red, green, blue, opacity: CGFloat
    static var random: Tint {
        Tint(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), opacity: 1)
    }
    static var black: Tint {
        Tint(red: 0, green: 0, blue: 0, opacity: 1)
    }
    var uiColor: NSColor {
        NSColor(displayP3Red: red, green: green, blue: blue, alpha: opacity)
    }
}

struct AMCard: Codable {
    let id: String
    var center: CGPoint
    var translation: CGVector
    var size: CGSize
    var z: Int
    var tint: Tint

    init(id: String = UUID().uuidString, center: CGPoint, translation: CGVector, size: CGSize, z: Int, tint: Tint) {
        self.id = id
        self.center = center
        self.translation = translation
        self.size = size
        self.z = z
        self.tint = tint
    }
}

struct AMBoard: Codable {
    let id: String
    var cards: [AMCard]

    init(id: String = UUID().uuidString, cards: [AMCard]) {
        self.id = id
        self.cards = cards
    }
}

class MergeCaseTest: XCTestCase {
    func testExample() throws {
        let id = "83621745-0F66-4F42-BEC2-95697B0FBA28"
        let center = CGPoint(x: 212.0, y: 355.0)
        let size = CGSize(width: 93.0, height: 122.0)
        let tint = Tint(red: 0.04607658198660225, green: 0.49460581464647846, blue: 0.02326815748005262, opacity: 1.0)
        let z = 1

        var model = Document(AMBoard(id: id, cards: []))
        let newCard = AMCard(center: center, translation: .zero, size: size, z: z, tint: tint)
        model.change { (proxy) in
            proxy.cards.append(newCard)
        }

        XCTAssertEqual(model.content.cards.count, 1)

        var otherModel = Document(AMBoard(id: id, cards: []))
        otherModel.apply(changes: model.allChanges())

        XCTAssertEqual(otherModel.content.cards.count, 1)
    }
}
