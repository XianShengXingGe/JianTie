//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit
import ApplicationServices

/// 辅助功能权限提供协议
public protocol AccessibilityPermissionProviding: Sendable {
    var isTrusted: Bool { get }
    @discardableResult
    func promptForPermission() -> Bool
    func openSystemAccessibilitySettings()
}

/// 系统辅助功能权限服务
public final class AccessibilityPermissionService: AccessibilityPermissionProviding, @unchecked Sendable {
    public static let shared = AccessibilityPermissionService()

    private let isTrustedProvider: () -> Bool
    private let promptProvider: () -> Bool
    private let openSettingsHandler: () -> Void

    public init(
        isTrustedProvider: @escaping () -> Bool = {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        promptProvider: @escaping () -> Bool = {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        openSettingsHandler: @escaping () -> Void = {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    ) {
        self.isTrustedProvider = isTrustedProvider
        self.promptProvider = promptProvider
        self.openSettingsHandler = openSettingsHandler
    }

    public var isTrusted: Bool {
        isTrustedProvider()
    }

    @discardableResult
    public func promptForPermission() -> Bool {
        promptProvider()
    }

    public func openSystemAccessibilitySettings() {
        openSettingsHandler()
    }
}
