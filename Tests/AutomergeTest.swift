//
//  AutomergeTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 25.05.20.
//

import Foundation
import XCTest
import Automerge

// /test/test.js
class AutomergeTest: XCTestCase {

    // should initially be an empty map
    func testInit1() {
        struct Scheme: Codable, Equatable {}
        let document = Document(Scheme())
        XCTAssertEqual(document.content, Scheme())
    }

    // should allow instantiating from an existing object
    func testInit2() {
        struct Scheme: Codable, Equatable {
            struct Birds: Codable, Equatable {
                let wrens: Int; let magpies: Int
            }
            let birds: Birds
        }
        let initialState = Scheme(birds: .init(wrens: 3, magpies: 4))
        let document = Document(initialState)
        XCTAssertEqual(document.content, initialState)
    }

    // should allow passing an actorId when instantiating from an existing object
    func testInit4() {
        struct Scheme: Codable, Equatable {}
        let actor = ActorId()
        let document = Document(Scheme(), options: .init(actorId: actor))
        XCTAssertEqual(document.actor, actor)
    }

    // should not enable undo after init
    func testInit5() {
        struct Scheme: Codable, Equatable {}
        let document = Document(Scheme())
        XCTAssertFalse(document.canUndo)
    }

    // should not mutate objects
    func testSerialUse1() {
        struct Scheme: Codable, Equatable { var foo: String?}
        let s1 = Document(Scheme(foo: nil))
        var s2 = s1
        s2.change { $0[\.foo, "foo"] = "bar" }
        XCTAssertEqual(s1.content.foo, nil)
        XCTAssertEqual(s2.content.foo, "bar")
    }

    //    // should not register any conflicts on repeated assignment
    //    func testSerialUse2() {
    //        struct Scheme: Codable, Equatable { var foo: String?}
    //        var s1 = Document(Scheme(foo: nil))
    //        s1.change { $0[\.foo, "foo"] = "bar" }
    //        XCTAssertNil(s1.conflicts(for: \.foo!, "foo"), nil)
    //        s1.change { $0[\.foo, "foo"] = "bar" }
    //        XCTAssertEqual(s1.conflicts(for: \.foo, "foo"), nil)
    //        s1.change { $0[\.foo, "foo"] = "bar" }
    //        XCTAssertEqual(s1.conflicts(for: \.foo, "foo"), nil)
    //
    //    }

    // should group several changes
    func testSerialUseChanges1() {
        struct Scheme: Codable, Equatable { var first: String?; var second: String?}
        let s1 = Document(Scheme(first: nil, second: nil))
        var s2 = s1
        s2.change { doc in
            doc[\.first, "first"] = "one"
            XCTAssertEqual(doc[\.first, "first"], "one")
            doc[\.second, "second"] = "two"
            XCTAssertEqual(doc.value, Scheme(first: "one", second: "two"))
        }

        XCTAssertEqual(s1.content, Scheme(first: nil, second: nil))
        XCTAssertEqual(s2.content, Scheme(first: "one", second: "two"))
    }

    // should allow repeated reading and writing of values
    func testSerialUseChanges2() {
        struct Scheme: Codable, Equatable { var value: String? }
        let s1 = Document(Scheme(value: nil))
        var s2 = s1
        s2.change { doc in
            doc[\.value, "value"] = "a"
            XCTAssertEqual(doc[\.value, "value"], "a")
            doc[\.value, "value"] = "b"
            doc[\.value, "value"] = "c"
            XCTAssertEqual(doc.value.value, "c")
        }

        XCTAssertEqual(s1.content, Scheme(value: nil))
        XCTAssertEqual(s2.content, Scheme(value: "c"))
    }

    //    // should not record conflicts when writing the same field several times within one change
    //    func testSerialUseChanges3() {
    //        struct Scheme: Codable, Equatable { var value: String? }
    //        let s1 = Document(Scheme(value: nil))
    //        var s2 = s1
    //        s2.change { doc in
    //            doc[\.value, "value"] = "a"
    //            doc[\.value, "value"] = "b"
    //            doc[\.value, "value"] = "c"
    //        }
    //
    //        XCTAssertEqual(s2.content, Scheme(value: "c"))
    //        //Check Conflicts
    //    }

    // should return the unchanged state object if nothing changed
    func testSerialUseChanges4() {
        struct Scheme: Codable, Equatable { var value: String? }
        var s1 = Document(Scheme(value: nil))
        s1.change { _ in }
        XCTAssertEqual(s1.content, Scheme(value: nil))
    }

    // sshould support Date objects in maps
    func testSerialUseChanges5() {
        struct Scheme: Codable, Equatable { var now: Date? }
        let now = Date(timeIntervalSince1970: 0)
        var s1 = Document(Scheme(now: nil))
        s1.change { $0[\.now, "now"] = now }

        let s2 = Document<Scheme>(changes: s1.allChanges())
        XCTAssertEqual(s2.content.now, now)
    }

    // should support Date objects in lists
    func testSerialUseChanges6() {
        struct Scheme: Codable, Equatable { var list: [Date]? }
        let now = Date(timeIntervalSince1970: 0)
        var s1 = Document(Scheme(list: nil))
        s1.change { $0[\.list, "list"] = [now] }

        let s2 = Document<Scheme>(changes: s1.allChanges())
        XCTAssertEqual(s2.content.list, [now])
    }

    // should handle single-property assignment
    func testSerialUseRootObject1() {
        struct Scheme: Codable, Equatable { var foo: String?; var zip: String? }
        var s1 = Document(Scheme(foo: nil, zip: nil))
        s1.change { $0[\.foo, "foo"] = "bar" }
        s1.change { $0[\.zip, "zip"] = "zap" }

        XCTAssertEqual(s1.content.foo, "bar")
        XCTAssertEqual(s1.content.zip, "zap")
        XCTAssertEqual(s1.content, Scheme(foo: "bar", zip: "zap"))
    }
    // should allow floating-point values
    func testSerialUseRootObject2() {
        struct Scheme: Codable, Equatable { var number: Double?; }
        var s1 = Document(Scheme(number: nil))
        s1.change { $0[\.number, "number"] = 1589032171.1 }

        XCTAssertEqual(s1.content.number, 1589032171.1)
    }

    // should handle multi-property assignment
    func testSerialUseRootObject3() {
        struct Scheme: Codable, Equatable { var foo: String?; var zip: String? }
        var s1 = Document(Scheme(foo: nil, zip: nil))
        s1.change(options: .init(message: "multi-assign"), execute: {
            $0[\.foo, "foo"] = "bar"
            $0[\.zip, "zip"] = "zap"
        })

        XCTAssertEqual(s1.content.foo, "bar")
        XCTAssertEqual(s1.content.zip, "zap")
        XCTAssertEqual(s1.content, Scheme(foo: "bar", zip: "zap"))
    }

    // should handle root property deletion
    func testSerialUseRootObject4() {
        struct Scheme: Codable, Equatable { var foo: String?; var zip: String? }
        var s1 = Document(Scheme(foo: nil, zip: nil))
        s1.change(options: .init(message: "set foo"), execute: {
            $0[\.foo, "foo"] = "bar"
            $0[\.zip, "zip"] = nil
        })
        s1.change(options: .init(message: "del foo"), execute: {
            $0[\.foo, "foo"] = nil
        })

        XCTAssertEqual(s1.content.foo, nil)
        XCTAssertEqual(s1.content.zip, nil)
        XCTAssertEqual(s1.content, Scheme(foo: nil, zip: nil))
    }

    // should assign an objectId to nested maps
    func testSerialUseNestedMaps1() {
        struct Scheme: Codable, Equatable {
            struct Nested: Codable, Equatable {}
            var nested: Nested?
        }
        var s1 = Document(Scheme(nested: nil))
        s1.change { $0[\.nested, "nested"] = .init() }
        #warning("assert.strictEqual(OPID_PATTERN.test(Automerge.getObjectId(s1.nested)), true)")
        XCTAssertNotEqual(s1.getObjectId(\.nested, "nested"), "00000000-0000-0000-0000-000000000000")
    }

    // should handle assignment of a nested property
    func testSerialUseNestedMaps2() {
        struct Scheme: Codable, Equatable {
            struct Nested: Codable, Equatable { var foo: String?; var one: Int? }
            var nested: Nested?
        }
        var s1 = Document(Scheme(nested: nil))
        s1.change {
            $0[\.nested, "nested"] = .init(foo: nil)
            $0[\.nested!.foo, "nested.foo"] = "bar"
        }
        s1.change {
            $0[\.nested!.one, "nested.one"] = 1
        }
        XCTAssertEqual(s1.content, Scheme(nested: .init(foo: "bar", one: 1)))
        XCTAssertEqual(s1.content.nested, .init(foo: "bar", one: 1))
        XCTAssertEqual(s1.content.nested?.foo, "bar")
        XCTAssertEqual(s1.content.nested?.one, 1)
    }

    // should handle assignment of an object
    func testSerialUseNestedMaps3() {
        struct Scheme: Codable, Equatable {
            struct Style: Codable, Equatable { let bold: Bool; let fontSize: Int }
            var style: Style?
        }
        var s1 = Document(Scheme(style: nil))
        s1.change {
            $0[\.style, "style"] = .init(bold: false, fontSize: 12)
        }
        XCTAssertEqual(s1.content, Scheme(style: .init(bold: false, fontSize: 12)))
        XCTAssertEqual(s1.content.style, .init(bold: false, fontSize: 12))
        XCTAssertEqual(s1.content.style?.bold, false)
        XCTAssertEqual(s1.content.style?.fontSize, 12)
    }

    // should handle assignment of multiple nested properties
    func testSerialUseNestedMaps4() {
        struct Scheme: Codable, Equatable {
            struct Style: Codable, Equatable { let bold: Bool; let fontSize: Int; let typeface: String? }
            var style: Style?
        }
        var s1 = Document(Scheme(style: nil))
        s1.change {
            $0[\.style, "style"] = .init(bold: false, fontSize: 12, typeface: nil)
            $0[\.style, "style"] = .init(bold: true, fontSize: 14, typeface: "Optima")
        }
        XCTAssertEqual(s1.content, Scheme(style: .init(bold: true, fontSize: 14, typeface: "Optima")))
        XCTAssertEqual(s1.content.style, .init(bold: true, fontSize: 14, typeface: "Optima"))
        XCTAssertEqual(s1.content.style?.bold, true)
        XCTAssertEqual(s1.content.style?.fontSize, 14)
        XCTAssertEqual(s1.content.style?.typeface, "Optima")
    }

    // should handle arbitrary-depth nesting
    func testSerialUseNestedMaps5() {
        struct A: Codable, Equatable { var b: B }
        struct B: Codable, Equatable { var c: C }
        struct C: Codable, Equatable { var d: D }
        struct D: Codable, Equatable { var e: E }
        struct E: Codable, Equatable { var f: F }
        struct F: Codable, Equatable { var g: String; var i: String? }
        struct Scheme: Codable, Equatable {
            var a: A
        }
        var s1 = Document(Scheme(a: A(b: B(c: C(d: D(e: E(f: F(g: "h", i: nil))))))))
        s1.change {
            $0[\.a.b.c.d.e.f.i, "a.b.c.d.e.f.i"] = "j"
        }
        XCTAssertEqual(s1.content, Scheme(a: A(b: B(c: C(d: D(e: E(f: F(g: "h", i: "j"))))))))
        XCTAssertEqual(s1.content.a.b.c.d.e.f.g, "h")
        XCTAssertEqual(s1.content.a.b.c.d.e.f.i, "j")
    }

    // should allow an old object to be replaced with a new one
    func testSerialUseNestedMaps6() {
        struct Scheme: Codable, Equatable {
            struct Pet: Codable, Equatable { let species: String; let legs: Int?; let breed: String?; let colors: [String: Bool]?; let variety: String? }
            var myPet: Pet?
        }
        var s1 = Document(Scheme(myPet: nil))
        s1.change {
            $0[\.myPet, "myPet"] = .init(species: "dog", legs: 4, breed: "dachshund", colors: nil, variety: nil)
        }
        var s2 = s1
        s2.change {
            $0[\.myPet, "myPet"] = .init(species: "koi", legs: nil, breed: nil, colors: ["red": true, "white": true, "black": false], variety: "紅白")
        }
        XCTAssertEqual(s1.content, Scheme(myPet: .init(species: "dog", legs: 4, breed: "dachshund", colors: nil, variety: nil)))
        XCTAssertEqual(s1.content.myPet?.breed, "dachshund")
        XCTAssertEqual(s2.content, Scheme(myPet: .init(species: "koi", legs: nil, breed: nil, colors: ["red": true, "white": true, "black": false], variety: "紅白")))
        XCTAssertEqual(s2.content.myPet?.breed, nil)
        XCTAssertEqual(s2.content.myPet?.variety, "紅白")
    }

    // should handle deletion of properties within a map
    func testSerialUseNestedMaps7() {
        struct Scheme: Codable, Equatable {
            struct Style: Codable, Equatable { var bold: Bool?; let fontSize: Int; let typeface: String? }
            var style: Style?
        }
        var s1 = Document(Scheme(style: nil))
        s1.change { $0[\.style, "style"] = .init(bold: false, fontSize: 12, typeface: "Optima") }
        s1.change { $0[\.style!.bold, "style.bold"] = nil }
        XCTAssertEqual(s1.content.style, .init(bold: nil, fontSize: 12, typeface: "Optima"))
        XCTAssertEqual(s1.content.style?.bold, nil)
    }

    // should handle deletion of references to a map
    func testSerialUseNestedMaps8() {
        struct Scheme: Codable, Equatable {
            struct Style: Codable, Equatable { var bold: Bool?; let fontSize: Int; let typeface: String? }
            var style: Style?
            let title: String
        }
        var s1 = Document(Scheme(style: nil, title: "Hello"))
        s1.change { $0[\.style, "style"] = .init(bold: false, fontSize: 12, typeface: "Optima") }
        s1.change { $0[\.style, "style"] = nil }
        XCTAssertEqual(s1.content.style, nil)
        XCTAssertEqual(s1.content, Scheme(style: nil, title: "Hello"))
    }

    // should allow elements to be inserted
    func testSerialUseLists1() {
        struct Scheme: Codable, Equatable {
            var noodles: [String]
        }
        var s1 = Document(Scheme(noodles: []))
        s1.change { $0[\.noodles, "noodles"].insert(contentsOf: ["udon", "soba"], at: 0) }
        s1.change { $0[\.noodles, "noodles"].insert("ramen", at: 1) }
        XCTAssertEqual(s1.content.noodles, ["udon", "ramen", "soba"])
        XCTAssertEqual(s1.content.noodles[0], "udon")
        XCTAssertEqual(s1.content.noodles[1], "ramen")
        XCTAssertEqual(s1.content.noodles[2], "soba")
        XCTAssertEqual(s1.content.noodles.count, 3)
    }

    // should handle assignment of a list literal
    func testSerialUseLists2() {
        struct Scheme: Codable, Equatable {
            var noodles: [String]
        }
        var s1 = Document(Scheme(noodles: []))
        s1.change { $0[\.noodles, "noodles"] = ["udon", "ramen", "soba"] }
        XCTAssertEqual(s1.content, Scheme(noodles: ["udon", "ramen", "soba"]))
        XCTAssertEqual(s1.content.noodles, ["udon", "ramen", "soba"])
        XCTAssertEqual(s1.content.noodles[0], "udon")
        XCTAssertEqual(s1.content.noodles[1], "ramen")
        XCTAssertEqual(s1.content.noodles[2], "soba")
        XCTAssertEqual(s1.content.noodles.count, 3)
    }

    // should handle deletion of list elements
    func testSerialUseLists3() {
        struct Scheme: Codable, Equatable {
            var noodles: [String]
        }
        var s1 = Document(Scheme(noodles:["udon", "ramen", "soba"]))
        s1.change { $0[\.noodles, "noodles"].remove(at: 1) }
        XCTAssertEqual(s1.content, Scheme(noodles: ["udon", "soba"]))
        XCTAssertEqual(s1.content.noodles, ["udon", "soba"])
        XCTAssertEqual(s1.content.noodles[0], "udon")
        XCTAssertEqual(s1.content.noodles[1], "soba")
        XCTAssertEqual(s1.content.noodles.count, 2)
    }

    // should handle assignment of individual list indexes
    func testSerialUseLists4() {
        struct Scheme: Codable, Equatable {
            var japaneseFood: [String]
        }
        var s1 = Document(Scheme(japaneseFood: ["udon", "ramen", "soba"]))
        s1.change { $0[\.japaneseFood[1], "japaneseFood[1]"] = "sushi" }
        XCTAssertEqual(s1.content, Scheme(japaneseFood: ["udon", "sushi", "soba"]))
        XCTAssertEqual(s1.content.japaneseFood, ["udon", "sushi", "soba"])
        XCTAssertEqual(s1.content.japaneseFood[0], "udon")
        XCTAssertEqual(s1.content.japaneseFood[1], "sushi")
        XCTAssertEqual(s1.content.japaneseFood[2], "soba")
        XCTAssertEqual(s1.content.japaneseFood.count, 3)
    }

    // should handle assignment of individual list indexes
    func testSerialUseLists5() {
        struct Scheme: Codable, Equatable {
            var japaneseFood: [String]
        }
        var s1 = Document(Scheme(japaneseFood: ["udon", "ramen", "soba"]))
        s1.change {
            $0[\.japaneseFood[0], "japaneseFood[0]"] = "うどん"
            $0[\.japaneseFood[2], "japaneseFood[2]"] = "そば"
        }
        XCTAssertEqual(s1.content, Scheme(japaneseFood: ["うどん", "ramen", "そば"]))
        XCTAssertEqual(s1.content.japaneseFood, ["うどん", "ramen", "そば"])
        XCTAssertEqual(s1.content.japaneseFood[0], "うどん")
        XCTAssertEqual(s1.content.japaneseFood[1], "ramen")
        XCTAssertEqual(s1.content.japaneseFood[2], "そば")
        XCTAssertEqual(s1.content.japaneseFood.count, 3)
    }

    // should handle nested objects
    func testSerialUseLists6() {
        struct Noodle: Codable, Equatable {
            enum TypeNoodle: String, Codable { case ramen, udon }
            let type: TypeNoodle
            var dishes: [String]
        }
        struct Scheme: Codable, Equatable {
            var noodles: [Noodle]
        }
        var s1 = Document(Scheme(noodles: [.init(type: .ramen, dishes: ["tonkotsu", "shoyu"])]))
        s1.change { $0[\.noodles, "noodles"].append(.init(type: .udon, dishes: ["tempura udon"])) }
        s1.change { $0[\.noodles[0].dishes, "noodles[0].dishes"].append("miso") }
        XCTAssertEqual(s1.content, Scheme(noodles: [.init(type: .ramen, dishes: ["tonkotsu", "shoyu", "miso"]), .init(type: .udon, dishes: ["tempura udon"])]))
        XCTAssertEqual(s1.content.noodles[0], .init(type: .ramen, dishes: ["tonkotsu", "shoyu", "miso"]))
        XCTAssertEqual(s1.content.noodles[1], .init(type: .udon, dishes: ["tempura udon"]))
    }

    // should handle assignment of individual list indexes
    func testSerialUseLists7() {
        struct Scheme: Codable, Equatable {
            var noodles: [String]?
            var japaneseFood: [String]?
        }
        var s1 = Document(Scheme(noodles: ["udon", "soba", "ramen"], japaneseFood: nil))
        s1.change {
            $0[\.japaneseFood, "japaneseFood"] = $0[\.noodles, "noodles"]
            $0[\.noodles, "noodles"] = ["wonton", "pho"]
        }
        XCTAssertEqual(s1.content, Scheme(noodles: ["wonton", "pho"], japaneseFood: ["udon", "soba", "ramen"]))
        XCTAssertEqual(s1.content.noodles, ["wonton", "pho"])
        XCTAssertEqual(s1.content.noodles?[0], "wonton")
        XCTAssertEqual(s1.content.noodles?[1], "pho")
        XCTAssertEqual(s1.content.noodles?.count, 2)
    }

    // should allow list creation and assignment in the same change callback
    func testSerialUseLists8() {
        struct Scheme: Codable, Equatable {
            var letters: [String]
        }
        var s1 = Document(Scheme(letters: []))
        s1.change {
            $0[\.letters, "letters"] = ["a", "b", "c"]
            $0[\.letters[1], "letters[1]"] = "d"
        }
        XCTAssertEqual(s1.content, Scheme(letters: ["a", "d", "c"]))
        XCTAssertEqual(s1.content.letters[1], "d")
    }

    // should allow adding and removing list elements in the same change callback
    func testSerialUseLists9() {
        struct Scheme: Codable, Equatable {
            var noodles: [String]
        }
        var s1 = Document(Scheme(noodles: []))
        s1.change {
            $0[\.noodles, "noodles"].append("udon")
            $0[\.noodles, "noodles"].remove(at: 0)
        }
        XCTAssertEqual(s1.content, Scheme(noodles: []))
        // do the add-remove cycle twice, test for #151 (https://github.com/automerge/automerge/issues/151)
        s1.change {
            $0[\.noodles, "noodles"].append("soba")
            $0[\.noodles, "noodles"].remove(at: 0)
        }
        XCTAssertEqual(s1.content, Scheme(noodles: []))
    }

    // should allow adding and removing list elements in the same change callback
    func testSerialUseLists10() {
        struct Scheme: Codable, Equatable {
            var maze: [[[[[[[[String]]]]]]]]
        }
        var s1 = Document(Scheme(maze: [[[[[[[["noodles"]]]]]]]]))
        s1.change {
            $0[\.maze[0][0][0][0][0][0][0], "maze[0][0][0][0][0][0][0]"].append("found")
        }
        XCTAssertEqual(s1.content, Scheme(maze: [[[[[[[["noodles", "found"]]]]]]]]))
        XCTAssertEqual(s1.content.maze[0][0][0][0][0][0][0][1], "found")
    }

    func testSerialUseCounter1() {
        struct Scheme: Codable, Equatable {
            var counter: Counter?
        }
        var s1 = Document(Scheme(counter: nil))
        s1.change { $0[\.counter, "counter"] = 1 }
        s1.change { $0[\.counter, "counter"]?.increment(2) }

        XCTAssertEqual(s1.content, Scheme(counter: Counter(integerLiteral: 3)))
    }

    func testSerialUseCounter2() {
        struct Scheme: Codable, Equatable {
            var counter: Counter?
        }
        let s1 = Document(Scheme(counter: 0))
        var s2 = s1
        s2.change {
            $0[\.counter, "counter"]?.increment(2)
            $0[\.counter, "counter"]?.decrement()
            $0[\.counter, "counter"]?.increment(3)
        }

        XCTAssertEqual(s1.content, Scheme(counter: 0))
        XCTAssertEqual(s2.content, Scheme(counter: 4))
    }

}
