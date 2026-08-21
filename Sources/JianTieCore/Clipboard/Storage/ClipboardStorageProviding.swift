//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 剪贴板持久化存储协议
public protocol ClipboardStorageProviding: Sendable {
    /// 加载当前存储的所有剪贴板历史记录（按时间倒序）
    func load() throws -> [ClipboardItem]

    /// 异步加载当前存储的所有剪贴板历史记录
    func loadAsync() async throws -> [ClipboardItem]

    /// 保存剪贴板历史记录列表
    func save(items: [ClipboardItem]) throws

    /// 异步保存剪贴板历史记录列表
    func saveAsync(items: [ClipboardItem]) async throws

    /// 插入单条新记录至头部，自动执行去重与修剪，返回更新后的列表
    @discardableResult
    func append(item: ClipboardItem) throws -> [ClipboardItem]

    /// 异步插入单条新记录至头部，自动执行去重与修剪
    @discardableResult
    func appendAsync(item: ClipboardItem) async throws -> [ClipboardItem]

    /// 删除指定 ID 的记录
    @discardableResult
    func delete(id: UUID) throws -> [ClipboardItem]

    /// 异步删除指定 ID 的记录
    @discardableResult
    func deleteAsync(id: UUID) async throws -> [ClipboardItem]

    /// 根据偏好设置执行过期与容量超限修剪
    @discardableResult
    func prune(now: Date) throws -> [ClipboardItem]

    /// 异步根据偏好设置执行过期与容量超限修剪
    @discardableResult
    func pruneAsync(now: Date) async throws -> [ClipboardItem]

    /// 清空所有历史记录与相关磁盘缓存
    func clear() throws

    /// 异步清空所有历史记录与相关磁盘缓存
    func clearAsync() async throws
}

public extension ClipboardStorageProviding {
    @discardableResult
    func prune() throws -> [ClipboardItem] {
        try prune(now: Date())
    }

    func loadAsync() async throws -> [ClipboardItem] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let result = try self.load()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveAsync(items: [ClipboardItem]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try self.save(items: items)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func appendAsync(item: ClipboardItem) async throws -> [ClipboardItem] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let result = try self.append(item: item)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func deleteAsync(id: UUID) async throws -> [ClipboardItem] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let result = try self.delete(id: id)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func pruneAsync(now: Date = Date()) async throws -> [ClipboardItem] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let result = try self.prune(now: now)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func clearAsync() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try self.clear()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
