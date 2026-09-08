//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Testing
@testable import PoieticCore

struct FrameAsGraphTests {
    let design: Design
    let frame: TransientPlane
    
    init() {
        design = Design()
        frame = design.createPlane()
    }
    
    @Test func basic() throws {
        let n1 = frame.create(TestDomain.Types.TestNode, topology: .node)
        let n2 = frame.create(TestDomain.Types.TestNode, topology: .node)
        let _ = frame.create(TestDomain.Types.TestUnstructured, topology: .unstructured)
        let e1 = frame.create(TestDomain.Types.TestEdge, topology: .edge(n1.objectID, n2.objectID))

        #expect(frame.nodeKeys.count == 2)
        #expect(frame.nodeKeys.contains(n1.objectID))
        #expect(frame.nodeKeys.contains(n2.objectID))
        
        #expect(frame.edgeKeys.count == 1)
        #expect(frame.edgeKeys.contains(e1.objectID))

    }
}
