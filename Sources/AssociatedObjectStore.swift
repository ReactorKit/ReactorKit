//
//  AssociatedObjectStore.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 14/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import Foundation

public protocol AssociatedObjectStore : class {}


internal enum AssociatedObjectKey : String {
    case actionSubject
    case action
    case currentState
    case state
    case reactor
}

let map = NSMapTable<AnyObject, NSMutableDictionary>.strongToStrongObjects()

extension AssociatedObjectStore {

    func associatedObject<T>(forKey key: AssociatedObjectKey) -> T? {
        let container = map.object(forKey: self as AnyObject)
        return container?.object(forKey: key.rawValue) as? T
    }
    

    func associatedObject<T>(forKey key: AssociatedObjectKey, default handler: @autoclosure () -> T) -> T {
        if let object: T = self.associatedObject(forKey: key) { return object }
        let object = handler()
        self.setAssociatedObject(object, forKey: key)
        return object
    }
    
    func associatedObject<T>(forKey key: AssociatedObjectKey, _ handler: () -> T) -> T {
        return self.associatedObject(forKey: key, default: handler())
    }

    func setAssociatedObject<T>(_ object: T?, forKey key: AssociatedObjectKey) {
        let container: NSMutableDictionary
        switch map.object(forKey: self as AnyObject) {
        case let exists?:
            container = exists
        default:
            container = NSMutableDictionary()
            map.setObject(container, forKey: self)
        }
        if let object = object { container.setObject(object, forKey: key.rawValue as NSCopying) }
        else { container.removeObject(forKey: key.rawValue)}
    }

    func removeAssociatedObject(forKey key: AssociatedObjectKey) {
        let removal:Any? = nil
        self.setAssociatedObject(removal, forKey: key)
    }

}

