//
//  ProxyTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 17/11/2024.
//

import Testing
@testable import PoieticCore

let TestPort = ObjectType(name: "Port", structuralType: .proxy)

@Suite struct ProxyTests {
    let metamodel: Metamodel
    let design: Design
    let frame: TransientFrame
    
    init() throws {
        self.metamodel = TestMetamodel
        self.design = Design(metamodel: self.metamodel)
        self.frame = design.createFrame()
    }

    @Test func proxyBasicCreation() throws {
        let group = frame.create(.Group, attributes: ["name": "group"])
        
        #expect(frame.proxies(parent: group.id).isEmpty)
        
        let a = frame.create(TestType, parent: group.id)
        frame.create(.Port, structure: .proxy(a.id), parent: group.id)

        #expect(frame.proxies(parent: group.id).count == 1)
    }

    @Test func proxySubject() throws {
        let group = frame.create(.Group, attributes: ["name": "group"])
        
        let a = frame.create(TestType, parent: group.id)
        let port = frame.create(.Port, structure: .proxy(a.id), parent: group.id)
        let wrapped = try #require(Proxy(port))

        #expect(wrapped.subject == a.id)
    }

    @Test func proxySelfLoop() throws {
        let _ = frame.create(TestPort, id: 10, structure: .proxy(10))
        let result = frame.ultimateSubjects()
        #expect(result == nil)
    }

    @Test func proxyLoop() throws {
        let _ = frame.create(TestPort, id: 10, structure: .proxy(20))
        let _ = frame.create(TestPort, id: 20, structure: .proxy(30))
        let _ = frame.create(TestPort, id: 30, structure: .proxy(10))
        let result = frame.ultimateSubjects()
        #expect(result == nil)
    }

    @Test func rejectProxyLoop() throws {
        let _ = frame.create(TestPort, id: 10, structure: .proxy(10))
        #expect(throws: TransientFrameError.proxyCycle) {
            try frame.accept()
        }
    }

    @Test func ultimates() throws {
        let subject = frame.create(TestType)
        let direct = frame.create(TestPort, structure: .proxy(subject.id))
        let indirect = frame.create(TestPort, structure: .proxy(direct.id))

        #expect(frame.ultimateSubject(proxy: subject.id) == nil)
        #expect(frame.ultimateSubject(proxy: direct.id) == subject.id)
        #expect(frame.ultimateSubject(proxy: indirect.id) == subject.id)

        let result = Array(try #require(frame.ultimateSubjects()))
        #expect(result.count == 2)
        #expect(result.contains(where: { $0 == (id: direct.id, subject: subject.id)}))
        #expect(result.contains(where: { $0 == (id: indirect.id, subject: subject.id)}))
    }

    @Test func removeCascading() throws {
        let a = frame.create(TestType)
        let port = frame.create(TestPort, structure: .proxy(a.id))
        #expect(frame.contains(a.id))
        #expect(frame.contains(port.id))
        frame.removeCascading(a.id)
        #expect(!frame.contains(a.id))
        #expect(!frame.contains(port.id))
    }
}
