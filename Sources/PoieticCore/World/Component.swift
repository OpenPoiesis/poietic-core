//
//  Component.swift
//  
//
//  Created by Stefan Urbanek on 11/08/2022.
//

/// Protocol for runtime components of objects.
///
/// Components hold data that are used during runtime. They are typically
/// derived from object attributes.
///
/// Runtime components are not persisted.
///
/// - Note: When designing a component, design it in a way that all its
///   contents can be reconstructed from other information present in the
///   design.
///
/// This is just an annotation protocol, has no requirements.
///
public protocol Component {
    // Empty, just an annotation.
}


