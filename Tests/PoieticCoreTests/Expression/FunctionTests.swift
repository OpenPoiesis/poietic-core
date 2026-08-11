//
//  FunctionTests.swift
//
//
//  Created by Stefan Urbanek on 05/07/2023.
//

import Testing
@testable import PoieticCore

/// Tests for `BuiltinFunction.Signature.validate(_:)`.
///
/// The Variant type system allows broad implicit conversions:
/// - `bool` → `int` → `double` (numeric chain)
/// - `int` → `bool`, `string` → `bool`
/// - `string` → `int`, `string` → `double`
/// - `point` → nothing except `string` and itself
///
/// Therefore `.point` is the only type that reliably rejects numeric
/// signatures, and `.double` (or `.point`) rejects boolean signatures.
@Suite struct SignatureTests {

    typealias Sig = BuiltinFunction.Signature
    typealias Result = ArgumentValidationResult

    @Test func unaryNumeric() {
        #expect(Sig.unaryNumeric.validate([.int]) == .ok)
        #expect(Sig.unaryNumeric.validate([.double]) == .ok)
        #expect(Sig.unaryNumeric.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.unaryNumeric.validate([.int, .int]) == .invalidNumberOfArguments)
        #expect(Sig.unaryNumeric.validate([.point]) == .typeMismatch([0]))
    }

    @Test func variadicNumeric_valid() {
        // Zero arguments is ok for plain variadic
        #expect(Sig.variadicNumeric.validate([]) == .ok)
        #expect(Sig.variadicNumeric.validate([.double]) == .ok)
        #expect(Sig.variadicNumeric.validate([.int, .double, .int]) == .ok)
    }

    @Test func variadicNumeric_typeMismatch() {
        #expect(Sig.variadicNumeric.validate([.point]) == .typeMismatch([0]))
        #expect(Sig.variadicNumeric.validate([.int, .point, .double]) == .typeMismatch([1]))
        #expect(Sig.variadicNumeric.validate([.point, .point]) == .typeMismatch([0, 1]))
    }

    @Test func variadicNumericNonEmpty() {
        #expect(Sig.variadicNumericNonEmpty.validate([.double]) == .ok)
        #expect(Sig.variadicNumericNonEmpty.validate([.int, .double, .int]) == .ok)
        #expect(Sig.variadicNumericNonEmpty.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.variadicNumericNonEmpty.validate([.point]) == .typeMismatch([0]))
    }

    @Test func unaryBoolean() {
        #expect(Sig.unaryBoolean.validate([.bool]) == .ok)
        #expect(Sig.unaryBoolean.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.unaryBoolean.validate([.bool, .bool]) == .invalidNumberOfArguments)
        #expect(Sig.unaryBoolean.validate([.double]) == .typeMismatch([0]))
    }

    @Test func ternaryConditional() {
        #expect(Sig.ternaryConditional.validate([.bool, .int, .double]) == .ok)
        #expect(Sig.ternaryConditional.validate([.bool, .string, .point]) == .ok)

        #expect(Sig.ternaryConditional.validate([.bool, .int]) == .invalidNumberOfArguments)
        #expect(Sig.ternaryConditional.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.ternaryConditional.validate([.bool, .int, .int, .int]) == .invalidNumberOfArguments)

        // First argument must be convertible to bool
        // double does NOT convert to bool
        #expect(Sig.ternaryConditional.validate([.double, .int, .int]) == .typeMismatch([0]))
    }

    @Test func returnTypes() {
        #expect(Sig.unaryNumeric.returnType == .double)
        #expect(Sig.variadicNumeric.returnType == .double)
        #expect(Sig.variadicNumericNonEmpty.returnType == .double)
        #expect(Sig.variadicBoolean.returnType == .bool)
        #expect(Sig.unaryBoolean.returnType == .bool)
        #expect(Sig.ternaryConditional.returnType == .double)
    }

    @Test func minimalArgumentCounts() {
        #expect(Sig.unaryNumeric.minimalArgumentCount == 1)
        #expect(Sig.variadicNumeric.minimalArgumentCount == 0)
        #expect(Sig.variadicNumericNonEmpty.minimalArgumentCount == 1)
        #expect(Sig.variadicBoolean.minimalArgumentCount == 2)
        #expect(Sig.unaryBoolean.minimalArgumentCount == 1)
        #expect(Sig.ternaryConditional.minimalArgumentCount == 3)
    }
}
