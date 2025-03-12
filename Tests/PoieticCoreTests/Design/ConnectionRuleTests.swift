//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2025.
//

import Testing
@testable import PoieticCore

@Suite struct ConnectionRuleTest {
    let metamodel: Metamodel
    let design: Design
    let checker: ConstraintChecker
    
    init() throws {
        self.metamodel = TestMetamodel
        self.design = Design(metamodel: self.metamodel)
        self.checker = ConstraintChecker(metamodel)
    }
    
    @Test func testAnyConnection() async throws {
        let frame = design.createFrame()
        let stock = frame.createNode(.Stock)
        let flow = frame.createNode(.FlowRate)
        let edge = frame.createEdge(.Arrow, origin: stock.id, target: flow.id)
        let frozen = try design.accept(frame)
        
        try checker.validate(edge: frozen.edge(edge.id), in: frozen)
    }
    
    @Test func noRuleForEdge() throws {
        let frame = design.createFrame()
        let a = frame.createNode(.Stock)
        let b = frame.createNode(.Stock)
        let e = frame.createEdge(.IllegalEdge, origin: a.id, target: b.id)
        let frozen = try design.accept(frame)
        
        #expect {
            try checker.validate(edge: frozen.edge(e.id), in: frozen)
        }
        throws: {
            guard let error = $0 as? EdgeRuleViolation else {
                return false
            }
            switch error {
            case .edgeNotAllowed: return true
            default: return false
            }
        }
    }
    
    @Test func noRuleSatisfied() throws {
        let frame = design.createFrame()
        let a = frame.createNode(.Stock)
        let b = frame.createNode(.Stock)
        let e = frame.createEdge(.Flow, origin: a.id, target: b.id)
        let frozen = try design.accept(frame)
        
        #expect {
            try checker.validate(edge: frozen.edge(e.id), in: frozen)
        }
        throws: {
            guard let error = $0 as? EdgeRuleViolation else {
                return false
            }
            switch error {
            case .noRuleSatisfied: return true
            default: return false
            }
        }
    }
    
    @Test func incomingCardinalityNotSatisfied() throws {
        let frame = design.createFrame()
        let a = frame.createNode(.Stock)
        let b = frame.createNode(.FlowRate)
        let e1 = frame.createEdge(.Flow, origin: a.id, target: b.id)
        let e2 = frame.createEdge(.Flow, origin: a.id, target: b.id)
        let frozen = try design.accept(frame)
        
        #expect {
            try checker.validate(edge: frozen.edge(e1.id), in: frozen)
        }
        throws: {
            guard let error = $0 as? EdgeRuleViolation else {
                return false
            }
            guard case let .cardinalityViolation(_, direction) = error else {
                return false
            }
            return direction == .incoming
        }

        // Both edges should have the same error
        #expect {
            try checker.validate(edge: frozen.edge(e2.id), in: frozen)
        }
        throws: {
            guard let error = $0 as? EdgeRuleViolation else {
                return false
            }
            guard case let .cardinalityViolation(_, direction) = error else {
                return false
            }
            return direction == .incoming
        }
    }
    @Test func outgoingCardinalityNotSatisfied() throws {
        let frame = design.createFrame()
        let a = frame.createNode(.FlowRate)
        let b = frame.createNode(.Stock)
        let e1 = frame.createEdge(.Flow, origin: a.id, target: b.id)
        let e2 = frame.createEdge(.Flow, origin: a.id, target: b.id)
        let frozen = try design.accept(frame)
        
        #expect {
            try checker.validate(edge: frozen.edge(e1.id), in: frozen)
        }
        throws: {
            guard let error = $0 as? EdgeRuleViolation else {
                return false
            }
            guard case let .cardinalityViolation(_, direction) = error else {
                return false
            }
            return direction == .outgoing
        }

        // Both edges should have the same error
        #expect {
            try checker.validate(edge: frozen.edge(e2.id), in: frozen)
        }
        throws: {
            guard let error = $0 as? EdgeRuleViolation else {
                return false
            }
            guard case let .cardinalityViolation(_, direction) = error else {
                return false
            }
            return direction == .outgoing
        }
    }
    @Test func canConnect() async throws {
        let frame = design.createFrame()
        let stock = frame.createNode(.Stock)
        let rate = frame.createNode(.FlowRate)
        let _ = frame.createEdge(.Flow, origin: stock.id, target: rate.id)
        let frozen = try design.accept(frame)
        
        #expect(checker.canConnect(type: .Arrow, from: stock.id, to: rate.id, in: frozen))
        #expect(!checker.canConnect(type: .IllegalEdge, from: stock.id, to: rate.id, in: frozen))
        // Cardinality violation
        #expect(!checker.canConnect(type: .Flow, from: stock.id, to: rate.id, in: frozen))
        #expect(checker.canConnect(type: .Flow, from: rate.id, to: stock.id, in: frozen))
    }
}
