//
//  FunctionTests.swift
//
//
//  Created by Stefan Urbanek on 05/07/2023.
//

import Testing
@testable import PoieticCore


@Suite struct SignatureTests {
    @Test func emptySignature() throws {
        let signature = Signature(returns: .bool)
        
        #expect(!signature.isVariadic)
        #expect(signature.validate() == .ok)
    }
    
    @Test func positional() throws {
        let signature = Signature([
            FunctionArgument("a", type: .concrete(.int)),
            FunctionArgument("b", type: .concrete(.int)),
            FunctionArgument("c", type: .concrete(.int)),
        ],returns: .int)
        
        #expect(signature.validate([.int, .int, .int]) == .ok)
        #expect(signature.validate([.int, .int, .ints]) == .typeMismatch([2]))
        #expect(signature.validate([.point, .bools, .strings]) == .typeMismatch([0, 1, 2]))
        #expect(signature.validate([]) == .invalidNumberOfArguments)
        #expect(signature.validate([.int, .int, .int, .int]) == .invalidNumberOfArguments)
    }
    
    @Test func variadic() throws {
        let signature = Signature(
            variadic: FunctionArgument("things", type: .concrete(.int)),
            returns: .int
        )
        #expect(signature.isVariadic)
        #expect(signature.validate([.int]) == .ok)
        #expect(signature.validate([.int, .int, .int]) == .ok)
        #expect(signature.validate([]) == .invalidNumberOfArguments)
        #expect(signature.validate([.int, .int, .point]) == .typeMismatch([2]))
        #expect(signature.validate([.point, .point, .point]) == .typeMismatch([0, 1, 2]))
    }
    
    @Test func variadicAtLeastOne() throws {
        let signature = Signature(
            variadic: FunctionArgument("values", type: .concrete(.int)),
            returns: .int
        )
        #expect(signature.isVariadic)
        #expect(signature.validate([.int]) == .ok)
        #expect(signature.validate([.int, .int, .int]) == .ok)
        #expect(signature.validate([]) == .invalidNumberOfArguments)
    }
    
    @Test func variadicAtLeastOneAndPositional() throws {
        let signature = Signature(
            [
                FunctionArgument("a", type: .concrete(.int)),
            ],
            variadic: FunctionArgument("values", type: .concrete(.int)),
            returns: .int
        )
        #expect(signature.isVariadic)
        #expect(signature.validate([.int]) == .invalidNumberOfArguments)
        #expect(signature.validate([.int, .int]) == .ok)
        #expect(signature.validate([.int, .int, .int]) == .ok)
        #expect(signature.validate([]) == .invalidNumberOfArguments)
    }

    @Test func variadicAndPositional() throws {
        let signature = Signature(
            [
                FunctionArgument("a", type: .concrete(.int)),
                FunctionArgument("b", type: .concrete(.int)),
                FunctionArgument("c", type: .concrete(.int)),
            ],
            variadic: FunctionArgument("things", type: .concrete(.int)),
            returns: .int
        )
        #expect(signature.isVariadic)
        #expect(signature.validate([.int]) == .invalidNumberOfArguments)
        #expect(signature.validate([.int, .int, .int]) == .invalidNumberOfArguments)
        #expect(signature.validate([.int, .int, .int, .int]) == .ok)
    }
}
