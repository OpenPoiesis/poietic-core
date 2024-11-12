//
//  Graph+algorighms.swift
//  
//
//  Created by Stefan Urbanek on 09/09/2022.
//

extension GraphProtocol {
    /// Sort nodes topologically.
    ///
    /// - Returns: Sorted node IDs when there were no issues, or nil if there was a cycle.
    ///
    public func topologicalSort() -> [Node.ID]? {
        var sorted: [Node.ID] = []
        var edges = self.edges
        let targets = Set(edges.map {$0.target})
        var sources: [Node.ID] =
            self.nodes.map { $0.id }.filter { !targets.contains($0) }
        
        while !sources.isEmpty {
            let node: Node.ID = sources.removeFirst()
            sorted.append(node)
            
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            for edge in outgoing {
                let m: Node.ID = edge.target
                
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
        let nodes: [Node.ID] = self.nodes.map { $0.id }
        var edges = self.edges
        
        let targets = Set(edges.map {$0.target})
        var sources: [Node.ID] = nodes.filter { !targets.contains($0) }
        
        while !sources.isEmpty {
            let node: Node.ID = sources.removeFirst()
            
            let outgoing: [Edge] = edges.filter { $0.origin == node }
            
            for edge in outgoing {
                let m: Node.ID = edge.target
                
                edges.removeAll { $0.id == edge.id }
                
                if edges.allSatisfy({$0.target != m}) {
                    sources.append(m)
                }
            }
        }
        
        return edges
    }
}
