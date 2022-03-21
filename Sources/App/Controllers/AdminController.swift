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
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("admin", use: renderAdmin)
        routes.post("admin", "user", ":userId", use: getSingleUser)
    }
    
    func renderAdmin
    
    
    
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
