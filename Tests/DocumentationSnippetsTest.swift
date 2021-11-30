//
//  DocumentationSnippetsTest.swift
//  Automerge
//
//
//  Created by Joseph Heck on 11/29/21.
//

import Foundation
import XCTest
@testable import Automerge

class DocumentationSnippetsTest: XCTestCase {
    
    // Code snippet in Document.change overview
    func testDocSnippetExample() {
        struct Model: Codable, Equatable {
            var bird: String?
        }
        // Create a model with an initial empty state.
        var doc = Document(Model(bird: nil))
        // Update the model to set a value.
        doc.change { proxy in
            proxy.bird?.set(newValue: "magpie")
        }
    }

    // Code snippets in ConflictingChanges.md article
    func testConflictingChangesExample() {
        struct Coordinate: Codable, Equatable {
            var x: Int?
        }

        // Initialize documents with known actor IDs.
        var doc1 = Document(Coordinate(),
                            actor: Actor(actorId: "actor-1"))
        var doc2 = Document(Coordinate(),
                            actor: Actor(actorId: "actor-2"))

        // Set values independently.
        doc1.change { proxy in
            proxy.x?.set(1)
        }
        // Swift/Array.swift:915: Fatal error: Can't construct Array with count < 0
        // 2021-11-30 14:35:46.141289-0800 xctest[2766:4023314] Swift/Array.swift:915: Fatal error: Can't construct Array with count < 0

        // also using the alternative closure:
        // { proxy in proxy.x.set(1) } results in a crash:
        //

        doc2.change { doc in
          doc.x.set(2)
        }
        // Swift/Array.swift:915: Fatal error: Can't construct Array with count < 0
        // 2021-11-30 14:35:46.141289-0800 xctest[2766:4023314] Swift/Array.swift:915: Fatal error: Can't construct Array with count < 0

        // Merge the changes in both directions.
        doc1.merge(doc2)
        doc2.merge(doc1)
        
        // Now, `doc1` might be either {x: 1} or {x: 2}.
        // However, `doc2` will be the same, whichever value is
        // chosen as winner.
        XCTAssertEqual(doc1.content.x, doc2.content.x)
        
// Future content once the crash gets fixed:
//
//        doc1
//        // {x: 2}
//        doc2
//        // {x: 2}
//
//        doc1.rootProxy().conflicts(dynamicMember: \.x))
//        // {'actor-1': 1}
//
//        doc2.rootProxy().conflicts(dynamicMember: \.x))
//        // {'actor-1': 1}

    }
}
