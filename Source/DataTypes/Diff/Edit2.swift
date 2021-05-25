//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 06.05.21.
//

import Foundation

enum Edit2: Codable, Equatable {

    enum Action: String, Codable {
        case insert
        case multiInsert = "multi-insert"
        case update
        case remove
    }

    case singleInsert(SingleInsertEdit)
    case multiInsert(MultiInsertEdit)
    case update(UpdateEdit)
    case remove(RemoveEdit)

    var action: Action {
        switch self {
        case .singleInsert(let edit):
            return edit.action
        case .multiInsert(let edit):
            return edit.action
        case .update(let edit):
            return edit.action
        case .remove(let edit):
            return edit.action
        }
    }

    var index: Int {
        switch self {
        case .singleInsert(let edit):
            return edit.index
        case .multiInsert(let edit):
            return edit.index
        case .update(let edit):
            return edit.index
        case .remove(let edit):
            return edit.index
        }
    }

    var opId: ObjectId? {
        switch self {
        case .singleInsert(let edit):
            return edit.opId
        case .update(let edit):
            return edit.opId
        default:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let singleInsert = try? container.decode(SingleInsertEdit.self) {
            self = .singleInsert(singleInsert)
        } else if let multiInsert = try? container.decode(MultiInsertEdit.self) {
            self = .multiInsert(multiInsert)
        } else if let update = try? container.decode(UpdateEdit.self) {
            self = .update(update)
        } else {
            self = .remove(try container.decode(RemoveEdit.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .singleInsert(let edit):
            try container.encode(edit)
        case .multiInsert(let edit):
            try container.encode(edit)
        case .update(let edit):
            try container.encode(edit)
        case .remove(let edit):
            try container.encode(edit)
        }
    }

    var value: Diff? {
        switch self {
        case .update(let update):
            return update.value
        case .singleInsert(let insert):
            return insert.value
        default:
            return nil
        }
    }
}
