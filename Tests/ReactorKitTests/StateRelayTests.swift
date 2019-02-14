//
//  StateRelayTests.swift
//  ReactorKit
//
//  Created by tokijh on 21/10/2018.
//

import XCTest
import RxExpect
import RxSwift
import RxTest
@testable import ReactorKit

class StateRelayTests: XCTestCase {
    func testInitialValues() {
        let a = StateRelay(value: 1)
        let b = StateRelay(value: 2)
        
        let c = Observable.combineLatest(a.asObservable(), b.asObservable(), resultSelector: +)
        
        var latestValue: Int?
        
        let subscription = c
            .subscribe(onNext: { next in
                latestValue = next
            })
        
        XCTAssertEqual(latestValue!, 3)
        
        a.value = 5
        
        XCTAssertEqual(latestValue!, 7)
        
        b.value = 9
        
        XCTAssertEqual(latestValue!, 14)
        
        subscription.dispose()
        
        a.value = 10
        
        XCTAssertEqual(latestValue!, 14)
    }
    
    func testAccept() {
        let relay = StateRelay(value: 0)
        
        relay.accept(100)
        XCTAssertEqual(relay.value, 100)
        
        relay.accept(200)
        XCTAssertEqual(relay.value, 200)
        
        relay.accept(300)
        XCTAssertEqual(relay.value, 300)
    }
    
    func testDoNotSendsCompletedOnDealloc() {
        var a = StateRelay(value: 1)
        
        var latest = 0
        var completed = false
        let disposable = a.asObservable().debug().subscribe(onNext: { n in
            latest = n
        }, onCompleted: {
            completed = true
        })
        
        XCTAssertEqual(latest, 1)
        XCTAssertFalse(completed)
        
        a = StateRelay(value: 2)
        
        XCTAssertEqual(latest, 1)
        XCTAssertFalse(completed)
        
        disposable.dispose()
        
        XCTAssertEqual(latest, 1)
        XCTAssertFalse(completed)
    }
    
    func testVariableREADMEExampleByStateRelay() {
        
        // Two simple Rx variables
        // Every variable is actually a sequence future values in disguise.
        let a /*: Observable<Int>*/ = StateRelay(value: 1)
        let b /*: Observable<Int>*/ = StateRelay(value: 2)
        
        // Computed third variable (or sequence)
        let c /*: Observable<Int>*/ = Observable.combineLatest(a.asObservable(), b.asObservable()) { $0 + $1 }
        
        // Reading elements from c.
        // This is just a demo example.
        // Sequence elements are usually never enumerated like this.
        // Sequences are usually combined using map/filter/combineLatest ...
        //
        // This will immediately print:
        //      Next value of c = 3
        // because variables have initial values (starting element)
        var latestValueOfC : Int? = nil
        // let _ = doesn't retain.
        let d/*: Disposable*/  = c
            .subscribe(onNext: { c in
                //print("Next value of c = \(c)")
                latestValueOfC = c
            })
        
        defer {
            d.dispose()
        }
        
        XCTAssertEqual(latestValueOfC!, 3)
        
        // This will print:
        //      Next value of c = 5
        a.value = 3
        
        XCTAssertEqual(latestValueOfC!, 5)
        
        // This will print:
        //      Next value of c = 8
        b.value = 5
        
        XCTAssertEqual(latestValueOfC!, 8)
    }
}
