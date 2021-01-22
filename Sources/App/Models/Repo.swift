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
    
    typealias IDValue = Int
    
    static var schema = "tblRepos"
    
    @ID(custom: "repoId")
    var id: Int?

    @Field(key: "repoFolder")
    var repoFolder: String

    @Field(key: "repoName")
    var repoName: String

    @Field(key: "hostId")
    var hostId: Int
    
    @Field(key: "userEncryptionKey")
    var userEncryptionKey: String
    
    init() { }

}
