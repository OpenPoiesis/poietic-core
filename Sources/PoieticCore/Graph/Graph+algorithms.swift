//
//  Graph+algorighms.swift
//  
//
//  Created by Stefan Urbanek on 09/09/2022.
//

/// An error raised when a cycle is detected in the graph.
///
public struct GraphCycleError: Error {

    /// List of edges that are part of a cycle
    ///
    public let edges: [ObjectID]

    /// Create an error object from a list of edges.
    ///
    /// - Precondition: The list of edges must not be empty.
    ///
    public init(edges: [ObjectID]) {
        precondition(!edges.isEmpty,
                     "Cycle error must contain at least one edge")
        self.edges = edges
    }
}

extension Graph {
    /// Sort nodes topologically.
    ///
    /// - Parameters:
    ///  - nodes: list of nodes to be sorted
    ///  - edges: list of edges to be considered during the sorting
    ///
    /// - Throws: ``GraphCycleError`` when a cycle is detected in the graph.
    ///
    /// - Note: The list of edges is expected to be valid and present edges
    ///   within the graph. The origin, the target or both refer to nodes that
    ///   are passed as an argument to this function. Behaviour is undefined if
    ///   it is not the case.
    ///
    public func topologicalSort(_ toSort: [ObjectID], edges: [Edge]) throws -> [ObjectID] {
        var sorted: [ObjectID] = []
        let nodes: [ObjectID] = toSort
        
        // Create a copy
        var edges = edges
        
        let targets = Set(edges.map {$0.target})
        // S ← Set of all nodes with no incoming edge
        var sources: [ObjectID] = nodes.filter { !targets.contains($0) }

        // while S is not empty do
        while !sources.isEmpty {
            // remove a node n from S
            let node: ObjectID = sources.removeFirst()
            // add n to L
            sorted.append(node)
            
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            for edge in outgoing {
                // for each node m with an edge e from n to m do
                let m: ObjectID = edge.target

                // remove edge e from the graph
                edges.removeAll { $0.snapshot === edge.snapshot }
                
                // if m has no other incoming edges then
                if edges.allSatisfy({$0.target != m}) {
                    //  insert m into S
                    sources.append(m)
                }
            }
        }
        if !edges.isEmpty {
            throw GraphCycleError(edges: edges.map {$0.id} )
        }

        return sorted
    }
}

public protocol EdgeType: Identifiable where ID == ObjectID {
    var origin: ObjectID { get }
    var target: ObjectID { get }
}

public func topologicalSort<T: EdgeType>(_ toSort: [ObjectID], edges: [T]) throws -> [ObjectID] {
    var sorted: [ObjectID] = []
    let nodes: [ObjectID] = toSort
    
    // Create a copy
    var edges = edges
    
    let targets = Set(edges.map {$0.target})
    // S ← Set of all nodes with no incoming edge
    var sources: [ObjectID] = nodes.filter { !targets.contains($0) }

    // while S is not empty do
    while !sources.isEmpty {
        // remove a node n from S
        let node: ObjectID = sources.removeFirst()
        // add n to L
        sorted.append(node)
        
        let outgoing: [T] = edges.filter { $0.origin == node }
        
        for edge in outgoing {
            // for each node m with an edge e from n to m do
            let m: ObjectID = edge.target

            // remove edge e from the graph
            edges.removeAll { $0.id == edge.id }
            
            // if m has no other incoming edges then
            if edges.allSatisfy({$0.target != m}) {
                //  insert m into S
                sources.append(m)
            }
        }
    }
    if !edges.isEmpty {
        throw GraphCycleError(edges: edges.map {$0.id} )
    }

    return sorted
}
