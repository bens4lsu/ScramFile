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
    
    struct HomeContext: Encodable {
        var title: String
        var fileProps: [FileProp]
        var availableRepos: [RepoListing]
        var showRepoSelector: Bool
        var showAdmin: Bool
    }

    struct FileProp: Encodable {
        var name: String
        var modified: Date?
        var isDirectory: Bool
        var size: String?
        var link: String
        var allowDeletes: Bool
    }
    
    struct FilePointer: Codable {
        var directory: String
        var fileName: String
        var isDirectory: Bool
        
        func encoded() throws -> String {
            let encoder  = JSONEncoder()
            let data = try encoder.encode(self)
            return data.base64EncodedString()
        }
    }
    
    struct RepoListing: Encodable {
        var repoId: UUID
        var repoName: String
        var isSelected: Bool
        var repoFolder: String
    }
    
    let fileManager = FileManager.default
        
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("x", use: renderHome)
        routes.get("download", ":filePointer", use: streamFile)
        routes.get("changeRepo", ":newRepo", use: changeRepo)
        routes.get("folderUp", use: folderUp)
        routes.get("folder", ":newFolder", use: newFolder)
    }
    

    private func directoryContents(on req: Request, for directory: String) throws -> [FileProp] {
        let files = try self.fileManager.contentsOfDirectory(atPath: directory)
        var dirList = [FileProp]()
        for file in files {
            let filePath = directory + "/" + file
            let attribs = try self.fileManager.attributesOfItem(atPath: filePath)
            let modDate = attribs[.modificationDate] as? Date
            let fileType = attribs[.type] as? String
            let isDirectory = fileType == "NSFileTypeDirectory"
            let fileSize = attribs[.size] as? UInt64 ?? UInt64(0)
            let fileSizeFormatted = isDirectory ? "-" : ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            let filePointer = try FilePointer(directory: directory, fileName: file, isDirectory: isDirectory).encoded()
            let link = isDirectory ? "folder/" + filePointer : "download/" + filePointer
            let listItem = FileProp(name: file, modified: modDate, isDirectory: isDirectory, size: fileSizeFormatted, link: link, allowDeletes: true)
            dirList.append(listItem)
        }
        if SessionController.currentSubfolder(req) != nil {
            dirList.append(FileProp(name: "..", modified: Date(), isDirectory: true, size: "-", link: "folderUp", allowDeletes: false))
        }
        return dirList
    }
    
    
    private func findDirectory(on req: Request, for repo: RepoListing) -> String {
        let directory = req.application.directory.resourcesDirectory + "Repos/" + repo.repoFolder
        guard let sub = SessionController.currentSubfolder(req) else {
            return directory
        }
        return directory + "/" + sub
    }
    
    private func subfolderPush(_ req: Request, _ new: String) {
        guard let path = SessionController.currentSubfolder(req) else {
            SessionController.setCurrentSubfolder(req, new)
            return
        }
        SessionController.setCurrentSubfolder(req, path + "/" + new)
    }
    
    private func subfolderPop(_ req: Request) {
        guard let path = SessionController.currentSubfolder(req) else {
            return
        }
        if let range = path.range(of: "/", options: .backwards) {
            let updated = String(path[range])
            SessionController.setCurrentSubfolder(req, updated)
            return
        }
        SessionController.setCurrentSubfolder(req, nil)
    }
    
    private func repoContext(_ req: Request) throws -> EventLoopFuture<[RepoListing]>{
        return UserRepo.query(on: req.db).filter(\.$userId == SessionController.userId(req)).join(Repo.self, on: \UserRepo.$repoId == \Repo.$id).all().flatMapThrowing { userRepos in
            guard userRepos.count >= 1 else {
                throw Abort(.notFound, reason: "User does not have access to any file repositories.")
            }
            
            var repoListing = [RepoListing]()
            for userRepo in userRepos {
                let repo = try userRepo.joined(Repo.self)
                
                guard let id = repo.id else {
                    throw Abort(.internalServerError, reason: "Unwrapped repo id problem.  This really can't happen")
                }
                
                let isSelected = repo.id == SessionController.currentRepo(req)
                repoListing.append(RepoListing(repoId: id, repoName: repo.repoName, isSelected: isSelected, repoFolder: repo.repoFolder))
            }
            return repoListing.sorted(by: \.repoName)
        }
    }


    // MARK: Request handlers
    
    func renderHome(_ req: Request) throws -> EventLoopFuture<View> {
        return try repoContext(req).flatMap { repoContext in
            do {
                let currentRepo = repoContext.filter{$0.isSelected}.first ?? repoContext[0]
                
                let directory = self.findDirectory(on: req, for: currentRepo)
                let contents = try self.directoryContents(on: req, for: directory)
                let showSelector = repoContext.count > 1
                let context = HomeContext(title: "Secure File Repository:  \(currentRepo.repoName)", fileProps: contents, availableRepos: repoContext, showRepoSelector: showSelector, showAdmin: SessionController.isAdmin(req))
                return req.view.render("index", context)
            }
            catch {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "failure in RenderHome method."))
            }
        }
    }
    
    
    public func streamFile(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let filePointer = req.parameters.get("filePointer"),
              let data = Data(base64Encoded: filePointer)
        else {
            throw Abort(.badRequest, reason: "Invalid file requested.")
        }
        let decoder = JSONDecoder()
        let fp = try decoder.decode(FilePointer.self, from: data)
        let filepath = fp.directory + "/" + fp.fileName
        let response = req.fileio.streamFile(at: filepath)
        response.headers.add(name: "content-disposition", value: "attachment; filename=\"\(fp.fileName)\"")
        return req.eventLoop.makeSucceededFuture(response)
    }
    
    
    public func changeRepo(_ req: Request) throws -> EventLoopFuture<View> {
        guard let string = req.parameters.get("newRepo"),
              let newRepoId = UUID(uuidString: string) else {
            throw Abort(.badRequest, reason: "Invalid repo identifier requested.")
        }
        
        SessionController.setCurrentRepo(req, newRepoId)
        return try renderHome(req)
    }
    
    
    public func folderUp(_ req: Request) throws -> EventLoopFuture<View> {
        subfolderPop(req)
        return try renderHome(req)
    }
    
    
    public func newFolder(_ req: Request) throws -> EventLoopFuture<View> {
        guard let filePointer = req.parameters.get("newFolder"),
              let data = Data(base64Encoded: filePointer)
        else {
            throw Abort(.badRequest, reason: "Invalid file requested.")
        }
        let decoder = JSONDecoder()
        let fp = try decoder.decode(FilePointer.self, from: data)
        SessionController.setCurrentSubfolder(req, fp.fileName)
        return try renderHome(req)
    }
}
