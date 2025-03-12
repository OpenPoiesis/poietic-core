//
//  MetamodelTest.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 12/03/2025.
//


import Testing
@testable import PoieticFlows
@testable import PoieticCore


@Suite struct MetamodelTest {
    @Test func uniqueAttributeTamens() throws {
        let metamodel = Metamodel.Basic
        for type in metamodel.types {
            var attributes: [String:[String]] = [:]
            
            for trait in type.traits {
                for attribute in trait.attributes {
                    attributes[attribute.name, default: []].append(trait.name)
                }
            }
            for (_, traits) in attributes {
                #expect(traits.count <= 1)
            }
        }
    }
    
    @Test func metamodelTypeTraits() throws {
        let metamodel = Metamodel.Basic
        for type in metamodel.types {
            for trait in type.traits {
                #expect(metamodel.trait(name: trait.name) != nil, "Missing trait \(trait.name)")
            }
        }
    }
}
