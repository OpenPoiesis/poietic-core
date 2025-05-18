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
        let e1 = frame.create(TestEdgeType, structure: .edge(n1.objectID, n2.objectID))

        XCTAssertEqual(frame.nodes.count, 2)
        XCTAssertTrue(frame.nodes.contains(where: {$0.objectID == n1.objectID}))
        XCTAssertTrue(frame.nodes.contains(where: {$0.objectID == n2.objectID}))
        
        XCTAssertEqual(frame.edges.count, 1)
        XCTAssertTrue(frame.edges.contains(where: {$0.id == e1.objectID}))

    }
}
