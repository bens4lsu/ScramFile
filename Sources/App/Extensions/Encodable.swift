//
//  File 2.swift
//  
//
//  Created by Ben Schultz on 2/18/21.
//

import Foundation

enum ExtStringEncoding {
    case jsonString
    case base64Encoded
}

extension Encodable {
    
    func toString(extStringEncoding: ExtStringEncoding) -> String {
        let jsonData = try! JSONEncoder().encode(self)
        switch extStringEncoding {
        case .jsonString:
            return String(data: jsonData, encoding: .utf8)!
        case .base64Encoded:
            return jsonData.base64EncodedString()
        }
    }
}

extension Array where Element: Encodable {
    func toString() -> String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        return data.base64EncodedString()
    }
}

extension Dictionary where Value: Encodable, Key: Encodable {
    func toString() -> String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        return data.base64EncodedString()
    }
}
