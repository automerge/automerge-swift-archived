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
    
}
