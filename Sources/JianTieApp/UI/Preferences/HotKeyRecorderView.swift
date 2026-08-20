import SwiftUI
import AppKit
import JianTieCore

/// Liquid Glass 风格的全局快捷键交互录制与预设切换组件
public struct HotKeyRecorderView: View {
    @ObservedObject public var viewModel: HotKeyRecorderViewModel
    @State private var isHovered: Bool = false
    @State private var isPulsing: Bool = false
    @State private var shakeOffset: CGFloat = 0

    public init(viewModel: HotKeyRecorderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                // 1. 录制状态/当前快捷键展示胶囊
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleRecording()
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                                .scaleEffect(isPulsing ? 1.25 : 0.85)
                                .opacity(isPulsing ? 1.0 : 0.5)

                            Text("请按下快捷键...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: iconName(for: viewModel.currentTrigger))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                            Text(viewModel.currentTrigger.displayTitle)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .liquidGlassBadge(
                        isCapsule: true,
                        tintColor: viewModel.isRecording ? Color.accentColor : (isHovered ? Color.primary.opacity(0.15) : nil)
                    )
                }
                .buttonStyle(.plain)
                .offset(x: shakeOffset)
                .onHover { hovering in
                    isHovered = hovering
                }
                .help(viewModel.isRecording ? "请直接在键盘上按下组合键 (Esc 取消, Delete 恢复默认)" : "点击录制新快捷键")
                .onChange(of: viewModel.isRecording) { recording in
                    if recording {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    } else {
                        isPulsing = false
                    }
                }
                .onChange(of: viewModel.shakeTrigger) { _ in
                    triggerShakeAnimation()
                }

                // 2. 快捷重置按钮 (仅在非默认快捷键时展示)
                if !viewModel.isDefaultHotKey && !viewModel.isRecording {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.resetToDefault()
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("恢复为默认快捷键 (双击 ⌘)")
                    .transition(.scale.combined(with: .opacity))
                }

                // 3. 预设修饰键与快捷选项下拉菜单
                Menu {
                    Section("常用双击修饰键") {
                        ForEach(ModifierKey.allCases, id: \.self) { modifier in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    viewModel.selectDoubleTapModifier(modifier)
                                }
                            }) {
                                if case .doubleTap(let activeMod) = viewModel.currentTrigger, activeMod == modifier {
                                    Label(modifier.localizedName, systemImage: "checkmark")
                                } else {
                                    Text(modifier.localizedName)
                                }
                            }
                        }
                    }

                    Divider()

                    Button("录制自定义快捷键...") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.startRecording()
                        }
                    }

                    Button("恢复默认快捷键 (双击 ⌘)") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.resetToDefault()
                        }
                    }
                    .disabled(viewModel.isDefaultHotKey)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("快捷键选项与双击预设")
            }

            // 4. 校验错误提示条
            if let errorMsg = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)

                    Text(errorMsg)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onDisappear {
            viewModel.stopRecording()
        }
    }

    private func triggerShakeAnimation() {
        withAnimation(.easeInOut(duration: 0.06)) {
            shakeOffset = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeInOut(duration: 0.06)) {
                shakeOffset = 6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.06)) {
                shakeOffset = -4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.06)) {
                shakeOffset = 0
            }
        }
    }

    private func iconName(for trigger: HotKeyTrigger) -> String {
        switch trigger {
        case .doubleTap:
            return "hand.tap.fill"
        case .keyCombination:
            return "command"
        }
    }
}
