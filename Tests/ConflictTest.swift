//
//  ConflictTest.swift
//  
//  Created by Joseph Heck on 12/3/21.
//

import Foundation
import XCTest
import Automerge

class ConflictTest: XCTestCase {
    func testActorsFromConflictingChanges_IndependentDocs() {
        struct Coordinate: Codable, Equatable {
            var x: Int?
        }
        
        let actor1 = Actor()
        let actor2 = Actor()
        
        // Initialize documents with known actor IDs.
        var doc1 = Document(Coordinate(), actor: actor1)
        // Creates a new, indepdendent doc:
        var doc2 = Document(Coordinate(), actor: actor2)

        // Set the values independently.
        doc1.change { proxy in
            proxy.x.set(1)
        }
        
        doc2.change { proxy in
            proxy.x.set(2)
        }
        
        // Merge the changes in both directions.
        doc1.merge(doc2)
        doc2.merge(doc1)
        
        // Now, `doc1` might be either {x: 1} or {x: 2}.
        // However, `doc2` will be the same, whichever value is
        // chosen as winner.
        XCTAssertEqual(doc1.content.x, doc2.content.x)
        
        let doc1_conflicts = doc1.rootProxy().conflicts(dynamicMember: \.x)
        // ex: Optional([1@40d336cdd6044c2f9886d5240b7ba91c: Optional(1), 1@554560f135b14f18b8fa37ed999624c2: Optional(2)])
        let doc2_conflicts = doc2.rootProxy().conflicts(dynamicMember: \.x)
        // ex: Optional([1@554560f135b14f18b8fa37ed999624c2: Optional(2), 1@40d336cdd6044c2f9886d5240b7ba91c: Optional(1)])
        
        // There will definitely be conflicts listed
        XCTAssertNotNil(doc1_conflicts)
        // Conflicts should be listed, and available from, each document
        XCTAssertEqual(doc1_conflicts, doc2_conflicts)
        // The list of conflict show the Actor ID's, and the value that each proposed for the given KeyPath.
        XCTAssertEqual(doc1_conflicts?.count, 2)
        
        if let doc1_conflicts = doc1_conflicts {
            doc1_conflicts.keys.forEach { actor in
                XCTAssertTrue([actor1, actor2].contains(actor), "Actor returned in conflict \(actor) doesn't match either of the original actors: [\(actor1),\(actor2)].")
            }
        }
    }
    
    func testActorsFromConflictingChanges_ClonedDoc() {
        struct Coordinate: Codable, Equatable {
            var x: Int?
        }
        
        let actor1 = Actor()
        let actor2 = Actor()
        
        // Initialize documents with known actor IDs.
        var doc1 = Document(Coordinate(), actor: actor1)
        // replicate, rather than create a whole new doc...
        var doc2 = Document<Coordinate>(data: doc1.save(), actor: actor2)

        // Set the values independently.
        doc1.change { proxy in
            proxy.x.set(1)
        }
        
        doc2.change { proxy in
            proxy.x.set(2)
        }
        
        // Merge the changes in both directions.
        doc1.merge(doc2)
        doc2.merge(doc1)
        
        // Now, `doc1` might be either {x: 1} or {x: 2}.
        // However, `doc2` will be the same, whichever value is
        // chosen as winner.
        XCTAssertEqual(doc1.content.x, doc2.content.x)
        
        let doc1_conflicts = doc1.rootProxy().conflicts(dynamicMember: \.x)
        // ex: Optional([1@40d336cdd6044c2f9886d5240b7ba91c: Optional(1), 1@554560f135b14f18b8fa37ed999624c2: Optional(2)])
        let doc2_conflicts = doc2.rootProxy().conflicts(dynamicMember: \.x)
        // ex: Optional([1@554560f135b14f18b8fa37ed999624c2: Optional(2), 1@40d336cdd6044c2f9886d5240b7ba91c: Optional(1)])
        
        // There will definitely be conflicts listed
        XCTAssertNotNil(doc1_conflicts)
        // Conflicts should be listed, and available from, each document
        XCTAssertEqual(doc1_conflicts, doc2_conflicts)
        // The list of conflict show the Actor ID's, and the value that each proposed for the given KeyPath.
        XCTAssertEqual(doc1_conflicts?.count, 2)
        
        if let doc1_conflicts = doc1_conflicts {
            doc1_conflicts.keys.forEach { actor in
                XCTAssertTrue([actor1, actor2].contains(actor), "Actor returned in conflict \(actor) doesn't match either of the original actors: [\(actor1),\(actor2)].")
            }
        }
    }
}

