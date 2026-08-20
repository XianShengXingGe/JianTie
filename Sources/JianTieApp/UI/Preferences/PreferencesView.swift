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
                Image(systemName: "paperclip.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("简贴")
                            .font(.title2.weight(.bold))
                        Text(viewModel.appVersionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("轻量、极简的 macOS 文件暂存与剪贴板工具")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Settings Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Section 1: Shelf
                    GroupBox(label: sectionLabel(title: "暂存架 (Shelf)", icon: "sidebar.squares.left")) {
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
                        .padding(8)
                    }

                    // Section 2: Clipboard
                    GroupBox(label: sectionLabel(title: "剪贴板历史 (Clipboard)", icon: "clock.arrow.circlepath")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("全局唤出快捷键")
                                    .font(.body)
                                Spacer()
                                Text("双击 ⌘ Command")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(6)
                            }

                            Divider()

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
                        .padding(8)
                    }

                    // Section 3: Permissions
                    GroupBox(label: sectionLabel(title: "系统权限 (Permissions)", icon: "lock.shield")) {
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
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("已授权")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.green)
                                    }
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
                        .padding(8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 480, height: 420)
        .onAppear {
            viewModel.refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshAccessibilityStatus()
        }
    }

    private func sectionLabel(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.bottom, 2)
    }
}
