//
//  File.swift
//  
//
//  Created by Ben Schultz on 1/22/21.
//

import Foundation
import Vapor
import Fluent
import FluentMySQLDriver
import SMTPKitten



class SecurityController: RouteCollection {
    
    struct UserRepoAccess: Codable, Comparable {
        var repoId: UUID
        var accessLevel: AccessLevel
        var repoName: String
        var repoFolder:String
        
        static func < (lhs: SecurityController.UserRepoAccess, rhs: SecurityController.UserRepoAccess) -> Bool {
            lhs.repoName < rhs.repoName
        }
    }
    
    let settings: ConfigurationSettings
    
    var concordMail: ConcordMail {
        ConcordMail(configKeys: settings)
    }
    
    init(_ settings: ConfigurationSettings) {
        self.settings = settings
    }
    
    
    func boot(routes: RoutesBuilder) throws {
        routes.group("security") { group in
            group.get("login", use: renderLogin)
        
            //group.get("create", use: renderUserCreate)
            group.get("change-password", use: renderUserCreate)
            group.get("request-password-reset", use: renderPasswordResetForm)
            group.get("check-email", use: renderCheckEmail)
            group.get("password-reset-process", ":resetString", use: verifyPasswordResetRequest)
            
            group.post("login", use: login)
//            group.post("create", use: createUser)
            //group.post("change-password", use: changePassword)
            group.post("request-password-reset", use: sendPWResetEmail)
            group.post("password-reset-process", ":resetString", use: verifyAndChangePassword)
        }
    }
        
    // MARK:  Methods connected to routes that return Views
    private func renderLogin(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-login")
    }
    
    private func renderUserCreate(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-create")
    }
    
    
    private func renderCheckEmail(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-password-check-email")
    }
    
    
    // MARK:  Methods connected to routes that return data
    
    private func login(_ req: Request) async throws -> Response {
        struct Form: Content {
            var email: String?
            var password: String?
        }
        
        let content = try req.content.decode(Form.self)

        guard let email = content.email, let password = content.password else {
            throw Abort(.badRequest)
        }
        
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        let userMatches = try await User.query(on: req.db).filter(\.$emailAddress == email).all()
        
        let user: User =  try {
            guard userMatches.count < 2 else {
                throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
            }
            
            guard userMatches.count == 1 else {
                throw Abort(.unauthorized, reason: "No user exists for that email address.")
            }
            
            let user = userMatches[0]
            
            // verify that password submitted matches
            guard try Bcrypt.verify(password, created: user.passwordHash) else {
                throw Abort(.unauthorized, reason: "Could not verify password.")
            }
            
            // login success
            guard user.isActive else {
                throw Abort(.unauthorized, reason: "User's system access has been revoked.")
            }
            // figure out which repos user has permission to see, and update the session.
            // done
            return user
        }()
        
        SessionController.setUserId(req, user.id!)
        SessionController.setIsAdmin(req, user.isAdmin)
        
        let userRepos = try await UserRepo.query(on: req.db).filter(\.$userId == user.id!).join(Repo.self, on: \UserRepo.$repoId == \Repo.$id).all()
        var userRepoAccess = [UserRepoAccess]()
        
        // if this list is empty, and the user is an admin, load all repos
        if userRepos.isEmpty && user.isAdmin {
            let allRepos = try await Repo.query(on: req.db).all()
            for aRepo in allRepos {
                let newUserRepo = UserRepo(id: nil, userId: user.id!, repoId: aRepo.id!, accessLevel: .full)
                try await newUserRepo.save(on: req.db).get()
                let access = UserRepoAccess(repoId: newUserRepo.id!, accessLevel: .full, repoName: aRepo.repoName, repoFolder: aRepo.repoFolder)
                userRepoAccess.append(access)
            }
        }
        // normal access init
        else {
            for repo in userRepos {
                if repo.accessLevel != .none {
                    let aRepo = try repo.joined(Repo.self)
                    let access = UserRepoAccess(repoId: repo.id!, accessLevel: repo.accessLevel, repoName: aRepo.repoName, repoFolder: aRepo.repoFolder)
                    userRepoAccess.append(access)
                }
            }
        }
        
        SessionController.setRepoAccesssList(req, userRepoAccess)
        guard let defaultRepo = userRepoAccess.sorted().first else {
            throw Abort(.internalServerError, reason: "Unable to set default repository for user.")
        }
        
        SessionController.setCurrentRepo(req, defaultRepo.repoId)
        
        return req.redirect(to: "/top")
    }
    
    
//    private func createUser(_ req: Request) throws -> EventLoopFuture<User> {
//        struct FormData: Decodable {
//            var emailAddress: String?
//            var password: String?
//            var name: String?
//        }
//        let form = try req.content.syncDecode(FormData.self)
//        guard let emailAddress = form.emailAddress,
//            let password = form.password,
//            let name = form.name,
//            let passwordHash = try? Bcrypt.hash(password)
//            else {
//                throw Abort(.partialContent, reason: "All fields on create user form are requird")
//        }
//        let newUser = User(id: nil, name: name, emailAddress: emailAddress, passwordHash: passwordHash)
//        return newUser.create(on: req)
//    }
    
    
    
    // MARK: Static methods - used for verification in other controllers
    
    static func redirectToLogin(_ req: Request) -> EventLoopFuture<Response> {
        SessionController.kill(req)
        return req.eventLoop.makeSucceededFuture(req.redirect(to: "./security/login"))
    }
    
    
    static func verifyAccess(_ req: Request, repo: UUID, onSuccess: @escaping () throws -> EventLoopFuture<Response>) throws -> EventLoopFuture<Response> {
        guard let available = SessionController.getRepoAcccessList(req) else {
            throw Abort(.unauthorized)
        }
        
        guard available.filter({ $0.repoId == repo }).first != nil else {
            throw Abort(.unauthorized)
        }
        return try onSuccess()
    }
}



// MARK:  Password reset methods

extension SecurityController {
    
    private func renderPasswordResetForm(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-password-reset")
    }
    
    private func sendPWResetEmail(_ req: Request) async throws -> Response {
        struct Form: Content {
            var emailAddress: String?
        }
        
        let content = try req.content.decode(Form.self)
        let email = content.emailAddress ?? ""
        
        guard email.count > 0 else {
            throw Abort(.badRequest, reason:  "No email address received for password reset.")
        }
        
        let userMatches = try await User.query(on: req.db).filter(\.$emailAddress == email).all()
        let user: User = try {
            guard userMatches.count < 2 else {
                throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
            }
            
            guard userMatches.count == 1 else {
                throw Abort(.unauthorized, reason: "No user exists for that email address.")
            }
            
            let user = userMatches[0]
            return user
        }()
        let userId = user.id!
        let resetRequest = PasswordResetRequest(id: nil, exp: Date().addingTimeInterval(TimeInterval(settings.resetKeyExpDuration)), userId: userId)
        try await resetRequest.save(on: req.db)  // sets resetRequest.id
                            
        let resetKey: String = try {
            guard let resetKey = resetRequest.id?.uuidString else {
                throw Abort(.internalServerError, reason: "Error getting unique key for tracking password reset request.")
            }
            return resetKey
        }()
                        
        // TODO:  Delete expired keys
        // TODO:  Delete any older (even unexpired) keys for this user.
                        
        let (_, text) = self.getResetEmailBody(key: resetKey)
        
        let sendTo = ConcordMail.Mail.User(name: nil, email: email)
        let sendFrom = ConcordMail.Mail.User(name: settings.smtp.friendlyName, email: settings.smtp.fromEmail)
        let mail = ConcordMail.Mail(from: sendFrom, to: sendTo, subject: "Password Reset Link for Secure File Share", contentType: .html, text: text)
        
        let mailResult = try await self.concordMail.send(mail: mail)
        switch mailResult {
        case .success:
            // redirect to page that tells them to check their email...
            return req.redirect(to: "/security/check-email")
        case .failure(let error):
            throw Abort (.internalServerError, reason: "Mail error:  \(error)")
        }
    }
    
    
    private func verifyKey(_ req: Request, resetKey: String) async throws -> PasswordResetRequest {
        
        guard let uuid = UUID(resetKey) else {
            throw Abort(.badRequest, reason: "No reset token read in request for password reset.")
        }
        
        let resetRequestW = try await PasswordResetRequest.query(on: req.db).filter(\.$id == uuid).filter(\.$exp >= Date()).first()
        guard let resetRequest = resetRequestW else {
            throw Abort(.badRequest, reason: "Reset link was invalid or expired.")
        }
        return resetRequest
    }
     
    
    private func verifyPasswordResetRequest(req: Request) async throws -> View {
        print (req.parameters)
        guard let parameter = req.parameters.get("resetString") else {
            throw Abort(.badRequest, reason: "Invalid password reset parameter received.")
        }
        
        let _ = try await verifyKey(req, resetKey: parameter)
        let context = ["resetKey" : parameter]
        return try await req.view.render("users-password-change-form", context)
    }
    
    private func verifyAndChangePassword(req: Request) async throws -> View {
        struct PostVars: Content {
            let pw1: String
            let pw2: String
            let resetKey: String
        }
        
        let vars = try req.content.decode(PostVars.self)
        let pw1 = vars.pw1
        let pw2 = vars.pw2
        let resetKey = vars.resetKey
        
        guard let _ = UUID(vars.resetKey) else {
            throw Abort(.badRequest, reason: "Invalid password reset key.")
        }
        
        
        
        guard pw1 == pw2 else {
            throw Abort(.badRequest, reason: "Form submitted two passwords that don't match.")
        }
        
        let resetRequest: PasswordResetRequest = try await verifyKey(req, resetKey: resetKey)
  
        #warning("bms - password enforcement")
        // TODO:  enforce minimum password requirement (configuration?)
        // TODO:  verify no white space.  any other invalid characrters?
                
        async let changeTask = changePassword(req, userId: resetRequest.userId, newPassword: pw1)
        async let deleteTask =  MySQLDirect().deleteExpiredAndCompleted(req, resetKey: resetKey)
        let (_, _) = (try await changeTask, try await deleteTask)
        return try await req.view.render("users-password-change-success")
    }
    
    private func changePassword(_ req: Request, userId: UUID, newPassword: String) async throws -> HTTPResponseStatus {
        let userMatch = try await User.query(on:req.db).filter(\.$id == userId).all()
        let user = userMatch[0]
        let passwordHash = try Bcrypt.hash(newPassword)
        user.passwordHash = passwordHash
        try await user.save(on: req.db)
        return HTTPResponseStatus.ok
    }
    
    
/*    private func changePassword(_ req: Request) throws -> Future<User> {
        let email: String = try req.content.syncGet(at: "emailAddress")
        let password: String = try req.content.syncGet(at: "password")
        
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        return User.query(on: req).filter(\User.emailAddress == email).all().flatMap(to: User.self) { userMatches in
            
            guard userMatches.count < 2 else {
                throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
            }
            
            guard userMatches.count == 1 else {
                throw Abort(.unauthorized, reason: "No user exists for that email address.")
            }
            
            var user = userMatches[0]
            let passwordHash = (try? BCrypt.hash(password)) ?? ""
            user.passwordHash = passwordHash
            return user.save(on: req)
        }
    }
    
    */
    
    // MARK: Private helper methods
 
    private func getResetEmailBody(key: String) -> (String, String) {
        let resetLink = "\(settings.systemRootPublicURL)/security/password-reset-process/\(key)"
        
        let html = """
        <p>We have received a password reset request for your account.  If you did not make this request, you can delete this email, and your password will remain unchanged.</p>
        <p>If you do want to change your password, follow <a href="\(resetLink)">this link</a>.</p>
        """
        
        let txt = "We have received a password reset request for your account.  If you did not make this request, you can delete this email, and your password will remain unchanged.\n\nIf you do want to change your password, visit \(resetLink) in your browser."
        
        return (html, txt)
    }

}

