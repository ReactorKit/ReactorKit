import RxSwift

public class Stub<Reactor: _Reactor> {
  private unowned var reactor: Reactor
  private let disposeBag: DisposeBag

  public var isEnabled: Bool = false

  public let state: Variable<Reactor.State>
  public let action: ActionSubject<Reactor.Action>
  public private(set) var actions: [Reactor.Action] = []

  public init(reactor: Reactor, disposeBag: DisposeBag) {
    self.reactor = reactor
    self.disposeBag = disposeBag
    self.state = .init(reactor.initialState)
    self.state.asObservable()
      .subscribe(onNext: { [weak reactor] state in
        reactor?.currentState = state
      })
      .disposed(by: disposeBag)
    self.action = .init()
    self.action
      .subscribe(onNext: { [weak self] action in
        self?.actions.append(action)
      })
      .disposed(by: self.disposeBag)
  }
}
