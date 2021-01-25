//
//  Mailer.swift
//  App
//
//  Created by Ben Schultz on 4/22/20.
//

import Foundation
import Vapor
import SwiftSMTP

class ConcordMail {
    
    let smtp: SMTP
    
    init(configKeys: ConfigurationSettings.Smtp) {

        smtp = SMTP(hostname: configKeys.hostname,
                       email: configKeys.username,
                    password: configKeys.password,
                        port: configKeys.port,
                     tlsMode: .normal,
            tlsConfiguration: nil,
                 authMethods: [.login],
                 //accessToken: nil,
                  domainName: "localhost",
                     timeout: configKeys.timeout)
    }
    
    public enum Result {
        case success
        case failure(error: Error)
    }
    
    func send(_ req: Request, _ mail: Mail) -> EventLoopFuture<ConcordMail.Result> {
        let promise = req.eventLoop.makePromise(of: ConcordMail.Result.self)
        smtp.send(mail) { error in
            if let error = error {
                promise.succeed(ConcordMail.Result.failure(error: error))
            } else {
                promise.succeed(ConcordMail.Result.success)
            }
        }
        return promise.futureResult
    }
    
   
}
