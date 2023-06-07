//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/06/2022.
//

/// Protocol for a predicate that matches a node.
///
/// Objects conforming to this protocol are expected to implement the method `match()`
///
public protocol NodePredicate {
    /// Tests a node whether it matches the predicate.
    ///
    /// - Returns: `true` if the node matches.
    ///
    func match(graph: Graph, node: Node) -> Bool
}

/// Protocol for a predicate that matches an edge.
///
/// Objects conforming to this protocol are expected to implement the method
/// `match(from:, to:, labels:)`.
///
public protocol EdgePredicate {
    /// Tests an edge whether it matches the predicate.
    ///
    /// - Returns: `true` if the edge matches.
    ///
    /// Default implementation calls `match(from:,to:,labels:)`
    ///
    func match(graph: Graph, edge: Edge) -> Bool
}


public enum LogicalConnective {
    case and
    case or
}

// TODO: Convert this to a generic.
// NOTE: So far I was fighting with the compiler (5.6):
// - compiler segfaulted
// - got: "Runtime support for parameterized protocol types is only available in macOS 99.99.0 or newer"
// - various compilation errors

/// A predicate.
///
/// - ToDo: This is waiting for Swift 5.7+ for some serious rewrite.
///
public protocol Predicate: NodePredicate, EdgePredicate {
    func match(graph: Graph, object: ObjectSnapshot) -> Bool
    func and(_ predicate: Predicate) -> CompoundPredicate
    func or(_ predicate: Predicate) -> CompoundPredicate
    func not() -> Predicate
}

extension Predicate {
    public func and(_ predicate: Predicate) -> CompoundPredicate {
        return CompoundPredicate(.and, predicates: self, predicate)
    }
    public func or(_ predicate: Predicate) -> CompoundPredicate {
        return CompoundPredicate(.or, predicates: self, predicate)
    }
    public func not() -> Predicate {
        return NegationPredicate(self)
    }
    public func match(graph: Graph, edge: Edge) -> Bool {
        return match(graph: graph, object: edge)
    }
    public func match(graph: Graph, node: Node) -> Bool {
        return match(graph: graph, object: node)
    }
}

// TODO: Add &&, || and ! operators

public class CompoundPredicate: Predicate {
    public let connective: LogicalConnective
    public let predicates: [Predicate]
    
    public init(_ connective: LogicalConnective, predicates: any Predicate...) {
        self.connective = connective
        self.predicates = predicates
    }
    
    public func match(graph: Graph, object: ObjectSnapshot) -> Bool {
        switch connective {
        case .and: return predicates.allSatisfy{ $0.match(graph: graph, object: object) }
        case .or: return predicates.contains{ $0.match(graph: graph, object: object) }
        }
    }
}

public class NegationPredicate: Predicate {
    public let predicate: Predicate
    public init(_ predicate: any Predicate) {
        self.predicate = predicate
    }
    public func match(graph: Graph, object: ObjectSnapshot) -> Bool {
        return !predicate.match(graph: graph, object: object)
    }
}
/// Predicate that matches any object.
///
public class AnyPredicate: Predicate {
    public init() {}
    
    /// Matches any node – always returns `true`.
    ///
    public func match(graph: Graph, object: ObjectSnapshot) -> Bool {
        return true
    }
}

public class HasComponentPredicate: Predicate {
    let type: Component.Type
    
    public init(_ type: Component.Type) {
        self.type = type
    }

    public func match(graph: Graph, object: ObjectSnapshot) -> Bool {
        return object.components.has(self.type)
    }
    
}

public class IsTypePredicate: Predicate {
    let types: [ObjectType]
    
    public init(_ types: [ObjectType]) {
        self.types = types
    }
    public init(_ type: ObjectType) {
        self.types = [type]
    }
    public func match(graph: Graph, object: ObjectSnapshot) -> Bool {
        return types.allSatisfy{
            object.type === $0
        }
    }
}
