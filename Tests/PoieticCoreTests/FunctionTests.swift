//
//  FunctionTests.swift
//
//
//  Created by Stefan Urbanek on 05/07/2023.
//

import XCTest
@testable import PoieticCore
@testable import PoieticFlows


final class FunctionTests: XCTestCase {
    func testSignatureEmpty() throws {
        let signature = Signature()
        
        XCTAssertFalse(signature.isVariadic)
        XCTAssertEqual(signature.validate(), .ok)
    }
    
    func testPositional() throws {
        let signature = Signature([
            FunctionArgument("a", type: .concrete(.int)),
            FunctionArgument("b", type: .concrete(.int)),
            FunctionArgument("c", type: .concrete(.int)),
        ])
        
        XCTAssertEqual(signature.validate([.int, .int, .int]), .ok)
        XCTAssertEqual(signature.validate([.int, .int, .double]),
                       .typeMismatch([2]))
        XCTAssertEqual(signature.validate([.double, .double, .double]),
                       .typeMismatch([0, 1, 2]))
        
        XCTAssertEqual(signature.validate([]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .int, .int]), .invalidNumberOfArguments)
    }
    
    func testVariadic() throws {
        let signature = Signature(
            variadic: FunctionArgument("things", type: .concrete(.int))
        )
        XCTAssertTrue(signature.isVariadic)
        
        XCTAssertEqual(signature.validate([.int]), .ok)
        XCTAssertEqual(signature.validate([.int, .int, .int]), .ok)
        XCTAssertEqual(signature.validate([]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .double]),
                       .typeMismatch([2]))
        XCTAssertEqual(signature.validate([.double, .double, .double]),
                       .typeMismatch([0, 1, 2]))
    }
    
    func testVariadicAndPositional() throws {
        let signature = Signature(
            [
                FunctionArgument("a", type: .concrete(.int)),
                FunctionArgument("b", type: .concrete(.int)),
                FunctionArgument("c", type: .concrete(.int)),
            ],
            variadic: FunctionArgument("things", type: .concrete(.int))
        )
        XCTAssertTrue(signature.isVariadic)

        XCTAssertEqual(signature.validate([.int]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .int]), .invalidNumberOfArguments)
        XCTAssertEqual(signature.validate([.int, .int, .int, .int]), .ok)
    }
}
