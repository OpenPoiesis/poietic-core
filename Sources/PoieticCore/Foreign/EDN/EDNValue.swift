//
//  EDNValue.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 12/03/2025.
//


enum EDNValue: Equatable {
    case `nil`
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)
    case symbol(String)
    case keyword(String)
    case list([EDNValue])
    case vector([EDNValue])
}
