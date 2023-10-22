//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 21/10/2023.
//

import Foundation
public class IssueCatcher {
    /// Flag whether the collector resumes after an exception.
    ///
    let resume: Bool
    var issues: [Error]
    public init(resume: Bool) {
        self.resume = resume
        self.issues = []
    }
    
    public func catched(block: (() throws -> Void)) throws {
        do {
            try block()
        }
        catch {
            issues.append(error)
            if !resume {
                throw error
            }
        }
    }
    
    public func catched<T>(_ defaultValue: T, block: (() throws -> T)) throws -> T{
        do {
            return try block()
        }
        catch {
            issues.append(error)
            if resume {
                return defaultValue
            }
            else {
                throw error
            }
        }
    }

}
