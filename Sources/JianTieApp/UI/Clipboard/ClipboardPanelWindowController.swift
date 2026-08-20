//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import SwiftUI
import AppKit
import JianTieCore

/// 自定义键盘拦截浮层 Panel
public final class ClipboardPanelWindow: NSPanel {
    public var onEscape: (() -> Void)?
    public var onEnter: (() -> Void)?
    public var onUpArrow: (() -> Void)?
    public var onDownArrow: (() -> Void)?

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch event.keyCode {
            case 53: // ESC
                onEscape?()
                return
            case 36, 76: // Enter / Keypad Enter
                onEnter?()
                return
            case 126: // Up Arrow
                onUpArrow?()
                return
            case 125: // Down Arrow
                onDownArrow?()
                return
            default:
                break
            }
        }
        super.sendEvent(event)
    }
}

/// 剪贴板浮层窗口控制器
@MainActor
public final class ClipboardPanelWindowController: NSWindowController, NSWindowDelegate {
    public let viewModel: ClipboardViewModel
    public weak var appCoordinator: AppCoordinator?
    public private(set) var targetApp: AppTarget?

    public init(
        viewModel: ClipboardViewModel,
        appCoordinator: AppCoordinator? = nil
    ) {
        self.viewModel = viewModel
        self.appCoordinator = appCoordinator

        let window = ClipboardPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isFloatingPanel = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: window)
        window.delegate = self

        setupEventHandlers(window: window)
        setupContentView(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupEventHandlers(window: ClipboardPanelWindow) {
        window.onEscape = { [weak self] in
            self?.dismissAndRestoreFocus()
        }

        window.onEnter = { [weak self] in
            self?.confirmCurrentSelectionAndPaste()
        }

        window.onUpArrow = { [weak self] in
            self?.viewModel.moveSelectionUp()
        }

        window.onDownArrow = { [weak self] in
            self?.viewModel.moveSelectionDown()
        }
    }

    private func setupContentView(window: ClipboardPanelWindow) {
        let rootView = ClipboardPanelView(
            viewModel: viewModel,
            onSelectAndPaste: { [weak self] item in
                self?.pasteItemAndClose(item)
            }
        )
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
    }

    /// 弹出浮层窗口
    /// - Parameter target: 唤出前的前台活动 App
    public func show(targetApp: AppTarget?) {
        guard let window = self.window else { return }

        let resolvedTarget: AppTarget?
        if let target = targetApp, target.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            resolvedTarget = target
        } else if let coordinatorTarget = appCoordinator?.lastFrontmostApp, coordinatorTarget.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            resolvedTarget = coordinatorTarget
        } else if let front = appCoordinator?.appActivator.frontmostApp(), front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            resolvedTarget = front
        } else {
            resolvedTarget = nil
        }

        self.targetApp = resolvedTarget
        viewModel.resetForPresentation()

        positionWindowOnActiveScreen(window)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 收起浮层窗口并归还前台应用焦点
    public func dismissAndRestoreFocus() {
        guard let window = self.window, window.isVisible else { return }
        window.orderOut(nil)

        if let target = targetApp {
            _ = appCoordinator?.appActivator.activate(target: target)
        }
    }

    /// 确认当前选中项并执行回贴
    public func confirmCurrentSelectionAndPaste() {
        guard let item = viewModel.confirmSelection() else { return }
        pasteItemAndClose(item)
    }

    /// 回贴指定项并关闭浮层
    public func pasteItemAndClose(_ item: ClipboardItem) {
        guard let window = self.window, window.isVisible else { return }
        let target = self.targetApp ?? appCoordinator?.lastFrontmostApp
        window.orderOut(nil)

        Task { @MainActor [weak self] in
            await self?.appCoordinator?.pasteItem(item, to: target)
        }
    }

    private func positionWindowOnActiveScreen(_ window: NSWindow) {
        // 定位至鼠标所在屏幕居中偏上位置，符合 Spotlight / Raycast 体验
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? window.screen

        if let screen = targetScreen {
            let screenFrame = screen.visibleFrame
            let windowWidth = window.frame.width
            let windowHeight = window.frame.height
            let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            let y = screenFrame.origin.y + (screenFrame.height - windowHeight) * 0.65
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
    }

    // MARK: - NSWindowDelegate

    public func windowDidResignKey(_ notification: Notification) {
        guard let window = self.window, window.isVisible else { return }
        window.orderOut(nil)
    }
}
