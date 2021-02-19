//
//  File.swift
//  
//
//  Created by Ben Schultz on 2/19/21.
//

import Foundation

extension Bool: Comparable {
    
    // sorts true in front of false
    public static func < (lhs: Bool, rhs: Bool) -> Bool {
        return lhs
    }
}

