import Foundation

/// 基于本地文件系统的剪贴板持久化存储
public final class FileClipboardStorage: ClipboardStorageProviding, @unchecked Sendable {
    public let baseDirectoryURL: URL
    public let preferences: PreferencesProviding

    private let fileManager = FileManager.default
    private let lock = NSRecursiveLock()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private var itemsFileURL: URL {
        baseDirectoryURL.appendingPathComponent("items.json")
    }

    private var imagesDirectoryURL: URL {
        baseDirectoryURL.appendingPathComponent("images", isDirectory: true)
    }

    public init(
        baseDirectoryURL: URL = FileClipboardStorage.defaultStorageDirectoryURL,
        preferences: PreferencesProviding = UserDefaultsPreferences.shared
    ) {
        self.baseDirectoryURL = baseDirectoryURL
        self.preferences = preferences
        self.jsonEncoder.outputFormatting = [.prettyPrinted]
        ensureDirectoryStructure()
    }

    public static var defaultStorageDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("JianTie/ClipboardStorage", isDirectory: true)
    }

    private func ensureDirectoryStructure() {
        try? fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Internal Record Struct for JSON Serialization

    private struct PersistedRecord: Codable {
        let id: UUID
        let timestamp: Date
        let contentType: String
        let plainText: String?
        let rtfData: Data?
        let htmlData: Data?
        let imageFormat: String?
    }

    public func load() throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: itemsFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: itemsFileURL)
        let records = try jsonDecoder.decode([PersistedRecord].self, from: data)

        var items: [ClipboardItem] = []
        for record in records {
            if record.contentType == "text", let plainText = record.plainText {
                let textContent = ClipboardTextContent(
                    plainText: plainText,
                    rtfData: record.rtfData,
                    htmlData: record.htmlData
                )
                items.append(ClipboardItem(id: record.id, timestamp: record.timestamp, content: .text(textContent)))
            } else if record.contentType == "image", let format = record.imageFormat {
                let imageFileURL = imagesDirectoryURL.appendingPathComponent("\(record.id.uuidString).\(format)")
                if let imageData = try? Data(contentsOf: imageFileURL) {
                    let imageContent = ClipboardImageContent(imageData: imageData, format: format)
                    items.append(ClipboardItem(id: record.id, timestamp: record.timestamp, content: .image(imageContent)))
                }
            }
        }
        return items
    }

    public func save(items: [ClipboardItem]) throws {
        lock.lock()
        defer { lock.unlock() }

        ensureDirectoryStructure()

        var recordsToSave: [PersistedRecord] = []
        var preservedImageIDs = Set<UUID>()

        for item in items {
            switch item.content {
            case .text(let text):
                recordsToSave.append(PersistedRecord(
                    id: item.id,
                    timestamp: item.timestamp,
                    contentType: "text",
                    plainText: text.plainText,
                    rtfData: text.rtfData,
                    htmlData: text.htmlData,
                    imageFormat: nil
                ))
            case .image(let image):
                recordsToSave.append(PersistedRecord(
                    id: item.id,
                    timestamp: item.timestamp,
                    contentType: "image",
                    plainText: nil,
                    rtfData: nil,
                    htmlData: nil,
                    imageFormat: image.format
                ))
                preservedImageIDs.insert(item.id)
                let imageFileURL = imagesDirectoryURL.appendingPathComponent("\(item.id.uuidString).\(image.format)")
                if !fileManager.fileExists(atPath: imageFileURL.path) {
                    try? image.imageData.write(to: imageFileURL, options: .atomic)
                }
            }
        }

        // 清理被 FIFO 淘汰、超期修剪或去重移除的孤儿图片文件
        if let existingImageFiles = try? fileManager.contentsOfDirectory(atPath: imagesDirectoryURL.path) {
            for fileName in existingImageFiles {
                let fileUUIDString = (fileName as NSString).deletingPathExtension
                if let fileUUID = UUID(uuidString: fileUUIDString), !preservedImageIDs.contains(fileUUID) {
                    let targetURL = imagesDirectoryURL.appendingPathComponent(fileName)
                    try? fileManager.removeItem(at: targetURL)
                }
            }
        }

        let encodedData = try jsonEncoder.encode(recordsToSave)
        try encodedData.write(to: itemsFileURL, options: .atomic)
    }

    @discardableResult
    public func append(item: ClipboardItem) throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        var currentItems = try load()

        // 智能去重：移除历史中已存在的相同内容记录
        currentItems.removeAll { existing in
            existing.content.isContentEqual(to: item.content)
        }

        // 最新记录置顶插入头部 (index 0)
        currentItems.insert(item, at: 0)

        // 执行保存周期与容量上限修剪
        currentItems = pruneItems(currentItems, now: item.timestamp)

        try save(items: currentItems)
        return currentItems
    }

    @discardableResult
    public func delete(id: UUID) throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        var currentItems = try load()
        currentItems.removeAll { $0.id == id }

        try save(items: currentItems)
        return currentItems
    }

    @discardableResult
    public func prune(now: Date = Date()) throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        let currentItems = try load()
        let pruned = pruneItems(currentItems, now: now)
        try save(items: pruned)
        return pruned
    }

    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        if fileManager.fileExists(atPath: itemsFileURL.path) {
            try? fileManager.removeItem(at: itemsFileURL)
        }
        if fileManager.fileExists(atPath: imagesDirectoryURL.path) {
            try? fileManager.removeItem(at: imagesDirectoryURL)
        }
        ensureDirectoryStructure()
    }

    // MARK: - Private Helpers

    private func pruneItems(_ items: [ClipboardItem], now: Date) -> [ClipboardItem] {
        var result = items

        // 1. 保存周期过期修剪 (Retention Period)
        if let days = preferences.clipboardRetentionPeriod.days {
            let cutoffDate = now.addingTimeInterval(-Double(days * 86400))
            result = result.filter { $0.timestamp >= cutoffDate }
        }

        // 2. 容量上限修剪 (FIFO Eviction)
        if let maxCount = preferences.clipboardCapacityLimit.maxCount {
            if result.count > maxCount {
                result = Array(result.prefix(maxCount))
            }
        }

        return result
    }
}
