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
    
    @Field(key: "isAdmin")
    var isAdmin: Bool
    
    @Field(key: "emailAddress")
    var emailAddress: String
    
    @Field(key: "passwordHash")
    var passwordHash: String
    
    @Field(key: "isActive")
    var isActive: Bool
    
    init() { }
    
    init (userName: String, isAdmin: Bool, emailAddress: String, isActive: Bool, passwordHash: String) {
        self.userName  = userName
        self.isAdmin = isAdmin
        self.emailAddress = emailAddress
        self.isActive = isActive
        self.passwordHash = passwordHash
    }
    
    struct UserContext: Content, Encodable, Comparable {
        var id: UUID
        var userName: String
        var emailAddress: String
        var isActive: Bool
        var isAdmin: Bool
        
        static func < (lhs: UserContext, rhs: UserContext) -> Bool {
            lhs.userName < rhs.userName
        }
        
        static func == (lhs: UserContext, rhs: UserContext) -> Bool {
            lhs.userName == rhs.userName
        }
    }
    
    func userContext() throws -> User.UserContext {
        guard let id = self.id else {
            throw Abort(.internalServerError, reason: "Attempt to retrieve contet for user with no id.")
        }
        return UserContext(id: id, userName: self.userName, emailAddress: self.emailAddress, isActive: self.isActive, isAdmin: self.isAdmin)
    }

}
