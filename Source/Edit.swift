//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

struct Edit: Equatable {
    enum Action: Equatable {
        case insert
        case remove
    }

    let action: Action
    let index: Int
}

extension Array where Element == Edit {
    func iterate(insertCallback: (Int, Int) -> Void, removeCallback: (Int, Int) -> Void) {
        var splicePosition = -1
        var deletions: Int!
        var insertions: Int!

        for (i, edit) in self.enumerated() {
            let index = edit.index

            if splicePosition < 0 {
                splicePosition = index
                deletions = 0
                insertions = 0
            }
            switch edit.action {
            case .insert:
                insertions += 1

                // If there are multiple consecutive insertions at successive indexes,
                // accumulate them and then process them in a single insertCallback
                if i == self.count - 1 || self[i + 1].action != .insert || self[i + 1].index != index + 1 {
                    insertCallback(splicePosition, insertions)
                    splicePosition = -1
                }
            case .remove:
                deletions += 1

                // If there are multiple consecutive removals of the same index,
                // accumulate them and then process them in a single removeCallback
                if i == self.count - 1 || self[i + 1].action != .remove || self[i + 1].index != index {
                    removeCallback(splicePosition, deletions)
                    splicePosition = -1
                }
            }

        }
    }
}

///**
// * `edits` is an array of edits to a list data structure, each of which is an object of the form
// * either `{action: 'insert', index}` or `{action: 'remove', index}`. This merges adjacent edits
// * and calls `insertCallback(index, count)` or `removeCallback(index, count)`, as appropriate,
// * for each sequence of insertions or removals.
// */
//function iterateEdits(edits, insertCallback, removeCallback) {
//  if (!edits) return
//  let splicePos = -1, deletions, insertions
//
//  for (let i = 0; i < edits.length; i++) {
//    const edit = edits[i], action = edit.action, index = edit.index
//
//    if (action === 'insert') {
//      if (splicePos < 0) {
//        splicePos = index
//        deletions = 0
//        insertions = 0
//      }
//      insertions += 1
//
//      // If there are multiple consecutive insertions at successive indexes,
//      // accumulate them and then process them in a single insertCallback
//      if (i === edits.length - 1 ||
//          edits[i + 1].action !== 'insert' ||
//          edits[i + 1].index  !== index + 1) {
//        insertCallback(splicePos, insertions)
//        splicePos = -1
//      }
//
//    } else if (action === 'remove') {
//      if (splicePos < 0) {
//        splicePos = index
//        deletions = 0
//        insertions = 0
//      }
//      deletions += 1
//
//      // If there are multiple consecutive removals of the same index,
//      // accumulate them and then process them in a single removeCallback
//      if (i === edits.length - 1 ||
//          edits[i + 1].action !== 'remove' ||
//          edits[i + 1].index  !== index) {
//        removeCallback(splicePos, deletions)
//        splicePos = -1
//      }
//    } else {
//      throw new RangeError(`Unknown list edit action: ${action}`)
//    }
//  }
//}
