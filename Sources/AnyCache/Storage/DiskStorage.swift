//
//  DiskStorage.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

public struct DiskStorageConfig {
    public let fileManager: FileManager
    public let countLimit: Int
    public let byteLimit: Int
    public let directory: String

    public init(fileManager: FileManager = .default, directory: String? = nil, countLimit: Int, byteLimit: Int) {
        self.fileManager = fileManager
        self.countLimit = countLimit
        self.byteLimit = byteLimit
        if let directory = directory {
            self.directory = directory
        } else {
            let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
            self.directory = (cachesDirectory as NSString).appendingPathComponent("AnyCache")
        }
    }

    public static let `default` = DiskStorageConfig(countLimit: Int.max, byteLimit: Int.max)
}

final class DiskStorage {
    let name: String
    let config: DiskStorageConfig
    private let fileManager: FileManager
    private let lock = NSRecursiveLock()
    private var manifest: [String: ResourceObject] = [:]
    private let ioQueue = DispatchQueue(label: "com.anyCache.ioQueue")

    private lazy var directory: String = {
        (config.directory as NSString).appendingPathComponent(name)
    }()

    init(name: String, config: DiskStorageConfig) {
        self.name = name
        self.config = config
        self.fileManager = config.fileManager
        self.manifest = readFiles()
    }

    private func createDirectory() throws {
        guard !fileManager.fileExists(atPath: directory) else {
            return
        }
        try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    }

    private func readFiles() -> [String: ResourceObject] {
        lock.lock(); defer { lock.unlock() }
        let resoucesKey: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: directory),
                                                      includingPropertiesForKeys: resoucesKey,
                                                      options: .skipsSubdirectoryDescendants)
        else {
            return [:]
        }

        var manifest: [String: ResourceObject] = [:]
        while let url = enumerator.nextObject() {
            if let url = url as? URL,
               let resourceValues = try? url.resourceValues(forKeys: Set(resoucesKey)),
               resourceValues.isDirectory == false,
               resourceValues.isHidden == false,
               let resourceObject = ResourceObject(url: url, fileManager: fileManager)
            {
                manifest[resourceObject.name] = resourceObject
            }
        }
        return manifest
    }
}

extension DiskStorage {
    var allKeys: [String] {
        lock.lock(); defer { lock.unlock() }
        return manifest.map { $0.key }
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        manifest.removeAll()
        ioQueue.async {
            try? self.fileManager.removeItem(atPath: self.directory)
        }
    }

    func removeEntity(forKey key: String) {
        lock.lock(); defer { lock.unlock() }

        if let resouceObject = manifest[key] {
            manifest.removeValue(forKey: key)
            ioQueue.async {
                try? self.fileManager.removeItem(at: resouceObject.url)
            }
        }
    }

    func entity(forKey key: String) -> Entity? {
        lock.lock(); defer { lock.unlock() }
        guard let resouceObject = manifest[key] else {
            return nil
        }
        if let data = fileManager.contents(atPath: resouceObject.url.path) {
            return Entity(object: data, filePath: resouceObject.url, cost: data.count, expiry: Expiry(from: resouceObject.expire))
        }
        return nil
    }

    func entity(forKey key: String, completion: @escaping ((Entity?) -> Void)) {
        lock.lock(); defer { lock.unlock() }
        guard let resouceObject = manifest[key] else {
            completion(nil)
            return
        }
        ioQueue.async {
            if let data = self.fileManager.contents(atPath: resouceObject.url.path) {
                let entity = Entity(object: data, filePath: resouceObject.url, cost: data.count, expiry: Expiry(from: resouceObject.expire))
                DispatchQueue.main.async {
                    completion(entity)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    func setEntity(_ entity: Entity, forKey key: String, completion: (() -> Void)?) throws {
        removeEntity(forKey: key)

        lock.lock(); defer { lock.unlock() }
        let fileExtension = (key as NSString).pathExtension
        let filename = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") + "\(fileExtension.isEmpty ? "" : ".\(fileExtension)")"
        let path = (directory as NSString).appendingPathComponent(filename)
        let url = URL(fileURLWithPath: path, isDirectory: false)

        let data = try entity.object.serialize()
        let createDate = Date()
        try createDirectory()

        let resouceObject = ResourceObject(name: key, url: url, expire: entity.expiry.date, create: createDate, size: data.count)
        manifest[key] = resouceObject

        ioQueue.async {
            let attributes = [FileAttributeKey.fileExtendedAttributes: ["expire": "\(entity.expiry.date.timeIntervalSince1970)".data(using: .utf8)!,
                                                                        "create": "\(createDate.timeIntervalSince1970)".data(using: .utf8)!,
                                                                        "key": key.data(using: .utf8)!]]
            _ = self.fileManager.createFile(atPath: url.path, contents: data, attributes: nil)
            try? self.fileManager.setAttributes(attributes, ofItemAtPath: url.path)

            DispatchQueue.main.async {
                completion?()
            }
        }
        entity.updateProperty(key: \.cost, value: data.count)
        entity.updateProperty(key: \.filePath, value: url)
    }

    func containsEntity(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let resourceObject = manifest[key], resourceObject.expire.timeIntervalSinceNow > 0 {
            return true
        }
        return false
    }

    func removeAllExpires() {
        lock.lock(); defer { lock.unlock() }
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            return
        }

        var filesOnUsed = [ResourceObject]()
        var filesToDelete = [ResourceObject]()

        // find expires
        while let url = enumerator.nextObject() {
            guard let url = url as? URL else { continue }
            guard let resourceObject = ResourceObject(url: url, fileManager: fileManager) else {
                ioQueue.async {
                    try? self.fileManager.removeItem(at: url)
                }
                continue
            }
            if resourceObject.expire.timeIntervalSinceNow < 0 {
                filesToDelete.append(resourceObject)
            } else {
                filesOnUsed.append(resourceObject)
            }
        }

        filesOnUsed = filesOnUsed.sorted(by: {
            let expire1 = $0.expire.timeIntervalSince1970
            let expire2 = $1.expire.timeIntervalSince1970
            let create1 = $0.create.timeIntervalSince1970
            let create2 = $1.create.timeIntervalSince1970
            if expire1 == expire2 {
                return create1 > create2
            }
            return expire1 > expire2
        })

        // find oversizes
        if config.byteLimit > 0 {
            var usedSize: Int = 0
            for (i, file) in filesOnUsed.enumerated() {
                usedSize += file.size
                if usedSize > config.byteLimit {
                    let overCostFiles = Array(filesOnUsed[i ..< filesOnUsed.count])
                    filesOnUsed = Array(filesOnUsed[0 ..< i])
                    filesToDelete.append(contentsOf: overCostFiles)
                    break
                }
            }
        }

        // find overcount
        if config.countLimit > 0, filesOnUsed.count > config.countLimit {
            let overCountFiles = Array(filesOnUsed[config.countLimit ..< filesOnUsed.count])
            filesToDelete.append(contentsOf: overCountFiles)
        }

        // delete expires & oversizes
        for resourceObject in filesToDelete {
            manifest.removeValue(forKey: resourceObject.name)
            ioQueue.async {
                try? self.fileManager.removeItem(at: resourceObject.url)
            }
        }
    }
}

private extension FileAttributeKey {
    static let fileExtendedAttributes = FileAttributeKey("NSFileExtendedAttributes")
}

private struct ResourceObject {
    let name: String
    let url: URL
    let expire: Date
    let create: Date
    let size: Int

    init(name: String, url: URL, expire: Date, create: Date, size: Int) {
        self.name = name
        self.url = url
        self.expire = expire
        self.create = create
        self.size = size
    }

    init?(url: URL, fileManager: FileManager) {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int,
              let fileExtendedAttributes = attributes[.fileExtendedAttributes],
              let attributes = fileExtendedAttributes as? [String: Any],
              let __expire = attributes["expire"] as? Data,
              let __create = attributes["create"] as? Data,
              let __name = attributes["key"] as? Data,
              let _expire = String(data: __expire, encoding: .utf8),
              let _create = String(data: __create, encoding: .utf8),
              let name = String(data: __name, encoding: .utf8),
              let expire = TimeInterval(_expire),
              let create = TimeInterval(_create)
        else {
            return nil
        }

        self.name = name
        self.url = url
        self.size = size
        self.expire = Date(timeIntervalSince1970: expire)
        self.create = Date(timeIntervalSince1970: create)
    }
}
