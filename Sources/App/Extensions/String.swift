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
}
