//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 直接回贴服务：将选定项写入系统剪贴板、恢复目标应用焦点并在 30ms 内合成 ⌘V 完成回贴
public final class DirectPasteService: Sendable {
    public let pasteboardWriter: PasteboardWriting
    public let appActivator: AppActivating
    public let keySynthesizer: KeyEventSynthesizing
    public let yieldDelay: TimeInterval
    public let delayProvider: @Sendable (TimeInterval) async -> Void

    public init(
        pasteboardWriter: PasteboardWriting = SystemPasteboardWriter(),
        appActivator: AppActivating = SystemAppActivator.shared,
        keySynthesizer: KeyEventSynthesizing = CGEventKeySynthesizer.shared,
        yieldDelay: TimeInterval = 0.03,
        delayProvider: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    ) {
        self.pasteboardWriter = pasteboardWriter
        self.appActivator = appActivator
        self.keySynthesizer = keySynthesizer
        self.yieldDelay = yieldDelay
        self.delayProvider = delayProvider
    }

    /// 执行直接回贴
    /// - Parameters:
    ///   - item: 要回贴的剪贴板历史项
    ///   - target: 呼出前的前台活动应用（可为空）
    /// - Returns: 是否执行成功
    @discardableResult
    public func directPaste(
        item: ClipboardItem,
        target: AppTarget?
    ) async -> Bool {
        // 1. 将选定项写入系统剪贴板
        let writeSuccess = pasteboardWriter.write(content: item.content)
        guard writeSuccess else {
            return false
        }

        // 2. 检查是否有有效的目标前台应用
        guard let target = target else {
            // 没有目标应用时，只保留剪贴板写入结果，安全返回
            return true
        }

        // 3. 恢复并激活目标应用
        let activateSuccess = appActivator.activate(target: target)
        guard activateSuccess else {
            // 激活失败（如目标 App 已退出），仅保留写入剪贴板
            return true
        }

        // 4. 等待 30ms 确保目标应用窗口与输入框完全捕获焦点
        await delayProvider(yieldDelay)

        // 5. 合成并发送 ⌘V 按键事件
        let synthSuccess = keySynthesizer.synthesizeCommandV()
        return synthSuccess
    }
}
