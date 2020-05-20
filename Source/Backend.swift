//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public protocol Backend {

    func applyLocalChange(request: Request) -> (Backend, Patch)

    func save() -> [UInt8]

    func getPatch() -> Patch
    
}

public struct DefaultBackend: Backend {

    public func getPatch() -> Patch {
        return Patch(clock: [:], version: 0, canUndo: false, canRedo: false, diffs: ObjectDiff(objectId: UUID().uuidString, type: .map))
    }


    public init(data: [UInt8]) { }

    public init() {}

    public func applyLocalChange(request: Request) -> (Backend, Patch) {
        return (self, Patch(clock: [:], version: 0, canUndo: false, canRedo: false, diffs: ObjectDiff(objectId: UUID().uuidString, type: .map)))
    }

    public func save() -> [UInt8] {
        return []
    }

}

public class RSBackend: Backend {

    private let automerge: OpaquePointer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public convenience init() {
        self.init(automerge: automerge_init())
    }

    public required init(data: [UInt8]) {
        self.automerge = automerge_load(UInt(data.count), data)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = .prettyPrinted
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

    init(automerge: OpaquePointer) {
        self.automerge = automerge
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = .prettyPrinted
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
//        let data = Array<UInt8>.init(unsafeUninitializedCapacity: length) { (buffer, size) in
//            automerge_read_binary(automerge, buffer.baseAddress!)
//        }

        return data
    }

    public func applyLocalChange(request: Request) -> (Backend, Patch) {
        let data = try! encoder.encode(request)
        let string = String(data: data, encoding: .utf8)
        let length = automerge_apply_local_change(automerge, string)
         var buffer = Array<Int8>(repeating: 0, count: length)
        buffer.append(0)
        automerge_read_json(automerge, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return (RSBackend(automerge: automerge_clone(automerge)), patch)
    }

    public func getPatch() -> Patch {
        let length = automerge_get_patch(automerge)
        var buffer = Array<Int8>(repeating: 0, count: length)
        buffer.append(0)
        automerge_read_json(automerge, &buffer)
        let newString = String(cString: buffer)
        let patch = try! decoder.decode(Patch.self, from: newString.data(using: .utf8)!)

        return patch
    }
}

