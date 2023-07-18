//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 07/06/2023.
//

import XCTest
@testable import PoieticFlows
@testable import PoieticCore


final class TestDomainView: XCTestCase {
    // TODO: Split to Compiler and DomainView test cases
    
    var db: ObjectMemory!
    var frame: MutableFrame!
    var graph: MutableGraph!
    
    override func setUp() {
        db = ObjectMemory()
        frame = db.deriveFrame()
        graph = frame.mutableGraph
    }
    
    func testCollectNames() throws {
        graph.createNode(FlowsMetamodel.Stock,
                         name: "a",
                         components: [FormulaComponent(expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         name: "b",
                         components: [FormulaComponent(expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         name: "c",
                         components: [FormulaComponent(expression:"0")])
        // TODO: Check using violation checker
        
        let view = DomainView(graph)
        
        let names = try view.namesToObjects()
        
        XCTAssertNotNil(names["a"])
        XCTAssertNotNil(names["b"])
        XCTAssertNotNil(names["c"])
        XCTAssertEqual(names.count, 3)
    }
    
    func testValidateDuplicateName() throws {
        let c1 = graph.createNode(FlowsMetamodel.Stock,
                                  name: "things",
                                  components:[FormulaComponent(expression:"0")])
        let c2 = graph.createNode(FlowsMetamodel.Stock,
                                  name: "things",
                                  components: [FormulaComponent(expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         name: "a",
                         components: [FormulaComponent(expression:"0")])
        graph.createNode(FlowsMetamodel.Stock,
                         name: "b",
                         components: [FormulaComponent(expression:"0")])
        
        // TODO: Check using violation checker
        
        let view = DomainView(graph)
        
        XCTAssertThrowsError(try view.namesToObjects()) {
            guard let error = $0 as? DomainError else {
                XCTFail("Expected DomainError")
                return
            }
            
            XCTAssertNotNil(error.issues[c1])
            XCTAssertNotNil(error.issues[c2])
            XCTAssertEqual(error.issues.count, 2)
        }
    }
    
    func testCompileExpressions() throws {
        throw XCTSkip("Conflicts with input validation, this test requires attention.")
#if false
        let names: [String:ObjectID] = [
            "a": 1,
            "b": 2,
        ]
        
        let l = graph.createNode(FlowsMetamodel.Stock,
                                 components: [FormulaComponent(name: "l",
                                                               expression: "sqrt(a*a + b*b)")])
        let view = DomainView(graph)
        
        let exprs = try view.boundExpressions(names: names)
        
        let varRefs = Set(exprs[l]!.allVariables)
        
        XCTAssertTrue(varRefs.contains(.object(1)))
        XCTAssertTrue(varRefs.contains(.object(2)))
        XCTAssertEqual(varRefs.count, 2)
#endif
    }
    
    func testSortedNodes() throws {
        // a -> b -> c
        
        let c = graph.createNode(FlowsMetamodel.Auxiliary,
                                 name: "c",
                                 components: [FormulaComponent(expression:"b")])
        let b = graph.createNode(FlowsMetamodel.Auxiliary,
                                 name: "b",
                                 components: [FormulaComponent(expression:"a")])
        let a = graph.createNode(FlowsMetamodel.Auxiliary,
                                 name: "a",
                                 components: [FormulaComponent(expression:"0")])
        
        
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: a,
                         target: b,
                         components: [])
        graph.createEdge(FlowsMetamodel.Parameter,
                         origin: b,
                         target: c,
                         components: [])
        
        let view = DomainView(graph)
        let sortedNodes = try view.sortNodes(nodes: [b, c, a])
        
        if sortedNodes.isEmpty {
            XCTFail("Sorted expression nodes must not be empty")
            return
        }
        
        XCTAssertEqual(sortedNodes.count, 3)
        XCTAssertEqual(sortedNodes[0].id, a)
        XCTAssertEqual(sortedNodes[1].id, b)
        XCTAssertEqual(sortedNodes[2].id, c)
    }
    
    func testInvalidInput2() throws {
        let broken = graph.createNode(FlowsMetamodel.Stock,
                                      name: "broken",
                                      components: [FormulaComponent(expression: "price")])
        let view = DomainView(graph)
        
        let parameters = view.parameters(broken, required:["price"])
        XCTAssertEqual(parameters.count, 1)
        XCTAssertEqual(parameters["price"], ParameterStatus.missing)
    }

    func testUnusedInputs() throws {
        let used = graph.createNode(FlowsMetamodel.Auxiliary,
                                    name: "used",
                                    components: [FormulaComponent(expression:"0")])
        let unused = graph.createNode(FlowsMetamodel.Auxiliary,
                                      name: "unused",
                                      components: [FormulaComponent(expression:"0")])
        let tested = graph.createNode(FlowsMetamodel.Auxiliary,
                                      name: "tested",
                                      components: [FormulaComponent(expression:"used")])
        
        let usedEdge = graph.createEdge(FlowsMetamodel.Parameter,
                         origin: used,
                         target: tested,
                         components: [])
        let unusedEdge = graph.createEdge(FlowsMetamodel.Parameter,
                         origin: unused,
                         target: tested,
                         components: [])
        
        let view = DomainView(graph)
        
        // TODO: Get the required list from the compiler
        let parameters = view.parameters(tested, required:["used"])

        XCTAssertEqual(parameters.count, 2)
        XCTAssertEqual(parameters["unused"],
                       ParameterStatus.unused(node: unused, edge: unusedEdge))
        XCTAssertEqual(parameters["used"],
                       ParameterStatus.used(node: used, edge: usedEdge))
    }

    func testUnknownParameters() throws {
        let known = graph.createNode(FlowsMetamodel.Auxiliary,
                                     name: "known",
                                     components: [FormulaComponent(expression:"0")])
        let tested = graph.createNode(FlowsMetamodel.Auxiliary,
                                      name: "tested",
                                      components: [FormulaComponent(expression:"known + unknown")])
        
        let knownEdge = graph.createEdge(FlowsMetamodel.Parameter,
                         origin: known,
                         target: tested,
                         components: [])
        
        let view = DomainView(graph)
        
        let parameters = view.parameters(tested, required:["known", "unknown"])
        XCTAssertEqual(parameters.count, 2)
        XCTAssertEqual(parameters["known"],
                       ParameterStatus.used(node: known, edge: knownEdge))
        XCTAssertEqual(parameters["unknown"],
                       ParameterStatus.missing)
    }
    
    func testFlowFillsAndDrains() throws {
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
        
        let view = DomainView(graph)
        
        XCTAssertEqual(view.flowFills(flow), sink)
        XCTAssertEqual(view.flowDrains(flow), source)
    }
    
    func testGraphicalFunction() throws {
        let param = graph.createNode(FlowsMetamodel.Auxiliary,
                                  name: "p",
                                  components: [FormulaComponent(expression: "1")])
        let gf = graph.createNode(FlowsMetamodel.GraphicalFunction,
                                  name: "g",
                                  components: [GraphicalFunctionComponent()])
        let aux = graph.createNode(FlowsMetamodel.Auxiliary,
                                   name:"a",
                                   components: [FormulaComponent(expression: "g")])

        graph.createEdge(FlowsMetamodel.Parameter, origin: param, target: gf)
        graph.createEdge(FlowsMetamodel.Parameter, origin: gf, target: aux)

        let view = DomainView(graph)

        let funcs = try view.boundGraphicalFunctions()
        XCTAssertEqual(funcs.count, 1)

        let boundFn = funcs.first!
        XCTAssertEqual(boundFn.functionNodeID, gf)
        XCTAssertEqual(boundFn.parameterID, param)

        let names = try view.namesToObjects()
        XCTAssertNotNil(names["g"])
        
        let issues = view.validateParameters(aux, required: ["g"])
        XCTAssertTrue(issues.isEmpty)
    }

    func testDisconnectedGraphicalFunction() throws {
        let _ = graph.createNode(FlowsMetamodel.GraphicalFunction,
                                  name: "g",
                                  components: [GraphicalFunctionComponent()])

        let view = DomainView(graph)

        XCTAssertThrowsError(try view.boundGraphicalFunctions()) {
            XCTAssertNotNil($0 as? DomainError)
        }
    }

}
