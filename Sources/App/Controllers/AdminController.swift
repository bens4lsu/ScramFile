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
        var hostId: UUID
        var hostName: String
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
    
    private struct AdminHostList: Content, Comparable {
        var hostId: UUID
        var hostName: String
        var repos: [AdminRepoList]
        
        static func < (lhs: AdminController.AdminHostList, rhs: AdminController.AdminHostList) -> Bool {
            lhs.hostName < rhs.hostName
        }
    }
    
    private struct AdminSingleUserContext: Content {
        var user: User.UserContext
        var accessList: [AdminHostList]
    }
    

    func boot(routes: RoutesBuilder) throws {
        routes.get("admin", use: renderUserList)
        routes.post("adminUDetails", use: getSingleUser)
    }
    
    func renderUserList(_ req: Request) async throws -> View {
        async let users = User.query(on: req.db).all().map { try $0.userContext() }
        
        guard let userId = try? SessionController.getUserId(req) else {
            throw Abort (.internalServerError, reason: "Can not use Admin when there is no user in session.")
        }
        
        guard let currentUser = try? await User.find(userId, on: req.db) else {
            throw Abort (.internalServerError, reason: "No user found during attempt to load admin page.")
        }
        
        guard let host = try? await Host.find(currentUser.hostId, on:req.db) else {
            throw Abort (.internalServerError, reason: "User associated with an invalid Host.")
        }
        
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
        
        let accessTree = try await MySQLDirect().getRepoListForUser(req, userId: userId)
        let hosts = Set(accessTree.map { $0.hostId })
        var list = [AdminHostList]()
        for host in hosts {
            let hostName = accessTree.filter { $0.hostId == host }.first!.hostName
            var adminHostList = AdminHostList(hostId: host, hostName: hostName, repos: [])
            let repos = Set(accessTree.filter { $0.hostId == host }.map { $0.repoId })
            for repo in repos {
                let branch = accessTree.filter { $0.repoId == repo && $0.hostId == host }.first!
                let access = branch.accessLevel
                let repoName = branch.repoName
                adminHostList.repos.append(AdminRepoList(repoId: repo, repoName: repoName, accessLevel: access))
            }
            list.append(adminHostList)
        }
        
        let context = AdminSingleUserContext(user: user, accessList: list)
        return try await context.encodeResponse(for: req)
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
