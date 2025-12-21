//
//  Schedule.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 21/12/2025.
//

/// Tag protocol for system schedule labels.
///
/// Schedule labels are compile-time tags of system schedules.
///
/// - SeeAlso: ``FrameChange``, ``InteractivePreview``.
///
public protocol ScheduleLabel {
    // Empty protocol, just a tag
}

/// Schedule label for systems that are run when frame did change.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum FrameChange: ScheduleLabel {}

/// Schedule label for systems that are run during interactive session, for example
/// a dragging or an object placement session.
///
/// For example, while dragging session, the systems are run on each move event.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum InteractivePreview: ScheduleLabel {}

