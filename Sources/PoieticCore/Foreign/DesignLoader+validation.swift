//
//  DesignLoader+validation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 14/10/2025.
//

extension DesignLoader {
    
    /// Validates identities that are to be created and that must be unique within the loading
    /// context.
    ///
    /// After successful validation, the context phase will be changed to
    /// ``LoadingContext/Phase/validated``.
    ///
    /// - Precondition: The context phase must be ``LoadingContext/Phase/initial``.
    ///
    public func validate(_ context: LoadingContext) throws (DesignLoaderError) {
        precondition(context.phase == .initial)
        
        // Validate duplicate IDs.
        var seen: Set<ForeignEntityID> = Set()
        
        for (index, snapshot) in context.rawSnapshots.enumerated() {
            guard let id = snapshot.snapshotID else { continue }
            if seen.contains(id) {
                throw .snapshotError(index, .duplicateID(id))
            }
            seen.insert(id)
        }

        for (index, frame) in context.rawFrames.enumerated() {
            guard let id = frame.id else { continue }
            if seen.contains(id) {
                throw .frameError(index, .identityError(.duplicateID))
            }
            seen.insert(id)
        }
        
        context.phase = .validated
    }
}
