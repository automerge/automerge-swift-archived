//
//  KeyPathIntrospection.swift
//  Automerge
//
//  Created by Lukas Schmidt on 30.05.20.
//

import Foundation

// see https://gist.github.com/ddddxxx/7ba69196b8551efcf4025e7001cefa26
// and https://github.com/wickwirew/Runtime

extension KeyPath {

    var fieldName: String? {
        guard let offset = MemoryLayout<Root>.offset(of: self) else {
            return nil
        }
        let typePtr = unsafeBitCast(Root.self, to: UnsafeMutableRawPointer.self)
        let metadata = typePtr.assumingMemoryBound(to: StructMetadata.self)
        let kind = metadata.pointee._kind
        // for struct only
        guard kind == 1 || kind == 0x200 else {
            assertionFailure()
            return nil
        }
        let typeDescriptor = metadata.pointee.typeDescriptor
        let numberOfFields = Int(typeDescriptor.pointee.numberOfFields)
        let offsets = typeDescriptor.pointee
            .offsetToTheFieldOffsetVector
            .buffer(metadata: typePtr, count: numberOfFields)
        guard let fieldIndex = offsets.firstIndex(of: Int32(offset)) else {
            // composite keypath
            // TODO: resolve nested type
            return nil
        }
        return typeDescriptor.pointee
            .fieldDescriptor.advanced().pointee
            .fields.pointer().advanced(by: fieldIndex).pointee
            .fieldName()
    }
}

// MARK: - Layout

private struct StructMetadata {
    var _kind: Int
    var typeDescriptor: UnsafeMutablePointer<StructTypeDescriptor>
}

private struct StructTypeDescriptor {
    var flags: Int32
    var parent: Int32
    var mangledName: RelativePointer<Int32, CChar>
    var accessFunctionPtr: RelativePointer<Int32, UnsafeRawPointer>
    var fieldDescriptor: RelativePointer<Int32, FieldDescriptor>
    var numberOfFields: Int32
    var offsetToTheFieldOffsetVector: RelativeBufferPointer<Int32, Int32>
//    var genericContextHeader: TargetTypeGenericContextDescriptorHeader
}

private struct FieldDescriptor {
    var mangledTypeNameOffset: Int32
    var superClassOffset: Int32
    var _kind: UInt16
    var fieldRecordSize: Int16
    var numFields: Int32
    var fields: Buffer<Record>

    struct Record {

        var fieldRecordFlags: Int32
        var _mangledTypeName: RelativePointer<Int32, UInt8>
        var _fieldName: RelativePointer<Int32, UInt8>

        mutating func fieldName() -> String {
            return String(cString: _fieldName.advanced())
        }
    }
}

// MARK: - Pointers

private struct Buffer<Element> {

    var element: Element

    mutating func pointer() -> UnsafeMutablePointer<Element> {
        return withUnsafePointer(to: &self) {
            return UnsafeMutableRawPointer(mutating: UnsafeRawPointer($0))
                .assumingMemoryBound(to: Element.self)
        }
    }
}

private struct RelativePointer<Offset: FixedWidthInteger, Pointee> {

    var offset: Offset

    mutating func advanced() -> UnsafeMutablePointer<Pointee> {
        let offset = self.offset
        return withUnsafePointer(to: &self) { p in
            return UnsafeMutableRawPointer(mutating: p)
                .advanced(by: numericCast(offset))
                .assumingMemoryBound(to: Pointee.self)
        }
    }
}

private struct RelativeBufferPointer<Offset: FixedWidthInteger, Pointee> {

    var strides: Offset

    func buffer(metadata: UnsafeRawPointer, count: Int) -> UnsafeBufferPointer<Pointee> {
        let offset = numericCast(strides) * MemoryLayout<UnsafeRawPointer>.size
        let ptr = metadata.advanced(by: offset).assumingMemoryBound(to: Pointee.self)
        return UnsafeBufferPointer(start: ptr, count: count)
    }
}


