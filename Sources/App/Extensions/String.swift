//
//  File.swift
//  
//
//  Created by Ben Schultz on 1/27/21.
//

import Foundation
   
extension String {

    func everythingBeforeLastOccurence(of findStr: Character) -> String? {
        guard let index = self.lastIndex(of: findStr) else {
            return nil
        }
        return String(self.prefix(upTo: index))
    }
    
    func toObject<T: Decodable>() -> T? {
        guard let data = Data(base64Encoded: self),
              let decoded = try? JSONDecoder().decode(T.self, from:data) else {
            return nil
        }
        return decoded
    }
        
    func converted(to: Capitalization) -> String {
        switch to {
        case .lower:
            return self.lowercased()
        case .title:
            return self.capitalized
        case .upper:
            return self.uppercased()
        case .random:
            guard let capitalization = Capitalization(rawValue: Int.random(in: 0...2)) else {
                print ("error getting random capitalization")
                return self.lowercased()
            }
            return self.converted(to: capitalization)
        }
    }
}




