//
//  AssociatedObjectStoreTests.swift
//  ReactorKit
//
//  Created by Seivan Heidari on 17/04/22.
//
//

import XCTest
@testable import ReactorKit

class Dummy : AssociatedObjectStore {
    
}

class AssociatedObjectStoreTests: XCTestCase {
    
    var subject:Dummy!
    override func setUp() {
        super.setUp()
        self.subject = Dummy()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    func testKeysAreRegistered() {
        let action = Date()
        self.subject.setAssociatedObject(action, forKey: .action)
        XCTAssertEqual(action, self.subject.associatedObject(forKey: .action))
    
    }
    
    func testKeysAreRemoved() {
        let action = Date()
        self.subject.setAssociatedObject(action, forKey: .action)
        self.subject.removeAssociatedObject(forKey: .action)
        
        XCTAssertNil(self.subject.associatedObject(forKey: .action))
        
        
    }
    
    func testKeysReplaceExistingValues() {
        let action = Date()
        self.subject.setAssociatedObject(action, forKey: .action)
        let newAction = Date()
        self.subject.setAssociatedObject(newAction, forKey: .action)
        XCTAssertEqual(newAction, self.subject.associatedObject(forKey: .action))
        XCTAssertNotEqual(newAction, action)
        
    }

    
    
}
