//
//  Mailer.swift
//  App
//
//  Created by Ben Schultz on 4/22/20.
//

import Foundation
import Vapor
import SMTPKitten

class ConcordMail {
    
    struct Mail {
        
        struct User {
            var name: String?
            var email: String
            
            var smtpKittenUser: SMTPKitten.MailUser {
                SMTPKitten.MailUser(name: self.name, email: self.email)
            }
        }
        
        enum ContentType {
            case plain
            case html
            
            var smtpKittenContentType: SMTPKitten.Mail.ContentType {
                switch self {
                case .plain:
                    return SMTPKitten.Mail.ContentType.plain
                case .html:
                    return SMTPKitten.Mail.ContentType.html
                }
            }
        }
        
        var from: Mail.User
        var to: Mail.User
        var subject: String
        var contentType: Mail.ContentType
        var text: String
        
        var smtpKittenMail: SMTPKitten.Mail {
            SMTPKitten.Mail(from: from.smtpKittenUser,
                            to: [to.smtpKittenUser],
                            cc: Set<SMTPKitten.MailUser>(),
                            subject: subject,
                            contentType: contentType.smtpKittenContentType,
                            text: text
            )
        }
    }
    
    var smtp: ConfigurationSettings.Smtp
    
    init(configKeys: ConfigurationSettings) {
        self.smtp = configKeys.smtp
    }
    
    public enum Result {
        case success
        case failure(error: Error)
    }
    
    func send(mail: Mail) async throws -> ConcordMail.Result  {
        let client = try await SMTPClient.connect(hostname: smtp.hostname, ssl: .startTLS(configuration: .default)).get()
        try await client.login(user: smtp.username,password: smtp.password).get()
        try await client.sendMail(mail.smtpKittenMail).get()
        return .success
    }
    
    func testMail() async throws -> ConcordMail.Result {
        let mail = Mail(
            from: Mail.User(name: smtp.username, email: smtp.username),
            to: Mail.User(name: "ben schultz", email: "bens4lsu@gmail.com"),
            subject: "Welcome to our app!",
            contentType: .plain,
            text: "Welcome to our app, you're all set up & stuff."
        )
        return try await send(mail: mail)
        
    }
}
