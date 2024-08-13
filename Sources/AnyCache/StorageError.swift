//
//  StorageError.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

public enum StorageError: Error {
  case notFound
  case typeNotMatch
  case isExpired
}

public enum CacheSerializableError: Error {
    case serializeFailure
    case deserializeFailure
}
