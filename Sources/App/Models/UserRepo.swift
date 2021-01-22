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
    //typealias IDValue = type
    
    static let schema = "tblUserRepos"
    
    @ID(key: "userRepoId")
    var id: Int?
    
    @Field(key: "userId")
    var userId: Int

    @Field(key: "repoId")
    var repoId: Int

    @Field(key: "accessLevel")
    var accessLevel: AccessLevel
    
    init() { }

}

