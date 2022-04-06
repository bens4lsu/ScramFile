//
//  File.swift
//  
//
//  Created by Ben Schultz on 2/16/21.
//

import Foundation
import Vapor
import Fluent
import FluentMySQLDriver

class HostController {
    
    func getHostContext(_ req: Request) async throws -> Host {
        let serverHostName = req.application.http.server.configuration.hostname
        print ("request forward from:")
        print(req.headers.forwarded.first!)
        guard let host = try await Host.query(on: req.db).filter(\.$rootUrl == serverHostName).first() else {
            throw Abort(.internalServerError, reason: "no host configured for \(serverHostName).")
        }
        return host
    }
    
}
