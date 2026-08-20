import SwiftUI
import AppKit
import JianTieCore

/// 偏好设置 SwiftUI 主视图
public struct PreferencesView: View {
    @ObservedObject public var viewModel: PreferencesViewModel
    public var onClose: (() -> Void)?
    @State private var showDonationModal: Bool = false
    @StateObject private var hotKeyRecorderViewModel: HotKeyRecorderViewModel

    public init(viewModel: PreferencesViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
        self._hotKeyRecorderViewModel = StateObject(wrappedValue: HotKeyRecorderViewModel(preferencesViewModel: viewModel))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Window Title & Drag Bar
            HStack {
                Text("偏好设置")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        NSApp.keyWindow?.orderOut(nil)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("关闭设置窗口 (ESC)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .windowDraggable()

            // Header / App Info
            HStack(spacing: 16) {
                if let appIcon = AppIconProvider.loadAppIcon() {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: "tray.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("简贴")
                            .font(.title3.weight(.bold))
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
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .windowDraggable()

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
                    // Section 0: General
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "通用设置 (General)", icon: "gearshape")

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("开机自启 (随系统启动)")
                                        .font(.body)
                                    Text("登录 macOS 系统时自动在后台启动简贴并常驻菜单栏。")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { viewModel.launchAtLogin },
                                    set: { viewModel.setLaunchAtLogin($0) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }

                            Divider()
                                .background(Color.primary.opacity(0.06))

                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("界面语言 (Language)")
                                        .font(.body)
                                    Text("更改界面语言后将实时应用至所有窗口与菜单栏，无需重启应用。")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Picker("", selection: Binding(
                                    get: { viewModel.appLanguage },
                                    set: { viewModel.setAppLanguage($0) }
                                )) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 170)
                            }
                        }
                        .padding(14)
                        .liquidGlassSection(cornerRadius: 12)
                    }

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
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("全局唤出快捷键")
                                        .font(.body)
                                    Text("支持点击录制或选择双击修饰键")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                HotKeyRecorderView(viewModel: hotKeyRecorderViewModel)
                            }

                            Divider()
                                .background(Color.primary.opacity(0.06))

                            HStack(alignment: .center) {
                                Text("历史容量上限")
                                    .font(.body)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { viewModel.clipboardCapacityLimit },
                                    set: { viewModel.setClipboardCapacityLimit($0) }
                                )) {
                                    ForEach(ClipboardCapacityLimit.allCases) { limit in
                                        Text(limit.title).tag(limit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }

                            HStack(alignment: .center) {
                                Text("保存过期周期")
                                    .font(.body)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { viewModel.clipboardRetentionPeriod },
                                    set: { viewModel.setClipboardRetentionPeriod($0) }
                                )) {
                                    ForEach(ClipboardRetentionPeriod.allCases) { period in
                                        Text(period.title).tag(period)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }

                            Text(viewModel.clipboardRetentionDescription)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()
                                .background(Color.primary.opacity(0.06))

                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("清空历史记录")
                                        .font(.body)
                                    Text("完全清除所有剪贴板记录与本地图片缓存")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive, action: {
                                    viewModel.showClearConfirmationAlert = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("清空剪贴板内容")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
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

                    // Section 4: Support & Community
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: "支持与互动 (Support & Community)", icon: "heart.circle")

                        VStack(alignment: .leading, spacing: 12) {
                            // 打赏开发者引导栏
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13))
                                        Text("支持独立开发")
                                            .font(.body.weight(.medium))
                                    }
                                    Text("简贴为独立开发开源项目，期待你的鼓励与支持")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        showDonationModal = true
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.pink)
                                            .font(.system(size: 11))
                                        Text("打赏开发者")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .liquidGlassBadge(isCapsule: true, tintColor: .pink)
                                }
                                .buttonStyle(.plain)
                                .help("打开打赏支持二维码弹窗")
                            }

                            Divider()
                                .background(Color.primary.opacity(0.06))

                            // 社交与合作渠道列表
                            VStack(spacing: 6) {
                                ForEach(SocialLinkItem.standardItems) { item in
                                    SocialLinkRow(item: item)
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
        .frame(width: 480, height: 600)
        .liquidGlassPanel(cornerRadius: 18, material: .hudWindow)
        .overlay {
            if showDonationModal {
                DonationModalView(isPresented: $showDonationModal)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: showDonationModal)
        .alert("确定要清空所有剪贴板历史吗？", isPresented: $viewModel.showClearConfirmationAlert) {
            Button("清空全部记录", role: .destructive) {
                viewModel.confirmClearClipboardHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将完全清除内存与磁盘中的所有剪贴板历史记录及图片缓存，且不可撤销。")
        }
        .onAppear {
            viewModel.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshStatus()
        }
    }

    private func sectionLabel(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary.opacity(0.9))
            .padding(.leading, 2)
    }
}
