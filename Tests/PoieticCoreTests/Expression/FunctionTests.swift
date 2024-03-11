//
//  FunctionTests.swift
//
//
//  Created by Stefan Urbanek on 05/07/2023.
//

import XCTest
@testable import PoieticCore


final class SignatureTests: XCTestCase {
    func testSignatureEmpty() throws {
        let signature = Signature(returns: .bool)
        
        XCTAssertFalse(signature.isVariadic)
        XCTAssertEqual(signature.validate(), .ok)
    }
    
    func testPositional() throws {
        let signature = Signature([
            FunctionArgument("a", type: .concrete(.int)),
            FunctionArgument("b", type: .concrete(.int)),
            FunctionArgument("c", type: .concrete(.int)),
        ],returns: .int)
        
        XCTAssertEqual(signature.validate([.int, .int, .int]), .ok)
        XCTAssertEqual(signature.validate([.int, .int, .ints]),
                       .typeMismatch([2]))
        XCTAssertEqual(signature.validate([.point, .bools, .strings]),
                       .typeMismatch([0, 1, 2]))
        
        XCTAssertEqual(signature.validate([]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .int, .int]), .invalidNumberOfArguments)
    }
    
    func testVariadic() throws {
        let signature = Signature(
            variadic: FunctionArgument("things", type: .concrete(.int)),
            returns: .int
        )
        XCTAssertTrue(signature.isVariadic)
        
        XCTAssertEqual(signature.validate([.int]), .ok)
        XCTAssertEqual(signature.validate([.int, .int, .int]), .ok)
        XCTAssertEqual(signature.validate([]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .point]),
                       .typeMismatch([2]))
        XCTAssertEqual(signature.validate([.point, .point, .point]),
                       .typeMismatch([0, 1, 2]))
    }
    
    func testVariadicAtLeastOne() throws {
        let signature = Signature(
            variadic: FunctionArgument("values", type: .concrete(.int)),
            returns: .int
        )
        XCTAssertTrue(signature.isVariadic)
        
        XCTAssertEqual(signature.validate([.int]), .ok)
        XCTAssertEqual(signature.validate([.int, .int, .int]), .ok)
        XCTAssertEqual(signature.validate([]), .invalidNumberOfArguments)
    }
    
    func testVariadicAtLeastOneAndPositional() throws {
        let signature = Signature(
            [
                FunctionArgument("a", type: .concrete(.int)),
            ],
            variadic: FunctionArgument("values", type: .concrete(.int)),
            returns: .int
        )
        XCTAssertTrue(signature.isVariadic)
        
        XCTAssertEqual(signature.validate([.int]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int]), .ok)
        XCTAssertEqual(signature.validate([.int, .int, .int]), .ok)
        XCTAssertEqual(signature.validate([]), .invalidNumberOfArguments)
    }

    func testVariadicAndPositional() throws {
        let signature = Signature(
            [
                FunctionArgument("a", type: .concrete(.int)),
                FunctionArgument("b", type: .concrete(.int)),
                FunctionArgument("c", type: .concrete(.int)),
            ],
            variadic: FunctionArgument("things", type: .concrete(.int)),
            returns: .int
        )
        XCTAssertTrue(signature.isVariadic)

        XCTAssertEqual(signature.validate([.int]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .int]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .int, .int]), .ok)
    }
}
