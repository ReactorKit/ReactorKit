//
//  Reactor+RunTests.swift
//  ReactorKit
//
//  Created by 이병찬 on 9/3/25.
//

import XCTest
import RxSwift

@testable import ReactorKit

final class Reactor_RunTests: XCTestCase {

    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    func testRunSimple() async {
        // Given
        let expectedCounts = [1, 2, 3, 4].shuffled()
        var recodedCounts: [Int] = []
        let reactor = TestReactor()
        let disposeBag = DisposeBag()

        // When
        reactor.state.compactMap(\.count)
            .subscribe(onNext: { count in
                recodedCounts.append(count)
            })
            .disposed(by: disposeBag)

        let stream = AsyncStream<Int> { continuation in
            for value in expectedCounts {
                continuation.yield(value)
            }
            continuation.finish()
        }
        reactor.action.onNext(.refreshCount(stream))

        // Then (just waiting 1 miliseonds for execution stream.)
        try? await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertEqual(expectedCounts, recodedCounts)
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
private final class TestReactor: Reactor {

    enum Action {
        case refreshCount(AsyncStream<Int>)
    }

    enum Mutation {
        case setCount(Int)
    }

    struct State {
        var count: Int?
    }

    let initialState = State()

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .refreshCount(let stream):
            run(scheduler: CurrentThreadScheduler.instance) { send in
                for await count in stream {
                    send(.setCount(count))
                }
            }
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state

        switch mutation {
        case .setCount(let count):
            newState.count = count
        }

        return newState
    }
}
