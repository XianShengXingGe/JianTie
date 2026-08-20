import SwiftUI
import AppKit
import JianTieCore

/// 偏好设置键盘与事件响应窗口
public final class PreferencesPanelWindow: NSWindow {
    public var onEscape: (() -> Void)?

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 { // ESC 键
            onEscape?()
            return
        }
        super.sendEvent(event)
    }

    public override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// 偏好设置独立窗口控制器
@MainActor
public final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    public let viewModel: PreferencesViewModel

    public init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel

        let window = PreferencesPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self

        window.onEscape = { [weak self] in
            self?.closeWindow()
        }

        let rootView = PreferencesView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.closeWindow()
            }
        )
        window.contentView = NSHostingView(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 显示并激活偏好设置窗口
    public func showWindow() {
        guard let window = self.window else { return }

        viewModel.refreshStatus()

        if !window.isVisible {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 立即隐藏并收起偏好设置窗口
    public func closeWindow() {
        self.window?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    public func windowDidBecomeKey(_ notification: Notification) {
        viewModel.refreshStatus()
    }

    public func windowDidBecomeMain(_ notification: Notification) {
        viewModel.refreshStatus()
    }
}
