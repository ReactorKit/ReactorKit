//
//  Reactor+Run.swift
//  Pods
//
//  Created by 이병찬 on 9/3/25.
//

import RxSwift

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension Reactor {

    /// Provides support for Swift Concurrency (inspired by The Composable Architecture).
    /// https://github.com/pointfreeco/swift-composable-architecture/blob/acd9bb8a7cf6e36a89d81a432c2e8eb3b1bb3771/Sources/ComposableArchitecture/Effect.swift#L87-L95
    ///
    /// This method bridges Swift Concurrency (`Task`) with ReactorKit's `Mutation` stream.
    /// Inside the `operation` closure, you can call `send(_:)` to emit mutations.
    /// Once the task finishes, the observable automatically sends `onCompleted()`.
    ///
    /// > Important: Both the execution of the `operation` closure and the emissions
    /// > from the returned `Observable<Mutation>` are guaranteed to occur on the **main thread**.
    /// > The `scheduler` parameter determines the thread for emissions, and by default,
    /// > `scheduler: ImmediateSchedulerType = MainScheduler.instance` ensures main-thread execution.
    ///
    /// ## Example
    /// ```swift
    /// func mutateA() -> Observable<Mutation> {
    ///     return run { send in
    ///         for await event in self.events() {
    ///             send(Mutation.event(event))
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - priority: The priority of the created `Task`. Default is `nil`,
    ///               meaning the system decides the priority automatically.
    ///   - scheduler: The Rx scheduler on which `operation` executes and the returned
    ///                `Observable` emits. Default is `MainScheduler.instance`.
    ///   - operation: A Swift Concurrency closure where mutations can be emitted
    ///                via the `Send<Mutation>` parameter. Executed on the provided scheduler.
    ///
    /// - Returns: An `Observable<Mutation>` that emits values sent during the Swift Concurrency operation,
    ///            on the provided scheduler (default: main thread).
    ///
    func run(
        priority: TaskPriority? = nil,
        scheduler: ImmediateSchedulerType = MainScheduler.instance,
        operation: @escaping @MainActor @Sendable (_ send: Send<Mutation>) async -> Void,
    ) -> Observable<Mutation> {
        .create { observer in
            let task = Task(priority: priority) {
                let send = Send { observer.onNext($0) }
                await operation(send)
                observer.onCompleted()
            }
            return Disposables.create {
                task.cancel()
            }
        }
        .observe(on: scheduler)
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
/// A helper type for emitting `Mutation`s inside a Swift Concurrency task.
/// unless the task has been cancelled.
public struct Send<Mutation>: Sendable {

    let send: @Sendable (Mutation) -> Void

    public init(_ send: @escaping @Sendable (Mutation) -> Void) {
        self.send = send
    }

    public func callAsFunction(_ mutation: Mutation) {
        guard !Task.isCancelled else { return }
        self.send(mutation)
    }
}
