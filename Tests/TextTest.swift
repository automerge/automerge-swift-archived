//
//  TextTests.swift
//  Automerge
//
//  Created by Lukas Schmidt on 03.06.20.
//

import Foundation
import XCTest
import Automerge

// /test/text_test.js
class TextTest: XCTestCase {

    // should support insertion
    func testText1() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        var s1 = Document(Scheme(text: Text()))
        s1.change({ $0.text.insert("a", at: 0) })
        XCTAssertEqual(s1.content.text[0], "a")
        XCTAssertEqual(s1.content.text.count, 1)
        XCTAssertEqual("\(s1.content.text)", "a")
    }

    // should support deletion
    func testText2() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        var s1 = Document(Scheme(text: Text()))
        s1.change({ $0.text.insert(contentsOf: ["a", "b", "c"], at: 0) })
        s1.change { $0.text.delete(1, charactersAtIndex: 1) }
        XCTAssertEqual(s1.content.text.count, 2)
        XCTAssertEqual(s1.content.text[0], "a")
        XCTAssertEqual(s1.content.text[1], "c")
        XCTAssertEqual("\(s1.content.text)", "ac")
    }

    // should support implicit and explicit deletion
    func testText3() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        var s1 = Document(Scheme(text: Text()))
        s1.change({ $0.text.insert(contentsOf: ["a", "b", "c"], at: 0) })
        s1.change { $0.text.delete(at: 1) }
        s1.change { $0.text.delete(0, charactersAtIndex: 1) }
        XCTAssertEqual(s1.content.text.count, 2)
        XCTAssertEqual(s1.content.text[0], "a")
        XCTAssertEqual(s1.content.text[1], "c")
        XCTAssertEqual("\(s1.content.text)", "ac")
    }

    // should handle concurrent insertion
    func testText4() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        var s1 = Document(Scheme(text: Text()))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change({ $0.text.insert(contentsOf: ["a", "b", "c"], at: 0) })
        s2.change({ $0.text.insert(contentsOf: ["x", "y", "z"], at: 0) })
        s1.merge(s2)
        XCTAssertEqual(s1.content.text.count, 6)
        XCTAssertEqualOneOf("\(s1.content.text)", "abcxyz", "xyzabc")
    }

    // should handle text and other ops in the same change
    func testText5() {
        struct Scheme: Codable, Equatable {
            var text: Text
            var foo: String?
        }

        var s1 = Document(Scheme(text: Text(), foo: nil))
        s1.change({
            $0.text.insert("a", at: 0)
            $0.foo?.set("bar")
        })
        XCTAssertEqual(s1.content.foo, "bar")
        XCTAssertEqual("\(s1.content.text)", "a")
    }

    // should allow modification before an object is assigned to a document
    func testText6() {
        struct Scheme: Codable, Equatable {
            var text: Text?
        }

        var s1 = Document(Scheme(text: nil))
        s1.change({
            var text = Text()
            text.insert(contentsOf: ["a", "b", "c", "d"], at: 0)
            text.delete(at: 2)
            $0.text?.set(text)
            XCTAssertEqual("\($0.text.get()!)", "abd")
        })
        XCTAssertEqual("\(s1.content.text!)", "abd")
    }

    // should accept a string as initial value
    func testTextWithInitialValue1() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        let s1 = Document(Scheme(text: Text("init")))
        XCTAssertEqual(s1.content.text.count, 4)
        XCTAssertEqual(s1.content.text[0], "i")
        XCTAssertEqual(s1.content.text[1], "n")
        XCTAssertEqual(s1.content.text[2], "i")
        XCTAssertEqual(s1.content.text[3], "t")
        XCTAssertEqual("\(s1.content.text)", "init")
    }

    // should accept a string literal as initial value
    func testTextWithInitialValue2() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        let s1 = Document(Scheme(text: "init"))
        XCTAssertEqual(s1.content.text.count, 4)
        XCTAssertEqual(s1.content.text[0], "i")
        XCTAssertEqual(s1.content.text[1], "n")
        XCTAssertEqual(s1.content.text[2], "i")
        XCTAssertEqual(s1.content.text[3], "t")
        XCTAssertEqual("\(s1.content.text)", "init")
    }

    // should encode the initial value as a change
    func testTextWithInitialValue3() {
        struct Scheme: Codable, Equatable {
            var text: Text
        }

        let s1 = Document(Scheme(text: "init"))
        let changes = s1.allChanges()
        XCTAssertEqual(changes.count, 1)
        let s2 = Document<Scheme>(changes: changes)
        XCTAssertEqual(s2.content.text.count, 4)
        XCTAssertEqual(s2.content.text[0], "i")
        XCTAssertEqual(s2.content.text[1], "n")
        XCTAssertEqual(s2.content.text[2], "i")
        XCTAssertEqual(s2.content.text[3], "t")
        XCTAssertEqual("\(s2.content.text)", "init")
    }

    // should allow immediate access to the value
    func testTextWithInitialValue4() {
        struct Scheme: Codable, Equatable {
            var text: Text?
        }

        var s1 = Document(Scheme(text: nil))
        s1.change { doc in
            let text = Text("init")
            XCTAssertEqual(text.count, 4)
            XCTAssertEqual(text[0], "i")
            XCTAssertEqual("\(text)", "init")
            doc.text?.set(text)
            XCTAssertEqual(doc.text?.get().count, 4)
            XCTAssertEqual(doc.text?.get()[0], "i")
            XCTAssertEqual("\(doc.text.get()!)", "init")
        }
    }

    // should allow pre-assignment modification of the initial value
    func testTextWithInitialValue5() {
        struct Scheme: Codable, Equatable {
            var text: Text?
        }

        var s1 = Document(Scheme(text: nil))
        s1.change { doc in
            var text = Text("init")
            text.delete(at: 3)
            XCTAssertEqual("\(text)", "ini")
            doc.text?.set(text)
            XCTAssertEqual("\(doc.text.get()!)", "ini")
        }
        XCTAssertEqual("\(s1.content.text!)", "ini")
    }

    // should allow pre-assignment modification of the initial value
    func testTextWithInitialValue6() {
        struct Scheme: Codable, Equatable {
            var text: Text?
        }

        var s1 = Document(Scheme(text: nil))
        s1.change { doc in
            let text = Text("init")
            doc.text?.set(text)
            doc.text?.delete(at: 0)
            doc.text?.insert("I", at: 0)
            XCTAssertEqual("\(doc.text.get()!)", "Init")
        }
        XCTAssertEqual("\(s1.content.text!)", "Init")
    }

}
