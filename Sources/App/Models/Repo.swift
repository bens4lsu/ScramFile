//
//  File.swift
//
//
//  Created by Ben Schultz on 8/24/20.
//

import Vapor
import Fluent
import FluentMySQLDriver

final class Repo: Model, Content, Codable {
        
    static var schema = "tblRepos"
    
    @ID
    var id: UUID?

    @Field(key: "repoFolder")
    var repoFolder: String

    @Field(key: "repoName")
    var repoName: String

//    @Field(key: "hostId")
//    var hostId: UUID
        
    init() { }
    
    init (repoFolder: String, repoName: String) {
        self.id = nil
        self.repoFolder = repoFolder
        self.repoName = repoName
    }

}
