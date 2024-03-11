//
//  Plane.swift
//  
//
//  Created by Stefan Urbanek on 31/10/2023.
//

// TODO: Remove this concept or replace with tags.

/// Plane in which an object or a component exists.
///
/// Components can be created and accessed by an use via an editor or by
/// a system. The main purpose of this access specification is to make sure
/// that the system is not accessing user-created components.
///
/// The logic is rather reversed from traditional access levels in other
/// systems. Here we are trying to protect the user data not the system
/// data. System data are here to be re-create from the user data.
///
public enum Plane {
    /// Data that are created and modified by the user.
    ///
    /// Typically the system should not modify any components or attributes
    /// that are protected by user access level.
    ///
    case user

    /// Data that are created by the system.
    ///
    /// Tools can offer users ability to see and alter the system data.
    ///
    case system
}
