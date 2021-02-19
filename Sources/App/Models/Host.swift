//
//  File.swift
//  
//
//  Created by Ben Schultz on 8/24/20.
//

import Vapor
import Fluent
import FluentMySQLDriver

struct HostColors: Decodable {
    var backgroundColor: String
    var activeLinkColor: String
    var linkColor: String
}


final class Host:  Model, Content, Codable {
            
    static var schema = "tblHosts"
    
    @ID
    var id: UUID?

    @Field(key: "hostFolder")
    var hostFolder: String

    @Field(key: "hostName")
    var hostName: String

    @Field(key: "rootUrl")
    var rootUrl: String
    
    @Field(key: "logo")
    var logo: String
    
    @Field(key: "colors")
    var colors: String
    
    init() { }
    
    var hostColors: HostColors {
        return colors.toObject() ?? HostColors(backgroundColor: "000000", activeLinkColor: "ffffff", linkColor: "aaaaaa")
    }
}
