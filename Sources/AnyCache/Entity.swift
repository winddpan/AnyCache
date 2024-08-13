//
//  Entity.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

public final class Entity {
    public private(set) var object: CacheSerializable
    public private(set) var expiry: Expiry
    public private(set) var cost: Int
    public private(set) var filePath: URL

    init(object: CacheSerializable, filePath: URL, cost: Int, expiry: Expiry) {
        self.object = object
        self.cost = cost
        self.expiry = expiry
        self.filePath = filePath
    }

    func updateProperty<T>(key: KeyPath<Entity, T>, value: T) {
        if let key = key as? ReferenceWritableKeyPath<Entity, T> {
            self[keyPath: key] = value
        }
    }
}
