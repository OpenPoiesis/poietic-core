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
    var design: Design!
    var frame: TransientFrame!
    
    override func setUp() {
        design = Design()
        frame = design.createFrame()
    }
    
    func testBasic() throws {
        let n1 = frame.create(TestNodeType)
        let n2 = frame.create(TestNodeType)
        let _ = frame.create(TestType)
        let e1 = frame.create(TestEdgeType, structure: .edge(n1.id, n2.id))

        XCTAssertEqual(frame.nodes.count, 2)
        XCTAssertTrue(frame.nodes.contains(where: {$0.id == n1.id}))
        XCTAssertTrue(frame.nodes.contains(where: {$0.id == n2.id}))
        
        XCTAssertEqual(frame.edges.count, 1)
        XCTAssertTrue(frame.edges.contains(where: {$0.id == e1.id}))

    }
}
