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
