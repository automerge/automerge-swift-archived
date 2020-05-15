//
//  File 2.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public struct Request: Equatable, Codable {

    public enum RequestType: String, Codable {
        case change
        case redo
        case undo
    }


    public var requestType: RequestType
    public var message: String
    public var time: Date
    public var actor: String
    public var seq: Int
    public var version: Int
    public var ops: [Op]
    var undoable: Bool

}
