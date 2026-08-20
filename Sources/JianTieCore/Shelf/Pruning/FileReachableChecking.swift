//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 文件可达性检测协议，用于巡检原文件是否被删除、移动或外接磁盘卸载
public protocol FileReachableChecking: Sendable {
    func isReachable(file: ShelfFileReference) -> Bool
}

/// 系统默认文件可达性检测器
public final class SystemFileReachableChecker: FileReachableChecking, @unchecked Sendable {
    public static let shared = SystemFileReachableChecker()

    public init() {}

    public func isReachable(file: ShelfFileReference) -> Bool {
        return file.isReachable
    }
}
