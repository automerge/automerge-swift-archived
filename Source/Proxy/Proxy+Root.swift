//
//  Proxy+Root.swift
//  Automerge
//
//  Created by Lukas Schmidt on 03.06.20.
//

import Foundation

extension Proxy {
    static func rootProxy<T: Codable>(context: Context) -> Proxy<T> {
        return Proxy<T>(context: context, objectId: .root, path: [], value: {
            let object = context.getObject(objectId: .root)
            
            return try! ObjectToTypeTransformer().map(object)
        })
    }
}
