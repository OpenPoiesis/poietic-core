//
//  Graph+algorithms.swift
//  
//
//  Created by Stefan Urbanek on 09/09/2022.
//

extension GraphProtocol where Edge: Identifiable {
    /// Sort nodes topologically.
    ///
    /// - Returns: Sorted node IDs when there were no issues, or nil if there was a cycle.
    ///
    public func topologicalSort() -> [NodeID]? {
        var edges = self.edges
        let targets = Set(edges.map {$0.target})
        var sources: [NodeID] = self.nodeIDs.filter { !targets.contains($0) }
        var sorted: [NodeID] = []

        while !sources.isEmpty {
            let node: NodeID = sources.removeFirst()
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            sorted.append(node)

            for edge in outgoing {
                let m: NodeID = edge.target
                
                edges.removeAll { $0.id == edge.id }
                
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
        let nodes: [NodeID] = self.nodeIDs
        let targets = Set(edges.map {$0.target})
        var sources: [NodeID] = nodes.filter { !targets.contains($0) }
        
        while !sources.isEmpty {
            let node: NodeID = sources.removeFirst()
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            for edge in outgoing {
                let m: NodeID = edge.target
                
                edges.removeAll { $0.id == edge.id }
                
                if edges.allSatisfy({$0.target != m}) {
                    sources.append(m)
                }
            }
        }
        
        return edges
    }
}
