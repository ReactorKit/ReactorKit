//
//  ThreadLocal.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Darwin

/// Thread-local storage backed by pthread_key_t.
/// Used to record property access during `ReactorObserving` scopes.
enum _ThreadLocal {

  private static let key: pthread_key_t = {
    var key = pthread_key_t()
    let result = pthread_key_create(&key, nil)
    precondition(result == 0, "pthread_key_create failed: \(result)")
    return key
  }()

  static var value: UnsafeMutableRawPointer? {
    get { pthread_getspecific(key) }
    set {
      let result = pthread_setspecific(key, newValue)
      precondition(result == 0, "pthread_setspecific failed: \(result)")
    }
  }
}
