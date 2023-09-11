//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Foundation
import XCTest
@testable import PoieticCore

final class MutableFrameTests: XCTestCase {
    var memory: ObjectMemory!
    
    override func setUp() {
        memory = ObjectMemory()
    }
    
    func testAddChild() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)
        
        XCTAssertEqual(frame.object(a).children, [b, c])
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, a)
    }
    
    func testRemoveChild() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)
        
        frame.removeChild(c, from: a)
        
        XCTAssertEqual(frame.object(a).children, [b])
        XCTAssertNil(frame.object(c).parent)
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, nil)
    }
    
    func testSetParent() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.setParent(c, to: a)
        
        XCTAssertEqual(frame.object(a).children, [b, c])
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, a)
        
        frame.setParent(c, to: b)
        
        XCTAssertEqual(frame.object(a).children, [b])
        XCTAssertEqual(frame.object(b).children, [c])
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, b)
    }
    func testRemoveFromParent() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)

        frame.removeFromParent(b)
        XCTAssertNil(frame.object(b).parent)
        XCTAssertEqual(frame.object(a).children, [c])

        frame.removeFromParent(c)
        XCTAssertNil(frame.object(c).parent)
        XCTAssertEqual(frame.object(a).children, [])
    }

    func testRemoveCascadingChildren() throws {
        // a - b - c
        // d - e - f
        //
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        let d = frame.create(TestType)
        let e = frame.create(TestType)
        let f = frame.create(TestType)

        frame.addChild(b, to: a)
        frame.addChild(c, to: b)
        frame.addChild(e, to: d)
        frame.addChild(f, to: e)

        frame.removeCascading(b)
        XCTAssertFalse(frame.contains(b))
        XCTAssertFalse(frame.contains(c))
        XCTAssertFalse(frame.object(a).children.contains(b))

        frame.removeCascading(d)
        XCTAssertFalse(frame.contains(d))
        XCTAssertFalse(frame.contains(e))
        XCTAssertFalse(frame.contains(f))
    }
    
    func testBrokenReferences() throws {
        let frame = memory.createFrame()
        let a = memory.allocateUnstructuredSnapshot(TestType, id: 1)
        a.parent = 10
        a.children = [20]
        a.initialize(structure: .edge(30, 40))
        frame.unsafeInsert(a, owned: true)

        let refs = frame.brokenReferences()
        
        XCTAssertEqual(refs.count, 4)
        XCTAssertTrue(refs.contains(10))
        XCTAssertTrue(refs.contains(20))
        XCTAssertTrue(refs.contains(30))
        XCTAssertTrue(refs.contains(40))
    }
    
}
