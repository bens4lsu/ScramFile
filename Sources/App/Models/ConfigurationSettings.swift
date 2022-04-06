//
//  File.swift
//  
//
//  Created by Ben Schultz on 5/6/20.
//

import Vapor
import NIOSSL

class ConfigurationSettings: Decodable {
    
    struct Database: Decodable {
        let hostname: String
        let port: Int
        let username: String
        let password: String
        let database: String
        let certificateVerificationString: String
    }
    
    struct Smtp: Codable {
        var hostname: String
        var port: Int32
        var username: String
        var password: String
        var timeout: UInt
        var friendlyName: String
        var fromEmail: String
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
    let listenOnPort: Int
    let smtp: ConfigurationSettings.Smtp
    let emailMessages: [String: ConfigurationSettings.Message]
    let resetKeyExpDuration: Int
    let systemRootPublicURL: String
    let maxFileSize: String
    
    
    var certificateVerification: CertificateVerification {
        if database.certificateVerificationString == "noHostnameVerification" {
            return .noHostnameVerification
        }
        else if database.certificateVerificationString == "fullVerification" {
            return .fullVerification
        }
        return .none
    }
    
    init() {
        let path = DirectoryConfiguration.detect().resourcesDirectory
        let url = URL(fileURLWithPath: path).appendingPathComponent("Config.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(ConfigurationSettings.self, from: data)
            self.database = decoder.database
            self.listenOnPort = decoder.listenOnPort
            self.smtp = decoder.smtp
            self.emailMessages = decoder.emailMessages
            self.resetKeyExpDuration = decoder.resetKeyExpDuration
            self.systemRootPublicURL = decoder.systemRootPublicURL
            self.maxFileSize = decoder.maxFileSize            
        }
        catch {
            print ("Could not initialize app from Config.json.  Initilizing with hard-coded default values. \n \(error)")
            exit(0)
        }
    }
}


