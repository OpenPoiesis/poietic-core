//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 07/06/2023.
//

import XCTest
@testable import PoieticFlows
@testable import PoieticCore


final class TestCompiler: XCTestCase {
    // TODO: Split to Compiler and DomainView test cases
    
    var db: ObjectMemory!
    var frame: MutableFrame!
    var graph: MutableGraph!
    
    override func setUp() {
        db = ObjectMemory()
        frame = db.deriveFrame()
        graph = frame.mutableGraph
    }
    
    func testCompileSome() throws {
        // a -> b -> c
        
        let c = graph.createNode(FlowsMetamodel.Auxiliary,
                                 components: [ExpressionComponent(name:"c",expression:"b")])
        let b = graph.createNode(FlowsMetamodel.Auxiliary,
                                 components: [ExpressionComponent(name:"b",expression:"a")])
        let a = graph.createNode(FlowsMetamodel.Auxiliary,
                                 components: [ExpressionComponent(name:"a",expression:"0")])
        
        
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: a,
                         target: b,
                         components: [])
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: b,
                         target: c,
                         components: [])
        
        // FIXME: Make this a test for DomainView instead
        let compiler = Compiler(frame: frame)
        
        let compiled = try compiler.compile()
        
        if compiled.sortedExpressionNodes.isEmpty {
            XCTFail("Sorted expression nodes must not be empty")
            return
        }
        
        XCTAssertEqual(compiled.sortedExpressionNodes.count, 3)
        XCTAssertEqual(compiled.sortedExpressionNodes[0].id, a)
        XCTAssertEqual(compiled.sortedExpressionNodes[1].id, b)
        XCTAssertEqual(compiled.sortedExpressionNodes[2].id, c)
        
        XCTAssertNotNil(compiled.expressions[a])
        XCTAssertNotNil(compiled.expressions[b])
        XCTAssertNotNil(compiled.expressions[c])
    }
    
    func testCollectNames() throws {
        graph.createNode(FlowsMetamodel.Stock,
                         components: [ExpressionComponent(name:"a",expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         components: [ExpressionComponent(name:"b",expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         components: [ExpressionComponent(name:"c",expression:"0")])
        // TODO: Check using violation checker
        
        let view = DomainView(graph)
        
        let names = try view.collectNames()
        
        XCTAssertNotNil(names["a"])
        XCTAssertNotNil(names["b"])
        XCTAssertNotNil(names["c"])
        XCTAssertEqual(names.count, 3)
    }
    
    func testValidateDuplicateName() throws {
        let c1 = graph.createNode(FlowsMetamodel.Stock,
                                  components:[ExpressionComponent(name:"things",expression:"0")])
        let c2 = graph.createNode(FlowsMetamodel.Stock,
                                  components: [ExpressionComponent(name:"things",expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         components: [ExpressionComponent(name:"a",expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         components: [ExpressionComponent(name:"b",expression:"0")])
        
        // TODO: Check using violation checker
        
        let view = DomainView(graph)
        
        do {
            _ = try view.collectNames()
        }
        catch let error as DomainError {
            XCTAssertNotNil(error.issues[c1])
            XCTAssertNotNil(error.issues[c2])
            XCTAssertEqual(error.issues.count, 2)
            return
        }
        catch {
            XCTFail("Unexpected exception raised: \(error)")
            return
        }
        
        XCTFail("collectNames should raise an exception")
    }
    
    func testCompileExpressions() throws {
        let names: [String:ObjectID] = [
            "a": 1,
            "b": 2,
        ]
        
        let l = graph.createNode(FlowsMetamodel.Stock,
                                 components: [ExpressionComponent(name: "l",
                                                      expression: "sqrt(a*a + b*b)")])
        let view = DomainView(graph)
        
        let exprs = try view.compileExpressions(names: names)
        
        let varRefs = Set(exprs[l]!.allVariables)
        
        XCTAssertTrue(varRefs.contains(.object(1)))
        XCTAssertTrue(varRefs.contains(.object(2)))
        XCTAssertEqual(varRefs.count, 2)
    }
    
    func testUnusedInputs() throws {
        let used = graph.createNode(FlowsMetamodel.Auxiliary,
                                    components: [ExpressionComponent(name:"used",expression:"0")])
        let unused = graph.createNode(FlowsMetamodel.Auxiliary,
                                      components: [ExpressionComponent(name:"unused",expression:"0")])
        let tested = graph.createNode(FlowsMetamodel.Auxiliary,
                                      components: [ExpressionComponent(name:"tested",expression:"used")])
        
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: used,
                         target: tested,
                         components: [])
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: unused,
                         target: tested,
                         components: [])
        
        let view = DomainView(graph)
        
        // TODO: Get the required list from the compiler
        let issues = view.validateInputs(nodeID: tested,
                                         required: ["used"])
        
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0], .unusedInput("unused"))
    }
    
    func testUnknownParameters() throws {
        let known = graph.createNode(FlowsMetamodel.Auxiliary,
                                     components: [ExpressionComponent(name:"known",expression:"0")])
        let tested = graph.createNode(FlowsMetamodel.Auxiliary,
                                      components: [ExpressionComponent(name:"tested",expression:"known + unknown")])
        
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: known,
                         target: tested,
                         components: [])
        
        let view = DomainView(graph)
        
        let issues = view.validateInputs(nodeID: tested,
                                         required:["known", "unknown"])
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0], .unknownParameter("unknown"))
    }
    
    func testFlowFillsAndDrains() throws {
        let flow = graph.createNode(FlowsMetamodel.Flow,
                                    components: [ExpressionComponent(name:"f",expression:"1")])
        let source = graph.createNode(FlowsMetamodel.Stock,
                                      components: [ExpressionComponent(name:"source",expression:"0")])
        let sink = graph.createNode(FlowsMetamodel.Stock,
                                    components: [ExpressionComponent(name:"sink",expression:"0")])
        
        graph.createEdge(FlowsMetamodel.Drains,
                         origin: source,
                         target: flow,
                         components: [])
        graph.createEdge(FlowsMetamodel.Fills,
                         origin: flow,
                         target: sink,
                         components: [])
        
        let view = DomainView(graph)
        
        XCTAssertEqual(view.flowFills(flow), sink)
        XCTAssertEqual(view.flowDrains(flow), source)
    }
    
    func testUpdateImplicitFlows() throws {
        let flow = graph.createNode(FlowsMetamodel.Flow,
                                    components: [ExpressionComponent(name:"f",expression:"1")])
        let source = graph.createNode(FlowsMetamodel.Stock,
                                      components: [ExpressionComponent(name:"source",expression:"0")])
        let sink = graph.createNode(FlowsMetamodel.Stock,
                                    components: [ExpressionComponent(name:"sink",expression:"0")])
        
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
}
