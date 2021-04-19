//
//  Proxy+Root.swift
//  Automerge
//
//  Created by Lukas Schmidt on 03.06.20.
//

import Foundation

extension Proxy {
    static func rootProxy<T>(context: Context) -> Proxy<T> {
        return Proxy<T>(context: context, objectId: ROOT_ID, path: [], value: {
            let object = context.getObject(objectId: ROOT_ID)
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            let json = try! encoder.encode(object)
            return try! decoder.decode(T.self, from: json)
        })
    }
}
