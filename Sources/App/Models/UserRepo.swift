//
//  File 2.swift
//  
//
//  Created by Ben Schultz on 8/24/20.
//

import Vapor
import Fluent
import FluentMySQLDriver
import SQLKit


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
    
    init(id: UUID?, userId: UUID, repoId: UUID, accessLevel: AccessLevel) {
        self.id = id
        self.userId = userId
        self.repoId = repoId
        self.accessLevel = accessLevel
            
        if id != nil {
            self.$id.exists = true  // 2021.11.19 - need this to fool Fluent into understanding
                                    //              that the id property is set.  It was trying
                                    //              to insert where I needed an update.
        }
    }

}

