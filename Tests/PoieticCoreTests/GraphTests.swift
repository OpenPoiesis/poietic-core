//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Foundation
import XCTest
@testable import PoieticCore

final class GraphTests: XCTestCase {
    var memory: ObjectMemory!
    var frame: MutableFrame!
    
    override func setUp() {
        memory = ObjectMemory()
        frame = memory.deriveFrame()
    }
    
    func testBasic() throws {
        let n1 = memory.createSnapshot(TestNodeType)
        let n2 = memory.createSnapshot(TestNodeType)
        let u1 = memory.createSnapshot(TestType)
        let e1 = memory.createSnapshot(TestEdgeType, structure: .edge(n1.id, n2.id))

        frame.insert(n1, owned: true)
        frame.insert(n2, owned: true)
        frame.insert(u1, owned: true)
        frame.insert(e1, owned: true)

        XCTAssertEqual(frame.nodes.count, 2)
        XCTAssertTrue(frame.nodes.contains(where: {$0.id == n1.id}))
        XCTAssertTrue(frame.nodes.contains(where: {$0.id == n2.id}))
        
        XCTAssertEqual(frame.edges.count, 1)
        XCTAssertTrue(frame.edges.contains(where: {$0.id == e1.id}))

    }
}
