//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import SwiftUI
import AppKit
import JianTieCore

/// 辅助功能授权引导 SwiftUI 视图
public struct AccessibilityGuidanceView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
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
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text(L10n.tr("accessibility.guidance_title"))
                    .font(.headline.weight(.semibold))

                Text(L10n.tr("accessibility.guidance_desc"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 12) {
                Button(L10n.tr("accessibility.button_later")) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button(L10n.tr("accessibility.button_open_settings")) {
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
        .liquidGlassPanel(cornerRadius: 18, material: .hudWindow)
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
        window.title = L10n.tr("accessibility.guidance_window_title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
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
