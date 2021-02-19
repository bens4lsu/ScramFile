//
//  File.swift
//  
//
//  Created by Ben Schultz on 1/22/21.
//

import Foundation

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { a, b in
            return a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
    
    func sorted<T: Comparable, U: Comparable>(by keyPath: KeyPath<Element, T>, thenBy keyPath2: KeyPath<Element, U>) -> [Element] {
        return sorted { a, b in
            if a[keyPath: keyPath] == b[keyPath: keyPath] {
                return a[keyPath: keyPath2] < b[keyPath: keyPath2]
            }
            return a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}


