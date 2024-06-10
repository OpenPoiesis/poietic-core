//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/07/2023.
//


public enum AudienceLevel: Int  {
    case any = 0
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4

    public init(rawValue: Int) {
        switch rawValue {
        case 0: self = .any
        case 1: self = .beginner
        case 2: self = .intermediate
        case 3: self = .advanced
        case 4: self = .expert
        default:
            if rawValue < 0 {
                self = .any
            }
            else {
                self = .expert
            }
        }
    }
    
    /// Compare two audience levels.
    ///
    /// Level `any` is always greater than anything else.
    ///
    static func < (lhs: AudienceLevel, rhs: AudienceLevel) -> Bool {
        if lhs == .any || rhs == .any {
            return false
        }
        else {
            return lhs.rawValue < rhs.rawValue
        }
    }

}

