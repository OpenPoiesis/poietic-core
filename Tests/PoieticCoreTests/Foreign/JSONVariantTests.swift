//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 16/12/2024.
//

import Testing
import Foundation
@testable import PoieticCore

@Suite struct JSONVariantTests {
    @Test func intVariantFromJSON() throws {
        #expect(try Variant(jsonWithFallback: "0") == Variant(0))
        #expect(try Variant(jsonWithFallback: "-10") == Variant(-10))
        #expect(try Variant(jsonWithFallback: "10.0") == Variant(10))
    }

    @Test func doubleVariantFromJSON() throws {
        #expect(try Variant(jsonWithFallback: "12.3") == Variant(12.3))
    }
    @Test func boolVariantFromJSON() throws {
        #expect(try Variant(jsonWithFallback: "true") == Variant(true))
        #expect(try Variant(jsonWithFallback: "false") == Variant(false))
    }

    @Test func stringVariantFromJSON() throws {
        #expect(try Variant(jsonWithFallback: "\"hello\"") == Variant("hello"))
    }
    @Test func arrayVariantFromJSON() throws {
        #expect(try Variant(jsonWithFallback: "[10, 20]")
                == Variant([10, 20]))
        #expect(try Variant(jsonWithFallback: "[[10, 20]]")
                == Variant([Point(x: 10, y:20)]))
    }
}

@Suite struct JSONVariantDecoding {
    var decoder = JSONDecoder()
    
    func data(_ string: String) -> Data {
        string.data(using: .utf8)!
    }
    
    func decode(_ string: String) throws -> Variant {
        try decoder.decode(Variant.self, from: string.data(using: .utf8)!)
    }
    
    @Test func dictionaryInt() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"int\", \"value\": 10}") == Variant(10))
    }
    @Test func dictionaryDouble() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"float\", \"value\": 10.5}") == Variant(10.5))
    }
    @Test func dictionaryBool() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"bool\", \"value\": true}") == Variant(true))
    }
    @Test func dictionaryString() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"string\", \"value\": \"thing\"}") == Variant("thing"))
    }
    @Test func dictionaryIntArray() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"int_array\", \"items\": [10, 20]}") == Variant([10, 20]))
        #expect(try decode("{\"type\": \"int_array\", \"items\": []}") == .array(.int([])))
    }
    @Test func dictionaryDoubleArray() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"double_array\", \"items\": [10.5, 20.5]}") == Variant([10.5, 20.5]))
        #expect(try decode("{\"type\": \"double_array\", \"items\": []}") == .array(.double([])))
    }
    @Test func dictionaryStringArray() throws {
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionary
        #expect(try decode("{\"type\": \"string_array\", \"items\": [\"one\", \"two\"]}") == Variant(["one", "two"]))
        #expect(try decode("{\"type\": \"string_array\", \"items\": []}") == .array(.string([])))
    }
    // FIXME: Implement NaN and Inf, see JSONDecoder.NonConformingFloatDecodingStrategy
//    @Test func doubleNaNs() throws {
//        decoder.userInfo[Variant.CodingTypeKey] = Variant.CodingType.dictionary
//        #expect(try decode("{\"type\": \"float\ondecoder, \"value\": \"Inf\"}") == Variant(Double.infinity))
//    }

}
