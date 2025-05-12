//
//  JSONFrameReader.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation
// TODO: [WIP] Add reading context to the reader (such as path)

public enum RawDesignReaderError: Error, Equatable {

    public enum PathItem: Equatable, Sendable {
        case int(Int)
        case string(String)
        
        var stringValue: String {
            switch self {
            case .int(let value): String(value)
            case .string(let value): value
            }
        }
    }
    protocol EquatableError: Error, Equatable {
        
    }
    public struct Context: Sendable, Equatable {

        let path: [PathItem]
        let underlyingError: (any Error)?
        
        init(_ decodingContext: DecodingError.Context) {
            var path: [PathItem] = []
            for item in decodingContext.codingPath {
                if let value = item.intValue {
                    path.append(.int(value))
                }
                else {
                    path.append(.string(item.stringValue))
                }
            }
            self.path = path
            self.underlyingError = decodingContext.underlyingError
        }
        init(path: [PathItem] = [], underlyingError: (any Error)?) {
            self.path = path
            self.underlyingError = underlyingError
        }
        
        public static func == (lhs: RawDesignReaderError.Context, rhs: RawDesignReaderError.Context) -> Bool {
            guard lhs.path == rhs.path else { return false }
            if lhs.underlyingError == nil && rhs.underlyingError == nil {
                return true
            }
            guard let lhsError = lhs.underlyingError, let rhsError = rhs.underlyingError else {
                return false
            }
            return "\(lhsError)" == "\(rhsError)"
        }
        
    }

    /// The data can not be read or parsed.
    ///
    case dataCorrupted(Context)
    case canNotReadData

    /// Error thrown when the reader can not read given version.
    ///
    /// Caller should catch this error and dispatch accordingly to other kinds of readers,
    /// if available.
    ///
    case unknownFormatVersion(String)

    case typeMismatch(String, [String])
    case valueNotFound(String, [String])
    case propertyNotFound(String, [String])
    case unknownDecodingError(String)

    
    init(_ error: DecodingError) {
        switch error {
            
        case let .typeMismatch(type, context):
            let path = context.codingPath.map { $0.stringValue }
            if type.self is Dictionary<String, Any>.Type {
                self = .typeMismatch("dictionary", path)
            }
            else if type.self is Array<Any>.Type {
                self = .typeMismatch("array", path)
            }
            else {
                self = .typeMismatch("\(type)", path)
            }

        case let .valueNotFound(key, context):
            let path = context.codingPath.map { $0.stringValue }
            self = .valueNotFound(String(describing: key), path)
            
        case let .keyNotFound(key, context):
            let path = context.codingPath.map { $0.stringValue }
            let key = key.stringValue
            self = .propertyNotFound(key, path)

        case let .dataCorrupted(context):
            self = .dataCorrupted(RawDesignReaderError.Context(context))

        @unknown default:
            self = .unknownDecodingError(String(describing: error))
        }
    }
}

/// Object for reading foreign frames represented as JSON.
///
/// - Note: Hand-writing foreign frames in JSON is discouraged, as they might become
///   complex very quickly. It is not the purpose of this toolkit to
///   process and maintain raw human-written textual representation of designs.
///
/// There are two representations of a foreign frame as JSON: single-file representation
/// and a bundle representation.
///
/// The single file representation is a dictionary with the keys described below:
///
/// - `format_version` _(recommended, string)_: Format of the frame. Currently `0`.
///    See ``JSONFrameReader/CurrentFormatVersion``.
/// - `objects`: An array of objects. See below _Foreign Objects_.
/// - `collections` (optional): List of collection names, if the frame is represented as a bundle.
///
/// Bundle or a directory representation is a directory that contains a required `info.json`
/// file and a collection of files with objects in the `objects` subdirectory. Typical bundle
/// directory structure might look like this:
///
/// ```
/// MyDesign.poieticframe/
///     info.json
///     objects/
///         design.json
///         main.json
///         ...
/// ```
///
/// - Note: The reason for a bundle representation is an experimentation with potential future
///   format that might include other assets in their more native form, such as data in CSV files.
///
/// ## Foreign Objects
///
/// The JSON representation of foreign object is a dictionary with the following
/// keys and their corresponding _string_ values:
///
/// - `id` (optional): Object ID, if not provided, one will be generated during
///   loading.
/// - `snapshot_id` (optional): snapshot ID, if not provided, one will be
///   generated during loading
/// - `name` (optional): used as both, object name and an object reference.
///   See note below about references. If provided, it will be used as
///   an attribute `name` of the object.
/// - `type` (required): name of the object type. During the loading process
///   the type must be known to the loader.
/// - `from` (contextual): if the object is an edge, the property references its origin
/// - `to` (contextual): if the object is an edge, the property references its target
/// - `parent` (optional): reference to object's parent
/// - `attributes`: a dictionary where keys are attribute names and values are
///    attribute values.
///
///
/// ## References
///
/// Typically the unique identifier of an object within a frame is its ID.
/// For convenience of hand-writing small foreign frames, objects can be
/// referenced by their names as well. One can refer to an object by its
/// name in an edge origin or a target, for example.
///
/// When multiple objects have the same name, then which object a reference
/// refers to is undefined.
///
///
/// ## Attributes and Variant Values
///
/// The variant values in the attribute dictionary are decoded from JSON as follows:
///
/// | JSON value | Variant | Example | Note |
/// |---|---|:---|:---|
/// | bool | bool | `true` | |
/// | number | int or double | `100` | First try exact conversion to _int_, otherwise _double_ |
/// | string | string | `"thing"` | |
/// | array of scalars | array of first item type | `[10, 20, 30]` | All items must be of the same type |
/// | array of two-number arrays | array of points | `[[0, 0], [10.5, 0]]` | Items must be exactly two numbers |
///
/// Any other JSON value is considered invalid.
///
/// The JSON encoding is lose and non-symmetric.
///
/// | Original Variant | Encoded JSON | Decoded Variant | Note |
/// |---|---|---|:---|
/// | bool | bool | bool | |
/// | int | number | int | |
/// | double | number | int or double | Decoded variant depends on the original variant's convertibility to int |
/// | string | string | string | |
/// | point | array of numbers | array of doubles | |
/// | array of bool | array of bool | array of bool |  |
/// | array of int | array of int | array of int |  |
/// | array of double | array of numbers | array of ints or doubles | Depends on the original variant's values |
/// | array of strings | array of strings | array of strings | |
/// | array of points | array of two-item number arrays | array of points | |
///
    /// There is no explicit JSON way of specifying a single point, it has to be expressed
/// as a two-item array of two numbers. Even then it will be treated just as an array of numbers.
///
/// Invalid variant values are:
///
/// - a dictionary
/// - an array of different types
/// - any nested arrays except the point array
///
public final class JSONDesignReader {
    // TODO: Rename to DecodableDesignReader
    public static let CurrentFormatVersion = SemanticVersion(0, 4, 0)
    public static let CompatibilityVersionKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "CompatibilityVersionKey")!
    
    // TODO: let forceFormatVersion: SemanticVersion
    
    /// Create a frame reader.
    ///
    public init() {
        // Nothing here for now
    }
    
    public func read(fileAtURL url: URL) throws (RawDesignReaderError) -> RawDesign {
        var data: Data
        do {
            data = try Data(contentsOf: url)
        }
        catch {
            
            throw .canNotReadData
        }
        return try read(data: data)
    }
    
    public func read(data: Data) throws (RawDesignReaderError) -> RawDesign {
        let decoder = JSONDecoder()
        decoder.userInfo[Variant.CodingTypeKey] = Variant.CodingType.dictionary
        
        let rawDesign: RawDesign
        do {
            rawDesign = try decoder.decode(RawDesign.self, from: data)
        }
        catch let error as DecodingError {
            throw RawDesignReaderError(error)
        }
        catch RawDesignReaderError.unknownFormatVersion(let version) {
            rawDesign = try read(data: data, version: version)
        }
        catch {
            // TODO: What other errors can happen here? Custom decoding errors?
            fatalError("Unhandled reader error \(type(of:error)): \(error)")
        }
        
        return rawDesign
    }
    public func read(data: Data, version: String) throws (RawDesignReaderError) -> RawDesign {
        switch version {
        case "makeshift_store":
            let makeshiftDesign: _MakeshiftPersistentDesign
            do {
                let decoder = JSONDecoder()
                makeshiftDesign = try decoder.decode(_MakeshiftPersistentDesign.self, from: data)
            }
            catch let error as DecodingError {
                throw RawDesignReaderError(error)
            }
            catch {
                // TODO: [WIP] HANDLE ERROR
                print("CAN NOT READ DATA: \(error)")
                throw .canNotReadData
            }
            return makeshiftDesign.asRawDesign()
        default:
            throw RawDesignReaderError.unknownFormatVersion(version)
        }
    }
}

public extension JSONValue {
    var rawIDValue: RawObjectID? {
        switch self {
        case let .int(value): .int(Int64(value))
        case let .string(value): .string(value)
        default: nil
        }
    }
    var rawIDArrayValue: [RawObjectID]? {
        guard let items = self.arrayValue else {
            return nil
        }
        var ids: [RawObjectID] = []
        for item in items {
            guard let id = item.rawIDValue else {
                return nil
            }
            ids.append(id)
        }
        return ids
    }
}

// Legacy
