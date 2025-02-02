//
//  JSONFrameReader.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation


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
public final class JSONFrameReader {
    public typealias ForeignFrame = JSONForeignFrame
    public static let CurrentFormatVersion = "0"
    
    public static let VersionKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "JSONForeignFrameVersion")!

    public class DecodingConfiguration {
        public var version: String
        public init(version: String) {
            self.version = version
        }
    }
    
    // NOTE: For now, the class exists only for code organisation purposes/name-spacing
   
    /// Create a frame reader.
    ///
    public init() {
        // Nothing here for now
    }
    
    /// Read a frame bundle at a given URL.
    ///
    /// The bundle is a directory with the following content:
    ///
    /// - `info.json` – information about the frame. A dictionary containing the
    ///   following keys:
    ///     - `frame_format_version`: Version of the frame format (required)
    ///     - `objects`: An array of objects (see the class information about
    ///        details)
    ///     - `collections`: List of collection names, where each collection is
    ///       a separate file.
    /// - `objects/` directory with JSON files where each file represents an
    ///   object collection. The names in this directory should correspond
    ///   to the names in the `collections` array.
    ///
    /// Example:
    ///
    /// ```
    /// MyModel.poieticframe/
    ///     info.json
    ///     objects/
    ///         design.json
    ///         core.json
    ///         charts.json
    /// ```
    ///
    public func read(bundleAtURL url: URL) throws (ForeignFrameError) -> ForeignFrame {
        // TODO: Check for file existence
        let data: Data
        let frame: JSONForeignFrame
        let decoder = JSONDecoder()
        let config = DecodingConfiguration(version: Self.CurrentFormatVersion)
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        
        let infoURL = url.appending(component: "info.json")

        do {
            data = try Data(contentsOf: infoURL)
        }
        catch let error as NSError {
            throw .dataCorrupted(error.localizedDescription, [])
        }
        catch {
            throw .unableToReadData
        }
        
        do {
            frame = try decoder.decode(JSONForeignFrame.self, from: data, configuration: config)
        }
        catch let error as ForeignFrameError {
            throw error
        }
        catch {
            throw .dataCorrupted(String(describing: error), [])
        }
        
        var collections: [String:[JSONForeignObject]] = [:]
        for name in frame.collectionNames {
            let collectionURL = url.appending(components: "objects", "\(name).json", directoryHint: .notDirectory)
            do {
                let data = try Data(contentsOf: collectionURL)
                let collection = try decoder.decode([JSONForeignObject].self,
                                                    from: data,
                                                    configuration: config)
                collections[name] = collection
            }
            catch let error as DecodingError {
                throw ForeignFrameError(error)
            }
            catch {
                throw .dataCorrupted(String(describing: error), [])
            }
        }

        if collections.isEmpty {
            return frame
        }
        else {
            let joinedObjects = frame.objects + collections.values.joined()
            return JSONForeignFrame(metamodel: frame.metamodel,
                                    objects: joinedObjects,
                                    collections: frame.collectionNames)
        }
    }
    
    /// Read a frame file at a given URL.
    ///
    /// The frame file is a JSON file with the following content:
    ///
    /// - `frame_format_version`: Version of the frame format (required)
    /// - `objects`: An array of objects (see the class information about
    ///    details)
    ///
    public func read(fileAtURL url: URL) throws (ForeignFrameError) -> ForeignFrame {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        }
        catch let error as NSError {
            // FIXME: We are not getting DecodingError on invalid JSON
            throw .dataCorrupted(error.localizedDescription, [])
        }
        catch {
            throw .dataCorrupted(String(describing: error), [])
        }
        return try self.read(data: data)
    }

    public func read(data: Data) throws (ForeignFrameError) -> ForeignFrame {
        let decoder = JSONDecoder()
        let config = DecodingConfiguration(version: Self.CurrentFormatVersion)
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true

        let frame: JSONForeignFrame
        do {
            frame = try decoder.decode(JSONForeignFrame.self,
                                           from: data,
                                           configuration: config)
        }
        catch let error as DecodingError {
            throw ForeignFrameError(error)
        }
        catch {
            // FIXME: [FIXME] Handle correctly
            throw .dataCorrupted("Unhandlederror \(type(of:error)): \(error)", [])
        }
        guard frame.collectionNames.isEmpty else {
            fatalError("Foreign frame from data (inline frame) must not refer to other collections, only bundle foreign frame can.")
        }
        return frame
    }
}
