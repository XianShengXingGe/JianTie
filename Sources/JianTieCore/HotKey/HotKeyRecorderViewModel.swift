//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit
import Carbon.HIToolbox
import Combine

/// 快捷键录制控制器与状态机
@MainActor
public final class HotKeyRecorderViewModel: ObservableObject {
    /// 当前是否处于快捷键录制中
    @Published public private(set) var isRecording: Bool = false

    /// 校验失败时的错误提示信息（如 "快捷键必须包含修饰键 (⌘/⌥/⌃/⇧)"）
    @Published public var errorMessage: String? = nil

    /// 触发 UI 抖动或提示动画的递增序号
    @Published public private(set) var shakeTrigger: Int = 0

    /// 当前热键触发模式
    public var currentTrigger: HotKeyTrigger {
        preferencesViewModel.hotKeyTrigger
    }

    /// 是否为默认全局快捷键 (双击 ⌘)
    public var isDefaultHotKey: Bool {
        preferencesViewModel.isDefaultHotKey
    }

    /// 所绑定的偏好设置视图模型
    public let preferencesViewModel: PreferencesViewModel

    /// macOS 本地事件监听器引用 (NSEvent local monitor)
    private var eventMonitor: Any?

    /// 自动清除错误提示的 Task
    private var errorDismissTask: Task<Void, Never>?

    public init(preferencesViewModel: PreferencesViewModel) {
        self.preferencesViewModel = preferencesViewModel
    }

    /// 开始进入按键录制状态
    public func startRecording() {
        guard !isRecording else { return }
        clearError()
        isRecording = true
        installEventMonitor()
    }

    /// 退出按键录制状态（取消录制）
    public func stopRecording() {
        guard isRecording else { return }
        removeEventMonitor()
        isRecording = false
        clearError()
    }

    /// 切换录制状态 (用于点击录制胶囊时)
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    /// 恢复默认快捷键 (双击 ⌘)
    public func resetToDefault() {
        stopRecording()
        preferencesViewModel.resetHotKeyToDefault()
    }

    /// 选择双击修饰键
    public func selectDoubleTapModifier(_ modifier: ModifierKey) {
        stopRecording()
        preferencesViewModel.setDoubleTapModifier(modifier)
    }

    /// 核心按键事件分发与校验处理 (返回 true 表示该事件被录制器拦截并吞没)
    @discardableResult
    public func handleKeyDown(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard isRecording else { return false }

        // 1. Esc 键 -> 取消本次录制，不修改当前快捷键
        if Int(keyCode) == kVK_Escape {
            stopRecording()
            return true
        }

        // 2. Delete / Forward Delete 键 -> 如果无修饰键按下时按 Delete，恢复为默认快捷键
        let keyModifiers = KeyModifiers.from(eventModifierFlags: modifierFlags)
        if (Int(keyCode) == kVK_Delete || Int(keyCode) == kVK_ForwardDelete) && keyModifiers.isEmpty {
            resetToDefault()
            return true
        }

        // 3. 校验按键组合合法性
        let uKeyCode = UInt32(keyCode)
        let validation = HotKeyValidator.validate(keyCode: uKeyCode, modifiers: keyModifiers)

        if validation.isValid {
            // 合法按键：保存新快捷键并退出录制
            let newTrigger = HotKeyTrigger.keyCombination(keyCode: uKeyCode, modifiers: keyModifiers)
            preferencesViewModel.setHotKeyTrigger(newTrigger)
            stopRecording()
            return true
        } else {
            // 非法按键（例如单字符无修饰键）：展示轻量错误提示，保持录制状态
            let message = validation.error?.localizedDescription ?? L10n.tr("hotkey.modifier_required")
            showError(message: message)
            return true
        }
    }

    private func showError(message: String) {
        errorMessage = message
        shakeTrigger += 1

        errorDismissTask?.cancel()
        errorDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled {
                self?.errorMessage = nil
            }
        }
    }

    private func clearError() {
        errorDismissTask?.cancel()
        errorDismissTask = nil
        errorMessage = nil
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            let handled = self.handleKeyDown(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
            return handled ? nil : event
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
