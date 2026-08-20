import SwiftUI
import AppKit
import JianTieCore

/// 辅助功能授权引导 SwiftUI 视图
public struct AccessibilityGuidanceView: View {
    public let permissionService: AccessibilityPermissionProviding
    public let onDismiss: () -> Void

    public init(
        permissionService: AccessibilityPermissionProviding = AccessibilityPermissionService.shared,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.permissionService = permissionService
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("简贴 需要辅助功能权限")
                    .font(.headline)

                Text("为了支持直接回贴（Direct Paste）将内容快速粘贴到目标应用，简贴需要系统「辅助功能」权限。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 12) {
                Button("稍后再说") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button("前往系统设置授权") {
                    permissionService.promptForPermission()
                    permissionService.openSystemAccessibilitySettings()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

/// 辅助功能引导非模态窗口控制器
@MainActor
public final class AccessibilityGuidanceWindowController: NSWindowController {
    public static let shared = AccessibilityGuidanceWindowController()

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 240),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "简贴 权限引导"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        super.init(window: window)

        let rootView = AccessibilityGuidanceView(
            onDismiss: { [weak self] in
                self?.window?.orderOut(nil)
            }
        )
        window.contentView = NSHostingView(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showWindow() {
        guard let window = self.window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
