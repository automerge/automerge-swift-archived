//
//  TableTests.swift
//  Automerge
//
//  Created by Lukas Schmidt on 12.06.20.
//

import Foundation
@testable import Automerge
import XCTest

class TableTest: XCTestCase {

    // should generate ops to create a table
    func testTableFronted1() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable { }
            var books: Table<Book>?
        }
        let actor = Actor()
        var doc = Document(Scheme(books: nil), actor: actor)

        let req = doc.change {
            $0.books?.set(Table())
        }

        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: actor.actorId, seq: 1, version: 0, ops: [
            Op(action: .makeTable, obj: ROOT_ID, key: "books", child: req!.ops[0].child)
        ], undoable: true))
    }

    // should generate ops to insert a row
    func testTableFronted2() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var doc = Document(Scheme(books: Table()), actor: actor)

        let req = doc.change {
            $0.books.add(.init(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications"))
        }

        let rowId = req!.ops[0].key
        XCTAssertEqual(req, Request(requestType: .change, message: "", time: req!.time, actor: actor.actorId, seq: 2, version: 1, ops: [
            Op(action: .makeMap, obj: req!.ops[0].obj, key: rowId, child: req!.ops[0].child),
            Op(action: .set, obj: "\(rowId)", key: "authors", value: .string("Kleppmann, Martin")),
            Op(action: .set, obj: "\(rowId)", key: "title", value: .string("Designing Data-Intensive Applications")),
        ], undoable: true))
    }

    // should look up a row by ID
    func testTableWithOneRow1() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)

        var rowId: String?
        s1.change {
            rowId = $0.books.add(.ddia)
        }
        XCTAssertEqual(s1.content.books.row(by: rowId!)?.value, .ddia)
    }

    // should return the row count
    func testTableWithOneRow2() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)

        s1.change {
            $0.books.add(.ddia)
        }
        XCTAssertEqual(s1.content.books.count, 1)
        XCTAssertEqual(Array(s1.content.books).map{ $0.value}, [.ddia])
    }

    // should return a list of row IDs
    func testTableWithOneRow3() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)

        var rowId: String?
        s1.change {
            rowId = $0.books.add(.ddia)
        }
        XCTAssertEqual(s1.content.books.ids, [rowId])
    }

    // should save and reload
    func testTableWithOneRow4() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)

        var rowId: String?
        s1.change {
            rowId = $0.books.add(.ddia)
        }
        XCTAssertEqual(Document<Scheme>(changes: s1.allChanges()).content.books.row(by: rowId!)?.value, .ddia)
    }

    // should allow a row to be updated
    func testTableWithOneRow5() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                var isbn: String?
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications", isbn: nil)
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)

        var rowId: String!
        s1.change {
            rowId = $0.books.add(.ddia)
        }
        s1.change {
            $0.books.row(by: rowId)?.isbn.set("9781449373320")
        }
        XCTAssertEqual(s1.content.books.row(by: rowId!)?.value, Scheme.Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications", isbn: "9781449373320"))
    }

    // should allow a row to be removed
    func testTableWithOneRow6() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)

        var rowId: String!
        s1.change {
            rowId = $0.books.add(.ddia)
        }
        s1.change {
            $0.books.removeRow(by: rowId)
        }
        XCTAssertEqual(s1.content.books.count, 0)
    }

    // should allow concurrent row insertion
    func testTableWithOneRow7() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: [String]
                let title: String
                static let ddia = Book(authors: ["Kleppmann, Martin"], title: "Designing Data-Intensive Applications")
                static let rsdp = Book(authors: ["Cachin, Christian", "Guerraoui, Rachid", "Rodrigues, Luís"], title: "Introduction to Reliable and Secure Distributed Programming")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = Document(Scheme(books: Table()), actor: actor)
        var s2 = Document<Scheme>(changes: s1.allChanges())

        var ddia: String!
        var rsdp: String!
        s1.change {
            ddia = $0.books.add(.ddia)
        }
        s2.change {
            rsdp = $0.books.add(.rsdp)
        }
        s1.merge(s2)
        XCTAssertEqual(s1.content.books.row(by: ddia)?.value, .ddia)
        XCTAssertEqual(s1.content.books.row(by: ddia)?.id, ddia)
        XCTAssertEqual(s1.content.books.row(by: rsdp)?.value, .rsdp)
        XCTAssertEqual(s1.content.books.row(by: rsdp)?.id, rsdp)
        XCTAssertEqual(s1.content.books.count, 2)
        XCTAssertEqualOneOf(s1.content.books.ids, [ddia, rsdp], [rsdp, ddia])
    }

}
