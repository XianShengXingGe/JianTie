import SwiftUI
import AppKit
import JianTieCore

public extension SocialLinkItem {
    var accentColor: Color {
        switch id {
        case "xiaohongshu":
            return Color(red: 0.95, green: 0.18, blue: 0.26)
        case "weibo":
            return Color(red: 0.94, green: 0.40, blue: 0.12)
        case "email":
            return Color(red: 0.18, green: 0.54, blue: 0.96)
        default:
            return Color.accentColor
        }
    }
}

/// 社交渠道交互项视图
public struct SocialLinkRow: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    public let item: SocialLinkItem
    @State private var isCopied: Bool = false
    @State private var isHovered: Bool = false

    public init(item: SocialLinkItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 图标与平台名称
            HStack(spacing: 8) {
                Image(systemName: item.iconSystemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.accentColor)
                    .frame(width: 18, height: 18)

                Text(item.localizedPlatform)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary.opacity(0.85))

                Text(item.displayText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            // 直达链接按钮
            if let url = item.openURL {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                        Text(L10n.tr("social.open"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .liquidGlassBadge(isCapsule: true)
                }
                .buttonStyle(.plain)
                .help(L10n.tr("social.open_help", item.localizedPlatform))
            }

            // 一键复制按钮
            Button(action: copyToClipboard) {
                HStack(spacing: 3) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: isCopied ? .bold : .regular))
                    Text(isCopied ? L10n.tr("social.copied") : L10n.tr("social.copy"))
                        .font(.system(size: 11, weight: isCopied ? .bold : .medium))
                }
                .foregroundColor(isCopied ? .green : .primary.opacity(0.75))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .liquidGlassBadge(isCapsule: true, tintColor: isCopied ? .green : nil)
            }
            .buttonStyle(.plain)
            .help(isCopied ? L10n.tr("social.copied_help") : L10n.tr("social.copy_help", item.copyValue))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .liquidGlassCard(cornerRadius: 8, isHovered: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.copyValue, forType: .string)

        withAnimation(.easeInOut(duration: 0.15)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}
