//
//  ExpressionParserTests.swift
//
//
//  Created by Stefan Urbanek on 28/05/2022.
//

import Testing
@testable import PoieticCore


@Suite struct ExpressionParserTests {
    @Test func empty() {
        let parser = ExpressionParser(string: "")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser.parse()
        }
    }

    @Test func unexpectedToken() throws {
        let parser = ExpressionParser(string: "$")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser.parse()
        }

        let parser2 = ExpressionParser(string: "1 1")
        #expect(throws: ExpressionSyntaxError.unexpectedToken) {
            try parser2.parse()
        }
    }

    @Test func parseBinary() throws {
        let expr = UnboundExpression.binary( "+", .variable("a"), .value(1) )
        #expect(try ExpressionParser(string: "a + 1").parse() == expr)
        #expect(try ExpressionParser(string: "a+1").parse() == expr)
    }

    @Test func binaryComparison() throws {
        let expr = UnboundExpression.binary( "<=", .value(1), .value(2) )
        #expect(try ExpressionParser(string: "1 <= 2").parse() == expr)
        #expect(try ExpressionParser(string: "1<=2").parse() == expr)
    }

    @Test func factorAndTermRepetition() throws {
        let expr = UnboundExpression.binary(
            "*",
            .binary( "*", .variable("a"), .variable("b") ),
            .variable("c")
        )
        #expect(try ExpressionParser(string: "a * b * c").parse() == expr)

        let expr2 = UnboundExpression.binary(
            "+",
            .binary( "+", .variable("a"), .variable("b") ),
            .variable("c")
        )
        #expect(try ExpressionParser(string: "a + b + c").parse() == expr2)
    }
    
    @Test func precedence() throws {
        let expr = UnboundExpression.binary(
            "+",
            .variable("a"),
            .binary( "*", .variable("b"), .variable("c") )
        )
        #expect(try ExpressionParser(string: "a + b * c").parse() == expr)
        #expect(try ExpressionParser(string: "a + (b * c)").parse() == expr)

        let expr2 = UnboundExpression.binary(
            "+",
            .binary( "*", .variable("a"), .variable("b") ),
            .variable("c")
        )
        #expect(try ExpressionParser(string: "a * b + c").parse() == expr2)
        #expect(try ExpressionParser(string: "(a * b) + c").parse() == expr2)
    }
    
    @Test func unaryExpression() throws {
        let expr = UnboundExpression.unary("-", .variable("x"))
        #expect(try ExpressionParser(string: "-x").parse() == expr)

        let expr2 = UnboundExpression.binary(
            "-",
            .variable("x"),
            .unary( "-", .variable("y") )
        )
        #expect(try ExpressionParser(string: "x - -y").parse() == expr2)
    }
    @Test func functionCall() throws {
        let expr = UnboundExpression.function("fun", [.variable("x")])
        #expect(try ExpressionParser(string: "fun(x)").parse() == expr)

        let expr2 = UnboundExpression.function("fun", [.variable("x"), .variable("y")])
        #expect(try ExpressionParser(string: "fun(x,y)").parse() == expr2)

    }
    
    @Test func errorMissingParenthesis() throws {
        let parser = ExpressionParser(string: "(")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser.parse()
        }
    }
    @Test func errorMissingParenthesisFunctionCall() throws {
        let parser = ExpressionParser(string: "func(1,2,3")
        #expect(throws: ExpressionSyntaxError.missingRightParenthesis) {
            try parser.parse()
        }
    }
    
    @Test func unaryExpressionExpected() throws {
        let parser = ExpressionParser(string: "1 + -")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser.parse()
        }

        let parser2 = ExpressionParser(string: "-")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser2.parse()
        }
    }
    
    @Test func factorUnaryExpressionExpected() throws {
        let parser = ExpressionParser(string: "1 *")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser.parse()
        }
    }
    
    @Test func termExpressionExpected() throws {
        let parser = ExpressionParser(string: "1 +")
        #expect(throws: ExpressionSyntaxError.expressionExpected) {
            try parser.parse()
        }
    }

    @Test func fullText() throws {
        // All-in-one, but works. Split this when nodes start mis-behaving.
        let text = " - ( a  + b ) * f( c, d, 100_000\n)"
        let parser = ExpressionParser(string: text)
        let result = try #require(try parser.expression(),
                                  "Expected valid expression to be parsed")
        #expect(result.fullText == "-(a+b)*f(c,d,100_000)")
    }
}
