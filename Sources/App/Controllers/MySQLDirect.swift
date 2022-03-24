//
//  MySQLDirect.swift
//  App
//
//  Created by Ben Schultz on 2/3/20.
//

import Foundation
import SQLKit
import FluentMySQLDriver
import Vapor

class MySQLDirect {
    
        
    let dateFormatter: DateFormatter =  {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func getResultsRows<T: Decodable>(_ req: Request, query: String, decodeUsing: T.Type) async throws -> [T] {
        let queryString = SQLQueryString(stringLiteral: query)
        return try await (req.db as! SQLDatabase).raw(queryString).all(decoding: T.self).get()
    }
    
    private func getResultRow<T: Decodable>(_ req: Request, query: String, decodeUsing: T.Type) async throws -> T? {
        let queryString = SQLQueryString(stringLiteral: query)
        return try await (req.db as! SQLDatabase).raw(queryString).first(decoding: T.self).get()
    }
    
    private func issueQuery (_ req: Request, query: String) async throws  {
        let queryString = SQLQueryString(stringLiteral: query)
        let _ = try await(req.db as! SQLDatabase).raw(queryString).all().get()
        return
    }
    
    
    func getRepoListForUser(_ req: Request, userId: UUID) async throws -> [AdminController.AdminRepoTreeBranch] {
        let sql = """
            SELECT th.id as hostId
                , th.hostName
                , tr.id as repoId
                , tr.repoName
                , IFNULL(tur.accessLevel, 'none') AS accessLevel
            FROM tblHosts th
                JOIN tblRepos tr  ON th.id = tr.hostId
                LEFT OUTER JOIN tblUserRepos tur ON tr.id  = tur.repoId AND tur.userId = '\(userId)'
        """
        
        return try await getResultsRows(req, query: sql, decodeUsing: AdminController.AdminRepoTreeBranch.self)
    }
 
}

