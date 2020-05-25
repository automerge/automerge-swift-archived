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

}

//
//    it('should handle assignment of an object literal', () => {
//      s1 = Automerge.change(s1, doc => {
//        doc.textStyle = {bold: false, fontSize: 12}
//      })
//      assert.deepStrictEqual(s1, {textStyle: {bold: false, fontSize: 12}})
//      assert.deepStrictEqual(s1.textStyle, {bold: false, fontSize: 12})
//      assert.strictEqual(s1.textStyle.bold, false)
//      assert.strictEqual(s1.textStyle.fontSize, 12)
//    })
//
//    it('should handle assignment of multiple nested properties', () => {
//      s1 = Automerge.change(s1, doc => {
//        doc['textStyle'] = {bold: false, fontSize: 12}
//        Object.assign(doc.textStyle, {typeface: 'Optima', fontSize: 14})
//      })
//      assert.strictEqual(s1.textStyle.typeface, 'Optima')
//      assert.strictEqual(s1.textStyle.bold, false)
//      assert.strictEqual(s1.textStyle.fontSize, 14)
//      assert.deepStrictEqual(s1.textStyle, {typeface: 'Optima', bold: false, fontSize: 14})
//    })
//
//    it('should handle arbitrary-depth nesting', () => {
//      s1 = Automerge.change(s1, doc => {
//        doc.a = {b: {c: {d: {e: {f: {g: 'h'}}}}}}
//      })
//      s1 = Automerge.change(s1, doc => {
//        doc.a.b.c.d.e.f.i = 'j'
//      })
//      assert.deepStrictEqual(s1, {a: { b: { c: { d: { e: { f: { g: 'h', i: 'j'}}}}}}})
//      assert.strictEqual(s1.a.b.c.d.e.f.g, 'h')
//      assert.strictEqual(s1.a.b.c.d.e.f.i, 'j')
//    })
//
//    it('should allow an old object to be replaced with a new one', () => {
//      s1 = Automerge.change(s1, 'change 1', doc => {
//        doc.myPet = {species: 'dog', legs: 4, breed: 'dachshund'}
//      })
//      s2 = Automerge.change(s1, 'change 2', doc => {
//        doc.myPet = {species: 'koi', variety: '紅白', colors: {red: true, white: true, black: false}}
//      })
//      assert.deepStrictEqual(s1.myPet, {
//        species: 'dog', legs: 4, breed: 'dachshund'
//      })
//      assert.strictEqual(s1.myPet.breed, 'dachshund')
//      assert.deepStrictEqual(s2.myPet, {
//        species: 'koi', variety: '紅白',
//        colors: {red: true, white: true, black: false}
//      })
//      assert.strictEqual(s2.myPet.breed, undefined)
//      assert.strictEqual(s2.myPet.variety, '紅白')
//    })
//
//    it('should allow fields to be changed between primitive and nested map', () => {
//      s1 = Automerge.change(s1, doc => doc.color = '#ff7f00')
//      assert.strictEqual(s1.color, '#ff7f00')
//      s1 = Automerge.change(s1, doc => doc.color = {red: 255, green: 127, blue: 0})
//      assert.deepStrictEqual(s1.color, {red: 255, green: 127, blue: 0})
//      s1 = Automerge.change(s1, doc => doc.color = '#ff7f00')
//      assert.strictEqual(s1.color, '#ff7f00')
//    })
//
//    it('should not allow several references to the same map object', () => {
//      s1 = Automerge.change(s1, doc => doc.object = {})
//      assert.throws(() => {
//        Automerge.change(s1, doc => { doc.x = doc.object })
//      }, /Cannot create a reference to an existing document object/)
//      assert.throws(() => {
//        Automerge.change(s1, doc => { doc.x = s1.object })
//      }, /Cannot create a reference to an existing document object/)
//      assert.throws(() => {
//        Automerge.change(s1, doc => { doc.x = {}; doc.y = doc.x })
//      }, /Cannot create a reference to an existing document object/)
//    })
//
//    it('should handle deletion of properties within a map', () => {
//      s1 = Automerge.change(s1, 'set style', doc => {
//        doc.textStyle = {typeface: 'Optima', bold: false, fontSize: 12}
//      })
//      s1 = Automerge.change(s1, 'non-bold', doc => delete doc.textStyle['bold'])
//      assert.strictEqual(s1.textStyle.bold, undefined)
//      assert.deepStrictEqual(s1.textStyle, {typeface: 'Optima', fontSize: 12})
//    })
//
//    it('should handle deletion of references to a map', () => {
//      s1 = Automerge.change(s1, 'make rich text doc', doc => {
//        Object.assign(doc, {title: 'Hello', textStyle: {typeface: 'Optima', fontSize: 12}})
//      })
//      s1 = Automerge.change(s1, doc => delete doc['textStyle'])
//      assert.strictEqual(s1.textStyle, undefined)
//      assert.deepStrictEqual(s1, {title: 'Hello'})
//    })
//
//    it('should validate field names', () => {
//      s1 = Automerge.change(s1, doc => doc.nested = {})
//      assert.throws(() => { Automerge.change(s1, doc => doc.nested[''] = 'x') }, /must not be an empty string/)
//      assert.throws(() => { Automerge.change(s1, doc => doc.nested = {'': 'x'}) }, /must not be an empty string/)
//    })
//  })
//
//  describe('lists', () => {
//    it('should allow elements to be inserted', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = [])
//      s1 = Automerge.change(s1, doc => doc.noodles.insertAt(0, 'udon', 'soba'))
//      s1 = Automerge.change(s1, doc => doc.noodles.insertAt(1, 'ramen'))
//      assert.deepStrictEqual(s1, {noodles: ['udon', 'ramen', 'soba']})
//      assert.deepStrictEqual(s1.noodles, ['udon', 'ramen', 'soba'])
//      assert.strictEqual(s1.noodles[0], 'udon')
//      assert.strictEqual(s1.noodles[1], 'ramen')
//      assert.strictEqual(s1.noodles[2], 'soba')
//      assert.strictEqual(s1.noodles.length, 3)
//    })
//
//    it('should handle assignment of a list literal', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = ['udon', 'ramen', 'soba'])
//      assert.deepStrictEqual(s1, {noodles: ['udon', 'ramen', 'soba']})
//      assert.deepStrictEqual(s1.noodles, ['udon', 'ramen', 'soba'])
//      assert.strictEqual(s1.noodles[0], 'udon')
//      assert.strictEqual(s1.noodles[1], 'ramen')
//      assert.strictEqual(s1.noodles[2], 'soba')
//      assert.strictEqual(s1.noodles[3], undefined)
//      assert.strictEqual(s1.noodles.length, 3)
//    })
//
//    it('should only allow numeric indexes', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = ['udon', 'ramen', 'soba'])
//      s1 = Automerge.change(s1, doc => doc.noodles[1] = 'Ramen!')
//      assert.strictEqual(s1.noodles[1], 'Ramen!')
//      s1 = Automerge.change(s1, doc => doc.noodles['1'] = 'RAMEN!!!')
//      assert.strictEqual(s1.noodles[1], 'RAMEN!!!')
//      assert.throws(() => { Automerge.change(s1, doc => doc.noodles['favourite'] = 'udon') }, /list index must be a number/)
//      assert.throws(() => { Automerge.change(s1, doc => doc.noodles[''         ] = 'udon') }, /list index must be a number/)
//      assert.throws(() => { Automerge.change(s1, doc => doc.noodles['1e6'      ] = 'udon') }, /list index must be a number/)
//    })
//
//    it('should handle deletion of list elements', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = ['udon', 'ramen', 'soba'])
//      s1 = Automerge.change(s1, doc => delete doc.noodles[1])
//      assert.deepStrictEqual(s1.noodles, ['udon', 'soba'])
//      s1 = Automerge.change(s1, doc => doc.noodles.deleteAt(1))
//      assert.deepStrictEqual(s1.noodles, ['udon'])
//      assert.strictEqual(s1.noodles[0], 'udon')
//      assert.strictEqual(s1.noodles[1], undefined)
//      assert.strictEqual(s1.noodles[2], undefined)
//      assert.strictEqual(s1.noodles.length, 1)
//    })
//
//    it('should handle assignment of individual list indexes', () => {
//      s1 = Automerge.change(s1, doc => doc.japaneseFood = ['udon', 'ramen', 'soba'])
//      s1 = Automerge.change(s1, doc => doc.japaneseFood[1] = 'sushi')
//      assert.deepStrictEqual(s1.japaneseFood, ['udon', 'sushi', 'soba'])
//      assert.strictEqual(s1.japaneseFood[0], 'udon')
//      assert.strictEqual(s1.japaneseFood[1], 'sushi')
//      assert.strictEqual(s1.japaneseFood[2], 'soba')
//      assert.strictEqual(s1.japaneseFood[3], undefined)
//      assert.strictEqual(s1.japaneseFood.length, 3)
//    })
//
//    it('should treat out-by-one assignment as insertion', () => {
//      s1 = Automerge.change(s1, doc => doc.japaneseFood = ['udon'])
//      s1 = Automerge.change(s1, doc => doc.japaneseFood[1] = 'sushi')
//      assert.deepStrictEqual(s1.japaneseFood, ['udon', 'sushi'])
//      assert.strictEqual(s1.japaneseFood[0], 'udon')
//      assert.strictEqual(s1.japaneseFood[1], 'sushi')
//      assert.strictEqual(s1.japaneseFood[2], undefined)
//      assert.strictEqual(s1.japaneseFood.length, 2)
//    })
//
//    it('should not allow out-of-range assignment', () => {
//      s1 = Automerge.change(s1, doc => doc.japaneseFood = ['udon'])
//      assert.throws(() => { Automerge.change(s1, doc => doc.japaneseFood[4] = 'ramen') }, /is out of bounds/)
//    })
//
//    it('should allow bulk assignment of multiple list indexes', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = ['udon', 'ramen', 'soba'])
//      s1 = Automerge.change(s1, doc => Object.assign(doc.noodles, {0: 'うどん', 2: 'そば'}))
//      assert.deepStrictEqual(s1.noodles, ['うどん', 'ramen', 'そば'])
//      assert.strictEqual(s1.noodles[0], 'うどん')
//      assert.strictEqual(s1.noodles[1], 'ramen')
//      assert.strictEqual(s1.noodles[2], 'そば')
//      assert.strictEqual(s1.noodles.length, 3)
//    })
//
//    it('should handle nested objects', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = [{type: 'ramen', dishes: ['tonkotsu', 'shoyu']}])
//      s1 = Automerge.change(s1, doc => doc.noodles.push({type: 'udon', dishes: ['tempura udon']}))
//      s1 = Automerge.change(s1, doc => doc.noodles[0].dishes.push('miso'))
//      assert.deepStrictEqual(s1, {noodles: [
//        {type: 'ramen', dishes: ['tonkotsu', 'shoyu', 'miso']},
//        {type: 'udon', dishes: ['tempura udon']}
//      ]})
//      assert.deepStrictEqual(s1.noodles[0], {
//        type: 'ramen', dishes: ['tonkotsu', 'shoyu', 'miso']
//      })
//      assert.deepStrictEqual(s1.noodles[1], {
//        type: 'udon', dishes: ['tempura udon']
//      })
//    })
//
//    it('should handle nested lists', () => {
//      s1 = Automerge.change(s1, doc => doc.noodleMatrix = [['ramen', 'tonkotsu', 'shoyu']])
//      s1 = Automerge.change(s1, doc => doc.noodleMatrix.push(['udon', 'tempura udon']))
//      s1 = Automerge.change(s1, doc => doc.noodleMatrix[0].push('miso'))
//      assert.deepStrictEqual(s1.noodleMatrix, [['ramen', 'tonkotsu', 'shoyu', 'miso'], ['udon', 'tempura udon']])
//      assert.deepStrictEqual(s1.noodleMatrix[0], ['ramen', 'tonkotsu', 'shoyu', 'miso'])
//      assert.deepStrictEqual(s1.noodleMatrix[1], ['udon', 'tempura udon'])
//    })
//
//    it('should handle replacement of the entire list', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = ['udon', 'soba', 'ramen'])
//      s1 = Automerge.change(s1, doc => doc.japaneseNoodles = doc.noodles.slice())
//      s1 = Automerge.change(s1, doc => doc.noodles = ['wonton', 'pho'])
//      assert.deepStrictEqual(s1, {
//        noodles: ['wonton', 'pho'],
//        japaneseNoodles: ['udon', 'soba', 'ramen']
//      })
//      assert.deepStrictEqual(s1.noodles, ['wonton', 'pho'])
//      assert.strictEqual(s1.noodles[0], 'wonton')
//      assert.strictEqual(s1.noodles[1], 'pho')
//      assert.strictEqual(s1.noodles[2], undefined)
//      assert.strictEqual(s1.noodles.length, 2)
//    })
//
//    it('should allow assignment to change the type of a list element', () => {
//      s1 = Automerge.change(s1, doc => doc.noodles = ['udon', 'soba', 'ramen'])
//      assert.deepStrictEqual(s1.noodles, ['udon', 'soba', 'ramen'])
//      s1 = Automerge.change(s1, doc => doc.noodles[1] = {type: 'soba', options: ['hot', 'cold']})
//      assert.deepStrictEqual(s1.noodles, ['udon', {type: 'soba', options: ['hot', 'cold']}, 'ramen'])
//      s1 = Automerge.change(s1, doc => doc.noodles[1] = ['hot soba', 'cold soba'])
//      assert.deepStrictEqual(s1.noodles, ['udon', ['hot soba', 'cold soba'], 'ramen'])
//      s1 = Automerge.change(s1, doc => doc.noodles[1] = 'soba is the best')
//      assert.deepStrictEqual(s1.noodles, ['udon', 'soba is the best', 'ramen'])
//    })
//
//    it('should allow list creation and assignment in the same change callback', () => {
//      s1 = Automerge.change(Automerge.init(), doc => {
//        doc.letters = ['a', 'b', 'c']
//        doc.letters[1] = 'd'
//      })
//      assert.strictEqual(s1.letters[1], 'd')
//    })
//
//    it('should allow adding and removing list elements in the same change callback', () => {
//      s1 = Automerge.change(Automerge.init(), doc => doc.noodles = [])
//      s1 = Automerge.change(s1, doc => {
//        doc.noodles.push('udon')
//        doc.noodles.deleteAt(0)
//      })
//      assert.deepStrictEqual(s1, {noodles: []})
//      // do the add-remove cycle twice, test for #151 (https://github.com/automerge/automerge/issues/151)
//      s1 = Automerge.change(s1, doc => {
//        doc.noodles.push('soba')
//        doc.noodles.deleteAt(0)
//      })
//      assert.deepStrictEqual(s1, {noodles: []})
//    })
//
//    it('should handle arbitrary-depth nesting', () => {
//      s1 = Automerge.change(s1, doc => doc.maze = [[[[[[[['noodles', ['here']]]]]]]]])
//      s1 = Automerge.change(s1, doc => doc.maze[0][0][0][0][0][0][0][1].unshift('found'))
//      assert.deepStrictEqual(s1.maze, [[[[[[[['noodles', ['found', 'here']]]]]]]]])
//      assert.deepStrictEqual(s1.maze[0][0][0][0][0][0][0][1][1], 'here')
//    })
//
//    it('should not allow several references to the same list object', () => {
//      s1 = Automerge.change(s1, doc => doc.list = [])
//      assert.throws(() => {
//        Automerge.change(s1, doc => { doc.x = doc.list })
//      }, /Cannot create a reference to an existing document object/)
//      assert.throws(() => {
//        Automerge.change(s1, doc => { doc.x = s1.list })
//      }, /Cannot create a reference to an existing document object/)
//      assert.throws(() => {
//        Automerge.change(s1, doc => { doc.x = []; doc.y = doc.x })
//      }, /Cannot create a reference to an existing document object/)
//    })
//  })
//
//  describe('counters', () => {
//    it('should coalesce assignments and increments', () => {
//      const s1 = Automerge.change(Automerge.init(), doc => doc.birds = {})
//      const s2 = Automerge.change(s1, doc => {
//        doc.birds.wrens = new Automerge.Counter(1)
//        doc.birds.wrens.increment(2)
//      })
//      assert.deepStrictEqual(s1, {birds: {}})
//      assert.deepStrictEqual(s2, {birds: {wrens: new Automerge.Counter(3)}})
//      const changes = Automerge.getAllChanges(s2).map(decodeChange)
//      assert.deepStrictEqual(changes[1], {
//        hash: changes[1].hash, actor: Automerge.getActorId(s2), seq: 2, startOp: 2,
//        time: changes[1].time, message: '', deps: [changes[0].hash], ops: [
//          {obj: Automerge.getObjectId(s2.birds), action: 'set', key: 'wrens', insert: false, value: 3, datatype: 'counter', pred: []}
//        ]
//      })
//    })
//
//    it('should coalesce multiple increments', () => {
//      const s1 = Automerge.change(Automerge.init(), doc => doc.birds = {wrens: new Automerge.Counter()})
//      const s2 = Automerge.change(s1, doc => {
//        doc.birds.wrens.increment(2)
//        doc.birds.wrens.decrement()
//        doc.birds.wrens.increment(3)
//      })
//      assert.deepStrictEqual(s1, {birds: {wrens: new Automerge.Counter(0)}})
//      assert.deepStrictEqual(s2, {birds: {wrens: new Automerge.Counter(4)}})
//      const changes = Automerge.getAllChanges(s2).map(decodeChange), actor = Automerge.getActorId(s2)
//      assert.deepStrictEqual(changes[1], {
//        hash: changes[1].hash, actor, seq: 2, startOp: 3, time: changes[1].time,
//        message: '', deps: [changes[0].hash], ops: [
//          {obj: Automerge.getObjectId(s2.birds), action: 'inc', key: 'wrens', insert: false, value: 4, pred: [`2@${actor}`]}
//        ]
//      })
//    })
//  })
//})
