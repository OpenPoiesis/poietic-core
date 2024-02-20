//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/06/2022.
//

public enum LogicalConnective {
    case and
    case or
}

/// A predicate.
///
public protocol Predicate {
    func match(frame: Frame, object: ObjectSnapshot) -> Bool
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
}

// TODO: Add &&, || and ! operators

public class CompoundPredicate: Predicate {
    public let connective: LogicalConnective
    public let predicates: [Predicate]
    
    public init(_ connective: LogicalConnective, predicates: any Predicate...) {
        self.connective = connective
        self.predicates = predicates
    }
    
    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        switch connective {
        case .and: return predicates.allSatisfy{ $0.match(frame: frame, object: object) }
        case .or: return predicates.contains{ $0.match(frame: frame, object: object) }
        }
    }
}

public class NegationPredicate: Predicate {
    public let predicate: Predicate
    public init(_ predicate: any Predicate) {
        self.predicate = predicate
    }
    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        return !predicate.match(frame: frame, object: object)
    }
}
/// Predicate that matches any object.
///
public class AnyPredicate: Predicate {
    public init() {}
    
    /// Matches any node – always returns `true`.
    ///
    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        return true
    }
}

public class HasComponentPredicate: Predicate {
    let type: Component.Type
    
    public init(_ type: Component.Type) {
        self.type = type
    }

    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        return object.components.has(self.type)
    }
    
}

public class HasTraitPredicate: Predicate {
    let trait: Trait
    
    public init(_ trait: Trait) {
        self.trait = trait
    }

    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        object.type.traits.contains { $0 === trait }
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
    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        return types.allSatisfy{
            object.type === $0
        }
    }
}

public class FunctionPredicate: Predicate {
    let block: (ObjectSnapshot) -> Bool
    
    public init(_ block: @escaping (ObjectSnapshot) -> Bool) {
        self.block = block
    }
    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        block(object)
    }
}
