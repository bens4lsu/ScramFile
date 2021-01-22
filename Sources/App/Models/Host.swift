//
//  File.swift
//  
//
//  Created by Ben Schultz on 8/24/20.
//

import Vapor
import Fluent
import FluentMySQLDriver


final class Host:  Model, Content, Codable {
    
    typealias IDValue = Int
        
    static var schema = "tblHosts"
    
    @ID(custom: "hostId")
    var id: Int?

    @Field(key: "hostFolder")
    var hostFolder: String

    @Field(key: "hostName")
    var hostName: String

    @Field(key: "rootUrl")
    var rootUrl: String
    
    init() { }
    
}
