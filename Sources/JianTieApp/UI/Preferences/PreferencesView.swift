import SwiftUI
import AppKit
import JianTieCore

/// 偏好设置 SwiftUI 主视图
public struct PreferencesView: View {
    @ObservedObject public var viewModel: PreferencesViewModel

    public init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header / App Info
            HStack(spacing: 16) {
                if let appIcon = AppIconProvider.loadAppIcon() {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 48, height: 48)

                        Image(systemName: "tray.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("简贴")
                            .font(.title2.weight(.bold))
                        Text(viewModel.appVersionText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .liquidGlassBadge(isCapsule: true)
                    }

                    Text("轻量、极简的 macOS 文件暂存与剪贴板工具")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.primary.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Settings Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Section 1: Shelf
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "暂存架 (Shelf)", icon: "sidebar.squares.left")

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 16) {
                                Text("屏幕停靠边缘")
                                    .font(.body)

                                Spacer()

                                Picker("", selection: Binding(
                                    get: { viewModel.shelfEdge },
                                    set: { viewModel.setShelfEdge($0) }
                                )) {
                                    Text("屏幕左侧").tag(ShelfEdge.left)
                                    Text("屏幕右侧").tag(ShelfEdge.right)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 170)
                            }

                            Text("文件拖拽至屏幕边缘或鼠标贴边悬停 150ms 时滑出暂存架，设置变更实时生效。")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .liquidGlassSection(cornerRadius: 12)
                    }

                    // Section 2: Clipboard
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "剪贴板历史 (Clipboard)", icon: "clock.arrow.circlepath")

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("全局唤出快捷键")
                                    .font(.body)
                                Spacer()
                                Text("双击 ⌘ Command")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .liquidGlassBadge(isCapsule: false, cornerRadius: 5)
                            }

                            Divider()
                                .background(Color.primary.opacity(0.06))

                            HStack(alignment: .top) {
                                Text("历史容量策略")
                                    .font(.body)
                                Spacer()
                                Text("最多 1000 条 (FIFO 淘汰)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Text(viewModel.clipboardRetentionDescription)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .liquidGlassSection(cornerRadius: 12)
                    }

                    // Section 3: Permissions
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "系统权限 (Permissions)", icon: "lock.shield")

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("辅助功能 (Accessibility)")
                                        .font(.body.weight(.medium))
                                    Text("直接回贴 (Direct Paste) 依赖辅助功能权限模拟按键")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if viewModel.isAccessibilityTrusted {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("已授权")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .liquidGlassBadge(isCapsule: true, tintColor: .green)
                                } else {
                                    Button(action: {
                                        viewModel.openAccessibilitySettings()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text("前往授权")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(14)
                        .liquidGlassSection(cornerRadius: 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 480, height: 430)
        .liquidGlassPanel(cornerRadius: 18, material: .hudWindow)
        .onAppear {
            viewModel.refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshAccessibilityStatus()
        }
    }

    private func sectionLabel(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary.opacity(0.9))
            .padding(.leading, 2)
    }
}
