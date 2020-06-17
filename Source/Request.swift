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
        case redo
        case undo
    }

    let requestType: RequestType
    let message: String
    let time: Date
    let actor: Actor
    let seq: Int
    let version: Int
    let ops: [Op]
    let undoable: Bool

}
