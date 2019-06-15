import RxSwift

public class Stub<Reactor: ReactorKit.Reactor> {
  private unowned var reactor: Reactor
  private let disposeBag: DisposeBag

  @available(*, deprecated, message: "Use 'Reactor.isStubEnabled' instead.")
  public var isEnabled: Bool {
    set { self.reactor.isStubEnabled = newValue }
    get { return self.reactor.isStubEnabled }
  }

  public let state: StateRelay<Reactor.State>
  public let action: ActionSubject<Reactor.Action>
  public private(set) var actions: [Reactor.Action] = []

  public init(reactor: Reactor, disposeBag: DisposeBag) {
    self.reactor = reactor
    self.disposeBag = disposeBag
    self.state = .init(value: reactor.initialState)
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
