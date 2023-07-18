//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/06/2023.
//

import XCTest
@testable import PoieticFlows
@testable import PoieticCore

final class BuiltinFunctionTests: XCTestCase {
    func testAllBuiltinsHaveReturnType() throws {
        for function in AllBuiltinFunctions {
            if function.signature.returnType == nil {
                XCTFail("Built-in function \(function.name) has no return type specified")
            }
            if function.signature.returnType != .double {
                XCTFail("Built-in function \(function.name) does not have a double return type")
            }
        }
    }
}

final class TestCompiler: XCTestCase {
    var db: ObjectMemory!
    var frame: MutableFrame!
    var graph: MutableGraph!
    
    override func setUp() {
        db = ObjectMemory()
        frame = db.deriveFrame()
        graph = frame.mutableGraph
    }
    
    func testInflowOutflow() throws {
        let source = graph.createNode(FlowsMetamodel.Stock,
                                      name: "source",
                                      components: [FormulaComponent(expression:"0")])
        let flow = graph.createNode(FlowsMetamodel.Flow,
                                    name: "f",
                                    components: [FormulaComponent(expression:"1")])
        let sink = graph.createNode(FlowsMetamodel.Stock,
                                    name: "sink",
                                    components: [FormulaComponent(expression:"0")])
        
        graph.createEdge(FlowsMetamodel.Drains,
                         origin: source,
                         target: flow,
                         components: [])
        graph.createEdge(FlowsMetamodel.Fills,
                         origin: flow,
                         target: sink,
                         components: [])
        
        let compiler = Compiler(frame: frame)
        let compiled = try compiler.compile()
        
        XCTAssertEqual(compiled.inflows.count, 2)
        XCTAssertEqual(compiled.inflows[sink], [flow])
        XCTAssertEqual(compiled.inflows[source], [])
        XCTAssertEqual(compiled.outflows.count, 2)
        XCTAssertEqual(compiled.outflows[source], [flow])
        XCTAssertEqual(compiled.outflows[sink], [])
    }
    
    func testUpdateImplicitFlows() throws {
        let flow = graph.createNode(FlowsMetamodel.Flow,
                                    name: "f",
                                    components: [FormulaComponent(expression:"1")])
        let source = graph.createNode(FlowsMetamodel.Stock,
                                      name: "source",
                                      components: [FormulaComponent(expression:"0")])
        let sink = graph.createNode(FlowsMetamodel.Stock,
                                    name: "sink",
                                    components: [FormulaComponent(expression:"0")])
        
        graph.createEdge(FlowsMetamodel.Drains,
                         origin: source,
                         target: flow,
                         components: [])
        graph.createEdge(FlowsMetamodel.Fills,
                         origin: flow,
                         target: sink,
                         components: [])
        
        let compiler = Compiler(frame: frame)
        let view = DomainView(graph)
        
        XCTAssertEqual(view.implicitDrains(source).count, 0)
        XCTAssertEqual(view.implicitFills(sink).count, 0)
        XCTAssertEqual(view.implicitDrains(source).count, 0)
        XCTAssertEqual(view.implicitFills(sink).count, 0)
        
        compiler.updateImplicitFlows()
        
        let src_drains = view.implicitDrains(source)
        let sink_drains = view.implicitDrains(sink)
        let src_fills = view.implicitFills(source)
        let sink_fills = view.implicitFills(sink)
        
        XCTAssertEqual(src_drains.count, 0)
        XCTAssertEqual(sink_drains.count, 1)
        XCTAssertEqual(sink_drains[0], source)
        XCTAssertEqual(src_fills.count, 1)
        XCTAssertEqual(src_fills[0], sink)
        XCTAssertEqual(sink_fills.count, 0)
    }
    
    func testGraphicalFunction() throws {
        let p = graph.createNode(FlowsMetamodel.Auxiliary,
                                   name:"p",
                                   components: [FormulaComponent(expression: "0")])

        let gf = graph.createNode(FlowsMetamodel.GraphicalFunction,
                                  name: "g",
                                  components: [GraphicalFunctionComponent()])
        let aux = graph.createNode(FlowsMetamodel.Auxiliary,
                                   name:"a",
                                   components: [FormulaComponent(expression: "g")])

        graph.createEdge(FlowsMetamodel.Parameter, origin: p, target: gf)
        graph.createEdge(FlowsMetamodel.Parameter, origin: gf, target: aux)

        let compiler = Compiler(frame: frame)
       let compiled = try compiler.compile()

        switch compiled.computations[gf] {
        case .formula(_): XCTFail("Graphical function compiled as formula")
        case .graphicalFunction(let fn, _):
            XCTAssertEqual(fn.name, "__graphical_g")
        case nil: XCTFail("Graphical function was not compiled")
        }
    }

}
