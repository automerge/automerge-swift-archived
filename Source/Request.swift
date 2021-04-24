//
//  File 2.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public struct Request: Equatable, Codable {

    let startOp: Int
    let deps: [ObjectId]
    let message: String
    let time: Date
    let actor: Actor
    let seq: Int
    let ops: [Op]

}
