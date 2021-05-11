//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation
import AutomergeBackend

public final class RSBackend {

    private let automerge: OpaquePointer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public convenience init() {
        self.init(automerge: automerge_init())
    }

    public convenience init(data: [UInt8]) {
        self.init(automerge: automerge_load(UInt(data.count), data))
    }

    public convenience init(changes: [[UInt8]]) {
        let newAutomerge = automerge_init()
        for change in changes {
            automerge_write_change(newAutomerge, UInt(change.count), change)
        }
        automerge_load_changes(newAutomerge)
        self.init(automerge: newAutomerge!)
    }

    init(automerge: OpaquePointer) {
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

    deinit {
        automerge_free(automerge)
    }

    public func save() -> [UInt8] {
        let length = automerge_save(automerge)
        var data = Array<UInt8>(repeating: 0, count: length)
        automerge_read_binary(automerge, &data)

        return data
    }

    public func applyLocalChange(request: Request) -> (RSBackend, Patch) {
        let copy = automerge_clone(automerge)
        let data = try! encoder.encode(request)
        let string = String(data: data, encoding: .utf8)
        let length = automerge_apply_local_change(copy, string)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(copy, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return (RSBackend(automerge: copy!), patch)
    }

    public func apply(changes: [[UInt8]]) -> (RSBackend, Patch) {
        let copy = automerge_clone(automerge)
        for change in changes {
            automerge_write_change(copy, UInt(change.count), change)
        }
        let length = automerge_apply_changes(copy)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(copy, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return (RSBackend(automerge: copy!), patch)
    }

    public func getPatch() -> Patch {
        let length = automerge_get_patch(automerge)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(automerge, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return patch
    }

    public func getChanges() -> [[UInt8]] {
        var resut = [[UInt8]]()
        var length = automerge_get_changes(automerge, 0, nil);
        while (length > 0) {
            var data = Array<UInt8>(repeating: 0, count: length)
            length = automerge_read_binary(automerge, &data)
            resut.append(data)
        }

        return resut
    }

    public func getChanges(heads: [String]) -> [[UInt8]] {
        var resut = [[UInt8]]()
        var headsBuffer = Array<UInt8>(hex: heads.joined())
        var length = automerge_get_changes(automerge, UInt(heads.count), &headsBuffer);
        while (length > 0) {
            var data = Array<UInt8>(repeating: 0, count: length)
            length = automerge_read_binary(automerge, &data)
            resut.append(data)
        }

        return resut
    }

    public func getMissingDeps() -> [String] {
        let length = automerge_get_missing_deps(automerge)
        var buffer = Array<Int8>(repeating: 0, count: length)
        automerge_read_json(automerge, &buffer)
        let newString = String(cString: buffer)
        return try! decoder.decode([String].self, from: newString.data(using: .utf8)!)
    }

    public func getHeads() -> [String] {
        var length = automerge_get_heads(automerge)
        var resut = [[UInt8]]()
        while (length > 0) {
            var data = Array<UInt8>(repeating: 0, count: 32)

            length = automerge_read_binary(automerge, &data)

            resut.append(data)
        }
        let heads: [String] = resut.map({ abcd in
            return abcd.toHexString()
        })

        return heads
    }
}
