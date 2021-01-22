//
//  ContentController.swift
//  App
//
//  Created by Ben Schultz on 1/21/21.
//

import Foundation
import Vapor
import Leaf
import Fluent
import FluentMySQLDriver

class ContentController: RouteCollection {
    
    let userId = 1
        
    func boot(routes: RoutesBuilder) throws {
        routes.get("", use: renderRepoDirectory(req, 1))
    }
    
    
    func renderHome(_ req: Request) throws -> EventLoopFuture<View> {
        return UserRepo.query(on: req.db).filter(\.$userId == self.userId).all().flatMap { userRepos in
            if userRepos.count > 1 {
                return self.renderRepoDirectory(req, userRepos[0].repoId)
            }
            return self.renderRepoListing(req, userRepos)
        }
    }
    
    
    func renderRepoDirectory(_ req: Request, _ repoId: Int) -> EventLoopFuture<View> {
        
        return Repo.query(on: req.db).filter(\.$id == repoId).first().map { repo in
            guard let repo = repo else {
                Abort(.internalServerError, reason: "Request to display contents of repository, but with an invalid repository identifier.")
            }
            let directory = req.application.directory.resourcesDirectory + "/Resources/Repos/" + repo.repoFolder
            
            let fileManager = FileManager.default
            let files = fileManager.contentsOfDirectory(atPath: directory)
            
            
        }
        
        
        return req.view.render("repoDirectory")
    }
    
    func renderRepoListing(_ req: Request, _ repos: [UserRepo]) -> EventLoopFuture<View> {
        return req.view.render("repoListing")
    }
    
    
}
