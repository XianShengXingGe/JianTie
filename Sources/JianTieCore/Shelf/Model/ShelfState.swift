//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics

/// Shelf 的生命周期与展示状态机
public enum ShelfState: Equatable, Sendable {
    /// 完全隐藏
    case hidden
    /// 拖拽激活中滑出展示 (Finder 拖拽中)
    case revealedDragging(screenFrame: CGRect, edge: ShelfEdge)
    /// 空状态下边缘停留 150ms 唤出展示
    case revealedEmpty(screenFrame: CGRect, edge: ShelfEdge)
    /// 包含暂存 Stack 的常驻展示状态 (Issue #6)
    case stored(screenFrame: CGRect, edge: ShelfEdge)

    /// 是否处于可见展示状态
    public var isVisible: Bool {
        switch self {
        case .hidden:
            return false
        case .revealedDragging, .revealedEmpty, .stored:
            return true
        }
    }

    /// 是否由拖拽触发
    public var isDragging: Bool {
        switch self {
        case .revealedDragging:
            return true
        default:
            return false
        }
    }

    /// 当前绑定的屏幕区域
    public var currentScreenFrame: CGRect? {
        switch self {
        case .hidden:
            return nil
        case .revealedDragging(let frame, _),
             .revealedEmpty(let frame, _),
             .stored(let frame, _):
            return frame
        }
    }

    /// 当前停靠边缘
    public var currentEdge: ShelfEdge? {
        switch self {
        case .hidden:
            return nil
        case .revealedDragging(_, let edge),
             .revealedEmpty(_, let edge),
             .stored(_, let edge):
            return edge
        }
    }
}
