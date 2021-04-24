//
//  File 2.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public struct Request: Equatable, Codable {

    enum RequestType: String, Codable {
        case change
    }

    let requestType: RequestType
    let startOp: Int
    let deps: [ObjectId]
    let message: String
    let time: Date
    let actor: Actor
    let seq: Int
    let ops: [Op]

}
