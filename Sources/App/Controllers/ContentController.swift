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
    
    struct FileProp: Encodable {
        var name: String
        var modified: Date?
        var isDirectory: Bool
        var size: String?
        var link: String?
        var filePointer: String
    }
    
    struct FileListing: Encodable {
        var title: String
        var fileProps: [FileProp]
        var availableRepos: [Repo]
        var showRepoSelector: Bool
        var showAdmin: Bool
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
    
    let fileManager = FileManager.default
    
    
    // TODO:  This stuff has to come from the session
    let userId = UUID(uuidString: "DCBE4EAA-5CAF-11EB-A925-080027363641")!
    let isAdmin = false
    var currentSubfolder: String? = nil
    var currentRepoId: UUID = UUID()
        
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("x", use: renderHome)
        routes.get("download", ":filePointer", use: streamFile)
        routes.get("changeRepo", ":newRepo", use:changeRepo)
    }
    

    private func directoryContents(for directory: String) throws -> [FileProp] {
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
            let listItem = FileProp(name: file, modified: modDate, isDirectory: isDirectory, size: fileSizeFormatted, filePointer: filePointer)
            dirList.append(listItem)
        }
        return dirList
    }
    
    private func findDirectory(on req: Request, for repo: Repo) -> String {
        let directory = req.application.directory.resourcesDirectory + "/Repos/" + repo.repoFolder
        guard let sub = self.currentSubfolder else {
            return directory
        }
        return directory + "/" + sub
    }


    // MARK: Request handlers
    
    func renderHome(_ req: Request) throws -> EventLoopFuture<View> {
        return UserRepo.query(on: req.db).filter(\.$userId == self.userId).join(Repo.self, on: \UserRepo.$repoId == \Repo.$id).all().flatMap { userRepos in
            do {
                guard userRepos.count >= 1 else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "User does not have access to any file repositories."))
                }
                
                // build list of repositories that the user can access
                let showSelector = userRepos.count > 1
                var repoList = [Repo]()
                for userRepo in userRepos {
                    let repo = try userRepo.joined(Repo.self)
                    repoList.append(repo)
                }
                let sortedList = repoList.sorted(by: \.repoName)
                
                // pick the first repo in their list and display the contents of it.
                
                let currentRepo = sortedList.first {$0.id == self.currentRepoId} ?? sortedList[0]
                let directory = self.findDirectory(on: req, for: currentRepo)
                let contents = try self.directoryContents(for: directory)
                let context = FileListing(title: "Secure File Repository:  \(currentRepo.repoName)", fileProps: contents, availableRepos: sortedList, showRepoSelector: showSelector, showAdmin: self.isAdmin)
                return req.view.render("index", context)
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
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
        if fp.isDirectory {
            self.currentSubfolder = fp.fileName
            return try renderHome(req).encodeResponse(for: req)
        }
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
        
        self.currentRepoId = newRepoId
        return try renderHome(req)
        
    }
}
