//
//  Variant+JSON.swift
//
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import Foundation

extension Variant {
    /// Try to read value from JSON: first try a variant-encoded dictionary
    /// then try to guess the value from JSON native value.
    ///
    /// | JSON value | Decoded variant | Note |
    /// | --- | --- | --- |
    /// | number | int or double atom | Try to convert to int first then to double |
    /// | string | string atom | |
    /// | bool | bool atom | |
    /// | array of numbers | Try to convert to int first then to double |
    /// | array of strings | string array | |
    /// | array of bools | bool array | |
    /// | array of arrays | array of points | Must be 2-item arrays with numbers |
    /// | heterogenous array | decoding error | |
    /// | object (dictionary) | decoding error | |
    ///
    /// There is no direct way how to specify a single point in JSON.
    /// Two item array is convertible to a point, therefore we do not need to guess it now.
    ///
    /// - Important: Use this method only for user input, such as in command-line tools or
    ///   text fields in an application. Do not use for data interchange.
    ///
    public init(jsonWithFallback string: String) throws {
        let decoder = JSONDecoder()
        decoder.userInfo[Variant.DecodingTypeKey] = Variant.DecodingType.dictionaryWithFallback
        
        guard let data = string.data(using: .utf8) else {
            let context = DecodingError.Context(codingPath: [],
                                                debugDescription: "Can not get data")
            throw DecodingError.dataCorrupted(context)
        }
        
        let value = try decoder.decode(Variant.self, from: data)

        self = value
    }
}
