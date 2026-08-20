//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// Shelf 底部快捷动作区支持的动作类型
public enum ShelfActionType: String, CaseIterable, Sendable {
    /// 唤起 macOS 原生 AirDrop 系统分享
    case airDrop = "airDrop"
    /// 换行复制全部文件绝对路径至剪贴板
    case copyPath = "copyPath"
}
