//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/06/2023.
//

import XCTest
@testable import PoieticFlows
@testable import PoieticCore


final class TestSolver: XCTestCase {
    var db: ObjectMemory!
    var frame: MutableFrame!
    var graph: MutableGraph!
    var compiler: Compiler!
    
    override func setUp() {
        db = ObjectMemory()
        frame = db.deriveFrame()
        graph = frame.mutableGraph
        compiler = Compiler(frame: frame)
    }
    func testInitializeStocks() throws {
        
        let a = graph.createNode(FlowsMetamodel.Auxiliary,
                                 components: [ExpressionComponent(name: "a",
                                                            expression: "1")])
        let b = graph.createNode(FlowsMetamodel.Auxiliary,
                                 components: [ExpressionComponent(name: "b",
                                                            expression: "a + 1")])
        let c =  graph.createNode(FlowsMetamodel.Stock,
                                  components: [ExpressionComponent(name: "const",
                                                         expression: "100")])
        let s_a = graph.createNode(FlowsMetamodel.Stock,
                                   components: [ExpressionComponent(name: "use_a",
                                                              expression: "a")])
        let s_b = graph.createNode(FlowsMetamodel.Stock,
                                   components: [ExpressionComponent(name: "use_b",
                                                          expression: "b")])
        
        graph.createEdge(FlowsMetamodel.Parameter, origin: a, target: b, components: [])
        graph.createEdge(FlowsMetamodel.Parameter, origin: a, target: s_a, components: [])
        graph.createEdge(FlowsMetamodel.Parameter, origin: b, target: s_b, components: [])
        
        let compiled = try compiler.compile()
        let solver = Solver(compiled)
        
        let vector = solver.initialize()
        
        XCTAssertEqual(vector[a], 1)
        XCTAssertEqual(vector[b], 2)
        XCTAssertEqual(vector[c], 100)
        XCTAssertEqual(vector[s_a], 1)
        XCTAssertEqual(vector[s_b], 2)
    }
}
