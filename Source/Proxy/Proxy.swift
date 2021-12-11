//
//  Proxy.swift
//  
//
//  Created by Lukas Schmidt on 24.04.20.
//

import Foundation

/// A wrapper around your model that a document uses to track changes the model instance.
///
/// A proxy is provided to the ``Document/change(message:_:)`` as an interface for updating your document's model.
///
/// ## Topics
///
/// ### Getting the Current State of your Document
///
/// - ``Proxy/get()``
///
/// ### Updating a Document
///
/// - ``Proxy/set(_:)``
///
/// ### Updating a Counter Model
///
/// - ``Proxy/increment(_:)``
/// - ``Proxy/decrement(_:)``
///
/// ### Updating a Text Model
///
/// - ``Proxy/insert(_:at:)-4pr84``
/// - ``Proxy/insert(_:at:)-64k5z``
/// - ``Proxy/insert(contentsOf:at:)``
/// - ``Proxy/delete(at:)``
/// - ``Proxy/delete(_:charactersAtIndex:)``
/// - ``Proxy/replaceSubrange(_:with:)-65ff4``
/// - ``Proxy/replaceSubrange(_:with:)-3vg23``
///
/// ### Updating a Table Model
///
/// - ``Proxy/add(_:)``
/// - ``Proxy/row(by:)``
/// - ``Proxy/removeRow(by:)``
///
/// ### Viewing Conflicts in a Document
///
/// - ``Proxy/conflicts(index:)``
/// - ``Proxy/conflicts(dynamicMember:)``
///
/// ### Inspecting a Proxy
///
/// - ``Proxy/objectId``
/// - ``Proxy/subscript(dynamicMember:)-2yow9``
/// - ``Proxy/subscript(dynamicMember:)-9yayd``
/// - ``Proxy/subscript(dynamicMember:)-4p1lt``
/// - ``Proxy/subscript(dynamicMember:)-4irc0``
///
/// ### Converting to a type-erased Proxy
///
/// - ``Proxy/toAny()``

@dynamicMemberLookup
public final class Proxy<Wrapped> {

    init(
        context: Context,
        objectId: ObjectId?,
        path: [Context.KeyPathElement],
        value: @escaping () -> Wrapped?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.valueResolver = value
    }

    init(
        context: Context,
        objectId: ObjectId?,
        path: [Context.KeyPathElement],
        value: @autoclosure @escaping () -> Wrapped?
    ) {
        self.context = context
        self.objectId = objectId
        self.path = path
        self.valueResolver = value
    }
    
    /// The Id of the object this proxy represents.
    public let objectId: ObjectId?
    let context: Context
    let path: [Context.KeyPathElement]
    private let valueResolver: () -> Wrapped?

    let objectDecoder = ObjectDecoder()
    let objectEncoder = ObjectEncoder()
    
    /// Returns the current instance of your document's model.
    public func get() -> Wrapped {
        return valueResolver()!
    }

    private var map: Map {
        guard case .map(let map)? = objectId.map({ context.getObject(objectId: $0) }) else {
           fatalError("Must be map")
        }

        return map
    }

    /// Returns the current value of the property using a KeyPath you provide to your model.
    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y>) -> Proxy<Y> {
        let fieldName = dynamicMember.fieldName!

        let objectId = map[fieldName]?.objectId
        return Proxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }
    
    /// Returns the current value of the optional property using a KeyPath you provide to your model.
    public subscript<Y>(dynamicMember dynamicMember: KeyPath<Wrapped, Y?>) -> Proxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        let objectId = map[fieldName]?.objectId
        return Proxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }

    /// Returns a mutable proxy to a property in your model at the writable KeyPath you provide.
    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<Wrapped, Y>) -> MutableProxy<Y> {
        let keyPath: KeyPath = dynamicMember as KeyPath
        let fieldName = keyPath.fieldName!

        let objectId = map[fieldName]?.objectId
        return MutableProxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }

    /// Returns an mutable proxy to an optional property in your model at the writable KeyPath you provide.
    public subscript<Y>(dynamicMember dynamicMember: WritableKeyPath<Wrapped, Y?>) -> MutableProxy<Y>? {
        let fieldName = dynamicMember.fieldName!
        let objectId = map[fieldName]?.objectId
        return MutableProxy<Y>(
            context: context,
            objectId: objectId,
            path: path + [.init(key: .string(fieldName), objectId: objectId)],
            value: self.valueResolver()?[keyPath: dynamicMember]
        )
    }
    
    func set(newValue: Object) {
        guard let lastPathKey = path.last?.key else {
            if case .map(let root) = newValue {
                set(rootObject: root)
            }
            return
        }
        switch lastPathKey {
        case .string(let key):
            let path = Array(self.path.dropLast())
            context.setMapKey(path: path, key: key, value: newValue)
        case .index(let index):
            let path = Array(self.path.dropLast())
            context.setListIndex(path: path, index: index, value: newValue)
        }
    }
    
    func set(rootObject: Map) {
        for (key, value) in rootObject {
            context.setMapKey(path: path, key: key, value: value)
        }
    }
    
}
