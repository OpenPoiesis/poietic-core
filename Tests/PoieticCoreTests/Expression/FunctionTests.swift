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
    typealias Result = BuiltinFunction.SignatureValidationResult

    // MARK: - unaryNumeric

    @Test func unaryNumeric_valid() {
        #expect(Sig.unaryNumeric.validate([.int]) == .ok)
        #expect(Sig.unaryNumeric.validate([.double]) == .ok)
    }

    @Test func unaryNumeric_invalidCount() {
        #expect(Sig.unaryNumeric.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.unaryNumeric.validate([.int, .int]) == .invalidNumberOfArguments)
    }

    @Test func unaryNumeric_typeMismatch() {
        // point does not convert to any numeric
        #expect(Sig.unaryNumeric.validate([.point]) == .typeMismatch([0]))
    }

    // MARK: - binaryNumeric

    @Test func binaryNumeric_valid() {
        #expect(Sig.binaryNumeric.validate([.double, .double]) == .ok)
        #expect(Sig.binaryNumeric.validate([.int, .int]) == .ok)
        #expect(Sig.binaryNumeric.validate([.int, .double]) == .ok)
    }

    @Test func binaryNumeric_invalidCount() {
        #expect(Sig.binaryNumeric.validate([.int]) == .invalidNumberOfArguments)
        #expect(Sig.binaryNumeric.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.binaryNumeric.validate([.int, .int, .int]) == .invalidNumberOfArguments)
    }

    @Test func binaryNumeric_typeMismatch() {
        #expect(Sig.binaryNumeric.validate([.point, .int]) == .typeMismatch([0]))
        #expect(Sig.binaryNumeric.validate([.int, .point]) == .typeMismatch([1]))
        #expect(Sig.binaryNumeric.validate([.point, .point]) == .typeMismatch([0, 1]))
    }

    // MARK: - variadicNumeric

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

    // MARK: - variadicNumericNonEmpty

    @Test func variadicNumericNonEmpty_valid() {
        #expect(Sig.variadicNumericNonEmpty.validate([.double]) == .ok)
        #expect(Sig.variadicNumericNonEmpty.validate([.int, .double, .int]) == .ok)
    }

    @Test func variadicNumericNonEmpty_invalidCount() {
        #expect(Sig.variadicNumericNonEmpty.validate([]) == .invalidNumberOfArguments)
    }

    @Test func variadicNumericNonEmpty_typeMismatch() {
        #expect(Sig.variadicNumericNonEmpty.validate([.point]) == .typeMismatch([0]))
    }

    // MARK: - unaryBoolean

    @Test func unaryBoolean_valid() {
        #expect(Sig.unaryBoolean.validate([.bool]) == .ok)
        // Note: `.int` and `.string` are also valid — they convert to bool
    }

    @Test func unaryBoolean_invalidCount() {
        #expect(Sig.unaryBoolean.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.unaryBoolean.validate([.bool, .bool]) == .invalidNumberOfArguments)
    }

    @Test func unaryBoolean_typeMismatch() {
        // double does not convert to bool
        #expect(Sig.unaryBoolean.validate([.double]) == .typeMismatch([0]))
    }

    // MARK: - binaryBoolean

    @Test func binaryBoolean_valid() {
        #expect(Sig.binaryBoolean.validate([.bool, .bool]) == .ok)
    }

    @Test func binaryBoolean_invalidCount() {
        #expect(Sig.binaryBoolean.validate([.bool]) == .invalidNumberOfArguments)
        #expect(Sig.binaryBoolean.validate([.bool, .bool, .bool]) == .invalidNumberOfArguments)
    }

    @Test func binaryBoolean_typeMismatch() {
        // double does not convert to bool
        #expect(Sig.binaryBoolean.validate([.double, .bool]) == .typeMismatch([0]))
        #expect(Sig.binaryBoolean.validate([.bool, .double]) == .typeMismatch([1]))
        #expect(Sig.binaryBoolean.validate([.double, .double]) == .typeMismatch([0, 1]))
    }

    // MARK: - binaryComparable — requires numeric

    @Test func binaryComparable_valid() {
        #expect(Sig.binaryComparable.validate([.int, .double]) == .ok)
        #expect(Sig.binaryComparable.validate([.double, .int]) == .ok)
    }

    @Test func binaryComparable_invalidCount() {
        #expect(Sig.binaryComparable.validate([.int]) == .invalidNumberOfArguments)
        #expect(Sig.binaryComparable.validate([]) == .invalidNumberOfArguments)
    }

    @Test func binaryComparable_typeMismatch() {
        #expect(Sig.binaryComparable.validate([.point, .int]) == .typeMismatch([0]))
        #expect(Sig.binaryComparable.validate([.int, .point]) == .typeMismatch([1]))
        #expect(Sig.binaryComparable.validate([.point, .point]) == .typeMismatch([0, 1]))
    }

    // MARK: - binaryEquatable — accepts any types

    @Test func binaryEquatable_valid() {
        #expect(Sig.binaryEquatable.validate([.int, .int]) == .ok)
        #expect(Sig.binaryEquatable.validate([.bool, .string]) == .ok)
        #expect(Sig.binaryEquatable.validate([.double, .point]) == .ok)
    }

    @Test func binaryEquatable_invalidCount() {
        #expect(Sig.binaryEquatable.validate([.int]) == .invalidNumberOfArguments)
        #expect(Sig.binaryEquatable.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.binaryEquatable.validate([.int, .int, .int]) == .invalidNumberOfArguments)
    }

    // MARK: - ternaryConditional

    @Test func ternaryConditional_valid() {
        #expect(Sig.ternaryConditional.validate([.bool, .int, .double]) == .ok)
        #expect(Sig.ternaryConditional.validate([.bool, .string, .point]) == .ok)
    }

    @Test func ternaryConditional_invalidCount() {
        #expect(Sig.ternaryConditional.validate([.bool, .int]) == .invalidNumberOfArguments)
        #expect(Sig.ternaryConditional.validate([]) == .invalidNumberOfArguments)
        #expect(Sig.ternaryConditional.validate([.bool, .int, .int, .int]) == .invalidNumberOfArguments)
    }

    @Test func ternaryConditional_typeMismatch() {
        // First argument must be convertible to bool
        // double does NOT convert to bool
        #expect(Sig.ternaryConditional.validate([.double, .int, .int]) == .typeMismatch([0]))
    }

    // MARK: - returnType

    @Test func returnTypes() {
        #expect(Sig.unaryNumeric.returnType == .double)
        #expect(Sig.binaryNumeric.returnType == .double)
        #expect(Sig.variadicNumeric.returnType == .double)
        #expect(Sig.variadicNumericNonEmpty.returnType == .double)
        #expect(Sig.unaryBoolean.returnType == .bool)
        #expect(Sig.binaryBoolean.returnType == .bool)
        #expect(Sig.binaryComparable.returnType == .bool)
        #expect(Sig.binaryEquatable.returnType == .bool)
        #expect(Sig.ternaryConditional.returnType == .double)
    }

    // MARK: - minimalArgumentCount

    @Test func minimalArgumentCounts() {
        #expect(Sig.unaryNumeric.minimalArgumentCount == 1)
        #expect(Sig.binaryNumeric.minimalArgumentCount == 2)
        #expect(Sig.variadicNumeric.minimalArgumentCount == 0)
        #expect(Sig.variadicNumericNonEmpty.minimalArgumentCount == 1)
        #expect(Sig.unaryBoolean.minimalArgumentCount == 1)
        #expect(Sig.binaryBoolean.minimalArgumentCount == 2)
        #expect(Sig.binaryComparable.minimalArgumentCount == 2)
        #expect(Sig.binaryEquatable.minimalArgumentCount == 2)
        #expect(Sig.ternaryConditional.minimalArgumentCount == 3)
    }
}
