//
//  JSONFrameReader.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation

/// Error raised by the design readers.
///
public enum RawDesignReaderError: Error, Equatable, CustomStringConvertible {

    public enum PathItem: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        
        case int(Int)
        case string(String)
        
        var stringValue: String {
            switch self {
            case .int(let value): String(value)
            case .string(let value): value
            }
        }
        public var description: String { self.stringValue }
        
        public var debugDescription: String {
            switch self {
            case .int(let value): String(value)
            case .string(let value): "\"" + value + "\""
            }
        }
    }

    /// Context of an error that is typically coming from other libraries.
    ///
    public struct Context: Sendable, Equatable {
        /// Path to the item that caused the error, if known.
        public let path: [PathItem]
        /// Actual underlying foreign error, if known.
        public let underlyingError: (any Error)?
        
        /// Create a new context from a decoding error context.
        ///
        public init(_ decodingContext: DecodingError.Context) {
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
        
        /// Create a new foreign error context.
        ///
        public init(path: [PathItem] = [], underlyingError: (any Error)?) {
            self.path = path
            self.underlyingError = underlyingError
        }
        
        /// Loosely compares two errors.
        ///
        /// The foreign underlying errors are compared based on their
        /// description (string) representations. Used only for testing or debugging.
        ///
        /// Internal comparison only. Do not use for anything critical or user-oriented.
        ///
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
        public var debugDescription: String {
            let pathString = path.map { $0.debugDescription }.joined(separator: ",")
            let errorString = underlyingError.map { String(describing: $0) } ?? "(underlying error not specified)"
            return "[\(pathString)], \(errorString)"
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

    
    public var description: String {
        switch self {
        case .canNotReadData: "Can not read data"
        case let .dataCorrupted(context):
            if context.path.isEmpty {
                "Data corrupted"
            }
            else {
                "Data corrupted at path: " + context.path.map { $0.description }.joined(separator: ".")
            }
        case let .propertyNotFound(name, path): "Required property '\(name)' not found at \(path)"
        case let .typeMismatch(type, path): "Type mismatch. Expected \(type) at \(path)"
        case let .unknownDecodingError(error): "Unknown decoding error: \(error)"
        case let .unknownFormatVersion(version): "Unknown format version '\(version)'"
        case let .valueNotFound(property, path): "Value for property '\(property)' not found at \(path)"
        }
    }
    public var debugDescription: String {
        switch self {
        case .canNotReadData: "Can not read data"
        case let .dataCorrupted(error): "Data corrupted. Underlying error: \(error)"
        case let .propertyNotFound(name, path): "Required property '\(name)' not found at \(path)"
        case let .typeMismatch(type, path): "Type mismatch. Expected \(type) at \(path)"
        case let .unknownDecodingError(error): "Unknown decoding error: \(error)"
        case let .unknownFormatVersion(version): "Unknown format version '\(version)'"
        case let .valueNotFound(property, path): "Value for property '\(property)' not found at \(path)"
        }
    }

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

extension RawDesignReaderError: DesignIssueConvertible {
    public func asDesignIssue() -> DesignIssue {
        switch self {
        case .canNotReadData:
            DesignIssue(domain: .foreignInterface,
                        severity: .fatal,
                        identifier: "can_not_read_data",
                        message: description,
                        hint: "Report this error to the project developers",
                        details: [:])
        case let .dataCorrupted(context):
            DesignIssue(domain: .foreignInterface,
                        severity: .error,
                        identifier: "foreign_data_corrupted",
                        message: description,
                        hint: "Use a JSON validation tool",
                        details: [
                            "key_path": Variant(context.path.map { $0.stringValue })
                        ])
        case let .propertyNotFound(property, path):
            DesignIssue(domain: .foreignInterface,
                        severity: .error,
                        identifier: "foreign_property_not_found",
                        message: description,
                        hint: "Check the source of the foreign design or foreign design entity",
                        details: [
                            "property": Variant(property),
                            "key_path": Variant(path)
                        ])
        case let .typeMismatch(type, path):
            DesignIssue(domain: .foreignInterface,
                        severity: .error,
                        identifier: "foreign_type_mismatch",
                        message: description,
                        hint: "Check the source of the foreign design or foreign design entity",
                        details: [
                            "expected_value_type": Variant(type),
                            "key_path": Variant(path)
                        ])
        case .unknownDecodingError(_):
            DesignIssue(domain: .foreignInterface,
                        severity: .fatal,
                        identifier: "unknown_decoding_error",
                        message: description,
                        hint: "Report this error to the project developers",
                        details: [:])
        case .unknownFormatVersion(_):
            DesignIssue(domain: .foreignInterface,
                        severity: .error,
                        identifier: "unknown_foreign_format_version",
                        message: description,
                        hint: "Convert the format to a known version",
                        details: [:])
        case let .valueNotFound(property, path):
            DesignIssue(domain: .foreignInterface,
                        severity: .error,
                        identifier: "foreign_value_not_found",
                        message: description,
                        hint: "Check the source of the foreign design or foreign design entity",
                        details: [
                            "property": Variant(property),
                            "key_path": Variant(path)
                        ])
        }
    }
}

/// Object for reading foreign designs represented as JSON.
///
/// - Note: Hand-writing foreign frames in JSON is discouraged, as they might become
///   complex very quickly. It is not the purpose of this toolkit to
///   process and maintain raw human-written textual representation of designs.
///
/// The top-level structure of the design is a dictionary with the following keys:
///
/// - `format_version` _(recommended, string)_: Version of the JSON encoding format. Currently
///    `"0.4.0"`.
///    See ``JSONDesignReader/CurrentFormatVersion``.
/// - `metamodel`: Name of the metamodel the design contents conforms to. See ``Metamodel``.
///     If not present, the default metamodel by the tool/application at hand is assumed. It is
///     always preferred to include the metamodel name.
/// - `metamodel_version`: Version of the metamodel. If not provided, then the latest version
///     should be assumed by the application/tool.
/// - `snapshots`: All object version snapshots, referenced by frames. See ``RawSnapshot``.
/// - `frames`: Design frames contained within. See ``RawFrame``.
/// - `user_references`: User defined references to any identifiable entity within the design.
///         See ``RawNamedReference``.
///         Named frames (``Design/frame(name:)``) are stored in the user references as well.
/// - `system_references`: References used by the system (same structure as `user_references`).
///         For example the current design frame is stored as a system reference.
/// - `user_lists`: User defined lists of references to any identifiable entity within the design. See ``RawNamedList``.
/// - `system_lists`: Reference lists used by the system (same structure as `user_references`).
///         For example undo and redo history is stored in the system lists.
///
/// ## Snapshots
///
/// For detailed information see ``RawSnapshot``.
///
/// The JSON representation of a snapshot object is a dictionary with the following
/// keys and their corresponding values:
///
/// - `type` _(required)_: Name of the object type. The type must exist in the metamodel that the
///   design conforms to.
/// - `id` _(recommended)_: Object ID, if not provided, one will be generated during
///   loading, but the object can not be referenced to within structural references
///   (edges, parent/child). Can be an int or a string.
/// - `snapshot_id` _(recommended)_: snapshot ID, if not provided, one will be
///   generated during loading. Can be an int or a string.
/// - `structure`_(recommended)_: Structure type: `node`, `edge`, `unstructured`. See ``RawStructure``.
/// - `origin` (structural): If the structure is an edge, the property references its origin object ID.
/// - `target` (structural): If the structure is an edge, the property references its target object ID.
/// - `parent` (optional): reference to object's parent object ID.
/// - `attributes`: a dictionary where keys are attribute names and values are
///    variants. See below how variants are encoded.
///
/// ## Variants
///
/// Variant values are encoded as dictionaries with two keys. Required key is `type` which
/// denotes the variant type. The other key depends on the variant type:
///
/// - Variant atom types `bool`, `int`, `float`, `string`, `point`: value is under the `value` key.
/// - Variant array types `bool_array`, `int_array`, `float_array`, `string_array`, `point_array`:
///   value is under the `items` key.
///
/// Validation and requirements:
///
/// - For array variants all items must be of the same type.
/// - For int or float variants or arrays of ints or floats, any int or float convertible value is
///   accepted. If the value is not exactly convertible, the value is invalid.
/// - Point is represented as a two-item array of numeric values. Empty, one item or array with more
///   items is considered invalid.
/// - Array of points is an array of two-item arrays of numeric values.
///
/// Examples:
///
/// | JSON value | Variant | Example | Note |
/// |---|---|:---|:---|
/// | `{"type": "bool", "value": true}` | bool | `true` | |
/// | `{"type": "int", "value": 10}` | int | 10 | Any convertible JSON numeric value is allowed.|
/// | `{"type": "float", "value": 1.5}` | float | 1.5 | Any convertible JSON numeric value is allowed. |
/// | `{"type": "point", "value": [10, 20]}` | point | Point(x: 10.0, y: 20.0) | Must be an array of exactly two numbers. |
/// | `{"type": "int_array", "items": [10, 20, 30]}` | array of ints | `[10, 20, 30]`| All items must be of the same type. |
/// | `{"type": "point_array", "items": [[10, 20], [30, 40]]}` | array of ints | `[Point(x:10, y:20), Point(x:30, y:40)]`| |
///
public final class JSONDesignReader {
    // NOTE: Update in the JSONDesignReader class documentation
    public static let CurrentFormatVersion = SemanticVersion(0, 1, 0)
    
    // TODO: let forceFormatVersion: SemanticVersion
    public let variantCoding: Variant.CodingType
    
    /// Create a frame reader.
    ///
    public init(variantCoding: Variant.CodingType = .dictionary) {
        self.variantCoding = variantCoding
        // Nothing here for now
    }
    
    /// Read a raw design from a JSON file at given URL.
    ///
    /// See the class documentation for more information about the format.
    ///
    /// See ``read(data:)`` for more information about reading and version handling.
    ///
    public func read(fileAtURL url: URL) throws (RawDesignReaderError) -> RawDesign {
        var data: Data
        do {
            data = try Data(contentsOf: url)
        }
        catch {
            
            throw .dataCorrupted(RawDesignReaderError.Context(underlyingError: error))
        }
        return try read(data: data)
    }
    
    /// Read a raw design from JSON data.
    ///
    /// See the class documentation for more information about the format.
    ///
    /// When the data does not match expected version, the method tries to delegate to
    /// built-in adapters dispatched in ``read(data:version:)``. When even the adapters
    /// can not successfully read the data, then ``RawDesignReaderError/unknownFormatVersion(_:)``
    /// is thrown. Caller can then handle custom reading based on the version included
    /// in the error.
    ///
    public func read(data: Data) throws (RawDesignReaderError) -> RawDesign {
        let decoder = JSONDecoder()
        decoder.userInfo[Variant.CodingTypeKey] = self.variantCoding
        
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

    /// Read a raw design from JSON data using an adapter for a non-current version.
    ///
    /// This method is called by the ``read(data:)`` when the format version is incompatible
    /// with the current version reader.
    ///
    /// See the class documentation for more information about the format.
    ///
    public func read(data: Data, version: String) throws (RawDesignReaderError) -> RawDesign {
        switch version {
        case "makeshift_store":
            let makeshiftDesign: _MakeshiftPersistentDesign
            let decoder = JSONDecoder()
            decoder.userInfo[Variant.CodingTypeKey] = Variant.CodingType.tuple
            do {
                makeshiftDesign = try decoder.decode(_MakeshiftPersistentDesign.self, from: data)
            }
            catch let error as DecodingError {
                throw RawDesignReaderError(error)
            }
            catch {
                throw .canNotReadData
            }
            return makeshiftDesign.asRawDesign()
        default:
            throw RawDesignReaderError.unknownFormatVersion(version)
        }
    }
}
