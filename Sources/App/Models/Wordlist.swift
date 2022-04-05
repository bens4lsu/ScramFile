//
//  File.swift
//  
//
//  Created by Ben Schultz on 4/5/22.
//

import Foundation
import Vapor

struct Wordlist {

    var words = [String]()
    
    init() throws {
    
        let path = DirectoryConfiguration.detect().resourcesDirectory
        let url = URL(fileURLWithPath: path).appendingPathComponent("words.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode([String].self, from: data)
            self.words = decoder
        }
        catch {
            throw Abort(.internalServerError, reason: "Could not initialize app from words.json.  \n \(error)")
        }
    }
    
    var rand: String {
        words[Int.random(in: 0...(words.count - 1))]
    }
    
    func arrayOf(_ n: Int) -> [String] {
        var words = [String]()
        var word: String
        for _ in (0..<n) {
            repeat {
                let capitalization = Capitalization.random
                word = rand.converted(to: capitalization)
            } while words.contains(word)
            words.append(word)
        }
        return words
    }
    
    func arrayOf(_ n: NumberOfWords) -> [String] {
        var words = self.arrayOf(n.asInt)
        let capitalization = n.capitalizationArray()
        guard words.count == capitalization.count else {
            print ("Something went horribly wrong!")
            return []
        }
        
        for i in 0..<words.count {
            words[i] = words[i].converted(to: capitalization[i])
        }
        return words
    }
}
