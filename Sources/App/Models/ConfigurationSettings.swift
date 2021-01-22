//
//  File.swift
//  
//
//  Created by Ben Schultz on 5/6/20.
//

import Vapor

class ConfigurationSettings: Decodable {
    
    struct Database: Decodable {
        let hostname: String
        let port: Int
        let username: String
        let password: String
        let database: String
    }
    
    struct Smtp: Codable {
        var hostname: String
        var port: Int32
        var username: String
        var password: String
        var timeout: UInt
        var techMailTo: String
        var adminMailTo: String
    }
    
    struct Message: Codable {
        var subject: String
        var body: String
        var sendToAdmin: Bool
        var sendToTech: Bool
        
        func mergedBody(_ replaceDict: [String: String]) -> String {
            var retval = body
            for (key, val) in replaceDict {
                retval = retval.replacingOccurrences(of: key, with: val)
            }
            return retval
        }
    }
    
    let database: ConfigurationSettings.Database
    let smtp: ConfigurationSettings.Smtp
    let emailMessages: [String: ConfigurationSettings.Message]
    
    
    init() {
        let path = DirectoryConfiguration.detect().resourcesDirectory
        let url = URL(fileURLWithPath: path).appendingPathComponent("Config.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(ConfigurationSettings.self, from: data)
            self.database = decoder.database
            self.smtp = decoder.smtp
            self.emailMessages = decoder.emailMessages
            
        }
        catch {
            print ("Could not initialize app from Config.json.  Initilizing with hard-coded default values. \n \(error)")
            exit(0)
        }
    }
}


