//
//  NameNormalizationSystem.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 31/08/2026.
//

/// System that collects object names and normalises them.
///
/// - **Input:** All objects with ``Name`` trait.
/// - **Output:** ``NormalizedName`` for objects where the required name is present and is
///     not visually empty.
/// - **Forgiveness:** Nothing to be forgiven.
/// - **Issues collected:**
///     - `name.empty`: Name is empty (no characters) or visually empty – contains only whitespaces
///       or underscores `_` (which is equal to whitespace with normalisation).
///     - `name.required`: The name attribute is missing. Validation of the plane failed.
///
public struct NameNormalizationSystem: System {
    public static let IssueSourceName = "NameNormalizationSystem"

    public static func update(_ world: World) throws (InternalSystemError) {
        guard let plane = world.plane else { return }
        for object in plane.filter(trait: .Name) {
            guard let entity = world.entity(object.objectID) else { continue }

            guard let name = object.name else {
                // This should be unreachable if the plane was correctly validated.
                // We are keeping it here as crash prevention. The hint points to a "solution.
                let issue = Issue(
                    identifier: IssueIdentifier.nameRequired,
                    severity: .fatal,
                    source: Self.IssueSourceName,
                    message: "'name' attribute is required (validation failed)",
                    hints: [
                        "Contact application developers",
                        "Set a name attribute"
                    ],
                )
                entity.appendIssue(issue)
                continue
            }

            let normalized = NormalizedName(name: name)
            
            guard !normalized.isVisuallyEmpty else {
                let issue = Issue(
                    identifier: IssueIdentifier.emptyName,
                    severity: .error,
                    source: Self.IssueSourceName,
                    message: "Object name is empty",
                    hints: [ "Set a node name that is not visually empty" ],
                )
                entity.appendIssue(issue)
                continue
            }
            
            entity.setComponent(normalized)
        }
    }
}
