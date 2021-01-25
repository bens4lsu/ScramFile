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
    
    @ID
    var id: UUID?

    @Field(key: "userName")
    var userName: String

    @Field(key: "hostId")
    var hostId: UUID
    
    @Field(key: "userEncryptionKey")
    var userEncryptionKey: String
    
    @Field(key: "isAdmin")
    var isAdmin: Bool
    
    @Field(key: "emailAddress")
    var emailAddress: String
    
    @Field(key: "passwordHash")
    var passwordHash: String
    
    @Field(key: "isActive")
    var isActive: Bool
    
    init() { }

}
