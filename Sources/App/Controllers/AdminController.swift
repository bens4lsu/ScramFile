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
        var host: Host
        var users: [User.UserContext]
        var hideRepoSelector:Bool = true
        var availableRepos: [ContentController.RepoListing] = []
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
    

    func boot(routes: RoutesBuilder) throws {
        routes.get("admin", use: renderUserList)
        routes.post("adminUDetails", use: getSingleUser)
        routes.post("adminChangeAccess", use: changeAccess)
        routes.post("adminCreateRepo", use: createNewRepo)
        routes.post("adminUpdateUser", use: updateUser)
    }
    
    func renderUserList(_ req: Request) async throws -> View {
        async let users = User.query(on: req.db).all().map { try $0.userContext() }
        
        guard let userId = try? SessionController.getUserId(req) else {
            throw Abort (.internalServerError, reason: "Can not use Admin when there is no user in session.")
        }
        
        let host = try await HostController().getHostContext(req)
        
        let context = AdminUserContext(host: host, users: try await users)
        return try await req.view.render("admin-user", context)
    }
    
    
    func getSingleUser(_ req: Request) async throws -> Response {
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
        return try await accessListForUser(req, userId: userId).encodeResponse(for: req)

    }
    
    func updateUser(_ req: Request) async throws -> Response {
        struct UpdateUserPost: Codable {
            var userId: String?
            var userName: String?
            var emailAddress: String?
            var isActive: String?
            var isAdmin: String?
        }
        
        guard let input = try? req.content.decode(UpdateUserPost.self),
              let userIdStr = input.userId,
              let userId = UUID(uuidString: userIdStr),
              let userName = input.userName,
              let emailAddress = input.emailAddress,
              let user = try? await User.find(userId, on: req.db)
        else {
            throw Abort(.badRequest, reason: "Invalid input to update request.")
        }
        
        print(input)
        let isActive = input.isActive == "true"
        let isAdmin = input.isAdmin == "true"
        user.userName = userName
        user.emailAddress = emailAddress
        user.isAdmin = isAdmin
        user.isActive = isActive
        print(user)
        try await user.save(on: req.db)
        return try req.redirect(to: "/admin")
    }
    
    
    private func accessListForUser(_ req: Request, userId: UUID) async throws -> [AdminRepoList] {
        let accessTree = try await MySQLDirect().getRepoListForUser(req, userId: userId)
        var list = [AdminRepoList]()
        let repos = Set(accessTree.map { $0.repoId })
        print(access)
        for repo in repos {
            let branch = accessTree.filter { $0.repoId == repo}.first!
            let access = branch.accessLevel
            let repoName = branch.repoName
            list.append(AdminRepoList(repoId: repo, repoName: repoName, accessLevel: access))
        }
        return list.sorted()
    }
    
    
    
}
//
//    struct UserRepoContext: Codable, Content {
//        var repoId: UUID
//        var repoName: String
//        var accessLevel: AccessLevel
//    }
//
//    struct UserContext: Codable, Content {
//
//    }
//
//

//
//    func getUserList(_ req: Request) -> EventLoopFuture<View> {
//        struct AdminUserContext: Encodable {
//            var userList: [User]
//        }
//
//        return User.query(on: req.db).all().flatMap { users in
//            let context = AdminUserContext(userList: users)
//            return req.view.render("admin-user", context)
//        }
//    }
//
//    func getSingleUser(_ req: Request) throws -> EventLoopFuture<[RepoContext]> {
//        struct UserPost: Codable {
//            var userId: String
//        }
//
//        guard let input = try? req.content.decode(UserPost.self),
//              let userId = UUID(uuidString: input.userId) else {
//            throw Abort(.badRequest, reason: "Requested admin access to a user that does not exist.")
//        }
//
//        return UserRepo.query(on: req.db).filter(\.$userId == userId).join(Repo.self, on: \UserRepo.$repoId == \Repo.$id).all().flatMapThrowing { userRepos in
//
//            var repoContext = [RepoContext]()
//            for userRepo in userRepos {
//                let repo = try userRepo.joined(Repo.self)
//                let thisLine = RepoContext(repoId: userRepo.repoId, repoName: repo.repoName, accessLevel: userRepo.accessLevel)
//                repoContext.append(thisLine)
//            }
//            let sorted = repoContext.sorted(by: \.repoName)
//
//            return User.find(userId, on: req.db) { user in
//                guard let user = user else {
//                    throw Abort(.badRequest, reason: "Could not find requested user in database.")
//                }
//
//                return user
//            }
//
//        }
//
//        let userContext: EventLoopFuture<User> = User.find(userId, on: req.db) { user in
//            guard let user = user else {
//                throw Abort(.badRequest, reason: "Could not find requested user in database.")
//            }
//
//            return user
//        }
//
//        return repoContextArray.map { repoContext in
//            return repoContext
//        }.map(
//    }
//}
