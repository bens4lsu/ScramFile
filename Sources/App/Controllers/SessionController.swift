//
//  File.swift
//  
//
//  Created by Ben Schultz on 1/23/21.
//

import Foundation
import Vapor


class SessionController {
    

    static func getUserId(_ req: Request) throws -> UUID {
        guard let userId = req.session.data["userId"],
              let uuid = UUID(uuidString: userId ) else {
            throw Abort (.badRequest, reason: "Invalid user id requested")
        }
        return uuid
    }

    static func setUserId(_ req: Request, _ userId: UUID) {
        req.session.data["userId"] = userId.uuidString
    }

    static func getIsAdmin(_ req: Request) -> Bool {
        req.session.data["isAdmin"] == "true"
    }
    
    static func setIsAdmin(_ req: Request, _ isAdmin: Bool) {
        let string = isAdmin ? "true" : "false"
        req.session.data["isAdmin"] = string
    }
    
    static func getCurrentRepo(_ req: Request) -> UUID? {
        guard let str = req.session.data["currentRepo"] else {
            return nil
        }
        return UUID(uuidString: str)
    }
    
    static func setCurrentRepo(_ req: Request, _ repoId: UUID){
        req.session.data["currentRepo"] = repoId.uuidString
    }
    
    static func getCurrentSubfolder(_ req: Request) -> String? {
        req.session.data["currentSubfolder"]
    }
    
    static func setCurrentSubfolder(_ req: Request, _ currentSubfolder: String?){
        req.session.data["currentSubfolder"] = currentSubfolder
    }
    
    static func getRepoAcccessList(_ req: Request) -> [SecurityController.UserRepoAccess]? {
        guard let sessData = req.session.data["userRepoAccess"],
              let data = Data(base64Encoded: sessData) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([SecurityController.UserRepoAccess].self, from: data)
    }
    
    static func setRepoAccesssList(_ req: Request, _ accessList: [SecurityController.UserRepoAccess]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(accessList)
        req.session.data["userRepoAccess"] = data.base64EncodedString()
    }
    
    static func getAccessLevelToCurrentRepo(_ req: Request) -> AccessLevel {
        if self.getIsAdmin(req) {
            return .full
        }
              
        guard let accessList = getRepoAcccessList(req),
              let currentRepo = getCurrentRepo(req),
              let accessToCurrent = accessList.filter({$0.repoId == currentRepo}).first
        else {
            return .none
        }
        return accessToCurrent.accessLevel
    }
    
    

    
    
    static func kill(_ req: Request) {
        req.session.data = SessionData()
    }
}

