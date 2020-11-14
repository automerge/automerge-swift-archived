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
        let actor = Actor()
        let document = Document(Scheme(), actor: actor)
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
        s2.change { $0.foo?.set("bar") }
        XCTAssertEqual(s1.content.foo, nil)
        XCTAssertEqual(s2.content.foo, "bar")
    }

    // should not register any conflicts on repeated assignment
    func testSerialUse2() {
        struct Scheme: Codable, Equatable { var foo: String?}
        var s1 = Document(Scheme(foo: nil))
        s1.change { $0.foo?.set("bar") }
        XCTAssertNil(s1.rootProxy().conflicts(dynamicMember: \.foo))
        s1.change { $0.foo?.set("bar") }
        XCTAssertNil(s1.rootProxy().conflicts(dynamicMember: \.foo))
        s1.change { $0.foo?.set("bar") }
        XCTAssertNil(s1.rootProxy().conflicts(dynamicMember: \.foo))
    }

    // should group several changes
    func testSerialUseChanges1() {
        struct Scheme: Codable, Equatable { let first: String?; let second: String? }
        let s1 = Document(Scheme(first: nil, second: nil))
        var s2 = s1
        s2.change { doc in
            doc.first.set("one")
            XCTAssertEqual(doc.first.get(), "one")
            doc.second.set("two")
            XCTAssertEqual(doc.get(), Scheme(first: "one", second: "two"))
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
            doc.value.set("a")
            XCTAssertEqual(doc.value.get(), "a")
            doc.value.set("b")
            doc.value.set("c")
            XCTAssertEqual(doc.value.get(), "c")
        }

        XCTAssertEqual(s1.content, Scheme(value: nil))
        XCTAssertEqual(s2.content, Scheme(value: "c"))
    }

    // should not record conflicts when writing the same field several times within one change
    func testSerialUseChanges3() {
        struct Scheme: Codable, Equatable { var value: String? }
        let s1 = Document(Scheme(value: nil))
        var s2 = s1
        s2.change { doc in
            doc.value.set("a")
            doc.value.set("b")
            doc.value.set("c")
        }

        XCTAssertEqual(s2.content, Scheme(value: "c"))
        XCTAssertNil(s1.rootProxy().conflicts(dynamicMember: \.value))
    }

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
        s1.change { $0.now.set(now) }

        let s2 = Document<Scheme>(changes: s1.allChanges())
        XCTAssertEqual(s2.content.now, now)
    }

    // should support Date objects in lists
    func testSerialUseChanges6() {
        struct Scheme: Codable, Equatable { var list: [Date]? }
        let now = Date(timeIntervalSince1970: 0)
        var s1 = Document(Scheme(list: nil))
        s1.change { $0.list.set([now]) }

        let s2 = Document<Scheme>(changes: s1.allChanges())
        XCTAssertEqual(s2.content.list, [now])
    }

    // should handle single-property assignment
    func testSerialUseRootObject1() {
        struct Scheme: Codable, Equatable { var foo: String?; var zip: String? }
        var s1 = Document(Scheme(foo: nil, zip: nil))
        s1.change { $0.foo.set("bar") }
        s1.change { $0.zip.set("zap") }

        XCTAssertEqual(s1.content.foo, "bar")
        XCTAssertEqual(s1.content.zip, "zap")
        XCTAssertEqual(s1.content, Scheme(foo: "bar", zip: "zap"))
    }
    // should allow floating-point values
    func testSerialUseRootObject2() {
        struct Scheme: Codable, Equatable { var number: Double?; }
        var s1 = Document(Scheme(number: nil))
        s1.change { $0.number.set(1589032171.1) }

        XCTAssertEqual(s1.content.number, 1589032171.1)
    }

    // should handle multi-property assignment
    func testSerialUseRootObject3() {
        struct Scheme: Codable, Equatable { var foo: String?; var zip: String? }
        var s1 = Document(Scheme(foo: nil, zip: nil))
        s1.change(message: "multi-assign") {
            $0.foo.set("bar")
            $0.zip.set("zap")
        }

        XCTAssertEqual(s1.content.foo, "bar")
        XCTAssertEqual(s1.content.zip, "zap")
        XCTAssertEqual(s1.content, Scheme(foo: "bar", zip: "zap"))
    }

    // should handle root property deletion
    func testSerialUseRootObject4() {
        struct Scheme: Codable, Equatable { var foo: String?; var zip: String? }
        var s1 = Document(Scheme(foo: nil, zip: nil))
        s1.change(message: "set foo", {
            $0.foo.set("bar")
            $0.zip.set(nil)
        })
         s1.change(message: "del foo", {
            $0.foo.set(nil)
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
        s1.change { $0.nested.set(.init()) }
        #warning("assert.strictEqual(OPID_PATTERN.test(Automerge.getObjectId(s1.nested)), true)")
        XCTAssertNotEqual(s1.rootProxy().nested?.objectId, "00000000-0000-0000-0000-000000000000")
        XCTAssertEqual(s1.content, Scheme(nested: .init()))
    }

    // should handle assignment of a nested property
    func testSerialUseNestedMaps2() {
        struct Scheme: Codable, Equatable {
            struct Nested: Codable, Equatable { var foo: String?; var one: Int? }
            var nested: Nested?
        }
        var s1 = Document(Scheme(nested: nil))
        s1.change {
            $0.nested.set(.init(foo: nil, one: nil))
            $0.nested?.foo.set("bar")
        }
        s1.change {
            $0.nested?.one?.set(1)
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
            $0.style?.set(.init(bold: false, fontSize: 12))
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
            $0.style?.set(.init(bold: false, fontSize: 12, typeface: nil))
            $0.style?.set(.init(bold: true, fontSize: 14, typeface: "Optima"))
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
            $0.a.b.c.d.e.f.i?.set("j")
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
            $0.myPet?.set(.init(species: "dog", legs: 4, breed: "dachshund", colors: nil, variety: nil))
        }
        var s2 = s1
        s2.change {
            $0.myPet?.set(.init(species: "koi", legs: nil, breed: nil, colors: ["red": true, "white": true, "black": false], variety: "紅白"))
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
        s1.change { $0.style?.set(.init(bold: false, fontSize: 12, typeface: "Optima")) }
        s1.change { $0.style?.bold.set(nil) }
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
        s1.change { $0.style?.set(.init(bold: false, fontSize: 12, typeface: "Optima")) }
        s1.change { $0.style.set(nil) }
        XCTAssertEqual(s1.content.style, nil)
        XCTAssertEqual(s1.content, Scheme(style: nil, title: "Hello"))
    }

    // should allow elements to be inserted
    func testSerialUseLists1() {
        struct Scheme: Codable, Equatable {
            var noodles: [String]
        }
        var s1 = Document(Scheme(noodles: []))
        s1.change { $0.noodles.insert(contentsOf: ["udon", "soba"], at: 0) }
        s1.change { $0.noodles.insert("ramen", at: 1) }
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
        s1.change { $0.noodles.set(["udon", "ramen", "soba"]) }
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
        s1.change {
            $0.noodles.remove(at: 1)
        }
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
        s1.change { $0.japaneseFood[1].set("sushi") }
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
            $0.japaneseFood[0].set("うどん")
            $0.japaneseFood[2].set("そば")
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
            let dishes: [String]
        }
        struct Scheme: Codable, Equatable {
            let noodles: [Noodle]
        }
        var s1 = Document(Scheme(noodles: [.init(type: .ramen, dishes: ["tonkotsu", "shoyu"])]))
        s1.change {
            $0.noodles.append(.init(type: .udon, dishes: ["tempura udon"]))
        }
        s1.change {
            $0.noodles[0].dishes.append("miso")
        }
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
            $0.japaneseFood.set($0.noodles?.get())
            $0.noodles?.set(["wonton", "pho"])
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
            $0.letters.set(["a", "b", "c"])
            $0.letters[1].set("d")
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
            $0.noodles.append("udon")
            $0.noodles.remove(at: 0)
        }
        XCTAssertEqual(s1.content, Scheme(noodles: []))
        // do the add-remove cycle twice, test for #151 (https://github.com/automerge/automerge/issues/151)
        s1.change {
            $0.noodles.append("soba")
            $0.noodles.remove(at: 0)
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
            $0.maze[0][0][0][0][0][0][0].append("found")
        }
        XCTAssertEqual(s1.content, Scheme(maze: [[[[[[[["noodles", "found"]]]]]]]]))
        XCTAssertEqual(s1.content.maze[0][0][0][0][0][0][0][1], "found")
    }

    func testSerialUseCounter1() {
        struct Scheme: Codable, Equatable {
            var counter: Counter?
        }
        var s1 = Document(Scheme(counter: nil))
        s1.change { $0.counter?.set(1) }
        s1.change { $0.counter?.increment(2) }

        XCTAssertEqual(s1.content, Scheme(counter: Counter(integerLiteral: 3)))
    }

    func testSerialUseCounter2() {
        struct Scheme: Codable, Equatable {
            var counter: Counter?
        }
        let s1 = Document(Scheme(counter: 0))
        var s2 = s1
        s2.change {
            $0.counter?.increment(2)
            $0.counter?.decrement()
            $0.counter?.increment(3)
        }

        XCTAssertEqual(s1.content, Scheme(counter: 0))
        XCTAssertEqual(s2.content, Scheme(counter: 4))
    }

    // should merge concurrent updates of different properties
    func testConcurrentUse1() {
        struct Scheme: Codable, Equatable {
            var foo: String?; var hello: String?
        }
        let s1 = Document(Scheme(foo: "bar", hello: nil))
        let s2 = Document(Scheme(foo: nil, hello: "world"))
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s3.content.foo, "bar")
        XCTAssertEqual(s3.content.hello, "world")
        XCTAssertEqual(s3.content, Scheme(foo: "bar", hello: "world"))
        XCTAssertNil(s3.rootProxy().conflicts(dynamicMember: \.foo))
        XCTAssertNil(s3.rootProxy().conflicts(dynamicMember: \.hello))
    }

    // should add concurrent increments of the same property
    func testConcurrentUse2() {
        struct Scheme: Codable, Equatable {
            var counter: Counter?
        }
        var s1 = Document(Scheme(counter: 0))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change { $0.counter?.increment() }
        s2.change { $0.counter?.increment(2) }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s1.content.counter?.value, 1)
        XCTAssertEqual(s2.content.counter?.value, 2)
        XCTAssertEqual(s3.content.counter?.value, 3)
        XCTAssertNil(s3.rootProxy().conflicts(dynamicMember: \.counter))
    }

    // should add increments only to the values they precede
    func testConcurrentUse3() {
        struct Scheme: Codable, Equatable {
            var counter: Counter?
        }
        var s1 = Document(Scheme(counter: 0))
        s1.change { $0.counter?.increment() }
        var s2 = Document(Scheme(counter: 100))
        s2.change { $0.counter?.increment(3) }
        var s3 = s1
        s3.merge(s2)
        if s1.actor > s2.actor {
            XCTAssertEqual(s3.content.counter?.value, 1)
        } else {
            XCTAssertEqual(s3.content.counter?.value, 103)
        }

        XCTAssertEqual(s3.rootProxy().conflicts(dynamicMember: \.counter), [
            "1@\(s1.actor)": 1,
            "1@\(s2.actor)": 103
        ])
    }

    // should detect concurrent updates of the same field
    func testConcurrentUse4() {
        struct Scheme: Codable, Equatable {
            var field: String?
        }
        var s1 = Document(Scheme(field: "one"))
        let s2 = Document(Scheme(field: "two"))
        s1.merge(s2)
        if s1.actor > s2.actor {
            XCTAssertEqual(s1.content.field, "one")
        } else {
            XCTAssertEqual(s1.content.field, "two")
        }
        XCTAssertEqual(s1.rootProxy().conflicts(dynamicMember: \.field), [
            "1@\(s1.actor)": "one",
            "1@\(s2.actor)": "two"
        ])
    }

    // should detect concurrent updates of the same field
    func testConcurrentUse5() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["finch"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change { $0.birds[0].set("greenfinch") }
        s2.change { $0.birds[0].set("goldfinch") }
        s1.merge(s2)
        if s1.actor > s2.actor {
            XCTAssertEqual(s1.content.birds, ["greenfinch"])
        } else {
            XCTAssertEqual(s1.content.birds, ["goldfinch"])
        }
        XCTAssertEqual(s1.rootProxy().birds.conflicts(index: 0), [
            "3@\(s1.actor)": "greenfinch",
            "3@\(s2.actor)": "goldfinch"
        ])
    }

    // should handle changes within a conflicting list element
    func testConcurrentUse6() {
        struct Scheme: Codable, Equatable {
            struct Obj: Codable, Equatable {
                var map1: Bool?
                var map2: Bool?
                var key: Int?
            }
            var list: [Obj]
        }
        var s1 = Document(Scheme(list: [.init(map1: false, map2: false, key: 0)]))
        XCTAssertEqual(s1.content, Scheme(list: [.init(map1: false, map2: false, key: 0)]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change { $0.list[0].set(.init(map1: true, map2: nil, key: nil)) }
        s1.change { $0.list[0].key.set(1) }
        s2.change { $0.list[0].set(.init(map1: nil, map2: true, key: nil)) }
        s2.change { $0.list[0].key.set(2) }
        var s3 = s1
        s3.merge(s2)
        if s1.actor > s2.actor {
            XCTAssertEqual(s3.content.list, [.init(map1: true, map2: nil, key: 1)])
        } else {
            XCTAssertEqual(s3.content.list, [.init(map1: nil, map2: true, key: 2)])
        }

        XCTAssertEqual(s3.rootProxy().list.conflicts(index: 0), [
            "6@\(s1.actor)": .init(map1: true, map2: nil, key: 1),
            "6@\(s2.actor)": .init(map1: nil, map2: true, key: 2)
        ])
    }

    // should not merge concurrently assigned nested maps
    func testConcurrentUse7() {
        struct Scheme: Codable, Equatable {
            struct Config: Codable, Equatable {
                var background: String?
                var logo_url: String?
            }
            var config: Config
        }
        let s1 = Document(Scheme(config: .init(background: "blue")))
        let s2 = Document(Scheme(config: .init(logo_url: "logo.png")))
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqualOneOf(s3.content,
                            Scheme(config: .init(background: "blue")),
                            Scheme(config: .init(logo_url: "logo.png")))
        XCTAssertEqual(s3.rootProxy().conflicts(dynamicMember: \.config), [
            "1@\(s1.actor)": .init(background: "blue"),
            "1@\(s2.actor)": .init(logo_url: "logo.png")
        ])
    }

    // should clear conflicts after assigning a new value
    func testConcurrentUse8() {
        struct Scheme: Codable, Equatable {
            var field: String
        }
        let s1 = Document(Scheme(field: "one"))
        var s2 = Document(Scheme(field: "two"))
        var s3 = s1
        s3.merge(s2)
        s3.change { $0.field.set("three") }
        XCTAssertEqual(s3.content, Scheme(field: "three"))
        s2.merge(s3)
        XCTAssertEqual(s2.content, Scheme(field: "three"))
        XCTAssertNil(s2.rootProxy().conflicts(dynamicMember: \.field))
    }

    // should handle concurrent insertions at different list positions
    func testConcurrentUse9() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }
        var s1 = Document(Scheme(list: ["one", "three"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change {
            $0.list.insert("two", at: 1)
        }
        s2.change({
            $0.list.append("four")
        })
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s3.content, Scheme(list: ["one", "two", "three", "four"]))
        s2.merge(s3)
        XCTAssertNil(s2.rootProxy().conflicts(dynamicMember: \.list))
    }

    // should handle concurrent insertions at different list positions
    func testConcurrentUse10() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["parakeet"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change {
            $0.birds.append("starling")
        }
        s2.change({
            $0.birds.append("chaffinch")
        })
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqualOneOf(s3.content,
                            Scheme(birds: ["parakeet", "starling", "chaffinch"]),
                            Scheme(birds: ["parakeet", "chaffinch", "starling"]))
        s2.merge(s3)
        XCTAssertEqual(s2.content, s3.content)
    }

    //should handle concurrent assignment and deletion of a map entry
    func testConcurrentUse11() {
        // Add-wins semantics
        struct Scheme: Codable, Equatable {
            var bestBird: String?
        }
        var s1 = Document(Scheme(bestBird: "robin"))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change { $0.bestBird.set(nil) }
        s2.change { $0.bestBird.set("magpie") }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s1.content, Scheme(bestBird: nil))
        XCTAssertEqual(s2.content, Scheme(bestBird: "magpie"))
        XCTAssertEqual(s3.content, Scheme(bestBird: "magpie"))
        XCTAssertNil(s2.rootProxy().conflicts(dynamicMember: \.bestBird))
    }

    //should handle concurrent assignment and deletion of a list element
    func testConcurrentUse12() {
        // Concurrent assignment ressurects a deleted list element. Perhaps a little
        // surprising, but consistent with add-wins semantics of maps (see test above)
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["blackbird", "thrush", "goldfinch"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change { $0.birds[1].set("starling") }
        s2.change {
            $0.birds.remove(at: 1)
        }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s1.content, Scheme(birds: ["blackbird", "starling", "goldfinch"]))
        XCTAssertEqual(s2.content, Scheme(birds: ["blackbird", "goldfinch"]))
        XCTAssertEqual(s3.content, Scheme(birds: ["blackbird", "starling", "goldfinch"]))
    }

    // should handle insertion after a deleted list element
    func testConcurrentUse13() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["blackbird", "thrush", "goldfinch"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change {
            $0.birds.replaceSubrange(1...2, with: [String]())
        }
        s2.change {
            $0.birds.insert("starling", at: 2)
        }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s3.content, Scheme(birds: ["blackbird", "starling"]))
        s2.merge(s3)
        XCTAssertEqual(s2.content, Scheme(birds: ["blackbird", "starling"]))
    }

    // should handle concurrent deletion of the same element
    func testConcurrentUse14() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["albatross", "buzzard", "cormorant"])) // 1
        var s2 = Document<Scheme>(changes: s1.allChanges()) // 0
        s1.change {
            $0.birds.remove(at: 1)
        } // 2
        s2.change {
            $0.birds.remove(at: 1)
        } // 1
        var s3 = s1
        s3.merge(s2) // s3
        XCTAssertEqual(s3.content, Scheme(birds: ["albatross", "cormorant"]))
    }

    // should handle concurrent deletion of different elements
    func testConcurrentUse15() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["albatross", "buzzard", "cormorant"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change {
            $0.birds.remove(at: 0)
        }
        s2.change {
            $0.birds.remove(at: 1)
        }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s3.content, Scheme(birds: ["cormorant"]))
    }

    // should handle concurrent updates at different levels of the tree
    func testConcurrentUse16() {
        struct Scheme: Codable, Equatable {
            struct Animals: Codable, Equatable {
                struct Birds: Codable, Equatable {
                    let pink: String
                    let black: String
                    var brown: String?
                }
                var birds: Birds?
                var mammals: [String]
            }
            var animals: Animals
        }
        var s1 = Document(Scheme(animals: .init(birds: .init(pink: "flamingo", black: "starling", brown: nil), mammals: ["badger"])))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change { $0.animals.birds?.brown?.set("sparrow") }
        s2.change { $0.animals.birds.set(nil) }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s1.content, Scheme(animals: .init(birds: .init(pink: "flamingo", black: "starling", brown: "sparrow"), mammals: ["badger"])))
        XCTAssertEqual(s2.content, Scheme(animals: .init(birds: nil, mammals: ["badger"])))
        XCTAssertEqual(s3.content, Scheme(animals: .init(birds: nil, mammals: ["badger"])))
    }

    // should not interleave sequence insertions at the same position
    func testConcurrentUse17() {
        struct Scheme: Codable, Equatable {
            var wisdom: [String]
        }
        var s1 = Document(Scheme(wisdom: []))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change {
            $0.wisdom.append(contentsOf: ["to", "be", "is", "to", "do"])
        }
        s2.change {
            $0.wisdom.append(contentsOf: ["to", "do", "is", "to", "be"])
        }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqualOneOf(s3.content.wisdom,
                            ["to", "be", "is", "to", "do", "to", "do", "is", "to", "be"],
                            ["to", "do", "is", "to", "be", "to", "be", "is", "to", "do"])
        // In case you're wondering: http://quoteinvestigator.com/2013/09/16/do-be-do/
    }

    // should handle insertion by greater actor ID
    func testConcurrentUseMultipleInsertsAtTheSameListPosition1() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: []), actor: Actor(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
        var s2 = Document(Scheme(list: []), actor: Actor(actorId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
        s1.change { $0.list.set(["two"]) }
        s2.merge(s1)
        s2.change {
            $0.list.insert("one", at: 0)
        }
        XCTAssertEqual(s2.content.list, ["one", "two"])
    }

    // should handle insertion by lesser actor ID
    func testConcurrentUseMultipleInsertsAtTheSameListPosition2() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: []), actor: Actor(actorId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
        var s2 = Document(Scheme(list: []), actor: Actor(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
        s1.change { $0.list.set(["two"]) }
        s2.merge(s1)
        s2.change {
            $0.list.insert("one", at: 0)
        }
        XCTAssertEqual(s2.content.list, ["one", "two"])
    }

    // should handle insertion by lesser actor ID
    func testConcurrentUseMultipleInsertsAtTheSameListPosition3() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: []))
        s1.change { $0.list.set(["two"]) }
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change {
            $0.list.insert("one", at: 0)
        }
        XCTAssertEqual(s2.content.list, ["one", "two"])
    }

    // should make insertion order consistent with causality
    func testConcurrentUseMultipleInsertsAtTheSameListPosition4() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: ["four"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change {
            $0.list.insert("three", at: 0)
        }
        s1.merge(s2)
        s1.change {
            $0.list.insert("two", at: 0)
        }
        s2.merge(s1)
        s2.change {
            $0.list.insert("one", at: 0)
        }

        XCTAssertEqual(s2.content.list, ["one", "two", "three", "four"])
    }

    // should allow undo if there have been local changes
    func testUndo1() {
        struct Scheme: Codable, Equatable {
            var hello: String?
        }

        var s1 = Document(Scheme(hello: nil))
        XCTAssertFalse(s1.canUndo)
        s1.change { $0.hello?.set("world") }
        XCTAssertTrue(s1.canUndo)
        let s2 = Document<Scheme>(changes: s1.allChanges())
        XCTAssertFalse(s2.canUndo)
    }

    // should allow undo if there have been local changes
    func testUndo2() {
        struct Scheme: Codable, Equatable {
            var hello: String?
        }

        var s1 = Document(Scheme(hello: nil))
        s1.change { $0.hello?.set("world") }
        XCTAssertEqual(s1.content, Scheme(hello: "world"))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(hello: nil))
    }

    // should undo a field update by reverting to the previous value
    func testUndo3() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 3))
        s1.change { $0.value.set(4) }
        XCTAssertEqual(s1.content, Scheme(value: 4))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 3))
    }

    // should allow undoing multiple changes
    func testUndo4() {
        struct Scheme: Codable, Equatable {
            var value: Int?
        }

        var s1 = Document(Scheme(value: nil))
        s1.change { $0.value.set(1) }
        s1.change { $0.value.set(2) }
        s1.change { $0.value.set(3) }
        XCTAssertEqual(s1.content, Scheme(value: 3))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 2))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 1))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: nil))
        XCTAssertFalse(s1.canUndo)
    }

    // should undo only local changes
    func testUndo5() {
        struct Scheme: Codable, Equatable {
            var s1: String?
            var s2: String?
        }

        var s1 = Document(Scheme(s1: "s1.old", s2: nil))
        s1.change { $0.s1.set("s1.new") }
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change { $0.s2?.set("s2") }

        s1.merge(s2)
        XCTAssertEqual(s1.content, Scheme(s1: "s1.new", s2: "s2"))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(s1: "s1.old", s2: "s2"))
    }

    // should apply undos by growing the history
    func testUndo6() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 1))
        s1.change(message: "set 2") { $0.value.set(2) }
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.undo(message: "undo!")
        let seqs = History(document: s1).map { $0.change.seq }
        XCTAssertEqual(seqs, [1, 2, 3])
        let messages = History(document: s1).map { $0.change.message }
        XCTAssertEqual(messages, ["Initialization", "set 2", "undo!"])
        s2.merge(s1)
        XCTAssertEqual(s2.content, Scheme(value: 1))
        XCTAssertEqual(s1.content, Scheme(value: 1))
    }

    // should ignore other actors' updates to an undo-reverted field
    func testUndo7() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 1))
        s1.change { $0.value.set(2) }
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change { $0.value.set(3) }
        s1.merge(s2)
        XCTAssertEqual(s1.content, Scheme(value: 3))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 1))
    }

    // should undo object creation by removing the link
    func testUndo8() {
        struct Scheme: Codable, Equatable {
            struct Settings: Codable, Equatable {
                let background: String
                let text: String
            }
            var settings: Settings?
        }

        var s1 = Document(Scheme(settings: nil))
        s1.change { $0.settings.set(.init(background: "white", text: "black")) }
        XCTAssertEqual(s1.content, Scheme(settings: .init(background: "white", text: "black")))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(settings: nil))
    }

    // should undo primitive field deletion by setting the old value
    func testUndo9() {
        struct Scheme: Codable, Equatable {
            var k1: String?
            var k2: String?
        }

        var s1 = Document(Scheme(k1: "v1", k2: "v2"))
        s1.change { $0.k2.set(nil) }
        XCTAssertEqual(s1.content, Scheme(k1: "v1", k2: nil))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(k1: "v1", k2: "v2"))
    }

    // should undo link deletion by linking the old value
    func testUndo10() {
        struct Scheme: Codable, Equatable {
            var fish: [String]?
            var birds: [String]?
        }

        var s1 = Document(Scheme(fish: ["trout", "sea bass"], birds: nil))
        s1.change { $0.birds.set(["heron", "magpie"]) }

        var s2 = s1
        s2.change { $0.fish.set(nil) }
        XCTAssertEqual(s2.content, Scheme(fish: nil, birds: ["heron", "magpie"]))
        s2.undo()
        XCTAssertEqual(s2.content, Scheme(fish: ["trout", "sea bass"], birds: ["heron", "magpie"]))
    }

    // should undo list insertion by removing the new element
    func testUndo11() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: ["A", "B", "C"]))
        s1.change { $0.list.append("D") }
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C", "D"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C"]))
    }

    // should undo list element deletion by re-assigning the old value
    func testUndo12() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: ["A", "B", "C"]))
        s1.change { $0.list.remove(at: 1) }
        XCTAssertEqual(s1.content, Scheme(list: ["A", "C"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C"]))
    }

    // should undo counter increments
    func testUndo13() {
        struct Scheme: Codable, Equatable {
            var counter: Counter
        }

        var s1 = Document(Scheme(counter: 0))
        s1.change { $0.counter.increment() }
        XCTAssertEqual(s1.content, Scheme(counter: 1))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(counter: 0))
    }

    // should allow redo if the last change was an undo
    func testRedo1() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["peregrine falcon"]))
        s1.change { $0.birds.append("magpie") }
        XCTAssertFalse(s1.canRedo)
        s1.undo()
        XCTAssertTrue(s1.canRedo)
        s1.redo()
        XCTAssertFalse(s1.canRedo)
    }

    // should allow several undos to be matched by several redos
    func testRedo2() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: []))
        s1.change { $0.birds.append("peregrine falcon") }
        s1.change { $0.birds.append("sparrowhawk") }
        XCTAssertEqual(s1.content, Scheme(birds: ["peregrine falcon", "sparrowhawk"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(birds: ["peregrine falcon"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(birds: []))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(birds: ["peregrine falcon"]))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(birds: ["peregrine falcon", "sparrowhawk"]))
    }

    // should allow several undos to be matched by several redos
    func testRedo3() {
        struct Scheme: Codable, Equatable {
            var sparrows: Int?
            var skylarks: Int?
        }
        var s1 = Document<Scheme>(Scheme(sparrows: nil, skylarks: nil))
        s1.change { $0.sparrows?.set(1) }
        s1.change { $0.skylarks?.set(1) }
        s1.change { $0.sparrows?.set(2) }
        s1.change { $0.skylarks.set(nil) }
        let states: [Scheme] = [.init(sparrows: nil, skylarks: nil), .init(sparrows: 1, skylarks: nil), .init(sparrows: 1, skylarks: 1), .init(sparrows: 2, skylarks: 1), .init(sparrows: 2, skylarks: nil)]
        for _ in (0..<3) {
            for undo in (0...(states.count - 2)).reversed() {
                s1.undo()
                XCTAssertEqual(s1.content, states[undo])
            }
            for redo in 1..<states.count {
                s1.redo()
                XCTAssertEqual(s1.content, states[redo])
            }
        }
    }

    // should undo/redo an initial field assignment
    func testRedo4() {
        struct Scheme: Codable, Equatable {
            var hello: String?
        }
        var s1 = Document(Scheme(hello: nil))
        s1.change { $0.hello?.set("world") }
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(hello: nil))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(hello: "world"))
    }

    // should undo/redo a field update
    func testRedo5() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 3))
        s1.change { $0.value.set(4) }
        XCTAssertEqual(s1.content, Scheme(value: 4))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 3))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(value: 4))
    }

    // should undo/redo a field deletion
    func testRedo6() {
        struct Scheme: Codable, Equatable {
            var value: Int?
        }

        var s1 = Document(Scheme(value: 123))
        s1.change { $0.value.set(nil) }
        XCTAssertEqual(s1.content, Scheme(value: nil))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 123))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(value: nil))
    }

    // should undo/redo object creation and linking
    func testRedo7() {
        struct Scheme: Codable, Equatable {
            struct Settings: Codable, Equatable {
                let background: String
                let text: String
            }
            var settings: Settings?
        }

        var s1 = Document(Scheme(settings: nil))
        s1.change { $0.settings.set(.init(background: "white", text: "black")) }
        XCTAssertEqual(s1.content, Scheme(settings: .init(background: "white", text: "black")))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(settings: nil))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(settings: .init(background: "white", text: "black")))
    }

    // should undo/redo link deletion
    func testRedo8() {
        struct Scheme: Codable, Equatable {
            var fish: [String]?
            var birds: [String]?
        }

        var s1 = Document(Scheme(fish: ["trout", "sea bass"], birds: nil))
        s1.change { $0.birds.set(["heron", "magpie"]) }
        s1.change { $0.fish.set(nil) }
        XCTAssertEqual(s1.content, Scheme(fish: nil, birds: ["heron", "magpie"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(fish: ["trout", "sea bass"], birds: ["heron", "magpie"]))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(fish: nil, birds: ["heron", "magpie"]))
    }

    // should undo/redo a list element insertion
    func testRedo9() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: ["A", "B", "C"]))
        s1.change { $0.list.append("D") }
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C", "D"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C"]))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C", "D"]))
    }

    // should undo/redo a list element deletion
    func testRedo10() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: ["A", "B", "C"]))
        s1.change { $0.list.remove(at: 1) }
        XCTAssertEqual(s1.content, Scheme(list: ["A", "C"]))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(list: ["A", "B", "C"]))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(list: ["A", "C"]))
    }

    // should undo/redo counter increments
    func testRedo11() {
        struct Scheme: Codable, Equatable {
            var counter: Counter
        }

        var s1 = Document(Scheme(counter: 0))
        s1.change { $0.counter.increment() }
        XCTAssertEqual(s1.content, Scheme(counter: 1))
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(counter: 0))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(counter: 1))
    }

    // should redo assignments by other actors that precede the undo
    func testRedo12() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 1))
        s1.change({ $0.value.set(2) })
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change({ $0.value.set(3) })
        s1.merge(s2)
        s1.undo()
        XCTAssertEqual(s1.content, Scheme(value: 1))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(value: 3))
    }

    // should overwrite assignments by other actors that follow the undo
    func testRedo13() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 1))
        s1.change({ $0.value.set(2) })
        s1.undo()
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change({ $0.value.set(3) })
        s1.merge(s2)
        XCTAssertEqual(s1.content, Scheme(value: 3))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(value: 2))
    }

    // should merge with concurrent changes to other fields
    func testRedo14() {
        struct Scheme: Codable, Equatable {
            var trout: Int?
            var salmon: Int?
        }

        var s1 = Document(Scheme(trout: 2, salmon: nil))
        s1.change({ $0.trout.set(3) })
        s1.undo()
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s2.change({ $0.salmon.set(1) })
        s1.merge(s2)
        XCTAssertEqual(s1.content, Scheme(trout: 2, salmon: 1))
        s1.redo()
        XCTAssertEqual(s1.content, Scheme(trout: 3, salmon: 1))
    }

    // should apply redos by growing the history
    func testRedo15() {
        struct Scheme: Codable, Equatable {
            var value: Int
        }

        var s1 = Document(Scheme(value: 1))
        s1.change(message: "set 2") { $0.value.set(2) }
        s1.undo(message: "undo")
        s1.redo(message: "redo!")
        let history = History(document: s1)
        let seqs = history.map { $0.change.seq }
        XCTAssertEqual(seqs, [1, 2, 3, 4])
        let messages = history.map { $0.change.message }
        XCTAssertEqual(messages, ["Initialization", "set 2", "undo", "redo!"])
        XCTAssertEqual(history.count, 4)
    }

    // should save and restore an empty document
    func testSaveAndLoading1() {
        struct Scheme: Codable, Equatable { }
        let s = Document<Scheme>(data: Document(Scheme()).save())
        XCTAssertEqual(s.content, Scheme())
    }

    // should generate a new random actor ID
    func testSaveAndLoading2() {
        struct Scheme: Codable, Equatable { }
        let s1 = Document(Scheme())
        let s2 = Document<Scheme>(data:s1.save())
        XCTAssertNotEqual(s1.actor, s2.actor)
    }

    // should allow a custom actor ID to be set
    func testSaveAndLoading3() {
        struct Scheme: Codable, Equatable { }
        let s = Document<Scheme>(data: Document(Scheme()).save(), actor: Actor(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
        XCTAssertEqual(s.actor, Actor(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
    }

    // should allow a custom actor ID to be set
    func testSaveAndLoading4() {
        struct Scheme: Codable, Equatable {
            struct Todo: Codable, Equatable {
                let title: String
                let done: Bool
            }
            let todos: [Todo]
        }
        let s1 = Document(Scheme(todos: [.init(title: "water plants'", done: false)]))
        let s2 = Document<Scheme>(data: s1.save())
        XCTAssertEqual(s2.content, Scheme(todos: [.init(title: "water plants'", done: false)]))
    }

    // should reconstitute conflicts
    func testSaveAndLoading5() {
        struct Scheme: Codable, Equatable {
            let x: Int
        }
        var s1 = Document(Scheme(x: 3), actor: Actor(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
        let s2 = Document(Scheme(x: 5), actor: Actor(actorId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
        s1.merge(s2)
        let s3 = Document<Scheme>(data: s1.save())
        XCTAssertEqual(s1.content.x, 5)
        XCTAssertEqual(s3.content.x, 5)
        XCTAssertEqual(s1.rootProxy().conflicts(dynamicMember: \.x), ["1@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": 3, "1@bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb": 5])
        XCTAssertEqual(s3.rootProxy().conflicts(dynamicMember: \.x), ["1@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": 3, "1@bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb": 5])
    }

    // should allow a reloaded list to be mutated
    func testSaveAndLoading6() {
        struct Scheme: Codable, Equatable {
            var foo: [Int]
        }
        var doc = Document(Scheme(foo: []))
        doc = Document(data: doc.save())
        doc.change { $0.foo.append(1) }
        doc = Document(data: doc.save())
        XCTAssertEqual(doc.content.foo, [1])
    }

    // should make past document states accessible
    func testHistory1() {
        struct Scheme: Codable, Equatable {
            struct Config: Codable, Equatable { let background: String }
            let config: Config
            var birds: [String]
        }
        var s = Document(Scheme(config: .init(background: "blue"), birds: []))
        s.change({ $0.birds.set(["mallard"]) })
        s.change { $0.birds.insert("oystercatcher", at: 0) }
        let history = History(document: s).map { $0.snapshot }
        XCTAssertEqual(history, [
            Scheme(config: .init(background: "blue"), birds: []),
            Scheme(config: .init(background: "blue"), birds: ["mallard"]),
            Scheme(config: .init(background: "blue"), birds: ["oystercatcher", "mallard"])
        ])
    }

    // should make change messages accessible
    func testHistory2() {
        struct Scheme: Codable, Equatable {
            var books: [String]
        }
        var s = Document(Scheme(books: []))
        s.change(message: "Add Orwell") {
            $0.books.append("Nineteen Eighty-Four")
        }
        s.change(message: "Add Huxley") {
            $0.books.append("Brave New World")
        }
        let messages = History(document: s).map { $0.change.message }
        XCTAssertEqual(messages, [
            "Initialization",
            "Add Orwell",
            "Add Huxley"
        ])
    }

    // should make access fast
    func testHistory3() {
        struct Scheme: Codable, Equatable {
            var books: [String]
        }
        var s = Document(Scheme(books: []))
        s.change(message: "Add Orwell") {
            $0.books.append("Nineteen Eighty-Four")
        }
        s.change(message: "Add Huxley") {
            $0.books.append("Brave New World")
        }
        let message = History(document: s).last?.change.message
        XCTAssertEqual(message, "Add Huxley")
    }

    // should contain actor
    func testHistory4() {
        struct Scheme: Codable, Equatable {
            var books: [String]
        }
        let actor = Actor()
        var s = Document(Scheme(books: []), actor: actor)
        s.change(message: "Add Orwell") {
            $0.books.append("Nineteen Eighty-Four")
        }
        s.change(message: "Add Huxley") {
            $0.books.append("Brave New World")
        }
        let historyActor = History(document: s).last?.change.actor
        XCTAssertEqual(historyActor, actor)
    }

    // should report missing dependencies
    func testgetMissingDeps1() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        let s1 = Document(Scheme(birds: ["Chaffinch"]))
        var s2 = Document<Scheme>(data: s1.save())
        s2.change({
            $0.birds.append("Bullfinch")
        })
        let changes = s2.allChanges()
        var s3 = Document<Scheme>(changes: [changes[1]])
        XCTAssertEqual(s3.getMissingsDeps(), Change(change: changes[1]).deps)
        s3.apply(changes: [changes[0]])
        XCTAssertEqual(s3.content, Scheme(birds: ["Chaffinch", "Bullfinch"]))
        XCTAssertEqual(s3.getMissingsDeps(), [])
    }

}


