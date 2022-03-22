//
//  File.swift
//  
//
//  Created by Ben Schultz on 2/17/21.
//

import Foundation
import Vapor
import Fluent
import FluentMySQLDriver

class AdminController: RouteCollection {
    
    
    private struct AdminUserContext: Content {
        var host: Host
        var users: [User.UserContext]
        var hideRepoSelector:Bool = true
        var availableRepos: [ContentController.RepoListing] = []
    }
    
    struct AdminRepoTreeBranch: Content, Comparable {
        var hostId: UUID
        var hostName: String
        var repoId: UUID
        var repoName: String
        var accessLevel: AccessLevel
        var newTree: Bool
        
        static func < (lhs: AdminController.AdminRepoTreeBranch, rhs: AdminController.AdminRepoTreeBranch) -> Bool {
            if lhs.hostName == rhs.hostName {
                return lhs.repoName < rhs.repoName
            }
            return lhs.hostName < rhs.hostName
        }
        
    }
    
    private struct AdminSingleUserContext: Content {
        var user: User.UserContext
        var accessList: [AdminRepoTreeBranch]
    }
    

    func boot(routes: RoutesBuilder) throws {
        routes.get("admin", use: renderUserList)
        routes.post("adminDetails", use: getSingleUser)
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
        let context = AdminSingleUserContext(user: user, accessList: accessTree)
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
