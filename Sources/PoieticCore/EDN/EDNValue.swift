//
//  EDNValue.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 12/03/2025.
//


public enum EDNValue: Equatable {
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)
    case symbol(String)
    case keyword(String)
    case list([EDNValue])
    case vector([EDNValue])
}
