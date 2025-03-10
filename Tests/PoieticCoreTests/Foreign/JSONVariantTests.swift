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
        #expect(try decode("10.2") == .double(10.2))
        #expect(try decode("\"text\"") == .string("text"))
        #expect(try decode("null") == .null)
        #expect(try decode("[10, true]") == .array([.int(10), .bool(true)]))
        #expect(try decode("{\"a\": 10, \"b\": true}")
                == .object(["a": .int(10), "b": .bool(true)]))
    }
    
    @Test func valueEncoding() throws {
        #expect(JSONValue.int(10).asJSONString() == "10")
        #expect(JSONValue.double(10.2).asJSONString() == "10.2")
        #expect(JSONValue.bool(true).asJSONString() == "true")
        #expect(JSONValue.string("text").asJSONString() == "\"text\"")
        #expect(JSONValue.null.asJSONString() == "null")
        #expect(JSONValue.array([.int(10), .bool(true)]).asJSONString()
                == "[10,true]")
        #expect(JSONValue.object(["a": .int(10)]).asJSONString()
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
        #expect(VariantAtom(10).asJSON().asJSONString() == "10")
        #expect(VariantAtom(10.1).asJSON().asJSONString() == "10.1")
        #expect(VariantAtom(true).asJSON().asJSONString() == "true")
        #expect(VariantAtom("hello").asJSON().asJSONString() == "\"hello\"")
        #expect(VariantAtom(Point(10, 20)).asJSON().asJSONString() == "[10,20]")
    }
}

