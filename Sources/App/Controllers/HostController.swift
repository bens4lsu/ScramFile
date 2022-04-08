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
        
        let referringHost = req.headers.forwarded.first?.host       // forwarded host -- when behing reverse proxy
                            ?? req.application.http.server.configuration.hostname   // for when the client connects directly to the vapor app
        
        print ("request from: \(referringHost)")
        
        guard let host = try await Host.query(on: req.db).filter(\.$rootUrl == referringHost).first() else {
            throw Abort(.internalServerError, reason: "no host configured for \(referringHost).")
        }
        return host
    }
    
}
