import SwiftUI
import AppKit
import JianTieCore

/// 偏好设置独立窗口控制器
@MainActor
public final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    public let viewModel: PreferencesViewModel

    public init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self

        let rootView = PreferencesView(viewModel: viewModel)
        window.contentView = NSHostingView(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 显示并激活偏好设置窗口
    public func showWindow() {
        guard let window = self.window else { return }

        viewModel.refreshAccessibilityStatus()

        if !window.isVisible {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    public func windowDidBecomeKey(_ notification: Notification) {
        viewModel.refreshAccessibilityStatus()
    }
}
