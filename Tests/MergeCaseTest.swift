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

    typealias AMDocData = [UInt8]
    typealias AMChangesData = [[UInt8]]

    // In the following arrays are sorted so that the successfulDocs[i] + successfulChanges[i] were a pair
    // that was generted from a successful run of `testExample`. Similarly, failedDocs[i] + failedChanges[i]
    // were a pair from a failed run of `testExample`.
    static let successfulDocs: [AMDocData] = [
        [133, 111, 74, 131, 10, 79, 238, 3, 1, 109, 16, 1, 147, 3, 214, 105, 107, 74, 154, 168, 204, 25, 109, 108, 14, 157, 168, 1, 1, 149, 235, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 73, 104, 14, 48, 1, 109, 16, 145, 184, 81, 101, 234, 41, 75, 114, 164, 255, 246, 17, 243, 219, 129, 127, 1, 1, 223, 253, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 81, 105, 95, 207, 1, 109, 16, 70, 70, 183, 3, 179, 231, 66, 86, 151, 49, 67, 248, 55, 60, 184, 73, 1, 1, 255, 253, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 49, 13, 155, 70, 1, 109, 16, 45, 110, 252, 61, 107, 205, 76, 51, 176, 117, 138, 70, 46, 50, 8, 50, 1, 1, 146, 254, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 207, 106, 155, 44, 1, 109, 16, 112, 98, 30, 242, 161, 194, 74, 84, 135, 101, 246, 29, 82, 44, 126, 204, 1, 1, 166, 254, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
    ]
    static let successfulChanges: [AMChangesData] = [
        [[133, 111, 74, 131, 138, 0, 9, 178, 1, 109, 16, 24, 52, 230, 23, 79, 196, 76, 144, 167, 58, 149, 68, 132, 48, 24, 188, 1, 1, 149, 235, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 89, 131, 122, 27, 1, 194, 2, 16, 24, 52, 230, 23, 79, 196, 76, 144, 167, 58, 149, 68, 132, 48, 24, 188, 2, 3, 149, 235, 171, 132, 6, 0, 0, 1, 138, 0, 9, 178, 56, 246, 107, 182, 130, 251, 1, 248, 228, 152, 140, 162, 73, 7, 88, 201, 166, 209, 249, 22, 242, 45, 181, 78, 77, 10, 159, 193, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 70, 48, 56, 49, 69, 56, 67, 68, 45, 52, 49, 52, 53, 45, 52, 51, 49, 50, 45, 66, 48, 66, 51, 45, 66, 51, 57, 49, 57, 54, 50, 57, 68, 51, 65, 49, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 208, 212, 100, 33, 1, 109, 16, 224, 104, 34, 1, 51, 156, 71, 241, 141, 137, 52, 48, 58, 13, 154, 21, 1, 1, 223, 253, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 250, 156, 5, 193, 1, 194, 2, 16, 224, 104, 34, 1, 51, 156, 71, 241, 141, 137, 52, 48, 58, 13, 154, 21, 2, 3, 223, 253, 171, 132, 6, 0, 0, 1, 208, 212, 100, 33, 127, 168, 88, 177, 180, 110, 242, 207, 58, 45, 81, 239, 28, 21, 102, 32, 26, 51, 169, 37, 139, 40, 66, 114, 34, 71, 175, 6, 1, 2, 17, 0, 2, 19, 126, 2, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 57, 57, 67, 52, 55, 68, 48, 50, 45, 66, 51, 53, 65, 45, 52, 67, 52, 49, 45, 65, 57, 65, 56, 45, 67, 54, 70, 70, 66, 50, 49, 51, 65, 66, 70, 48, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 101, 58, 30, 239, 1, 109, 16, 191, 161, 108, 206, 66, 113, 75, 76, 158, 255, 29, 150, 211, 154, 197, 229, 1, 1, 255, 253, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 23, 83, 12, 2, 1, 194, 2, 16, 191, 161, 108, 206, 66, 113, 75, 76, 158, 255, 29, 150, 211, 154, 197, 229, 2, 3, 255, 253, 171, 132, 6, 0, 0, 1, 101, 58, 30, 239, 193, 222, 51, 49, 193, 136, 254, 227, 160, 16, 31, 56, 57, 198, 113, 64, 126, 38, 105, 13, 169, 140, 144, 1, 48, 2, 11, 165, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 53, 50, 49, 66, 50, 65, 67, 51, 45, 57, 70, 69, 67, 45, 52, 49, 56, 51, 45, 65, 50, 56, 48, 45, 67, 54, 70, 68, 54, 70, 68, 57, 56, 55, 70, 66, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 240, 112, 89, 33, 1, 109, 16, 94, 99, 3, 193, 253, 21, 72, 132, 161, 235, 213, 234, 113, 64, 70, 247, 1, 1, 146, 254, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 151, 54, 135, 134, 1, 194, 2, 16, 94, 99, 3, 193, 253, 21, 72, 132, 161, 235, 213, 234, 113, 64, 70, 247, 2, 3, 146, 254, 171, 132, 6, 0, 0, 1, 240, 112, 89, 33, 19, 107, 253, 153, 5, 151, 240, 180, 102, 154, 253, 158, 18, 197, 95, 7, 55, 190, 231, 85, 58, 254, 107, 233, 19, 210, 48, 111, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 57, 53, 66, 53, 57, 50, 65, 66, 45, 70, 70, 67, 67, 45, 52, 48, 57, 50, 45, 56, 69, 57, 50, 45, 65, 54, 68, 65, 52, 55, 51, 48, 54, 54, 49, 51, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 19, 78, 201, 134, 1, 109, 16, 250, 188, 201, 133, 15, 176, 68, 106, 170, 80, 46, 107, 90, 71, 211, 129, 1, 1, 166, 254, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 165, 8, 152, 195, 1, 194, 2, 16, 250, 188, 201, 133, 15, 176, 68, 106, 170, 80, 46, 107, 90, 71, 211, 129, 2, 3, 166, 254, 171, 132, 6, 0, 0, 1, 19, 78, 201, 134, 56, 210, 249, 43, 185, 12, 3, 63, 245, 4, 47, 192, 83, 117, 68, 250, 92, 237, 202, 153, 113, 148, 141, 190, 39, 90, 170, 254, 1, 2, 17, 0, 2, 19, 126, 2, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 53, 49, 55, 53, 70, 49, 55, 54, 45, 66, 53, 70, 67, 45, 52, 57, 69, 54, 45, 65, 53, 69, 67, 45, 66, 66, 54, 68, 52, 56, 48, 51, 68, 70, 49, 51, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
    ]
    static let failedDocs: [AMDocData] = [
        [133, 111, 74, 131, 62, 225, 6, 230, 1, 109, 16, 93, 68, 133, 206, 177, 170, 71, 30, 156, 158, 110, 246, 206, 101, 94, 219, 1, 1, 193, 238, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 132, 138, 181, 95, 1, 109, 16, 219, 129, 77, 109, 117, 241, 75, 15, 154, 153, 103, 130, 50, 51, 219, 69, 1, 1, 211, 255, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 171, 130, 249, 72, 1, 109, 16, 133, 192, 160, 128, 249, 166, 66, 81, 173, 245, 247, 78, 5, 27, 216, 207, 1, 1, 193, 128, 172, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 27, 198, 16, 13, 1, 109, 16, 85, 83, 34, 244, 119, 75, 78, 152, 143, 46, 152, 215, 138, 138, 134, 24, 1, 1, 233, 128, 172, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
        [133, 111, 74, 131, 190, 206, 12, 3, 1, 109, 16, 112, 9, 126, 30, 203, 53, 77, 133, 171, 142, 53, 80, 123, 0, 44, 212, 1, 1, 129, 129, 172, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 2, 105, 100, 5, 99, 97, 114, 100, 115, 28, 1, 2, 34, 3, 126, 1, 2, 46, 4, 126, 198, 4, 0, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0],
    ]
    static let failedChanges: [AMChangesData] = [
        [[133, 111, 74, 131, 106, 150, 145, 148, 1, 109, 16, 93, 68, 133, 206, 177, 170, 71, 30, 156, 158, 110, 246, 206, 101, 94, 219, 1, 1, 193, 238, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 197, 27, 245, 223, 1, 194, 2, 16, 93, 68, 133, 206, 177, 170, 71, 30, 156, 158, 110, 246, 206, 101, 94, 219, 2, 3, 193, 238, 171, 132, 6, 0, 0, 1, 106, 150, 145, 148, 221, 216, 115, 198, 233, 230, 123, 139, 184, 228, 154, 125, 254, 41, 155, 219, 186, 38, 29, 209, 216, 60, 136, 122, 236, 76, 132, 83, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 51, 54, 56, 52, 48, 66, 50, 51, 45, 65, 52, 66, 49, 45, 52, 51, 65, 56, 45, 66, 54, 69, 68, 45, 51, 57, 70, 66, 56, 53, 49, 49, 51, 52, 66, 57, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 50, 166, 7, 225, 1, 109, 16, 232, 178, 184, 11, 189, 82, 65, 156, 141, 203, 209, 146, 242, 199, 60, 33, 1, 1, 211, 255, 171, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 206, 77, 247, 104, 1, 194, 2, 16, 232, 178, 184, 11, 189, 82, 65, 156, 141, 203, 209, 146, 242, 199, 60, 33, 2, 3, 211, 255, 171, 132, 6, 0, 0, 1, 50, 166, 7, 225, 125, 140, 193, 185, 59, 88, 213, 90, 245, 106, 75, 204, 230, 145, 51, 164, 71, 50, 15, 221, 38, 83, 100, 85, 33, 86, 8, 198, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 65, 51, 49, 70, 70, 51, 57, 56, 45, 48, 54, 68, 54, 45, 52, 66, 65, 67, 45, 57, 48, 49, 67, 45, 57, 70, 65, 55, 50, 53, 50, 51, 52, 53, 54, 48, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 149, 32, 38, 159, 1, 109, 16, 184, 146, 30, 198, 194, 91, 74, 59, 130, 74, 252, 252, 163, 194, 241, 136, 1, 1, 193, 128, 172, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 53, 19, 114, 102, 1, 194, 2, 16, 184, 146, 30, 198, 194, 91, 74, 59, 130, 74, 252, 252, 163, 194, 241, 136, 2, 3, 193, 128, 172, 132, 6, 0, 0, 1, 149, 32, 38, 159, 183, 209, 227, 183, 27, 225, 235, 7, 189, 79, 42, 74, 173, 83, 218, 252, 113, 162, 75, 211, 205, 131, 215, 124, 241, 58, 250, 145, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 70, 57, 52, 55, 69, 50, 49, 67, 45, 57, 54, 57, 70, 45, 52, 51, 54, 55, 45, 57, 66, 66, 70, 45, 57, 55, 49, 70, 51, 49, 49, 55, 65, 57, 70, 53, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 0, 131, 199, 235, 1, 109, 16, 71, 80, 204, 214, 116, 52, 68, 82, 140, 198, 203, 77, 221, 234, 240, 109, 1, 1, 233, 128, 172, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 20, 51, 118, 130, 1, 194, 2, 16, 71, 80, 204, 214, 116, 52, 68, 82, 140, 198, 203, 77, 221, 234, 240, 109, 2, 3, 233, 128, 172, 132, 6, 0, 0, 1, 0, 131, 199, 235, 207, 136, 188, 194, 232, 84, 90, 106, 43, 221, 59, 217, 3, 127, 27, 2, 237, 23, 56, 237, 9, 95, 104, 3, 135, 171, 133, 232, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 48, 68, 49, 55, 67, 50, 69, 51, 45, 54, 67, 55, 70, 45, 52, 67, 55, 52, 45, 65, 57, 65, 51, 45, 65, 67, 67, 54, 55, 50, 69, 68, 67, 52, 55, 65, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
        [[133, 111, 74, 131, 162, 207, 149, 199, 1, 109, 16, 158, 66, 74, 79, 206, 129, 79, 224, 130, 169, 14, 198, 31, 3, 93, 254, 1, 1, 129, 129, 172, 132, 6, 14, 73, 110, 105, 116, 105, 97, 108, 105, 122, 97, 116, 105, 111, 110, 0, 0, 13, 10, 126, 5, 99, 97, 114, 100, 115, 2, 105, 100, 28, 1, 2, 34, 3, 126, 2, 1, 46, 4, 126, 0, 198, 4, 47, 36, 56, 51, 54, 50, 49, 55, 52, 53, 45, 48, 70, 54, 54, 45, 52, 70, 52, 50, 45, 66, 69, 67, 50, 45, 57, 53, 54, 57, 55, 66, 48, 70, 66, 65, 50, 56, 56, 2, 2, 0], [133, 111, 74, 131, 157, 104, 252, 161, 1, 194, 2, 16, 158, 66, 74, 79, 206, 129, 79, 224, 130, 169, 14, 198, 31, 3, 93, 254, 2, 3, 129, 129, 172, 132, 6, 0, 0, 1, 162, 207, 149, 199, 21, 138, 102, 18, 30, 9, 70, 29, 235, 84, 237, 120, 34, 238, 172, 175, 127, 182, 52, 197, 170, 47, 229, 63, 95, 162, 38, 19, 1, 2, 17, 0, 2, 19, 126, 1, 3, 2, 4, 2, 3, 2, 8, 127, 3, 4, 11, 127, 3, 2, 16, 127, 3, 9, 14, 0, 3, 127, 0, 0, 3, 127, 0, 0, 7, 127, 0, 0, 1, 11, 19, 127, 0, 0, 1, 126, 0, 5, 0, 2, 126, 123, 9, 0, 6, 126, 119, 17, 0, 1, 13, 69, 0, 1, 127, 6, 99, 101, 110, 116, 101, 114, 0, 2, 126, 2, 105, 100, 4, 115, 105, 122, 101, 0, 2, 122, 4, 116, 105, 110, 116, 4, 98, 108, 117, 101, 5, 103, 114, 101, 101, 110, 7, 111, 112, 97, 99, 105, 116, 121, 3, 114, 101, 100, 11, 116, 114, 97, 110, 115, 108, 97, 116, 105, 111, 110, 0, 2, 127, 1, 122, 28, 9, 0, 1, 1, 2, 2, 2, 6, 2, 1, 34, 17, 126, 0, 2, 3, 1, 127, 2, 2, 1, 127, 0, 4, 1, 127, 2, 3, 1, 46, 22, 2, 0, 2, 35, 126, 198, 4, 0, 2, 19, 127, 0, 2, 133, 1, 125, 19, 133, 1, 0, 3, 19, 47, 70, 212, 1, 227, 2, 69, 52, 52, 49, 49, 68, 70, 66, 45, 53, 56, 66, 65, 45, 52, 66, 51, 70, 45, 65, 52, 49, 65, 45, 50, 68, 51, 68, 57, 67, 66, 69, 53, 66, 56, 68, 93, 122, 192, 246, 168, 157, 155, 211, 151, 63, 36, 91, 148, 37, 159, 167, 223, 63, 1, 0, 227, 124, 137, 89, 151, 167, 63, 0, 0, 1, 56, 2, 17, 0]],
    ]

    func testExample() throws {
        let id = "83621745-0F66-4F42-BEC2-95697B0FBA28"
        let center = CGPoint(x: 212.0, y: 355.0)
        let size = CGSize(width: 93.0, height: 122.0)
        let tint = Tint(red: 0.04607658198660225, green: 0.49460581464647846, blue: 0.02326815748005262, opacity: 1.0)
        let z = 1

        var firstModel = Document(AMBoard(id: id, cards: []))
        let newCard = AMCard(center: center, translation: .zero, size: size, z: z, tint: tint)
        firstModel.change { (proxy) in
            proxy.cards.append(newCard)
        }

        XCTAssertEqual(firstModel.content.cards.count, 1)

        // Test apply(changes:), try two different empty documents. Sometimes only one of the empty documents will fail
        var applyModel1 = Document(AMBoard(id: id, cards: []))
        applyModel1.apply(changes: firstModel.allChanges())
        XCTAssertEqual(applyModel1.content.cards.count, 1)

        var applyModel2 = Document(AMBoard(id: id, cards: []))
        applyModel2.apply(changes: firstModel.allChanges())
        XCTAssertEqual(applyModel2.content.cards.count, 1)

        // Test .merge() with two different empty documents. Sometimes only one of these will fail, sometimes both, sometimes neither.
        var mergeModel1 = Document(AMBoard(id: id, cards: []))
        mergeModel1.merge(firstModel)
        XCTAssertEqual(mergeModel1.content.cards.count, 1)

        var mergeModel2 = Document(AMBoard(id: id, cards: []))
        mergeModel2.merge(firstModel)
        XCTAssertEqual(mergeModel2.content.cards.count, 1)
    }

    /// This test shows that all successful test cases will consistently pass on every run. These document/data pairs were generted by successful
    /// runs of the `testExample` test case.
    func testApplyEachSuccessfulPatch() throws {
        for (i, data) in Self.successfulDocs.enumerated() {
            let changes = Self.successfulChanges[i]
            var firstModel = Document<AMBoard>(data: data)

            XCTAssertEqual(firstModel.content.cards.count, 0, "doc \(i) change \(i)")

            firstModel.apply(changes: changes)

            XCTAssertEqual(firstModel.content.cards.count, 1, "doc \(i) change \(i)")
        }
    }

    /// Similar to `testApplyEachSuccessfulPatch`, except that every successful document has every successful changeset applied
    /// instead of only the pair that we already know is successful. Interestingly, some of these test cases fail.
    func testApplyAllSuccessfulPatch() throws {
        for (di, data) in Self.successfulDocs.enumerated() {
            for (ci, changes) in Self.successfulChanges.enumerated() {
                var firstModel = Document<AMBoard>(data: data)

                XCTAssertEqual(firstModel.content.cards.count, 0, "doc \(di) change \(ci)")

                firstModel.apply(changes: changes)

                XCTAssertEqual(firstModel.content.cards.count, 1, "doc \(di) change \(ci)")
            }
        }
    }

    /// This test shows that a failing document/changeset generated from the `testExample` will always fail, even when
    /// changing the pairing of document/changeset
    func testApplyFailedPatch() throws {
        var caseNum = 0
        for (di, data) in Self.failedDocs.enumerated() {
            for (ci, changes) in Self.failedChanges.enumerated() {
                var firstModel = Document<AMBoard>(data: data)

                XCTAssertEqual(firstModel.content.cards.count, 0, "doc \(di) change \(ci)")

                firstModel.apply(changes: changes)

                XCTAssertEqual(firstModel.content.cards.count, 1, "doc \(di) change \(ci)")
                caseNum += 1
            }
        }
    }

    /// These next two tests mismatch pairs of successful documents to successful changesets to try and narrow down if the
    /// changesets are what is formatted badly or if the document data is formatted badly. However, it seems from
    /// `testApplyAllSuccessfulPatch` that _both_ are formatted badly.
    func testFailedDocSuccessfulChanges() throws {
        for (di, data) in Self.failedDocs.enumerated() {
            for (ci, changes) in Self.successfulChanges.enumerated() {
                var firstModel = Document<AMBoard>(data: data)

                XCTAssertEqual(firstModel.content.cards.count, 0, "doc \(di) change \(ci)")

                firstModel.apply(changes: changes)

                XCTAssertEqual(firstModel.content.cards.count, 1, "doc \(di) change \(ci)")
            }
        }
    }

    func testSuccessfulDocFailedChanges() throws {
        for (di, data) in Self.successfulDocs.enumerated() {
            for (ci, changes) in Self.failedChanges.enumerated() {
                var firstModel = Document<AMBoard>(data: data)

                XCTAssertEqual(firstModel.content.cards.count, 0, "doc \(di) change \(ci)")

                firstModel.apply(changes: changes)

                XCTAssertEqual(firstModel.content.cards.count, 1, "doc \(di) change \(ci)")
            }
        }
    }
}
