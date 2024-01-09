//
//  File.swift
//  
//
//  Created by Ben Schultz on 4/27/23.
//

import Foundation
import Vapor
import Fluent

final class MailQueue: Model, Content {
    static let schema = "MailQueue"
    
    @ID(custom: "MailID")
    var id: Int?
    
    @Field(key: "EmailAddressFrom")
    var emailAddressFrom: String
    
    @Field(key: "EmailAddressTo")
    var emailAddressTo: String
    
    @Field(key: "Subject")
    var subject: String
    
    @Field(key: "Body")
    var body: String
    
    @Field(key: "Status")
    var status: String
    
    @Field(key: "FromName")
    var fromName: String
    
    @Field(key: "ToName")
    var toName: String
    
    @Field(key: "PlainOrHTML")
    var plainOrHtml: String
    
    @Field(key: "RequestDate")
    var requestDate: Date
    
    @Field(key: "StatusDate")
    var statusDate: Date
    
    
    init() { }
    
    init(emailAddressFrom: String, emailAddressTo: String, subject: String, body: String, fromName: String? = nil, toName: String? = nil, plainOrHtml: String? = nil) {
        
        self.emailAddressFrom = emailAddressFrom
        self.emailAddressTo = emailAddressTo
        self.subject = subject
        self.body = body
        self.fromName = fromName ?? emailAddressFrom
        self.toName = toName ?? emailAddressTo
        self.plainOrHtml = plainOrHtml ?? "H"
        self.status = "P"
        self.requestDate = Date()
        self.statusDate = Date()
    }
    
}
