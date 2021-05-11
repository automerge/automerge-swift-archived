//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation
import AutomergeBackend

fileprivate final class RSBackendReference {

    init(automerge: OpaquePointer) {
        self.automerge = automerge
    }

    convenience init() {
        self.init(automerge: automerge_init())
    }

    let automerge: OpaquePointer

    deinit {
        automerge_free(automerge)
    }

    func clone() -> RSBackendReference {
        return RSBackendReference(automerge: automerge_clone(automerge))
    }

}

public final class RSBackend {

    private var automerge: RSBackendReference
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public convenience init() {
        self.init(automerge: RSBackendReference())
    }

    public convenience init(data: [UInt8]) {
        let automerge = RSBackendReference(automerge: automerge_load(UInt(data.count), data))
        self.init(automerge: automerge)
    }

    public convenience init(changes: [[UInt8]]) {
        let newAutomerge = RSBackendReference()
        for change in changes {
            automerge_write_change(newAutomerge.automerge, UInt(change.count), change)
        }
        automerge_load_changes(newAutomerge.automerge)
        self.init(automerge: newAutomerge)
    }

    private init(automerge: RSBackendReference) {
        self.automerge = automerge
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .custom({ (date, encoder) throws in
            var container = encoder.singleValueContainer()
            let seconds: UInt = UInt(date.timeIntervalSince1970)
            try container.encode(seconds)
        })
        decoder.dateDecodingStrategy = .custom({ (decoder) throws in
            var container = try decoder.unkeyedContainer()
            return try Date(timeIntervalSince1970: container.decode(TimeInterval.self))
        })
    }

    public func save() -> [UInt8] {
        let length = automerge_save(automerge.automerge)
        var data = Array<UInt8>(repeating: 0, count: length)
        automerge_read_binary(automerge.automerge, &data)

        return data
    }

    public func applyLocalChange(request: Request) -> (RSBackend, Patch) {
        let writeable: RSBackendReference
        if isKnownUniquelyReferenced(&automerge) {
            writeable = automerge
        } else {
            writeable = automerge.clone()
        }
        let data = try! encoder.encode(request)
        let string = String(data: data, encoding: .utf8)
        let length = automerge_apply_local_change(writeable.automerge, string)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(writeable.automerge, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return (RSBackend(automerge: writeable), patch)
    }

    public func apply(changes: [[UInt8]]) -> (RSBackend, Patch) {
        let writeable: RSBackendReference
        if isKnownUniquelyReferenced(&automerge) {
            writeable = automerge
        } else {
            writeable = automerge.clone()
        }
        for change in changes {
            automerge_write_change(writeable.automerge, UInt(change.count), change)
        }
        let length = automerge_apply_changes(writeable.automerge)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(writeable.automerge, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return (RSBackend(automerge: writeable), patch)
    }

    public func getPatch() -> Patch {
        let length = automerge_get_patch(automerge.automerge)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(automerge.automerge, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return patch
    }

    public func getChanges(heads: [String] = []) -> [[UInt8]] {
        var changes = [[UInt8]]()
        var headsBuffer = Array<UInt8>(hex: heads.joined())
        var length = automerge_get_changes(automerge.automerge, UInt(heads.count), &headsBuffer);
        while (length > 0) {
            var data = Array<UInt8>(repeating: 0, count: length)
            length = automerge_read_binary(automerge.automerge, &data)
            changes.append(data)
        }

        return changes
    }

    public func getMissingDeps() -> [String] {
        let length = automerge_get_missing_deps(automerge.automerge)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(automerge.automerge, &buffer)
        let newString = String(cString: buffer)
        return try! decoder.decode([String].self, from: newString.data(using: .utf8)!)
    }

    public func getHeads() -> [String] {
        var length = automerge_get_heads(automerge.automerge)
        var heads = [[UInt8]]()
        while (length > 0) {
            var data = Array<UInt8>(repeating: 0, count: 32)
            length = automerge_read_binary(automerge.automerge, &data)
            heads.append(data)
        }

        return heads.map { $0.toHexString() }
    }
}
