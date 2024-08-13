//
//  CacheSerializable.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

public protocol CacheSerializable {
    func serialize() throws -> Data
    static func deserialize(from data: Data) throws -> Self
}
