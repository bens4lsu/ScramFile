//
//  File 2.swift
//  
//
//  Created by Ben Schultz on 8/24/20.
//

import Vapor
import Fluent
import FluentMySQLDriver

final class UserRepo: Model, Content, Codable {
    
    static let schema = "tblUserRepos"
    
    @ID
    var id: UUID?
    
    @Field(key: "userId")
    var userId: UUID

    @Field(key: "repoId")
    var repoId: UUID

    @Field(key: "accessLevel")
    var accessLevel: AccessLevel
    
    init() { }

}

