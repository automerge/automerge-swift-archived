//
//  AutomergeTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 25.05.20.
//

import Foundation
import XCTest
@testable import Automerge

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
        struct Scheme: Codable, Equatable { var first: String?; var second: String?}
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
        s1.change(options: .init(message: "multi-assign"), execute: {
            $0.foo.set("bar")
            $0.zip.set("zap")
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
            $0.foo.set("bar")
            $0.zip.set(nil)
        })
        s1.change(options: .init(message: "del foo"), execute: {
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
        s1.change({
            var abc = $0.noodles
            abc.insert(contentsOf: ["udon", "soba"], at: 0)
        })
        s1.change({
            var abc = $0.noodles
            abc.insert("ramen", at: 1)
        })
        //        s1.change { $0.noodles.insert(contentsOf: ["udon", "soba"], at: 0) }
        //        s1.change { $0.noodles.insert("ramen", at: 1) }
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
            var noodles = $0.noodles
            noodles.remove(at: 1)
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
            var dishes: [String]
        }
        struct Scheme: Codable, Equatable {
            var noodles: [Noodle]
        }
        var s1 = Document(Scheme(noodles: [.init(type: .ramen, dishes: ["tonkotsu", "shoyu"])]))
        s1.change {
            var noodles = $0.noodles
            noodles.append(.init(type: .udon, dishes: ["tempura udon"]))
        }
        s1.change {
            var dishes: Proxy<[String]> = $0.noodles[0].dishes
            dishes.append("miso")
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
            var noodle = $0.noodles
            noodle.append("udon")
            noodle.remove(at: 0)
        }
        XCTAssertEqual(s1.content, Scheme(noodles: []))
        // do the add-remove cycle twice, test for #151 (https://github.com/automerge/automerge/issues/151)
        s1.change {
            var noodle = $0.noodles
            noodle.append("soba")
            noodle.remove(at: 0)
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
            var maze: Proxy<[String]> = $0.maze[0][0][0][0][0][0][0]
            maze.append("found")
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
        XCTAssertEqual(s1.content, Scheme(list: [.init(map1: true, map2: nil, key: nil)]))
        s1.change { $0.list[0].key.set(1) }
        s2.change { $0.list[0].set(.init(map1: true, map2: nil, key: nil)) }
        s2.change { $0.list[0].key.set(2) }
        s1.merge(s2)
        if s1.actor > s2.actor {
            XCTAssertEqual(s1.content.list, [.init(map1: true, map2: nil, key: 1)])
        } else {
            XCTAssertEqual(s1.content.list, [.init(map1: nil, map2: true, key: 2)])
        }

        let proxy: Proxy<[Scheme.Obj]> = s1.rootProxy().list

        XCTAssertEqual(proxy.conflicts(index: 0), [
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
            var proxy = $0.list
            proxy.insert("two", at: 1)
        }
        s2.change({
            var proxy = $0.list
            proxy.append("four")
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
            $0.birds.set([])
            var proxy = $0.birds
            proxy.append("starling")
        }
        s2.change({
            var proxy = $0.birds
            proxy.append("chaffinch")
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
            var proxy = $0.birds
            proxy.remove(at: 1)
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
            $0.birds.replaceSubrange(1...2, with: [])
        }
        s2.change {
            var proxy = $0.birds
            proxy.insert("starling", at: 2)
        }
        var s3 = s1
        s3.merge(s2)
        XCTAssertEqual(s3.content, Scheme(birds: ["blackbird", "starling"]))
        s2.merge(s3)
        XCTAssertEqual(s2.content, Scheme(birds: ["blackbird", "starling"]))
    }

    //    // should handle concurrent deletion of the same element
    //    func testConcurrentUse14() {
    //        struct Scheme: Codable, Equatable {
    //            var birds: [String]
    //        }
    //        var s1 = Document(Scheme(birds: ["albatross", "buzzard", "cormorant"]))
    //        var s2 = Document<Scheme>(changes: s1.allChanges())
    //        s1.change {
    //            var proxy = $0.birds
    //            proxy.remove(at: 1)
    //        }
    //        s2.change {
    //            var proxy = $0.birds
    //            proxy.remove(at: 1)
    //        }
    //        var s3 = s1
    //        s3.merge(s2)
    //        XCTAssertEqual(s3.content, Scheme(birds: ["albatross", "cormorant"]))
    //    }

    //  it('should handle concurrent deletion of the same element', () => {
    //    s1 = Automerge.change(s1, doc => doc.birds = ['albatross','buzzard', 'cormorant'])
    //    s2 = Automerge.merge(s2, s1)
    //    s1 = Automerge.change(s1, doc => doc.birds.deleteAt(1)) // buzzard
    //    s2 = Automerge.change(s2, doc => doc.birds.deleteAt(1)) // buzzard
    //    s3 = Automerge.merge(s1, s2)
    //    assert.deepStrictEqual(s3.birds, ['albatross','cormorant'])
    //  })

    // should handle concurrent deletion of different elements
    func testConcurrentUse15() {
        struct Scheme: Codable, Equatable {
            var birds: [String]
        }
        var s1 = Document(Scheme(birds: ["albatross", "buzzard", "cormorant"]))
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.change {
            var proxy = $0.birds
            proxy.remove(at: 0)
        }
        s2.change {
            var proxy = $0.birds
            proxy.remove(at: 1)
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
            var proxy = $0.wisdom
            proxy.append(contentsOf: ["to", "be", "is", "to", "do"])
        }
        s2.change {
            var proxy = $0.wisdom
            proxy.append(contentsOf: ["to", "do", "is", "to", "be"])
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

        var s1 = Document(Scheme(list: []), options: .init(actorId: ActorId(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")))
        var s2 = Document(Scheme(list: []), options: .init(actorId: ActorId(actorId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")))
        s1.change { $0.list.set(["two"]) }
        s2.merge(s1)
        s2.change {
            var proxy = $0.list
            proxy.insert("one", at: 0)
        }
        XCTAssertEqual(s2.content.list, ["one", "two"])
    }

    // should handle insertion by lesser actor ID
    func testConcurrentUseMultipleInsertsAtTheSameListPosition2() {
        struct Scheme: Codable, Equatable {
            var list: [String]
        }

        var s1 = Document(Scheme(list: []), options: .init(actorId: ActorId(actorId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")))
        var s2 = Document(Scheme(list: []), options: .init(actorId: ActorId(actorId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")))
        s1.change { $0.list.set(["two"]) }
        s2.merge(s1)
        s2.change {
            var proxy = $0.list
            proxy.insert("one", at: 0)
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
            var proxy = $0.list
            proxy.insert("one", at: 0)
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
            var proxy = $0.list
            proxy.insert("three", at: 0)
        }
        s1.merge(s2)
        s1.change {
            var proxy = $0.list
            proxy.insert("two", at: 0)
        }
        s2.merge(s1)
        s2.change {
            var proxy = $0.list
            proxy.insert("one", at: 0)
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
        s1.change(options: .init(message: "set 2"), execute: { $0.value.set(2) })
        var s2 = Document<Scheme>(changes: s1.allChanges())
        s1.undo(options: .init(message: "undo!"))
        #warning("history")
        s2.merge(s1)
        XCTAssertEqual(s2.content, Scheme(value: 1))
    }
}

//describe('.undo()', () => {
//  function getTopOfUndoStack(doc) {
//    const stack = Automerge.Backend.getUndoStack(Automerge.Frontend.getBackendState(doc))
//    return stack[stack.length - 1]
//  }
//
//  it('should apply undos by growing the history', () => {
//    let s1 = Automerge.change(Automerge.init(), 'set 1', doc => doc.value = 1)
//    s1 = Automerge.change(s1, 'set 2', doc => doc.value = 2)
//    let s2 = Automerge.merge(Automerge.init(), s1)
//    assert.deepStrictEqual(s2, {value: 2})
//    s1 = Automerge.undo(s1, 'undo!')
//    assert.deepStrictEqual(Automerge.getHistory(s1).map(state => [state.change.seq, state.change.message]),
//                           [[1, 'set 1'], [2, 'set 2'], [3, 'undo!']])
//    s2 = Automerge.merge(s2, s1)
//    assert.deepStrictEqual(s1, {value: 1})
//  })
//
//  it("should ignore other actors' updates to an undo-reverted field", () => {
//    let s1 = Automerge.change(Automerge.init(), doc => doc.value = 1)
//    s1 = Automerge.change(s1, doc => doc.value = 2)
//    let s2 = Automerge.merge(Automerge.init(), s1)
//    s2 = Automerge.change(s2, doc => doc.value = 3)
//    s1 = Automerge.merge(s1, s2)
//    assert.deepStrictEqual(s1, {value: 3})
//    s1 = Automerge.undo(s1)
//    assert.deepStrictEqual(s1, {value: 1})
//  })
//
//  it('should undo object creation by removing the link', () => {
//    let s1 = Automerge.init()
//    s1 = Automerge.change(s1, doc => doc.settings = {background: 'white', text: 'black'})
//    assert.deepStrictEqual(s1, {settings: {background: 'white', text: 'black'}})
//    assert.deepStrictEqual(getTopOfUndoStack(s1), [
//      {action: 'del', obj: ROOT_ID, key: 'settings', insert: false}
//    ])
//    s1 = Automerge.undo(s1)
//    assert.deepStrictEqual(s1, {})
//  })
//
//  it('should undo primitive field deletion by setting the old value', () => {
//    let s1 = Automerge.change(Automerge.init(), doc => { doc.k1 = 'v1'; doc.k2 = 'v2' })
//    s1 = Automerge.change(s1, doc => delete doc.k2)
//    assert.deepStrictEqual(s1, {k1: 'v1'})
//    assert.deepStrictEqual(getTopOfUndoStack(s1), [
//      {action: 'set', obj: ROOT_ID, key: 'k2', insert: false, value: 'v2'}
//    ])
//    s1 = Automerge.undo(s1)
//    assert.deepStrictEqual(s1, {k1: 'v1', k2: 'v2'})
//  })
//
//  it('should undo link deletion by linking the old value', () => {
//    let s1 = Automerge.change(Automerge.init(), doc => doc.fish = ['trout', 'sea bass'])
//    s1 = Automerge.change(s1, doc => doc.birds = ['heron', 'magpie'])
//    let s2 = Automerge.change(s1, doc => delete doc['fish'])
//    assert.deepStrictEqual(s2, {birds: ['heron', 'magpie']})
//    assert.deepStrictEqual(getTopOfUndoStack(s2), [
//      {action: 'link', obj: ROOT_ID, key: 'fish', insert: false, child: Automerge.getObjectId(s1.fish)}
//    ])
//    s2 = Automerge.undo(s2)
//    assert.deepStrictEqual(s2, {fish: ['trout', 'sea bass'], birds: ['heron', 'magpie']})
//  })
//
//  it('should undo list insertion by removing the new element', () => {
//    let s1 = Automerge.change(Automerge.init(), doc => doc.list = ['A', 'B', 'C'])
//    s1 = Automerge.change(s1, doc => doc.list.push('D'))
//    assert.deepStrictEqual(s1, {list: ['A', 'B', 'C', 'D']})
//    const actor = Automerge.Frontend.getActorId(s1)
//    assert.deepStrictEqual(getTopOfUndoStack(s1), [
//      {action: 'del', obj: Automerge.getObjectId(s1.list), key: `5@${actor}`, insert: false}
//    ])
//    s1 = Automerge.undo(s1)
//    assert.deepStrictEqual(s1, {list: ['A', 'B', 'C']})
//  })
//
//  it('should undo list element deletion by re-assigning the old value', () => {
//    let s1 = Automerge.change(Automerge.init(), doc => doc.list = ['A', 'B', 'C'])
//    const actor = Automerge.Frontend.getActorId(s1)
//    s1 = Automerge.change(s1, doc => doc.list.splice(1, 1))
//    assert.deepStrictEqual(s1, {list: ['A', 'C']})
//    assert.deepStrictEqual(getTopOfUndoStack(s1), [
//      {action: 'set', obj: Automerge.getObjectId(s1.list), key: `3@${actor}`, insert: false, value: 'B'}
//    ])
//    s1 = Automerge.undo(s1)
//    assert.deepStrictEqual(s1, {list: ['A', 'B', 'C']})
//  })
//
//  it('should undo counter increments', () => {
//    let s1 = Automerge.change(Automerge.init(), doc => doc.counter = new Automerge.Counter())
//    s1 = Automerge.change(s1, doc => doc.counter.increment())
//    assert.deepStrictEqual(s1, {counter: new Automerge.Counter(1)})
//    assert.deepStrictEqual(getTopOfUndoStack(s1), [
//      {action: 'inc', obj: ROOT_ID, key: 'counter', insert: false, value: -1}
//    ])
//    s1 = Automerge.undo(s1)
//    assert.deepStrictEqual(s1, {counter: new Automerge.Counter(0)})
//  })
//})
