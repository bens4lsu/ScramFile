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
            
    static var schema = "tblHosts"
    
    @ID
    var id: UUID?

//    @Field(key: "hostFolder")
//    var hostFolder: String

    @Field(key: "hostName")
    var hostName: String

    @Field(key: "rootUrl")
    var rootUrl: String
    
    @Field(key: "logo")
    var logo: String
    
    @Field(key: "colors")
    var colors: String
    
    init() { }
    

}
