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
    
//    func getHostContext(_ req: Request, hostId: UUID) throws -> EventLoopFuture<Host> {
//        return Host.find(hostId, on: req.db).flatMapThrowing() { host in
//            guard let host = host else {
//                throw Abort (.internalServerError, reason: "Current repo is associated with an invalid host.")
//            }
//            return host
//        }
//    }
//    
//    func getHostContext(_ req: Request, hostId: UUID) async throws -> Host {
//        let optionalHost = try await Host.find(hostId, on: req.db)
//        guard let host = optionalHost else {
//            throw Abort (.internalServerError, reason: "Current repo is associated with an invalid host.")
//        }
//        return host
//    }
    
    func getHostContext(_ req: Request) async throws -> Host {
        let serverHostName = req.application.http.server.configuration.hostname
        guard let host = try await Host.query(on: req.db).filter(\.$hostName == serverHostName).first() else {
            throw Abort(.internalServerError, reason: "no host configured for \(serverHostName).")
        }
        return host
    }
    
}
