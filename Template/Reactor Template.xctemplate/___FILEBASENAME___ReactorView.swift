//___FILEHEADER___

import Foundation
import ReactorKit
import RxSwift

class ___FILEBASENAME___: Reactor {
    
    enum Action {
        // actiom cases
    }
    
    enum Mutation {
        // mutation cases
    }
    
    struct State {
        //state
    }
    
    let initialState: State
    
    init() {
        // init state initialState = State(...)
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        // switch action {
        // }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        // switch mutation {
        // }
        return newState
    }
    
}
