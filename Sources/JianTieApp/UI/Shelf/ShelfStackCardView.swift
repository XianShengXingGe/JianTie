import SwiftUI
import AppKit
import JianTieCore

/// 单个 Stack 暂存卡片视图
public struct ShelfStackCardView: View {
    public let stack: ShelfStack
    public let isDragging: Bool
    public let onDiscard: () -> Void

    @State private var isHovered: Bool = false

    public init(stack: ShelfStack, isDragging: Bool = false, onDiscard: @escaping () -> Void) {
        self.stack = stack
        self.isDragging = isDragging
        self.onDiscard = onDiscard
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 10) {
                // 文件主图标 / 多文件层叠指示
                ZStack(alignment: .bottomTrailing) {
                    fileIconView
                        .frame(width: 32, height: 32)

                    if stack.count > 1 {
                        Text("\(stack.count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .liquidGlassBadge(isCapsule: true, tintColor: .accentColor)
                            .offset(x: 4, y: 4)
                    }
                }

                // 文件名称与体积信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(stack.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(formattedFileSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidGlassCard(cornerRadius: 10, isHovered: isHovered)

            // 左上角悬停展示的微型 ✕ 丢弃按钮（仅在非拖拽状态下浮现）
            if isHovered && !isDragging {
                Button(action: onDiscard) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.secondary)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .padding(3)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    private var fileIconView: some View {
        Group {
            if let firstRef = stack.files.first, let url = firstRef.resolveURL() {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: stack.count > 1 ? "doc.on.doc.fill" : "doc.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.accentColor)
            }
        }
    }

    private var formattedFileSize: String {
        guard stack.totalSize > 0 else {
            return stack.count > 1 ? "\(stack.count) 个文件" : "文件"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: stack.totalSize)
        if stack.count > 1 {
            return "\(stack.count) 个文件 · \(sizeStr)"
        }
        return sizeStr
    }
}
