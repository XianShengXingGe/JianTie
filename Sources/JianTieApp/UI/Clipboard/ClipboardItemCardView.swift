import SwiftUI
import AppKit
import JianTieCore

/// 剪贴板历史记录项卡片视图
public struct ClipboardItemCardView: View {
    public let item: ClipboardItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered: Bool = false

    public init(
        item: ClipboardItem,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            contentView
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 10, isSelected: isSelected, isHovered: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 6) {
            itemTypeIcon
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            Text(timeAgoFormatted(item.timestamp))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            badgesView

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(3)
                    .background(Circle().fill(Color.primary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("从历史中删除")
            .opacity(isHovered ? 1.0 : 0.0)
            .disabled(!isHovered)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .frame(height: 18)
    }

    @ViewBuilder
    private var itemTypeIcon: some View {
        switch item.content {
        case .text(let text):
            if text.rtfData != nil || text.htmlData != nil {
                Image(systemName: "doc.richtext")
            } else {
                Image(systemName: "doc.plaintext")
            }
        case .image:
            Image(systemName: "photo")
        }
    }

    @ViewBuilder
    private var badgesView: some View {
        switch item.content {
        case .text(let text):
            if text.rtfData != nil || text.htmlData != nil {
                badgeText("富文本")
            }
            badgeText("\(text.plainText.count) 字符")
        case .image(let image):
            badgeText(image.format.uppercased())
            if let nsImage = NSImage(data: image.imageData) {
                let width = Int(nsImage.size.width)
                let height = Int(nsImage.size.height)
                if width > 0 && height > 0 {
                    badgeText("\(width) × \(height)")
                }
            }
        }
    }

    private func badgeText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .liquidGlassBadge(isCapsule: true)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch item.content {
        case .text(let text):
            Text(text.plainText)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(4)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        case .image(let image):
            if let nsImage = NSImage(data: image.imageData) {
                HStack {
                    Spacer()
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.primary.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                Text("无法解析的图片数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func timeAgoFormatted(_ date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(max(1, interval / 60)) 分钟前"
        } else if interval < 86400 {
            return "\(interval / 3600) 小时前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}
