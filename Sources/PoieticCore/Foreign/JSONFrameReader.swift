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
        

        let path: [PathItem]
        let underlyingError: (any Error)?
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

    public enum EntityError: Error, Equatable {
        case propertyNotFound(String)
    }
    
    case dataCorrupted(Context)
    case typeMismatch(String, [String])
    case valueNotFound(String, [String])
    case propertyNotFound(String, [String])
    case unknownDecodingError(String)

    case unknownFormatVersion(String)
    case snapshotError(Int, EntityError)
    
    
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
    public static let CurrentFormatVersion = "0.1"
    
    public static let VersionKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "JSONForeignFrameVersion")!

    // TODO: let forceFormatVersion: SemanticVersion
    
    /// Create a frame reader.
    ///
    public init() {
        // Nothing here for now
    }
    
    public func read(data: Data) throws (RawDesignReaderError) -> RawDesign {
        let decoder = JSONDecoder()
        let json: JSONValue
        do {
            json = try decoder.decode(JSONValue.self, from: data)
        }
        catch let error as DecodingError {
            throw RawDesignReaderError(error)
        }
        catch {
            // TODO: What other errors can happen here? Custom decoding errors?
            fatalError("Unhandled reader error \(type(of:error)): \(error)")
        }

        let design = try read(json: json)
        
        return design
    }
    public func read(json: JSONValue, forceFormatVersion: String? = nil) throws (RawDesignReaderError) -> RawDesign {
        guard let dict = json.objectValue else {
            throw .typeMismatch("object", [])
        }

        let formatVersion: String? = forceFormatVersion ?? dict["format_version"]?.stringValue
        switch formatVersion {
        case .none, Self.CurrentFormatVersion: return try readCurrentVersion(dict)
        case "0": return try readMakeshiftVersion(dict)
        default: throw .unknownFormatVersion(formatVersion!)
        }
    }
    func readMakeshiftVersion(_ dict: [String:JSONValue]) -> RawDesign {
        fatalError("Makeshift version reading not implemented")
    }
    func readCurrentVersion(_ dict: [String:JSONValue]) throws (RawDesignReaderError) -> RawDesign {
        let metamodelName: String? = dict["metamodel"]?.stringValue
        let metamodelVersion: SemanticVersion?
        if let versionString: String = dict["metamodel_version"]?.stringValue {
            metamodelVersion = SemanticVersion(versionString)
        }
        else {
            metamodelVersion = nil
        }

        let design = RawDesign(
            metamodelName: metamodelName,
            metamodelVersion: metamodelVersion
        )
        
        if let jsonSnapshots = dict["snapshots"] {
            guard jsonSnapshots.type == .array else {
                throw .typeMismatch("array", ["snapshots"])
            }
            let snapshots = try readSnapshots(jsonSnapshots.arrayValue!)
            design.snapshots = snapshots
        }
        
        return design
    }
    func readSnapshots(_ jsonSnapshots: [JSONValue]) throws (RawDesignReaderError) -> [RawSnapshot] {
        var snapshots: [RawSnapshot] = []
        for (i, json) in jsonSnapshots.enumerated() {
            guard let dict = json.objectValue else {
                throw .typeMismatch("object", ["snapshots", String(i)])
            }

            let typeName = dict["type"]?.stringValue
            let id = dict["id"]?.rawIDValue
            let snapshotID = dict["snapshot_id"]?.rawIDValue
            let parent = dict["parent"]?.rawIDValue
            let structure: RawStructure
            if let structureType = dict["structure"]?.stringValue {
                switch structureType {
                case "unstructured": structure = RawStructure("unstructured")
                case "node": structure = RawStructure("node")
                case "edge":
                    guard let origin = dict["origin"]?.rawIDValue else {
                        fatalError()
                    }
                    guard let target = dict["target"]?.rawIDValue else {
                        fatalError()
                    }
                    structure = RawStructure("edge", references: [origin, target])
                default:
                    fatalError()
                }
            }
            else {
                structure = RawStructure("unstructured")
            }

            var attributes: [String:Variant] = [:]

            if let maybeAttributes = dict["attributes"] {
                guard let jsonAttributes = maybeAttributes.objectValue else {
                    fatalError()
                }
                for (key, jsonValue) in jsonAttributes {
                    guard let value = jsonValue.typedVariantValue else {
                        fatalError()
                    }
                    attributes[key] = value
                }
            }
            let snapshot = RawSnapshot(
                typeName: typeName,
                snapshotID: snapshotID,
                id: id,
                structure: structure,
                parent: parent,
                attributes: attributes,
            )
            snapshots.append(snapshot)
        }
        return snapshots
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
}

extension JSONValue {
    /// Get a variant value with type represented within the JSON.
    ///
    /// Typed variant is represented as a dictionary
    var typedVariantValue: Variant? {
        guard let dict = self.objectValue,
              let type = dict["type"]?.stringValue
        else {
            return nil
        }
        
        switch type {
        case "bool":
            guard let value = dict["value"]?.boolValue else {
                return nil
            }
            return .atom(.bool(value))
        case "int":
            guard let value = dict["value"]?.intValue else {
                return nil
            }
            return .atom(.int(value))
        case "float":
            guard let value = dict["value"]?.doubleValue else {
                return nil
            }
            return .atom(.double(value))
        case "string":
            guard let value = dict["value"]?.stringValue else {
                return nil
            }
            return .atom(.string(value))
        case "point":
            guard let items = dict["value"]?.arrayValue,
                  items.count == 2,
                  let x = items[0].numericValue,
                  let y = items[1].numericValue
            else {
                return nil
            }
            return .atom(.point(Point(x, y)))
        case "bool_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Bool] = jsonItems.compactMap { $0.boolValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.bool(items))
        case "int_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Int] = jsonItems.compactMap { $0.intValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.int(items))
        case "float_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Double] = jsonItems.compactMap { $0.numericValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.double(items))
        case "string_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [String] = jsonItems.compactMap { $0.stringValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.string(items))
        case "point_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Point] = jsonItems.compactMap {
                guard let items = $0.arrayValue,
                      items.count == 2,
                      let x = items[0].numericValue,
                      let y = items[1].numericValue
                else {
                    return nil
                }
                return Point(x, y)
            }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.point(items))
        default:
            return nil
        }
    }
    
    init(typedVariant variant: Variant) {
        switch variant {
        case .atom(let atom):
            let type: String
            let outValue: JSONValue
            switch atom {
            case .bool(let value):
                type = "bool"
                outValue = JSONValue.bool(value)
            case .int(let value):
                type = "int"
                outValue = JSONValue.int(value)
            case .double(let value):
                type = "float"
                outValue = JSONValue.float(value)
            case .string(let value):
                type = "string"
                outValue = JSONValue.string(value)
            case .point(let value):
                type = "point"
                outValue = JSONValue.array([.float(value.x), .float(value.y)])
            }
            self = .object([
                "type": .string(type),
                "value": outValue,
            ])
        case .array(let array):
            let type: String
            let outItems: [JSONValue]
            switch array {
            case .bool(let items):
                type = "bool"
                outItems = items.map { JSONValue.bool($0) }
            case .int(let items):
                type = "int"
                outItems = items.map { JSONValue.int($0) }
            case .double(let items):
                type = "float"
                outItems = items.map { JSONValue.float($0) }
            case .string(let items):
                type = "string"
                outItems = items.map { JSONValue.string($0) }
            case .point(let items):
                type = "point"
                outItems = items.map {
                    JSONValue.array([.float($0.x), .float($0.y)])
                }
            }
            self = .object([
                "type": .string(type),
                "items": .array(outItems),
            ])
        }
    }
}


