//
//  RuntimeEntity+Probing.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/08/2026.
//

extension RuntimeEntity {

    /// Probe a numeric value of the entity. Primary use is visual value indicator.
    ///
    /// Expected components:
    ///
    /// - ``NumericValueSample``: numeric value to be probed. If not present,
    ///         the caller (visual indicator) is recommended to provide "no value" visual.
    /// - ``NumericValueStats``: provides actual min and max value. Used for ``ValueBounds``.
    /// - ``DisplayValueBounds``: bounds used to limit the value.
    ///     If not present, then (0, 1) should be assumed. Used to limit value bounds from the stats.
    ///
    /// If no components are present, the function returns `(nil, ValueBounds(min: 0, max: 1))`.
    ///
    public func numericProbe() -> (value: Double?, bounds: ValueBounds) {
        let sample: NumericValueSample? = self.component()
        let stats: NumericValueStats? = self.component()
        let displayBounds: DisplayValueBounds? = self.component()
        let bounds: ValueBounds
        if let stats {
            bounds = ValueBounds(min: stats.min, max: stats.max, limit: displayBounds)
        }
        else {
            bounds = ValueBounds(min: displayBounds?.min ?? 0, max: displayBounds?.max ?? 1)
        }
        return (value: sample?.value, bounds: bounds)
    }

}
