//
//  Graph+algorithms.swift
//  
//
//  Created by Stefan Urbanek on 09/09/2022.
//

extension GraphProtocol {
    /// Sort nodes topologically.
    ///
    /// - Returns: Sorted node IDs when there were no issues, or nil if there was a cycle.
    ///
    public func topologicalSort() -> [NodeKey]? {
        // TODO: Use the global topologicalSort<T>(edges:) function
        var edges = self.edges
        let targets = Set(edges.map {$0.target})
        var sources: [NodeKey] = self.nodeKeys.filter { !targets.contains($0) }
        var sorted: [NodeKey] = []

        while !sources.isEmpty {
            let node: NodeKey = sources.removeFirst()
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            sorted.append(node)

            for edge in outgoing {
                let m: NodeKey = edge.target
                
                edges.removeAll { $0.key == edge.key }
                
                if edges.allSatisfy({$0.target != m}) {
                    sources.append(m)
                }
            }
        }
        
        if edges.isEmpty {
            return sorted
        }
        else {
            return nil
        }
    }

    /// Find cycles in a subgraph.
    ///
    /// - Returns: List of cycles
    ///
    public func cycles() -> [Edge] {
        var edges = self.edges
        let nodes: [NodeKey] = self.nodeKeys
        let targets = Set(edges.map {$0.target})
        var sources: [NodeKey] = nodes.filter { !targets.contains($0) }
        
        while !sources.isEmpty {
            let node: NodeKey = sources.removeFirst()
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            for edge in outgoing {
                let m: NodeKey = edge.target
                
                edges.removeAll { $0.key == edge.key }
                
                if edges.allSatisfy({$0.target != m}) {
                    sources.append(m)
                }
            }
        }
        
        return edges
    }
}

/// Sort nodes topologically using Kahn's algorithm.
///
/// - Parameters:
///     - edges: An array of tuples, where each tuple `(u, v)` represents a
///              directed edge from node `u` to node `v`.
/// - Returns: An array of nodes of type `T` in a valid topological order or `nil` if a
///   cycle was detected.
///
public func topologicalSort<T: Hashable>(_ edges: [(T, T)]) -> [T]? {
    // Step 1: Build the graph representation
    var adjacency: [T: [T]] = [:]
    var inDegree: [T: Int] = [:]

    // Find all unique nodes to ensure every node is in our inDegree map.
    let allNodes = Set(edges.flatMap { [$0.0, $0.1] })
    for node in allNodes {
        inDegree[node] = 0
    }

    // Now, populate the adjacency list and calculate in-degrees.
    for (from, to) in edges {
        adjacency[from, default: []].append(to)
        inDegree[to]! += 1 // Force unwrap is safe as we initialized all nodes.
    }

    // Step 2: Find all nodes with an in-degree of 0 (no incoming edges)
    //
    var queue: [T] = inDegree.compactMap { (node, degree) in
        degree == 0 ? node : nil
    }

    var sortedResult: [T] = []

    // Step 3: Process the nodes
    //
    while !queue.isEmpty {
        let currentNode = queue.removeFirst()
        sortedResult.append(currentNode)

        if let neighbors = adjacency[currentNode] {
            for neighbor in neighbors {
                inDegree[neighbor]! -= 1
                
                if inDegree[neighbor]! == 0 {
                    queue.append(neighbor)
                }
            }
        }
    }

    // Step 4: Check for cycles
    // If the result contains fewer nodes than the total number of nodes in the graph,
    // it means some nodes were never processed, which can only happen if there's a cycle.
    guard sortedResult.count == allNodes.count else { return nil }

    return sortedResult
}
