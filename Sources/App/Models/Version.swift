//
//  File.swift
//  
//
//  Created by Ben Schultz on 4/5/22.
//

import Foundation
import Vapor

struct Version: Encodable {

    var version: String
    
    var versionLong: String {
        let yr = Calendar.current.component(.year, from: Date())
        var cprt = "© Concord Business Services, LLC, 2022"
        if yr > 2022 {
            cprt = "\(cprt) - \(yr)"
        }
        return "\(version)  \(cprt)"
    }
    
    init() throws {
    
        struct VersionObj: Decodable {
            var version: String
        }
        
        let path = DirectoryConfiguration.detect().resourcesDirectory
        let url = URL(fileURLWithPath: path).appendingPathComponent("version.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(VersionObj.self, from: data)
            self.version = decoder.version
        }
        catch {
            throw Abort(.internalServerError, reason: "Could not initialize app from version.json.  \n \(error)")
        }
    }
}
