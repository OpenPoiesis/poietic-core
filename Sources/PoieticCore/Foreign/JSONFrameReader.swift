//
//  JSONFrameReader.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation


/// Object for reading foreign frames represented as JSON.
///
/// ## Foreign Objects
///
/// The JSON representation of foreign object is a dictionary with the following
/// keys:
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
/// - `children` (optional): list of object's children – convenience mechanism
///    for parent-child relationships, only recommended for hand-written frames
/// - `attributes`: a dictionary where keys are attribute names and values are
///    attribute values.
///
/// ## References
///
/// Typically the unique identifier of an object within a frame is its ID.
/// For convenience of hand-writing small foreign frames, objects can be
/// referenced by their names as well. One can refer to an object by its
/// name in an edge origin or a target, for example.
///
/// When multiple objects have the same name, then which object will be
/// referred to is undefined.
///
/// - Note: Hand-writing foreign frames is discouraged, as they might become
///   complex very quickly. It is not the purpose of this toolkit to
///   process and maintain raw human-written textual representation of models.
///
public final class JSONFrameReader {
    public static let VersionKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "JSONForeignFrameVersion")!

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
        // FIXME: Check for file existence, decouple data reading from decoding
        let container: _JSONForeignFrameContainer
        let decoder = JSONDecoder()
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        
        let infoURL = url.appending(component: "info.json")
        do {
            let data = try Data(contentsOf: infoURL)
            container = try decoder.decode(_JSONForeignFrameContainer.self, from: data)
        }
        catch let error as NSError {
            throw .dataCorrupted(error.localizedDescription, [])
        }
        catch {
            throw .dataCorrupted(String(describing: error), [])
        }
        
        var collections: [String:_JSONForeignObjectCollection] = [:]
        for name in container.collectionNames {
            let collectionURL = url.appending(components: "objects", "\(name).json", directoryHint: .notDirectory)
            do {
                let data = try Data(contentsOf: collectionURL)
                let collection = try decoder.decode(_JSONForeignObjectCollection.self, from: data)
                collections[name] = collection
            }
            catch let error as DecodingError {
                throw ForeignFrameError(error)
            }
            catch {
                throw .dataCorrupted(String(describing: error), [])
            }
        }

        return _JSONForeignFrame(container: container, collections: collections)
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
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true

        let container: _JSONForeignFrameContainer
        do {
            container = try decoder.decode(_JSONForeignFrameContainer.self, from: data)
        }
        catch let error as DecodingError {
            throw ForeignFrameError(error)
        }
        catch {
            // FIXME: [FIXME] Handle correctly
            throw .dataCorrupted("Unhandlederror \(type(of:error)): \(error)", [])
        }
        guard container.collectionNames.isEmpty else {
            fatalError("Foreign frame from data (inline frame) must not refer to other collections, only bundle foreign frame can.")
        }

        return _JSONForeignFrame(container: container, collections: [:])
    }
}
