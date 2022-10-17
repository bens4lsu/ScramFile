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
    
    func toUserAccessRepoListItem (_ req: Request) -> SecurityController.UserRepoAccess? {
        guard let id = self.id else {
            return nil
        }
        guard let repo = try await Repo.find(self.repoId, on: req.db) else {
            return nil
        }
        
        guard let repoName = repo.repoName,
              let repoFolder = repo.repoFolder
        else {
            return nil
        }
        let ura = SecurityController.UserRepoAccess (repoId: id, accessLevel: self.accessLevel, repoName: repoName, repoFolder: repoFolder)
    }

}

