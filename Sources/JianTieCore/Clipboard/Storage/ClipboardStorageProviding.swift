import Foundation

/// 剪贴板持久化存储协议
public protocol ClipboardStorageProviding: Sendable {
    /// 加载当前存储的所有剪贴板历史记录（按时间倒序）
    func load() throws -> [ClipboardItem]

    /// 保存剪贴板历史记录列表
    func save(items: [ClipboardItem]) throws

    /// 插入单条新记录至头部，自动执行去重与修剪，返回更新后的列表
    @discardableResult
    func append(item: ClipboardItem) throws -> [ClipboardItem]

    /// 删除指定 ID 的记录
    @discardableResult
    func delete(id: UUID) throws -> [ClipboardItem]

    /// 根据偏好设置执行过期与容量超限修剪
    @discardableResult
    func prune(now: Date) throws -> [ClipboardItem]

    /// 清空所有历史记录与相关磁盘缓存
    func clear() throws
}

public extension ClipboardStorageProviding {
    @discardableResult
    func prune() throws -> [ClipboardItem] {
        try prune(now: Date())
    }
}
