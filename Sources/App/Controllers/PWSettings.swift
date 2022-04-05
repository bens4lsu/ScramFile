//
//  File.swift
//  
//
//  Created by Ben Schultz on 4/4/22.
//

import Foundation


enum Capitalization: Int, CaseIterable {
    case lower = 0
    case title = 1
    case upper = 2
    case random
}

enum Symbol: String {
    case dash = "-"
    case bang = "!"
    case at = "@"
    case plus = "+"
    case equals = "="
    case dot = "."
    case tilde = "~"
    case pound = "#"
    case dollar = "$"
    case percent = "%"
    case carrot = "^"
    case amp = "&"
    case star = "*"
    case openparen = "("
    case closeparen = ")"
    case under = "_"
    case openwiz = "{"
    case closewiz = "}"
    case opensquare = "["
    case closesquare = "]"
    case pipe = "|"
    case whack = "\\"
    case colon = ":"
    case semicolon = ";"
    case singlequo = "'"
    case doublequo = "\""
    case lt = "<"
    case gt = ">"
    case comma = ","
    case question = "?"
    case slash = "/"
    
    func str() -> String {
        return self.rawValue
    }
}

enum NumberOfWords {
    case two (Capitalization, Capitalization)
    case three (Capitalization, Capitalization, Capitalization)
    case four (Capitalization, Capitalization, Capitalization, Capitalization)
    case five (Capitalization, Capitalization, Capitalization, Capitalization, Capitalization)
    
    var asInt: Int {
        switch self {
        case .two:
            return 2
        case .three:
            return 3
        case .four:
            return 4
        case .five:
            return 5
        }
    }
    
    func capitalizationArray() -> [Capitalization] {
        switch self {
        case .two (let c1, let c2):
            return [c1, c2]
        case .three (let c1, let c2, let c3):
            return [c1, c2, c3]
        case .four (let c1, let c2, let c3, let c4):
            return [c1, c2, c3, c4]
        case .five (let c1, let c2, let c3, let c4, let c5):
            return [c1, c2, c3, c4, c5]
        }
    }
}

enum OptionalSymbol {
    case none
    case symbol(Symbol)
    
    func str() -> String {
        switch self {
        case .none:
            return ""
        case .symbol(let symbol):
            return symbol.str()
        }
    }
}

enum Digits: Int {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    
    func str() -> String {
        let rand = Int.random(in: 0...99999)
        let stringValue = "00000" + String(rand)
        return String(stringValue.suffix(self.rawValue))
    }
}


class PWSettings {

    var beginDigits: Digits
    var numberOfWords: NumberOfWords
    var beginSymbol: OptionalSymbol
    var betweenSymbol: Symbol
    var endSymbol: OptionalSymbol
    var endDigits: Digits
    
    
    init() {
        beginDigits = .zero
        numberOfWords = .two(Capitalization.random, Capitalization.random)
        beginSymbol = .none
        betweenSymbol = .plus
        endSymbol = .symbol(.equals)
        endDigits = .two
    }
    
    func newPassword() throws -> String {
        var str = beginSymbol.str() + beginDigits.str()
        let words = try Wordlist().arrayOf(numberOfWords)
        for (i, word) in words.enumerated() {
            str += word
            if i != words.count - 1 {
                str += betweenSymbol.str()
            }
        }
        str += endSymbol.str()
        str += endDigits.str()
        return str
    }
}
