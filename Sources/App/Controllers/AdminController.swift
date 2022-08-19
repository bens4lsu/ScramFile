//
//  File.swift
//  
//
//  Created by Ben Schultz on 2/17/21.
//

import Foundation
import Vapor
import SQLKit
import FluentMySQLDriver

class AdminController: RouteCollection {
    
    
    private struct AdminUserContext: Content {
        var hostInfo: Host
        var users: [User.UserContext]
        var hideRepoSelector:Bool = true
        var availableRepos: [ContentController.RepoListing] = []
        var version: String
    }
    
    struct AdminRepoTreeBranch: Content {
        var repoId: UUID
        var repoName: String
        var accessLevel: AccessLevel
    }
    
    private struct AdminRepoList: Content, Comparable {
        var repoId: UUID
        var repoName: String
        var accessLevel: AccessLevel
        
        static func < (lhs: AdminController.AdminRepoList, rhs: AdminController.AdminRepoList) -> Bool {
            lhs.repoName < rhs.repoName
        }
    }
    
    private struct AdminSingleUserContext: Content {
        var user: User.UserContext
        var accessList: [AdminRepoList]
    }
    
    let securityController: SecurityController
    
    init(_ securityController: SecurityController) {
        self.securityController = securityController
    }
    

    func boot(routes: RoutesBuilder) throws {
        routes.group("admin") { group in
            group.get(use: renderUserList)
            group.post("uDetails", use: getSingleUser)
            group.post("changeAccess", use: changeAccess)
            group.post("createRepo", use: createNewRepo)
            group.post("updateUser", use: updateUser)
            group.get("getPassword", use: getNewPassword)
            group.post("updatePw", use: updateUserPassword)
        }
    }
    
    func renderUserList(_ req: Request) async throws -> View {
        
        guard SessionController.getIsAdmin(req) else { throw Abort(.forbidden, reason: "User does not have access to administrator functionality.") }
        
        var users = try await User.query(on: req.db).all().map { try $0.userContext() }
        users.sort()
        
        guard let _ = try? SessionController.getUserId(req) else {
            throw Abort (.internalServerError, reason: "Can not use Admin when there is no user in session.")
        }
        
        let host = try await HostController().getHostContext(req)
        let version = try Version().versionLong
        
        let context = AdminUserContext(hostInfo: host, users: users, version: version)
        return try await req.view.render("admin-user", context)
    }
    
    
    func getSingleUser(_ req: Request) async throws -> Response {
        
        guard SessionController.getIsAdmin(req) else { throw Abort(.forbidden, reason: "User does not have access to administrator functionality.") }
        
        struct UserPost: Codable {
            var id: String?
        }

        guard let input = try? req.content.decode(UserPost.self),
              let idString = input.id,
              let userId = UUID(uuidString: idString),
              let user = try await User.find(userId, on: req.db).get()?.userContext()
        else {
            throw Abort(.badRequest, reason: "Requested admin access to a user that does not exist.")
        }
        let list = try await accessListForUser(req, userId: userId)
        let context = AdminSingleUserContext(user: user, accessList: list)
        return try await context.encodeResponse(for: req)
    }
    
    func changeAccess(_ req: Request) async throws -> Response {
        
        guard SessionController.getIsAdmin(req) else { throw Abort(.forbidden, reason: "User does not have access to administrator functionality.") }
        
        struct ChangeAccessPost: Codable {
            var userId: String?
            var accessLevel: String?
            var repoId: String?
        }
        
        guard let input = try? req.content.decode(ChangeAccessPost.self),
              let userIdStr = input.userId,
              let userId = UUID(uuidString: userIdStr),
              let repoIdStr = input.repoId,
              let repoId = UUID(uuidString: repoIdStr),
              let accessLevelStr = input.accessLevel,
              let accessLevel = AccessLevel(rawValue: accessLevelStr)
        else {
            throw Abort(.badRequest, reason: "Invalid input to change access request.")
        }
        
        let ur = UserRepo.query(on: req.db).filter(\.$userId == userId).filter(\.$repoId == repoId)
        if accessLevel == .none {
            try await ur.delete()
        }
        else {
            let id = try await ur.field(\.$id).first()?.id
            let updt = UserRepo(id: id, userId: userId, repoId: repoId, accessLevel: accessLevel)
            print(updt)
            try await updt.save(on: req.db)
        }
        
        return try await "ok".encodeResponse(for: req)
    }
    
    func createNewRepo(_ req: Request) async throws -> Response {
        
        guard SessionController.getIsAdmin(req) else { throw Abort(.forbidden, reason: "User does not have access to administrator functionality.") }
        
        struct NewRepoPost: Codable {
            var newRepoName: String?
        }
        
        guard let input = try? req.content.decode(NewRepoPost.self),
              let newRepoName = input.newRepoName,
              let userId = try SessionController.getUserId(req)
        else {
            throw Abort(.badRequest, reason: "Invalid input to create new repo request.")
        }
        
        guard newRepoName.count >= 3 else {
            throw Abort(.badRequest, reason: "Repository name must be at least 3 characters long.")
        }
        
        let directory = req.application.directory.resourcesDirectory + "Repos/" + newRepoName
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: false, attributes: nil)
        let newRepo = Repo(repoFolder: newRepoName, repoName: newRepoName)
        try await newRepo.save(on: req.db)
        
        var repoList = SessionController.getRepoAcccessList(req) ?? []
        let newEntry = SecurityController.UserRepoAccess(repoId: newRepo.id!, accessLevel: .full, repoName: newRepo.repoName, repoFolder: newRepo.repoFolder)
        repoList.append(newEntry)
        SessionController.setRepoAccesssList(req, repoList)
        
        return try await accessListForUser(req, userId: userId).encodeResponse(for: req)

    }
    
    func updateUser(_ req: Request) async throws -> Response {
        
        guard SessionController.getIsAdmin(req) else { throw Abort(.forbidden, reason: "User does not have access to administrator functionality.") }
        
        struct UpdateUserPost: Codable {
            var userId: String?
            var userName: String?
            var emailAddress: String?
            var isActive: String?
            var isAdmin: String?
        }
        
        
        guard let input = try? req.content.decode(UpdateUserPost.self),
              let userName = input.userName,
              let emailAddress = input.emailAddress
        else {
            throw Abort(.badRequest, reason: "Invalid input to update request.")
        }
        
        var user: User
        let pw = try PWSettings().newPassword()
        if input.userId == nil || input.userId == "" {
            let hash = try Bcrypt.hash(pw)
            user = User(userName: "", isAdmin: false, emailAddress: "", isActive: false, passwordHash: hash)
        }
        else {
            guard let userId = UUID(input.userId!),
                  let userTmp = try await User.find(userId, on: req.db)
            else {
                throw Abort(.badRequest, reason: "Invalid input to update request.")
            }
            user = userTmp
        }
        
        let isActive = input.isActive == "true"
        let isAdmin = input.isAdmin == "true"
        user.userName = userName
        user.emailAddress = emailAddress
        user.isAdmin = isAdmin
        user.isActive = isActive
        try await user.save(on: req.db)
        return try await pw.encodeResponse(for: req)
    }
    
    func getNewPassword(_ req: Request) async throws -> Response {
        let pw = try PWSettings().newPassword()
        return try await pw.encodeResponse(for: req)
    }
    
    func updateUserPassword(_ req: Request) async throws -> HTTPResponseStatus {
        struct UpdatePWPost: Codable {
            var userId: String?
            var pw: String?
        }
        
        guard let input = try? req.content.decode(UpdatePWPost.self),
              let userId = input.userId,
              let pw = input.pw,
              let userIdGuid = UUID(userId)
        else {
            throw Abort(.badRequest, reason: "Invalid input to update password request.")
        }
        
        return try await securityController.changePassword(req, userId: userIdGuid, newPassword: pw)
    }
    
    
    private func accessListForUser(_ req: Request, userId: UUID) async throws -> [AdminRepoList] {
        
        guard SessionController.getIsAdmin(req) else { throw Abort(.forbidden, reason: "User does not have access to administrator functionality.") }
        
        let accessTree = try await MySQLDirect().getRepoListForUser(req, userId: userId)
        var list = [AdminRepoList]()
        let repos = Set(accessTree.map { $0.repoId })
        for repo in repos {
            let branch = accessTree.filter { $0.repoId == repo}.first!
            let access = branch.accessLevel
            let repoName = branch.repoName
            list.append(AdminRepoList(repoId: repo, repoName: repoName, accessLevel: access))
        }
        return list.sorted()
    }
    
}
