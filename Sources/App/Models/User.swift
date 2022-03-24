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
    
    struct UserContext: Content, Encodable {
        var id: UUID
        var userName: String
    }
    
    func userContext() throws -> User.UserContext {
        guard let id = self.id else {
            throw Abort(.internalServerError, reason: "Attempt to retrieve contet for user with no id.")
        }
        return UserContext(id: id, userName: self.userName)
    }

}
