//
//  MemoryStorage.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation
#if canImport(UIKit)
    import UIKit
#endif

public struct MemoryStorageConfig {
    public let countLimit: Int
    public let byteLimit: Int

    public init(countLimit: Int, byteLimit: Int) {
        self.countLimit = countLimit
        self.byteLimit = byteLimit
    }

    public static let `default` = MemoryStorageConfig(countLimit: Int.max, byteLimit: Int.max)
}

final class MemoryStorage {
    private let cache = NSCache<NSString, Entity>()
    let lock = NSRecursiveLock()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    init(name: String, config: MemoryStorageConfig) {
        cache.name = name
        cache.countLimit = config.countLimit
        cache.totalCostLimit = config.byteLimit

        #if canImport(UIKit)
            NotificationCenter.default.addObserver(self, selector: #selector(_autoCleanup), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(_autoCleanup), name: UIApplication.didEnterBackgroundNotification, object: nil)
        #endif
    }

    @objc private func _autoCleanup() {
        removeAll()
    }
}

extension MemoryStorage {
    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        cache.removeAllObjects()
    }

    func removeEntity(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        cache.removeObject(forKey: key as NSString)
    }

    func entity(forKey key: String) -> Entity? {
        lock.lock(); defer { lock.unlock() }
        return cache.object(forKey: key as NSString)
    }

    func setEntity(_ entity: Entity, forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard cache.countLimit > 0, cache.totalCostLimit > 0 else { return }
        cache.setObject(entity, forKey: key as NSString, cost: entity.cost)
    }

    func containsEntity(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let entity = cache.object(forKey: key as NSString), !entity.expiry.isExpired {
            return true
        }
        return false
    }

    func removeAllExpires() {}
}
