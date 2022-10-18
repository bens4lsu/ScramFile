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
    
    private struct HomeContext: Encodable {
        var title: String
        var fileProps: [FileProp]
        var availableRepos: [RepoListing]
        var showRepoSelector: Bool
        var showAdmin: Bool
        var pathAtTop: [FileProp]
        var hostInfo: Host
        var isWritable: Bool
        var version: String
    }

    private struct FileProp: Encodable {
        var name: String
        var modified: Date?
        var isDirectory: Bool
        var size: String?
        var link: String
        var allowDeletes: Bool
    }
    
    private struct FilePointer: Codable {
        var directory: String
        var fileName: String
        var isDirectory: Bool = true
        
        var filepath: String { self.directory + "/" + self.fileName }
        var url: URL? { return URL(fileURLWithPath: filepath) }
        
        func encoded() throws -> String {
            let encoder  = JSONEncoder()
            let data = try encoder.encode(self)
            return data.base64EncodedString()
        }
    }
    
    struct RepoListing: Content {
        var repoId: UUID
        var repoName: String
        var isSelected: Bool
        var repoFolder: String
        var accessLevel: AccessLevel
    }
    
    private let fileManager = FileManager.default
    private let settings: ConfigurationSettings
    private let hostController = HostController()
    
    static let urlRootString = "list"
    static var urlRoot: String {"/\(urlRootString)"}
    static var urlRootPath: PathComponent {PathComponent(stringLiteral: urlRootString)}
    
        
    init(_ settings: ConfigurationSettings) {
        self.settings = settings
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.get(Self.urlRootPath, use: renderHome)
        routes.get("download", ":filePointer", use: streamFile)
        routes.get("changeRepo", ":newRepo", use: changeRepo)
        routes.get("folderUp", use: folderUp)
        routes.get("folder", ":newFolder", use: goIntoFolder)
        routes.get("folderdir", ":newFolder", use:goToFolder)
        routes.get("top", use: folderTop)
        routes.post("createFolder", use: createFolder)
        routes.post("delete", use: delete)
        
        routes.on(.POST, "upload", body: .collect(maxSize: ByteCount(stringLiteral: settings.maxFileSize)), use: upload)
    }
    
    
    // MARK: Request handlers
    
    func renderHome(_ req: Request) async throws -> View {
        let repoContextAll = try await repoContext(req)
        let repoContext = repoContextAll.filter { $0.accessLevel != .none }
            
        let currentRepo = repoContext.filter{$0.isSelected}.first ?? repoContext[0]
        SessionController.setCurrentRepo(req, currentRepo.repoId)
        
        let access = SessionController.getAccessLevelToCurrentRepo(req)
        guard access == .read || access == .full else {
            let uid = (try? SessionController.getUserId(req)?.uuidString) ?? "nil"
            throw Abort(.unauthorized, reason: "User does not have access to this repository.  uid = \(uid)   repoid = \(currentRepo)")
        }
        
        let directory = try await self.findDirectory(on: req, for: currentRepo)
        let contents = try self.directoryContents(on: req, for: directory)
        
        let isWriteable = SessionController.getAccessLevelToCurrentRepo(req) == .full
        let showSelector = repoContext.count > 1
        let version = try Version().versionLong
        let pathAtTop = try self.folderHeirarchy(req)
        let host = try await hostController.getHostContext(req)
        let context = HomeContext(title: "Secure File Repository:  \(currentRepo.repoName)", fileProps: contents, availableRepos: repoContext, showRepoSelector: showSelector, showAdmin: SessionController.getIsAdmin(req), pathAtTop: pathAtTop, hostInfo: host, isWritable: isWriteable, version: version)
        return try await req.view.render("index", context)
    }
    
    
    public func streamFile(_ req: Request) throws -> EventLoopFuture<Response> {
        let fp = try decodeFilePointer(req, parameter: "filePointer")
        let filepath = fp.directory + "/" + fp.fileName
        let response = req.fileio.streamFile(at: filepath)
        response.headers.add(name: "content-disposition", value: "attachment; filename=\"\(fp.fileName)\"")
        return req.eventLoop.makeSucceededFuture(response)
    }
    
    
    public func changeRepo(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let string = req.parameters.get("newRepo"),
              let newRepoId = UUID(uuidString: string) else {
            throw Abort(.badRequest, reason: "Invalid repo identifier requested.")
        }
        SessionController.setCurrentRepo(req, newRepoId)
        SessionController.setCurrentSubfolder(req, nil)
        return req.eventLoop.makeSucceededFuture(req.redirect(to: Self.urlRoot))
    }
    
    
    public func upload(_ req: Request) async throws -> Response {
        struct Input: Content {
            var file: File
        }
        
        guard SessionController.getAccessLevelToCurrentRepo(req) == .full else {
            throw Abort(.unauthorized, reason: "User does not have write access to this repository.")
        }
        
        let input = try req.content.decode(Input.self)
        let repoListing = try await currentRepoContext(req)
        guard let repo = repoListing else{
            throw Abort(.internalServerError, reason: "Could not determine a current repository context.")
        }
        
        let path = try await self.findDirectory(on: req, for: repo)
        let newfile = path + "/" + input.file.filename
        return try await req.application.fileio.openFile(path: newfile, mode: .write, flags: .allowFileCreation(posixMode: 0x744), eventLoop: req.eventLoop).flatMap { handle in
            return req.application.fileio.write(fileHandle: handle, buffer: input.file.data, eventLoop: req.eventLoop).flatMapThrowing { _ in
                try handle.close()
                return req.redirect(to: Self.urlRoot)
            }
        }.get()
    }
    
    public func createFolder(_ req: Request) async throws -> Response {
        struct FolderPost: Codable {
            var newFolder: String
        }
        
        guard SessionController.getAccessLevelToCurrentRepo(req) == .full else {
            throw Abort(.unauthorized, reason:  "User does not have write access to this repository.")
        }
        
        let newFolder = try req.content.decode(FolderPost.self).newFolder
        
        guard newFolder.count >= 1 else {
            throw Abort(.badRequest, reason: "Invalid folder identifier requested: \(newFolder)")
        }
        
        let repoListing = try await currentRepoContext(req)
        guard let repoListing = repoListing else {
            throw Abort(.badRequest, reason: "Invalid repo specified for new folder.")
        }
        let dir = try await self.findDirectory(on: req, for: repoListing) + "/" + newFolder
        try self.fileManager.createDirectory(atPath: dir, withIntermediateDirectories: false, attributes: nil)
        return req.redirect(to: Self.urlRoot)
    }
    
    
    func delete(_ req: Request) async throws -> Response {
        struct FPPost: Codable {
            var pointers: [String]
        }
        
        guard SessionController.getAccessLevelToCurrentRepo(req) == .full else {
            throw Abort(.unauthorized, reason:  "User does not have write access to this repository.")
        }
        
        let repoListing = try await currentRepoContext(req)
        guard repoListing != nil else{
            throw Abort(.internalServerError, reason: "Could not determine a current repository context.")
        }
        
        let pointers = try req.content.decode(FPPost.self).pointers
        for pointer in pointers {
            let decodedPointer = try self.decodeFilePointer(pointer)
            guard let fp = decodedPointer, let url = fp.url else {
                throw Abort(.badRequest, reason: "Delete requested for a key that is not a valid file pointer.")
            }
            try self.fileManager.removeItem(at: url)
        }
        return req.redirect(to: Self.urlRoot)
    }

    
    // MARK:  Folder Navigation
    
    public func folderUp(_ req: Request) throws -> EventLoopFuture<Response> {
        subfolderPop(req)
        return req.eventLoop.makeSucceededFuture(req.redirect(to: Self.urlRoot))
    }
    
    public func folderTop(_ req: Request) throws -> EventLoopFuture<Response> {
        SessionController.setCurrentSubfolder(req, nil)
        return req.eventLoop.makeSucceededFuture(req.redirect(to: Self.urlRoot))
    }
    
    public func goIntoFolder(_ req: Request) throws -> EventLoopFuture<Response> {
        let fp = try decodeFilePointer(req, parameter: "newFolder")
        var folder = (SessionController.getCurrentSubfolder(req) ?? "").replacingOccurrences(of: "//", with: "/")
        if folder != "" {
            folder += "/"
        }
        folder = folder + fp.fileName
        SessionController.setCurrentSubfolder(req, folder)
        return req.eventLoop.makeSucceededFuture(req.redirect(to: Self.urlRoot))
    }
    
    public func goToFolder(_ req: Request) throws -> EventLoopFuture<Response> {
        let fp = try decodeFilePointer(req, parameter: "newFolder")
        SessionController.setCurrentSubfolder(req, fp.directory)
        return req.eventLoop.makeSucceededFuture(req.redirect(to: Self.urlRoot))
    }

    
    // MARK:  Futures that help build the results for the public methods.
    
    private func repoContext(_ req: Request) async throws -> [RepoListing]{
        guard let userRepos = SessionController.getRepoAcccessList(req) else {
            throw Abort(.forbidden, reason: "User does not have repository access.")
        }
        var repoListing = [RepoListing]()
        for userRepo in userRepos {
            
            let isSelected = userRepo.repoId == SessionController.getCurrentRepo(req)
            repoListing.append(RepoListing(repoId: userRepo.repoId, repoName: userRepo.repoName, isSelected: isSelected, repoFolder: userRepo.repoFolder, accessLevel: userRepo.accessLevel))
        }
        return repoListing.sorted(by: \.repoName)
        
    }
    
    
    // MARK: Private helper methods

    private func directoryContents(on req: Request, for directory: String) throws -> [FileProp] {
        let files = try self.fileManager.contentsOfDirectory(atPath: directory)
        var dirList = [FileProp]()
        for file in files {
            let filePath = directory + "/" + file
            let attribs = try self.fileManager.attributesOfItem(atPath: filePath)
            let modDate = attribs[.modificationDate] as? Date
            let fileType = attribs[.type] as? Foundation.FileAttributeType
            let isDirectory = (fileType?.rawValue ?? "zz") == "NSFileTypeDirectory"
            let fileSize = attribs[.size] as? UInt64 ?? UInt64(0)
            let fileSizeFormatted = isDirectory ? "-" : ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            let filePointer = try FilePointer(directory: directory, fileName: file, isDirectory: isDirectory).encoded()
            let link = isDirectory ? "folder/" + filePointer : "download/" + filePointer
            let listItem = FileProp(name: file, modified: modDate, isDirectory: isDirectory, size: fileSizeFormatted, link: link, allowDeletes: true)
            dirList.append(listItem)
        }
        if SessionController.getCurrentSubfolder(req) != nil {
            dirList.append(FileProp(name: "..", modified: Date(), isDirectory: true, size: "-", link: "folderUp", allowDeletes: false))
        }
        return dirList.sorted(by: \.isDirectory, thenBy: \.name)
    }
    
    
    private func findDirectory(on req: Request, for repo: RepoListing) async throws -> String {
        //let host = try await hostController.getHostContext(req)
        let directory = req.application.directory.resourcesDirectory + "Repos/" + repo.repoFolder
        guard let sub = SessionController.getCurrentSubfolder(req) else {
            return directory
        }
        return directory + "/" + sub
    }
    
    private func subfolderPop(_ req: Request) {
        guard let path = SessionController.getCurrentSubfolder(req) else {
            return
        }
        let updated = path.everythingBeforeLastOccurence(of: "/")
        SessionController.setCurrentSubfolder(req, updated)
        return
    }
    
    
    private func currentRepoContext(_ req: Request) async throws -> RepoListing? {
        return try await repoContext(req).filter{$0.isSelected}.first
    }
    
    private func folderHeirarchy(_ req: Request) throws ->  [FileProp] {
        guard let subfolderString = SessionController.getCurrentSubfolder(req) else {
            return []
        }
        var properties = [FileProp]()
        let folder = subfolderString.components(separatedBy: "/")
        for i in (0...(folder.count - 1)) {
            var path1 = ""
            for j in (0...i){
                if path1 != "" {
                    path1 += "/"
                }
                path1 += folder[j]
            }
            let pointer = try "/folderdir/" + FilePointer(directory: path1, fileName: folder[i], isDirectory: true).encoded()
            let fp = FileProp(name: folder[i], modified: nil, isDirectory: true, size: nil, link: pointer, allowDeletes: false)
            properties.append(fp)
        }
        return properties
    }
    
    private func decodeFilePointer(_ req: Request, parameter: String) throws -> FilePointer {
        guard let filePointer = req.parameters.get(parameter),
              let decoded = try decodeFilePointer(filePointer)
        else {
            throw Abort(.badRequest, reason: "Invalid file requested: \(parameter)")
        }
        return decoded
    }
    
    private func decodeFilePointer(_ str: Codable) throws -> FilePointer? {
        guard let string = str as? String,
              let data = Data(base64Encoded: string) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(FilePointer.self, from: data)
    }

}
