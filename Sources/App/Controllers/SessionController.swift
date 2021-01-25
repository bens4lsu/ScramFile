//
//  File.swift
//  
//
//  Created by Ben Schultz on 1/23/21.
//

import Foundation
import Vapor


class SessionController {


    static func userId(_ req: Request) -> UUID {
        return UUID(uuidString: "DCBE4EAA-5CAF-11EB-A925-080027363641")!
        //return req.session.data["userId"]
    }

    static func setUserId(_ req: Request, _ userId: UUID) {
        req.session.data["uuid"] = userId.uuidString
    }

    static func isAdmin(_ req: Request) -> Bool {
        return true
    }
    
    static func setIsAdmin(_ req: Request, _ isAdmin: Bool) {
        let string = isAdmin ? "true" : "false"
        req.session.data["isAdmin"] = string
    }
    
    static func currentRepo(_ req: Request) -> UUID? {
        guard let str = req.session.data["currentRepo"] else {
            return nil
        }
        return UUID(uuidString: str)
    }
    
    static func setCurrentRepo(_ req: Request, _ repoId: UUID){
        req.session.data["currentRepo"] = repoId.uuidString
    }
    
    static func currentSubfolder(_ req: Request) -> String? {
        return req.session.data["currentSubfolder"]
    }
    
    static func setCurrentSubfolder(_ req: Request, _ currentSubfolder: String?){
        req.session.data["currentSubfolder"] = currentSubfolder
    }
    
    static func kill(_ req: Request) {
        req.session.data = SessionData()
    }
    
    static func repoAcccessList(_ req: Request) -> [SecurityController.UserRepoAccess]? {
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
}

