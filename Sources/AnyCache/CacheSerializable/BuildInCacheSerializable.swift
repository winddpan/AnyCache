//
//  BuildInCacheSerializable.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

extension Optional: CacheSerializable where Wrapped: CacheSerializable {
    public func serialize() throws -> Data {
        if let self = self {
            return try self.serialize()
        }
        throw CacheSerializableError.serializeFailure
    }

    public static func deserialize(from data: Data) -> Wrapped? {
        if let wrapped = try? Wrapped.deserialize(from: data) {
            return Wrapped?(wrapped)
        }
        return nil
    }
}

extension Data: CacheSerializable {
    public static func deserialize(from data: Data) throws -> Data {
        return data
    }

    public func serialize() throws -> Data {
        return self
    }
}

#if os(iOS)
import UIKit

private let imageScale = UIScreen.main.scale

extension UIImage: CacheSerializable {
    public func serialize() throws -> Data {
        if let data = pngData() {
            return data
        }
        throw CacheSerializableError.serializeFailure
    }

    public static func deserialize(from data: Data) throws -> Self {
        if let image = Self(data: data, scale: imageScale) {
            return image
        }
        throw CacheSerializableError.deserializeFailure
    }
}
#endif

/* NSFoundation -- */

extension NSString: CacheSerializable {
    public func serialize() throws -> Data {
        if let data = data(using: String.Encoding.utf8.rawValue) {
            return data
        }
        throw CacheSerializableError.serializeFailure
    }

    public static func deserialize(from data: Data) throws -> Self {
        if let string = Self(data: data, encoding: String.Encoding.utf8.rawValue) {
            return string
        }
        throw CacheSerializableError.deserializeFailure
    }
}

extension NSNumber: CacheSerializable {
    public func serialize() throws -> Data {
        if let data = "\(self)".data(using: .utf8) {
            return data
        }
        throw CacheSerializableError.serializeFailure
    }

    public static func deserialize(from data: Data) throws -> Self {
        if let str = String(data: data, encoding: .utf8) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if let doubleValue = formatter.number(from: str)?.doubleValue {
                return Self(value: doubleValue)
            }
        }
        throw CacheSerializableError.deserializeFailure
    }
}
