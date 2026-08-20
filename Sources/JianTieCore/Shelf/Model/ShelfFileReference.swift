import Foundation

/// Shelf 中单个文件的非破坏性引用模型，通过 Bookmark / URL 指向原始磁盘位置
public struct ShelfFileReference: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let bookmarkData: Data?
    public let fileName: String
    public let fileSize: Int64
    public let isDirectory: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        bookmarkData: Data? = nil,
        fileName: String? = nil,
        fileSize: Int64? = nil,
        isDirectory: Bool? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName ?? url.lastPathComponent

        // 若未显式传入 bookmarkData，则尝试生成非破坏性 Bookmark
        if let bookmarkData = bookmarkData {
            self.bookmarkData = bookmarkData
        } else {
            #if os(macOS)
            self.bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            self.bookmarkData = nil
            #endif
        }

        // 读取文件元数据
        if let isDirectory = isDirectory {
            self.isDirectory = isDirectory
        } else {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            self.isDirectory = isDir.boolValue
        }

        if let fileSize = fileSize {
            self.fileSize = fileSize
        } else {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? NSNumber {
                self.fileSize = size.int64Value
            } else {
                self.fileSize = 0
            }
        }
    }

    /// 解析 Bookmark 数据或验证磁盘路径，返回当前有效的文件 URL
    public func resolveURL() -> URL? {
        #if os(macOS)
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if FileManager.default.fileExists(atPath: resolved.path) {
                    return resolved
                }
            }
        }
        #endif

        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }

    /// 文件当前是否在磁盘上依然可访问
    public var isReachable: Bool {
        return resolveURL() != nil
    }
}
