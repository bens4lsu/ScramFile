//
//  File.swift
//  
//
//  Created by Ben Schultz on 12/7/21.
//

import Foundation
import Fluent
import Vapor

final class PasswordResetRequest: Content, Model, Codable {
    @ID(custom: "ResetRequestKey")
    var id: UUID?
    
    @Field(key: "Expiration")
    var exp: Date
    
    @Field(key: "UserID")
    var userId: UUID

    static let schema = "tblPasswordResetRequests"

    private enum CodingKeys: String, CodingKey {
        case id = "ResetRequestKey",
             exp = "Expiration",
             person = "PersonID"
    }
    
    required init() { }
    
    init (id: UUID?, exp: Date, userId: UUID) {
        self.id = id
        self.exp = exp
        self.userId = userId
    }
}
