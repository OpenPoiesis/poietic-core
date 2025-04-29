//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 16/12/2024.
//

import Testing
import Foundation
@testable import PoieticCore

@Suite struct JSONValueTests {
    func decode(_ string: String) throws -> JSONValue {
        let decoder = JSONDecoder()
        return try decoder.decode(JSONValue.self, from: Data(string.utf8))
    }
    
    @Test func valueDecoding() throws {
        #expect(try decode("10") == .int(10))
        #expect(try decode("true") == .bool(true))
        #expect(try decode("10.2") == .float(10.2))
        #expect(try decode("\"text\"") == .string("text"))
        #expect(try decode("null") == .null)
        #expect(try decode("[10, true]") == .array([.int(10), .bool(true)]))
        #expect(try decode("{\"a\": 10, \"b\": true}")
                == .object(["a": .int(10), "b": .bool(true)]))
    }
    
    @Test func valueEncoding() throws {
        #expect(try JSONValue.int(10).string() == "10")
        #expect(try JSONValue.float(10.2).string() == "10.2")
        #expect(try JSONValue.bool(true).string() == "true")
        #expect(try JSONValue.string("text").string() == "\"text\"")
        #expect(try JSONValue.null.string() == "null")
        #expect(try JSONValue.array([.int(10), .bool(true)]).string()
                == "[10,true]")
        #expect(try JSONValue.object(["a": .int(10)]).string()
                == "{\"a\":10}")
    }
}

@Suite struct JSONVariantTests {
    @Test func intVariantFromJSON() throws {
        #expect(try Variant(json: JSONValue(parsing: "0")) == Variant(0))
        #expect(try Variant(json: JSONValue(parsing: "-10")) == Variant(-10))
        #expect(try Variant(json: JSONValue(parsing: "10.0")) == Variant(10))
    }

    @Test func doubleVariantFromJSON() throws {
        #expect(try Variant(json: JSONValue(parsing: "12.3")) == Variant(12.3))
    }
    @Test func boolVariantFromJSON() throws {
        #expect(try Variant(json: JSONValue(parsing: "true")) == Variant(true))
        #expect(try Variant(json: JSONValue(parsing: "false")) == Variant(false))
    }

    @Test func stringVariantFromJSON() throws {
        #expect(try Variant(json: JSONValue(parsing: "\"hello\"")) == Variant("hello"))
    }
    @Test func arrayVariantFromJSON() throws {
        #expect(try Variant(json: JSONValue(parsing: "[10, 20]"))
                == Variant([10, 20]))
        #expect(try Variant(json: JSONValue(parsing: "[[10, 20]]"))
                == Variant([Point(x: 10, y:20)]))
    }

    @Test func atomToJSON() throws {
        #expect(try VariantAtom(10).asJSON().string() == "10")
        #expect(try VariantAtom(10.1).asJSON().string() == "10.1")
        #expect(try VariantAtom(true).asJSON().string() == "true")
        #expect(try VariantAtom("hello").asJSON().string() == "\"hello\"")
        #expect(try VariantAtom(Point(10, 20)).asJSON().string() == "[10,20]")
    }
}

