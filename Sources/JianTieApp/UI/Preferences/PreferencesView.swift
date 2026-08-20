import SwiftUI
import AppKit
import JianTieCore

/// 偏好设置 SwiftUI 主视图
public struct PreferencesView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
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
            // Window Title & Drag Bar (macOS standard: Close button on top-left)
            HStack(spacing: 10) {
                Button(action: {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        NSApp.keyWindow?.orderOut(nil)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .padding(4)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("preferences.close_tooltip"))

                Text(L10n.tr("preferences.window_title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()
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
                        Text(L10n.tr("preferences.app_name"))
                            .font(.title3.weight(.bold))

                        Button(action: {
                            viewModel.openLatestRelease()
                        }) {
                            HStack(spacing: 3) {
                                Text(viewModel.appVersionText)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .liquidGlassBadge(isCapsule: true)
                        }
                        .buttonStyle(.plain)
                        .help("查看最新 Release 版本 (GitHub)")
                    }

                    Text(L10n.tr("preferences.app_tagline"))
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
                        sectionLabel(title: L10n.tr("preferences.section.general"), icon: "gearshape")

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr("preferences.launch_at_login"))
                                        .font(.body)
                                    Text(L10n.tr("preferences.launch_at_login_desc"))
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
                                    Text(L10n.tr("preferences.language"))
                                        .font(.body)
                                    Text(L10n.tr("preferences.language_desc"))
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
                        sectionLabel(title: L10n.tr("preferences.section.shelf"), icon: "sidebar.squares.left")

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 16) {
                                Text(L10n.tr("preferences.shelf_edge"))
                                    .font(.body)

                                Spacer()

                                Picker("", selection: Binding(
                                    get: { viewModel.shelfEdge },
                                    set: { viewModel.setShelfEdge($0) }
                                )) {
                                    Text(L10n.tr("preferences.shelf_edge_left")).tag(ShelfEdge.left)
                                    Text(L10n.tr("preferences.shelf_edge_right")).tag(ShelfEdge.right)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 170)
                            }

                            Text(L10n.tr("preferences.shelf_desc"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .liquidGlassSection(cornerRadius: 12)
                    }

                    // Section 2: Clipboard
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(title: L10n.tr("preferences.section.clipboard"), icon: "clock.arrow.circlepath")

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr("preferences.hotkey"))
                                        .font(.body)
                                    Text(L10n.tr("preferences.hotkey_desc"))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                HotKeyRecorderView(viewModel: hotKeyRecorderViewModel)
                            }

                            Divider()
                                .background(Color.primary.opacity(0.06))

                            HStack(alignment: .center) {
                                Text(L10n.tr("preferences.capacity_limit"))
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
                                Text(L10n.tr("preferences.retention_period"))
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
                                    Text(L10n.tr("preferences.clear_history"))
                                        .font(.body)
                                    Text(L10n.tr("preferences.clear_history_desc"))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive, action: {
                                    viewModel.showClearConfirmationAlert = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text(L10n.tr("preferences.clear_history_button"))
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
                        sectionLabel(title: L10n.tr("preferences.section.permissions"), icon: "lock.shield")

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr("preferences.accessibility"))
                                        .font(.body.weight(.medium))
                                    Text(L10n.tr("preferences.accessibility_desc"))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if viewModel.isAccessibilityTrusted {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(L10n.tr("preferences.authorized"))
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
                                            Text(L10n.tr("preferences.grant_permission"))
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
                        sectionLabel(title: L10n.tr("preferences.section.support"), icon: "heart.circle")

                        VStack(alignment: .leading, spacing: 12) {
                            // 打赏开发者引导栏
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13))
                                        Text(L10n.tr("preferences.support_dev"))
                                            .font(.body.weight(.medium))
                                    }
                                    Text(L10n.tr("preferences.support_dev_desc"))
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
                                        Text(L10n.tr("preferences.donate_button"))
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .liquidGlassBadge(isCapsule: true, tintColor: .pink)
                                }
                                .buttonStyle(.plain)
                                .help(L10n.tr("preferences.donate_tooltip"))
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
        .alert(L10n.tr("preferences.clear_alert_title"), isPresented: $viewModel.showClearConfirmationAlert) {
            Button(L10n.tr("preferences.clear_alert_confirm"), role: .destructive) {
                viewModel.confirmClearClipboardHistory()
            }
            Button(L10n.tr("preferences.clear_alert_cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("preferences.clear_alert_message"))
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
