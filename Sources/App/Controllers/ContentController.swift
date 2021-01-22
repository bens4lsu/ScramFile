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
    
    let fileManager = FileManager.default
    
    let userId = UUID(uuidString: "DCBE4EAA-5CAF-11EB-A925-080027363641")!
        
    func boot(routes: RoutesBuilder) throws {
        routes.get("xxx", use: renderHome)
    }
    
    
    func renderHome(_ req: Request) throws -> EventLoopFuture<View> {
        return UserRepo.query(on: req.db).filter(\.$userId == self.userId).all().flatMap { userRepos in
            do {
                if userRepos.count == 1 {
                    return try self.renderRepoDirectory(req, userRepos[0].repoId)
                }
                else if userRepos.count > 1 {
                    return try self.renderRepoListing(req, userRepos)
                }
                else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "User does not have access to any file repositories."))
                }
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    
    func renderRepoDirectory(_ req: Request, _ repoId: UUID) throws -> EventLoopFuture<View> {
        
        struct FileProp: Encodable {
            var name: String
            var modified: Date?
            var isDirectory: Bool
            var size: String
        }
        
        return Repo.query(on: req.db).filter(\.$id == repoId).first().flatMapThrowing { repo in
            guard let repo = repo else {
                throw Abort(.internalServerError, reason: "Request to display contents of repository, but with an invalid repository identifier.")
            }
            let directory = req.application.directory.resourcesDirectory + "/Repos/" + repo.repoFolder
            let files = try self.fileManager.contentsOfDirectory(atPath: directory)
            var dirList = [FileProp]()
            for file in files {
                let filePath = directory + "/" + file
                let attribs = try self.fileManager.attributesOfItem(atPath: filePath)
                let fileSize = attribs[.size] as? UInt64 ?? UInt64(0)
                let fileSizeFormatted = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                let modDate = attribs[.modificationDate] as? Date
                let fileType = attribs[.type] as? String
                let listItem = FileProp(name: file, modified: modDate, isDirectory: fileType == "NSFileTypeDirectory", size: fileSizeFormatted)
                dirList.append(listItem)
            }
            return try req.view.render("index",dirList).wait()
        }
    }
    
    func renderRepoListing(_ req: Request, _ repos: [UserRepo]) throws -> EventLoopFuture<View> {
        return req.view.render("repoListing")
    }
    
    
}
