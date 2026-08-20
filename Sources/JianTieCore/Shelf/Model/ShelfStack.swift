//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 单次 Drag 拖入 Shelf 的不可拆分原子单元 (Stack)，包含一个或多个文件引用
public struct ShelfStack: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let files: [ShelfFileReference]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        files: [ShelfFileReference]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.files = files
    }

    /// 文件数量
    public var count: Int {
        return files.count
    }

    /// 卡片展示主标题
    public var title: String {
        guard let first = files.first else {
            return L10n.tr("shelf.empty")
        }
        if files.count == 1 {
            return first.fileName
        } else {
            return "\(first.fileName) +\(files.count - 1)"
        }
    }

    /// 统计该 Stack 中所有文件的总字节大小
    public var totalSize: Int64 {
        return files.reduce(0) { $0 + $1.fileSize }
    }

    /// 获取 Stack 中所有有效的文件 URL 列表（用于拖出 Drag Out）
    public var resolvedURLs: [URL] {
        return files.compactMap { $0.resolveURL() }
    }

    /// 原始 URL 列表
    public var urls: [URL] {
        return files.map(\.url)
    }

    /// 该 Stack 是否包含有效文件（只要有文件损坏或全部不可达，可用于判定巡检）
    public var isReachable: Bool {
        guard !files.isEmpty else { return false }
        return files.allSatisfy { $0.isReachable }
    }
}
