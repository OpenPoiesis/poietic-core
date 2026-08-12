//
//  Design.swift
//
//
//  Created by Stefan Urbanek on 02/06/2023.
//

//  DEVELOPMENT NOTE:
//
//  If adding functionality to Design, make sure that the functionality is
//  implementable, and preferably implemented in the poietic-design command-line
//  tool. We want to maintain parity between what programmers can do and what
//  (expert) users can do without access to the development environment.
//

/// Design is a container representing a model, idea or a document with their
/// history of changes.
///
/// Design is a representation of an idea from a problem domain described by a ``Metamodel``.
/// Design comprises of objects with attributes and with a topology – references between objects.
/// The _Metamodel_ defines types of objects, constraints and other properties
/// of the design, which are used to validate design's integrity.
///
/// Different versions of design objects is organised in _version planes_. Each version plane
/// represents a change, which can be thought as a change in time or as an alternative version.
///
/// Each design object, as a logical entity, has a unique identity within the whole design:
/// ``ObjectProtocol/objectID``. The _objectID_ refers to an object including
/// all its versions – object snapshots. Within a plane, the object ID is unique.
///
/// The design distinguishes between two states of a version plane:
/// ``DesignPlane`` – immutable version snapshot of a plane, that is guaranteed
/// to be valid and follow all required constraints. The ``TransientPlane``
/// represents a transaction of plane. The integrity is enforced once the
/// plane is accepted using ``Design/accept(_:appendHistory:)``.
///
/// Design planes are immutable and they are persisted. They are guaranteed to follow requirements
/// of the metamodel.
///
/// ``TransientPlane``s can be changed, they do not have to follow requirements
/// of the metamodel. They are _not_ persisted. See _Archiving_ below.
///
/// The concept of planes allows us to have functionality like undo/redo,
/// version branching, different timelines, sub-system specific annotations
/// without disturbing the original planes, etc.
///
///
/// ## Editing (Mutating)
///
/// Objects of the design are always changed in a relationship with all
/// other objects within the same plane. When a single change requires mutating
/// multiple objects, all the object changes are grouped into a single change
/// that results in a new plane.
///
/// To make a change and produce a new plane:
///
/// 1. Derive a new plane from an existing one or create a new plane using
///   ``createPlane(deriving:id:)``.
/// 2. Add objects to the derived plane using ``TransientPlane/create(_:objectID:snapshotID:structure:parent:children:attributes:)``
///    or ``TransientPlane/insert(_:)``.
/// 3. To mutate existing objects in the plane, first derive an new mutable
///    snapshot of the object using ``TransientPlane/mutate(_:)`` and
///    make changes using the returned new snapshot.
/// 4. Conclude all the changes by accepting the plane ``accept(_:appendHistory:)``.
///
/// Plane can be accepted only if the constraints are satisfied. When the plane
/// violates ant of the constraints the `accept()` method throws a
/// ``ConstraintViolation`` with more details about which objects violated
/// which constraints.
///
/// If mutable plane for some reason is not going to be used further, for
/// example if it contains domain errors, it can be discarded using
/// ``discard(_:)``. Discarded plane and its derived object will be removed from
/// the design.
///
/// ## Named Planes
///
/// Named planes are used to store design-wide, non-versioned content. For example, application
/// state such as current view position. Named planes can not be included in the undo/redo history.
///
///
/// ## Archiving
///
/// The design can be archived (in the future incrementally synchronised)
/// to a persistent store. All stable planes are stored. Transient planes are not
/// included in the archive and therefore not restored after unarchiving.
/// Therefore one can rely on the archive containing only planes that maintain integrity as defined by the
/// metamodel.
///
/// ## Garbage Collection
///
/// The design keeps only those object snapshots which are contained in planes,
/// be it a transient plane or a stable plane. If a plane is removed, all objects
/// that are referred to only by that plane and no other plane, are removed
/// from the design as well.
///
/// - Remark: The concepts of mutable plane, accept and discard are somewhat
///   analogous to a transaction, commit and rollback respectively. However,
///   accepted planes are not immediately put into a single historical
///   timeline and they might organised into different arrangements. "Rollback"
///   would not make sense, since there might be nothing to go back from, if
///   we are not appending the plane to a history timeline.
///
public class Design {
    /// Meta-model that the design conforms to.
    ///
    /// The metamodel is used for validation of the model contained within the
    /// design and for creation of objects.
    ///
    public let metamodel: Metamodel
    
    /// Manager of entity identities that generates and reserves IDs.
    ///
    /// - Important: This is to be used by low-level functionality, such as loading. Typically
    ///   there is no need to directly use the identity manager.
    ///
    public let identityManager: IdentityManager
    
    var _objectSnapshots: RCTable<ObjectSnapshot>

    /// Planes that have been accepted and are in fact validated with the metamodel.
    var _validatedPlanes: RCTable<DesignPlane>
    var _objects: RCTable<LogicalObject>
    var _transientPlanes: [PlaneID: TransientPlane]

    var _namedPlanes: [String: DesignPlane]
    public var namedPlanes: [String: DesignPlane] { _namedPlanes }
    
    
    /// Chronological list of design snapshots.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``,``redoList``, ``undo(to:)``, ``redo(to:)``
    ///
    public var versionHistory: [PlaneID] {
        guard let currentPlaneID else {
            return []
        }
        return undoList + [currentPlaneID] + redoList
    }
    
    /// ID of the current plane from the history perspective.
    ///
    /// - Note: `currentPlaneID` is guaranteed not to be `nil` when there is
    ///   a history.
    ///
    public internal(set) var currentPlaneID: PlaneID?

    /// Get the current stable plane.
    ///
    /// - Note: It is a programming error to get current plane when there is no
    ///         history.
    ///
    public var currentPlane: DesignPlane? {
        guard let currentPlaneID,
              let plane = _validatedPlanes[currentPlaneID] else { return nil }
        return plane
    }

    /// List of IDs of planes in chronological order of acceptance, that can be removed from
    /// history.
    ///
    /// - SeeAlso: ``redoList``, ``undo(to:)``, ``redo(to:)``
    ///
    public internal(set) var undoList: [PlaneID] = []

    /// List of IDs of undone planes can be re-done.
    ///
    /// When a new plane is appended to the version history, the list
    /// of re-doable planes is emptied.
    ///
    /// - SeeAlso: ``undoList``, ``undo(to:)``, ``redo(to:)``
    ///
    public internal(set) var redoList: [PlaneID] = []

    // MARK: - Creation
    /// Create a new design that conforms to the given metamodel.
    ///
    /// The new design will be empty, it will not have any design planes. Typical next step is to
    /// create and populated first plane:
    ///
    /// ```swift
    /// let design = Design(metamodel: Metamodel.Basic)
    /// let trans = design.createPlane()
    /// let object = trans.create(ObjectType.DesignInfo)
    /// object["title"] = "My Design"
    ///
    /// try design.accept(trans)
    /// ```
    /// - SeeAlso: ``createPlane(deriving:id:)``
    ///
    public init(metamodel: Metamodel = Metamodel()) {
        self._objectSnapshots = RCTable()
        self._validatedPlanes = RCTable()
        self._objects = RCTable()
        self._transientPlanes = [:]
        self._namedPlanes = [:]
        self.undoList = []
        self.redoList = []
        self.metamodel = metamodel
        self.identityManager = IdentityManager()
    }
    
    // MARK: - Snapshots
    /// True if the design does not contain any stable planes nor object snapshots.
    ///
    /// - Note: Design might contain orphaned snapshots but no planes. Despite such design is
    ///         unusual, it is not considered empty, as the snapshots are still persisted.
    /// - Note: Transient planes are not counted as they are not persisted.
    ///
    public var isEmpty: Bool {
        return _objectSnapshots.isEmpty && _validatedPlanes.isEmpty
    }
   
    /// Get a collection of all stable snapshots in all stable planes.
    ///
    public var objectSnapshots: some Collection<ObjectSnapshot> {
        return _objectSnapshots
    }

    /// Get a snapshot by snapshot ID.
    ///
    func snapshot(_ id: ObjectSnapshotID) -> ObjectSnapshot? {
        return _objectSnapshots[id]
    }

    public func contains(snapshot id: ObjectSnapshotID) -> Bool {
        return _objectSnapshots.contains(id)
    }
    
    func referenceCount(_ snapshotID: ObjectSnapshotID) -> Int? {
        return _objectSnapshots.referenceCount(snapshotID)
    }
    
    // MARK: - Planes
    
    /// List of all stable planes in the design.
    ///
    public var planes: some Collection<DesignPlane> {
        return _validatedPlanes.items
    }
    
    /// Get a stable plane with given ID.
    ///
    /// - Returns: A stable plane, if it is contained in the design and is stable (not transient),
    ///   otherwise `nil`.
    ///
    public func plane(_ id: PlaneID) -> DesignPlane? {
        guard let plane = _validatedPlanes[id] else { return nil }
        return plane
    }

    /// Test whether the design contains a stable plane with given ID.
    ///
    public func containsPlane(_ id: PlaneID) -> Bool {
        return _validatedPlanes[id] != nil
    }
    
    /// Get a plane from the list of named planes.
    ///
    /// See the discussion in the ``Design`` about named planes.
    ///
    /// - SeeAlso: ``accept(_:replacingName:)``
    ///
    public func plane(name: String) -> DesignPlane? {
        guard let plane = _namedPlanes[name] else { return nil }
        return plane
    }

    /// Create a new plane or derive a plane from an existing plane.
    ///
    /// - Parameters:
    ///     - original: A stable plane to derive new plane from. If not provided,
    ///       a new plane will be created.
    ///     - id: Proposed ID of the new plane. Must be unique and must not
    ///       already exist in the design. If not provided, a new unique ID
    ///       is generated.
    ///
    /// The newly derived plane will not own any of the objects from the
    /// original plane.
    /// See ``TransientPlane/init(design:id:snapshots:)`` for more information
    /// about how the objects from the original plane are going to be treated.
    ///
    /// - Precondition: The `original` plane must exist in the design.
    /// - Precondition: The design must not contain a plane with `id`.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``, ``discard(_:)``
    ///
    @discardableResult
    public func createPlane(deriving original: (any Plane)? = nil,
                            id: PlaneID? = nil) -> TransientPlane {
        // TODO: Throw some identity error here
        let actualID: PlaneID
        if let id {
            let success = identityManager.reserve(id, type: .plane)
            precondition(success, "ID already used (\(id)")
            actualID = id
        }
        else {
            actualID = identityManager.reserveNew(type: .plane)
        }
        
        let derived: TransientPlane
        if let original {
            precondition(original.design === self, "Trying to clone a plane from different design")
            derived = TransientPlane(design: self, id: actualID, snapshots: original.snapshots)
        }
        else {
            derived = TransientPlane(design: self, id: actualID)
        }

        _transientPlanes[actualID] = derived
        return derived
    }

    /// Discards the mutable plane that is associated with the design.
    ///
    public func discard(_ plane: TransientPlane) {
        precondition(isPending(plane))

        identityManager.freeReservation(plane.id)
        identityManager.freeReservations(Array(plane._reservations))
        _transientPlanes[plane.id] = nil
        plane.discard()
    }
    
    /// Return `true` if the transient plane is owned by the design and is in transient state.
    /// 
    public func isPending(_ trans: TransientPlane) -> Bool {
        return trans.design === self
                && trans.state == .transient
                && _transientPlanes[trans.id] != nil
    }
    
    /// Remove a plane from the design.
    ///
    /// The plane will also be removed from named planes, undoable plane list and redo-able plane
    /// list. If the plane was the current plane, then the current plane will be the last plane in
    /// the undo list, if the list is not empty. Otherwise, the current plane will be nil.
    ///
    /// - Parameters:
    ///     - id: ID of a stable plane owned by the design.
    ///
    /// - Precondition: The plane with given ID must exist in the design.
    ///
    public func removePlane(_ id: PlaneID) {
        guard let plane = _validatedPlanes[id] else {
            preconditionFailure("Unknown plane ID \(id)")
        }
        // Currently no one can retain a plane.
        assert(_validatedPlanes.referenceCount(id) == 1)

        undoList.removeAll { $0 == id }
        redoList.removeAll { $0 == id }

        if currentPlaneID == id {
            if undoList.isEmpty {
                currentPlaneID = nil
            }
            else {
                currentPlaneID = undoList.removeLast()
            }
        }

        let removeKeys = _namedPlanes.compactMap {
            if $0.value.id == id { $0.key }
            else { nil }
        }
        for key in removeKeys {
            _namedPlanes[key] = nil
        }

        for snapshot in plane.snapshots {
            _release(snapshot: snapshot.snapshotID)
        }

        _validatedPlanes.remove(id)
        identityManager.free(id)
    }
    
    /// Release a snapshot.
    ///
    /// This method is called when a plane containing a snapshot is removed from the design. If
    /// there are no planes referring to a snapshot, then the snapshot is removed from the design.
    ///
    /// - SeeAlso: ``removePlane(_:)``
    ///
    internal func _release(snapshot id: ObjectSnapshotID) {
        guard let snapshot = _objectSnapshots[id] else {
            preconditionFailure("Unknown snapshot ID \(id)")
        }
        if _objectSnapshots.release(id) {
            identityManager.free(id)
            if _objects.release(snapshot.objectID) {
                identityManager.free(snapshot.objectID)
            }
        }
    }
    
    /// Accepts a transient plane if valid, make it a stable plane.
    ///
    /// Accepting a plane is analogous to a transaction commit in a database.
    ///
    /// Before the plane is accepted it is validated using
    /// ``ConstraintChecker/validate(_:)``.
    /// If the plane does not violate any constraints and has referential
    /// integrity, then it is frozen: all owned objects in the plane are
    /// frozen.
    ///
    /// A new ``DesignPlane`` is created with all objects from the original
    /// plane. The new plane is added to the list of stable planes.
    ///
    /// If `appendHistory` is `true` then the plane is also added at the end
    /// of the undo list. If there are any redo-able planes, they are all
    /// removed.
    ///
    /// - Returns: The newly created stable plane.
    /// - Throws: `PlaneValidationError` when the plane contents violates
    ///   constraints of the design.
    ///
    /// - SeeAlso: ``ConstraintChecker/validate(_:)``,
    ///     ``StructuralValidator/validate(_:in:)``
    ///
    /// - Precondition: Plane must belong to the design.
    /// - Precondition: Plane must be in transient state.
    /// - Precondition: Plane with give ID must not be already accepted and must
    ///   exist as a transient plane in the design.
    ///
    @discardableResult
    public func accept(_ plane: TransientPlane, appendHistory: Bool = true)
    throws (PlaneValidationError) -> DesignPlane {
        let validated = try validateAndInsert(plane)

        if appendHistory {
            if let currentPlaneID {
                undoList.append(currentPlaneID)
            }
            for id in redoList {
                removePlane(id)
            }
            redoList.removeAll()
        }
        currentPlaneID = validated.id

        return validated
    }

    /// Accept a plane as a named plane, replacing the previous plane with the same name.
    ///
    /// Example:
    ///
    /// ```swift
    /// let original = design.plane(name: "settings")
    /// let trans = design.createPlane(deriving: original)
    /// let settings: TransientObject
    ///
    /// if let obj = trans.first(type: .DiagramSettings) {
    ///    settings = trans.mutate(obj.id)
    /// }
    /// else {
    ///    settings = trans.create(.DiagramSettings)
    /// }
    ///
    /// settings["view_position"] = Variant(Point(100, 100))
    /// settings["view_zoom"] = Variant(2.0)
    ///
    /// try design.accept(trans, replacingName: "settings")
    /// ```
    ///
    /// - SeeAlso: ``plane(name:)``
    ///
    @discardableResult
    public func accept(_ plane: TransientPlane, replacingName name: String)
    throws (PlaneValidationError) -> DesignPlane {
        let old = _namedPlanes[name]
        let stable = try validateAndInsert(plane)

        if let old {
            removePlane(old.id)
        }
        _namedPlanes[name] = stable
        return stable
    }
    
    /// Unsafely create a named plane.
    ///
    /// Used by the design loader when finalising loading.
    ///
    internal func unsafeAssignName(name: String, planeID: PlaneID) {
        _namedPlanes[name] = plane(planeID)
    }

    internal func validateAndInsert(_ plane: TransientPlane) throws (PlaneValidationError) -> DesignPlane {
        precondition(plane.design === self)
        precondition(plane.state == .transient)
        precondition(!_validatedPlanes.contains(plane.id), "Duplicate plane ID \(plane.id)")
        precondition(_transientPlanes[plane.id] != nil, "No transient plane with ID \(plane.id)")
        
        let snapshots: [ObjectSnapshot] = plane.snapshots
        do {
            try StructuralValidator.validate(snapshots: snapshots, in: plane)
        }
        catch {
            throw .brokenStructuralIntegrity(error)
        }
        
        let stablePlane = DesignPlane(design: self, id: plane.id, snapshots: snapshots)

        let checker = ConstraintChecker(metamodel)
        try checker.validate(stablePlane)

        _transientPlanes[plane.id] = nil

        unsafeInsert(stablePlane)
        identityManager.use(reserved: plane.id)
        identityManager.use(reserved: plane._reservations)
        plane.accept()
        return stablePlane
    }

    /// Insert a plane without structural or snapshot reference validation.
    ///
    /// This method is used internally by transactions and by the loader.
    ///
    /// The caller is responsible for:
    ///
    /// 1. Validating the plane for structural integrity. See ``StructuralValidator/validate(_:in:)``.
    /// 2. Validating constraints with ``ConstraintChecker/validate(_:)``.
    /// 3. Making sure that the identities are properly marked as used with the
    ///    ``Design/identityManager``.
    ///
    /// - Parameters:
    ///   - plane: Plane to be inserted.
    ///
    /// - Precondition: The plane ID must be reserved.
    /// - Precondition: The design must not contain a plane with given ID.
    ///
    public func unsafeInsert(_ plane: DesignPlane) {
        precondition(plane.design === self)
        precondition(!_validatedPlanes.contains(plane.id), "Duplicate plane ID \(plane.id)")
        precondition(_transientPlanes[plane.id] == nil)

        for snapshot in plane.snapshots {
            if _objects.contains(snapshot.objectID) {
                _objects.retain(snapshot.objectID)
            }
            else {
                _objects.insert(LogicalObject(id: snapshot.objectID))
            }
            _objectSnapshots.insertOrRetain(snapshot)
        }

        _validatedPlanes.insert(plane)
    }
    
    /// Flag whether the design has any un-doable planes.
    ///
    /// - SeeAlso: ``undo(to:)``, ``redo(to:)``, ``canRedo``
    ///
    public var canUndo: Bool {
        return !undoList.isEmpty
    }

    /// Flag whether the design has any re-doable planes.
    ///
    /// - SeeAlso: ``undo(to:)``, ``redo(to:)``, ``canUndo``
    ///
    public var canRedo: Bool {
        return !redoList.isEmpty
    }

    /// Change the current plane to `planeID` which is one of the previous
    /// planes in the undo history.
    ///
    /// It is up to the caller to verify whether the provided plane ID is part
    /// of undoable history.
    ///
    /// - Returns: `true` if there was anything to undo, `false` if there was nothing to undo.
    /// - Precondition: `planeID` must exist in the undo history.
    /// - SeeAlso: ``redo(to:)``, ``canUndo``, ``canRedo``
    ///
    @discardableResult
    public func undo(to planeID: PlaneID? = nil) -> Bool {
        guard !undoList.isEmpty else {
            return false
        }
        
        let actualPlaneID = planeID ?? undoList.last!
        guard let index = undoList.firstIndex(of: actualPlaneID) else {
            fatalError("Trying to undo to plane \(actualPlaneID), which does not exist in the history")
        }

        var suffix = undoList.suffix(from: index)

        let newCurrentPlaneID = suffix.removeFirst()

        undoList = Array(undoList.prefix(upTo: index))
        redoList = suffix + [currentPlaneID!] + redoList

        currentPlaneID = newCurrentPlaneID
        return true
    }
    
    /// Change the current plane to `planeID` which is one of the previously
    /// undone planes.
    ///
    /// The redo history is emptied when a new plane is derived from the current
    /// plane.
    ///
    /// It is up to the caller to verify whether the provided plane ID is part
    /// of redoable history, otherwise it is a programming error.
    ///
    /// - Returns: `true` if there was anything to redo, `false` if there was nothing to redo.
    /// - Precondition: `planeID` must exist in the redo history.
    /// - SeeAlso: ``undo(to:)``, ``canUndo``, ``canRedo``
    ///
    @discardableResult
    public func redo(to planeID: PlaneID? = nil) -> Bool {
        guard !redoList.isEmpty else {
            return false
        }
        
        let actualPlaneID = planeID ?? redoList.first!

        guard let index = redoList.firstIndex(of: actualPlaneID) else {
            fatalError("Trying to redo to plane \(actualPlaneID), which does not exist in the history")
        }
        var prefix = redoList.prefix(through: index)

        let newCurrentPlaneID = prefix.removeLast()
        undoList = undoList + [currentPlaneID!] + prefix
        let after = redoList.index(after: index)
        redoList = Array(redoList.suffix(from: after))
        currentPlaneID = newCurrentPlaneID
        return true
    }
    
    /// Check constraints for the given plane.
    ///
    /// - Returns: List of constraint violations.
    /// 
    public func checkConstraints(_ plane: some Plane) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        for constraint in metamodel.constraints {
            let violators = constraint.check(plane)
            if violators.isEmpty {
                continue
            }
            let violation = ConstraintViolation(constraint: constraint,
                                                objects:violators)
            violations.append(violation)
        }
        return violations
    }
}
