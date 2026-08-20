import Foundation

/// 剪贴板持久化存储协议
public protocol ClipboardStorageProviding: Sendable {
    /// 加载当前存储的所有剪贴板历史记录（按时间倒序）
    func load() throws -> [ClipboardItem]

    /// 保存剪贴板历史记录列表
    func save(items: [ClipboardItem]) throws

    /// 插入单条新记录至头部，并自动执行 FIFO 容量淘汰，返回更新后的列表
    @discardableResult
    func append(item: ClipboardItem) throws -> [ClipboardItem]

    /// 删除指定 ID 的记录
    @discardableResult
    func delete(id: UUID) throws -> [ClipboardItem]

    /// 清空所有历史记录与相关磁盘缓存
    func clear() throws
}
