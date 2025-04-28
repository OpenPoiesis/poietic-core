//
//  GenerationalArrayTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/04/2025.
//


import Testing
@testable import PoieticCore

struct GenerationalArrayTests {
    @Test 
    func testEmptyInitialization() {
        let array = GenerationalArray<Int>()
        #expect(array.isEmpty)
        #expect(array.count == 0)
    }
    
    @Test 
    func testCollectionInitialization() {
        let array = GenerationalArray([1, 2, 3])
        #expect(!array.isEmpty)
        #expect(array.count == 3)
    }
    
    @Test 
    func testArrayLiteralInitialization() {
        let array: GenerationalArray = [1, 2, 3]
        #expect(!array.isEmpty)
        #expect(array.count == 3)
    }
    
    @Test 
    func testAppend() {
        var array = GenerationalArray<Int>()
        let index1 = array.append(10)
        #expect(array.count == 1)
        #expect(array[index1] == 10)
        #expect(array.isValid(index1))
        let index2 = array.append(20)
        #expect(array.count == 2)
        #expect(array[index2] == 20)
        #expect(array.isValid(index2))
    }
    
    @Test 
    func testRemove() {
        var array = GenerationalArray<Int>()
        let index = array.append(10)
        let flag = array.remove(at: index)
        #expect(flag)
        #expect(array.count == 0)
        #expect(!array.isValid(index))
        // Remove again
        let flag2 = array.remove(at: index)
        #expect(!flag2)
    }
    
    @Test
    func testIndexReuse() {
        var array = GenerationalArray<Int>()
        let index1 = array.append(10)
        array.remove(at: index1)
        
        let index2 = array.append(20)
        #expect(index1.position == index2.position)
        #expect(index1.generation + 1 == index2.generation)
    }
    
    @Test
    func testCollectionConformance() {
        var array = GenerationalArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        var collected: [Int] = []
        for element in array {
            collected.append(element)
        }
        
        #expect(collected == [1, 2, 3])
    }
    
    @Test 
    func testMutableCollectionConformance() {
        var array = GenerationalArray<Int>()
        let index = array.append(1)
        array[index] = 2
        #expect(array[index] == 2)
    }
    
    @Test 
    func testStartEndIndex() {
        var array = GenerationalArray<Int>()
        #expect(array.startIndex.position == array.storage.endIndex)
        #expect(array.endIndex.position == array.storage.endIndex)

        let index = array.append(10)
        #expect(array.startIndex == index)
    }
    
    @Test 
    func testIndexAfter() {
        var array = GenerationalArray<Int>()
        let index1 = array.append(10)
        let index2 = array.append(20)
        
        let nextIndex = array.index(after: index1)
        #expect(nextIndex == index2)
    }
    
    @Test 
    func testIndexAfterWithHoles() {
        var array = GenerationalArray<Int>()
        let index1 = array.append(10)
        _ = array.append(20)
        array.remove(at: index1)
        
        let index3 = array.append(30)
        let start = array.startIndex
        #expect(start == index3)
    }
    
    @Test
    func iterateEmpty() throws {
        var array = GenerationalArray<Int>()
        #expect(array.startIndex == array.endIndex)
        for _ in array { }
    }
}
