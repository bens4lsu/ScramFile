//
//  File.swift
//
//
//  Created by Ben Schultz on 8/24/20.
//

import Vapor
import Fluent
import FluentMySQLDriver

final class User: Model, Content, Codable {
    static let schema = "tblUsers"
    
    @ID(custom: "userId")
    var id: Int?

    @Field(key: "userName")
    var userName: String

    @Field(key: "hostId")
    var hostId: Int
    
    init() { }

}
