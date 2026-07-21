//
//  NumericValue.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 21/07/2026.
//

/// Tag component to indicate whether there should be a numeric indicator displayed for the entity.
///
/// - Note: Requiring a numeric indicator yet not having a numeric value is fine. Numeric indicator
///   might display an empty value or empty state.
///
/// - SeeAlso: ``NumericValueSample``
/// 
public struct HasNumericIndicator: Component {
    /* Just a tag */
    public init() { /* Nothing */ }
}

/// Simple statistics from time series associate with given entity.
///
/// The component is typically associated with a simulation object and the content of the component
/// is set after a simulation run.
///
/// This component is derived from existing values. To specify display value bounds see
/// ``DisplayValueBounds``.
///
/// - SeeAlso:``NumericValueSample``
///
public struct NumericValueStats: Component {
    public let min: Double
    public let max: Double
    
    public var range: Double { max - min }
    
    public init(min: Double, max: Double) {
        precondition(min <= max)
        self.min = min
        self.max = max
    }
}

/// A point-in-time reading from the time series at the playhead cursor.
///
/// Value sample typically taken from simulation generated time series for given entity and
/// at a time currently visualised.
///
/// For example, an application has a simulation player that replays simulation states. The player
/// has a current simulation time (playhead cursor) and the value in this component is a value from
/// time series at that time.
///
/// Used for visual value indicators, such as bars above simulation objects (blocks, pictograms).
///
/// - SeeAlso: ``NumericValueStats``
///
public struct NumericValueSample: Component {
    public let value: Double
    public init(value: Double) {
        self.value = value
    }
}


