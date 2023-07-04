//
//  BuiltinFunctions.swift
//  
//
//  Created by Stefan Urbanek on 12/07/2022.
//

import PoieticCore

#if os(Linux)
import Glibc
#else
import Darwin
#endif

// Mark: Builtins

/// List of built-in numeric unary operators.
///
/// The operators:
///
/// - `-` unary minus
///
public let BuiltinUnaryOperators: [FunctionProtocol] = [
    NumericUnaryOperator(name: "-") { -$0 }
]

/// List of built-in numeric binary operators.
///
/// The operators:
///
/// - `+` addition
/// - `-` subtraction
/// - `*` multiplication
/// - `/` division
/// - `%` remainder
///
public let BuiltinBinaryOperators: [FunctionProtocol] = [
    NumericBinaryOperator(name: "+") { $0 + $1 },
    NumericBinaryOperator(name: "-") { $0 - $1 },
    NumericBinaryOperator(name: "*") { $0 * $1 },
    NumericBinaryOperator(name: "/") { $0 / $1 },
    NumericBinaryOperator(name: "%") { $0.truncatingRemainder(dividingBy: $1) },
]

/// List of built-in numeric function.
///
/// The functions:
///
/// - `abs(number)` absolute value
/// - `floor(number)` rounded down, floor value
/// - `ceiling(number)` rounded up, ceiling value
/// - `round(number)` rounded value
/// - `sum(number, ...)` sum of multiple values
/// - `min(number, ...)` min out of of multiple values
/// - `max(number, ...)` max out of of multiple values
///
public let BuiltinFunctions: [FunctionProtocol] = [
    NumericFunction(name: "abs", signature: ["value"]) { args
        in args[0].magnitude
    },
    NumericFunction(name: "floor", signature: ["value"]) { args
        in args[0].rounded(.down)
    },
    NumericFunction(name: "ceiling", signature: ["value"]) { args
        in args[0].rounded(.up)
    },
    NumericFunction(name: "round", signature: ["value"]) { args
        in args[0].rounded()
    },

    NumericFunction(name: "power", signature: ["value", "exponent"]) { args
        in pow(args[0], args[1])
    },

    // Variadic
    
    NumericFunction(name: "sum", isVariadic: true) { args
        in args.reduce(0, { x, y in x + y })
    },
    NumericFunction(name: "min", isVariadic: true) { args
        in args.min()!
    },
    NumericFunction(name: "max", isVariadic: true) { args
        in args.max()!
    },
]

/// List of all built-in functions and operators.
let AllBuiltinFunctions: [FunctionProtocol] = BuiltinUnaryOperators + BuiltinBinaryOperators + BuiltinFunctions

enum BuiltinFunction: String {
    case abs
    case floor
    case ceiling
    case round
    case power
    case sum
    case min
    case max
}
