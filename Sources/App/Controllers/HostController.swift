//
//  File.swift
//  
//
//  Created by Ben Schultz on 2/16/21.
//

import Foundation
import Vapor

class HostController {
    
    func getHostContext(_ req: Request, hostId: UUID) throws -> EventLoopFuture<Host> {
        return Host.find(hostId, on: req.db).flatMapThrowing() { host in
            guard let host = host else {
                throw Abort (.internalServerError, reason: "Current repo is associated with an invalid host.")
            }
            return host
        }
    }
}
