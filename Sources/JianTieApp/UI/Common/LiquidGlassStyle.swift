//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import SwiftUI
import AppKit

/// macOS 毛玻璃材质背景辅助视图
public struct VisualEffectBackground: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public let cornerRadius: CGFloat

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        cornerRadius: CGFloat = 0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// 支持在 SwiftUI 区域中通过鼠标按下拖拽当前所属 NSWindow 的辅助视图
public struct WindowDragGestureView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DraggingNSView {
        DraggingNSView()
    }

    public func updateNSView(_ nsView: DraggingNSView, context: Context) {}

    public final class DraggingNSView: NSView {
        public override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// Apple Liquid Glass 风格主面板背景与高光边框修饰器
public struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public var cornerRadius: CGFloat
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(
        cornerRadius: CGFloat = 16,
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.blendingMode = blendingMode
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectBackground(material: material, blendingMode: blendingMode, cornerRadius: cornerRadius)

                    // 拟态玻璃内部折射微光晕
                    LinearGradient(
                        colors: innerGlowColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(specularBorderGradient, lineWidth: 1)
            )
    }

    private var innerGlowColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.12),
                Color.white.opacity(0.03),
                Color.clear
            ]
        } else {
            return [
                Color.white.opacity(0.40),
                Color.white.opacity(0.10),
                Color.clear
            ]
        }
    }

    private var specularBorderGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.35), location: 0.0),
                    .init(color: Color.white.opacity(0.12), location: 0.35),
                    .init(color: Color.white.opacity(0.04), location: 0.70),
                    .init(color: Color.white.opacity(0.08), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.75), location: 0.0),
                    .init(color: Color.white.opacity(0.25), location: 0.35),
                    .init(color: Color.white.opacity(0.05), location: 0.70),
                    .init(color: Color.white.opacity(0.15), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// Liquid Glass 风格卡片/列表项修饰器
public struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public var cornerRadius: CGFloat
    public var isSelected: Bool
    public var isHovered: Bool
    public var isTargeted: Bool
    public var tintColor: Color?

    public init(
        cornerRadius: CGFloat = 10,
        isSelected: Bool = false,
        isHovered: Bool = false,
        isTargeted: Bool = false,
        tintColor: Color? = nil
    ) {
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isTargeted = isTargeted
        self.tintColor = tintColor
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: (isSelected || isTargeted) ? 1.5 : 1)
            )
    }

    private var effectiveAccent: Color {
        tintColor ?? Color.accentColor
    }

    private var backgroundColor: Color {
        if isSelected || isTargeted {
            return effectiveAccent.opacity(colorScheme == .dark ? 0.22 : 0.14)
        } else if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
        } else {
            return Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.02)
        }
    }

    private var borderColor: LinearGradient {
        if isSelected || isTargeted {
            return LinearGradient(
                colors: [
                    effectiveAccent.opacity(0.9),
                    effectiveAccent.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isHovered {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [Color.white.opacity(0.40), Color.primary.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color.white.opacity(0.9), Color.primary.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [Color.white.opacity(0.20), Color.primary.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color.white.opacity(0.6), Color.primary.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

/// Liquid Glass 胶囊/微型徽章修饰器
public struct LiquidGlassBadgeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var isCapsule: Bool
    public var cornerRadius: CGFloat
    public var tintColor: Color?

    public init(isCapsule: Bool = true, cornerRadius: CGFloat = 6, tintColor: Color? = nil) {
        self.isCapsule = isCapsule
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
    }

    public func body(content: Content) -> some View {
        Group {
            if isCapsule {
                content
                    .background(
                        Capsule(style: .continuous)
                            .fill(badgeBackground)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(badgeBorder, lineWidth: 0.8)
                    )
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(badgeBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(badgeBorder, lineWidth: 0.8)
                    )
            }
        }
    }

    private var badgeBackground: Color {
        if let tint = tintColor {
            return tint.opacity(colorScheme == .dark ? 0.22 : 0.15)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
    }

    private var badgeBorder: LinearGradient {
        if let tint = tintColor {
            return LinearGradient(
                colors: [tint.opacity(0.6), tint.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        let topColor = colorScheme == .dark ? Color.white.opacity(0.3) : Color.white.opacity(0.8)
        let bottomColor = Color.primary.opacity(0.08)
        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Liquid Glass 输入框与搜索栏修饰器
public struct LiquidGlassInputModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.20) : Color.white.opacity(0.70), location: 0.0),
                                .init(color: Color.primary.opacity(0.08), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// Liquid Glass 分组卡片修饰器（偏好设置与表单区块）
public struct LiquidGlassSectionModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.65), location: 0.0),
                                .init(color: Color.primary.opacity(0.08), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// Liquid Glass 风格高光分割线组件
public struct LiquidGlassDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.70), location: 0.0),
                        .init(color: Color.primary.opacity(0.06), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

public extension View {
    func liquidGlassPanel(
        cornerRadius: CGFloat = 16,
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) -> some View {
        modifier(LiquidGlassPanelModifier(cornerRadius: cornerRadius, material: material, blendingMode: blendingMode))
    }

    func liquidGlassCard(
        cornerRadius: CGFloat = 10,
        isSelected: Bool = false,
        isHovered: Bool = false,
        isTargeted: Bool = false,
        tintColor: Color? = nil
    ) -> some View {
        modifier(LiquidGlassCardModifier(
            cornerRadius: cornerRadius,
            isSelected: isSelected,
            isHovered: isHovered,
            isTargeted: isTargeted,
            tintColor: tintColor
        ))
    }

    func liquidGlassBadge(
        isCapsule: Bool = true,
        cornerRadius: CGFloat = 6,
        tintColor: Color? = nil
    ) -> some View {
        modifier(LiquidGlassBadgeModifier(isCapsule: isCapsule, cornerRadius: cornerRadius, tintColor: tintColor))
    }

    func liquidGlassInput(cornerRadius: CGFloat = 10) -> some View {
        modifier(LiquidGlassInputModifier(cornerRadius: cornerRadius))
    }

    func liquidGlassSection(cornerRadius: CGFloat = 12) -> some View {
        modifier(LiquidGlassSectionModifier(cornerRadius: cornerRadius))
    }

    func liquidGlassDivider() -> some View {
        self.background(
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.18), location: 0.0),
                    .init(color: Color.primary.opacity(0.06), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    func windowDraggable() -> some View {
        self.background(WindowDragGestureView())
    }
}
