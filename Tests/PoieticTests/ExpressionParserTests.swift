//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 28/05/2022.
//

import XCTest
@testable import Poietic


final class ExpressionParserTests: XCTestCase {
    func testEmpty() {
        let parser = ExpressionParser(string: "")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.expressionExpected)
        }
    }

    func testBinary() {
        let expr = UnboundExpression.binary(
            "+",
            .variable("a"),
            .value(1)
        )
        XCTAssertEqual(try ExpressionParser(string: "a + 1").parse(), expr)
        XCTAssertEqual(try ExpressionParser(string: "a+1").parse(), expr)
    }
    
    func testFactorAndTermRepetition() {
        let expr = UnboundExpression.binary(
            "*",
            .binary(
                "*",
                .variable("a"),
                .variable("b")
            ),
            .variable("c")
        )
        XCTAssertEqual(try ExpressionParser(string: "a * b * c").parse(), expr)

        let expr2 = UnboundExpression.binary(
            "+",
            .binary(
                "+",
                .variable("a"),
                .variable("b")
            ),
            .variable("c")
        )
        XCTAssertEqual(try ExpressionParser(string: "a + b + c").parse(), expr2)
    }
    
    func testPrecedence() {
        let expr = UnboundExpression.binary(
            "+",
            .variable("a"),
            .binary(
                "*",
                .variable("b"),
                .variable("c")
            )
        )
        XCTAssertEqual(try ExpressionParser(string: "a + b * c").parse(), expr)
        XCTAssertEqual(try ExpressionParser(string: "a + (b * c)").parse(), expr)

        let expr2 = UnboundExpression.binary(
            "+",
            .binary(
                "*",
                .variable("a"),
                .variable("b")
            ),
            .variable("c")
        )
        XCTAssertEqual(try ExpressionParser(string: "a * b + c").parse(), expr2)
        XCTAssertEqual(try ExpressionParser(string: "(a * b) + c").parse(), expr2)
    }
    
    func testUnary() {
        let expr = UnboundExpression.unary("-", .variable("x"))
        XCTAssertEqual(try ExpressionParser(string: "-x").parse(), expr)

        let expr2 = UnboundExpression.binary(
            "-",
            .variable("x"),
            .unary(
                "-",
                .variable("y")
            )
        )
        XCTAssertEqual(try ExpressionParser(string: "x - -y").parse(), expr2)
    }
    func testFunction() {
        let expr = UnboundExpression.function("fun", [.variable("x")])
        XCTAssertEqual(try ExpressionParser(string: "fun(x)").parse(), expr)

        let expr2 = UnboundExpression.function("fun", [.variable("x"), .variable("y")])
        XCTAssertEqual(try ExpressionParser(string: "fun(x,y)").parse(), expr2)

    }
    
    func testErrorMissingParenthesis() throws {
        let parser = ExpressionParser(string: "(")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.expressionExpected)
        }
    }
    func testErrorMissingParenthesisFunctionCall() throws {
        let parser = ExpressionParser(string: "func(1,2,3")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.missingRightParenthesis)
        }
    }
    
    func testUnaryExpressionExpected() throws {
        let parser = ExpressionParser(string: "1 + -")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.expressionExpected)
        }

        let parser2 = ExpressionParser(string: "-")
        XCTAssertThrowsError(try parser2.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.expressionExpected)
        }
    }
    
    func testFactorUnaryExpressionExpected() throws {
        let parser = ExpressionParser(string: "1 *")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.expressionExpected)
        }
    }
    
    func testTermExpressionExpected() throws {
        let parser = ExpressionParser(string: "1 +")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.expressionExpected)
        }
    }

    func testUnexpectedToken() throws {
        let parser = ExpressionParser(string: "1 1")
        XCTAssertThrowsError(try parser.parse()) {
            XCTAssertEqual($0 as! SyntaxError, SyntaxError.unexpectedToken)
        }
    }
    
    func testFullText() throws {
        let text = "-( a  + b ) * f( c, d, 100_000\n)"
        let parser = ExpressionParser(string: text)
        guard let result = try parser.expression() else {
            XCTFail("Expected valid expression to be parsed")
            return
        }
        XCTAssertEqual(text, result.fullText)
    }
}
