//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics

/// 系统级文件拖拽监听协议
public protocol DragMonitoring: Sendable {
    /// 当前是否处于监听状态
    var isMonitoring: Bool { get }

    /// 当前是否存在活跃的 Finder 文件拖拽 Session
    var isDraggingActive: Bool { get }

    /// 启动系统拖拽监听
    /// - Parameters:
    ///   - onDragStart: 检测到拖拽开始（包含文件列表与鼠标位置）的回调
    ///   - onDragEnd: 拖拽结束（释放鼠标）的回调
    func startMonitoring(
        onDragStart: @escaping @Sendable (_ files: [URL], _ location: CGPoint) -> Void,
        onDragEnd: @escaping @Sendable () -> Void
    )

    /// 停止监听
    func stopMonitoring()

    /// 重置并同步拖拽状态（如内部拖出结束或异常释放时）
    func resetDraggingState()
}
