//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import SwiftUI
import AppKit
import JianTieCore

/// Shelf 卡片悬停展开的富信息浮层，展示 Stack 内全部文件的全名、体积与快捷预览入口
public struct ShelfStackHoverPopoverView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    public let stack: ShelfStack
    public let onPreviewSingleFile: (URL) -> Void

    @State private var hoveredFileURL: URL?

    public init(stack: ShelfStack, onPreviewSingleFile: @escaping (URL) -> Void = { _ in }) {
        self.stack = stack
        self.onPreviewSingleFile = onPreviewSingleFile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(stack.count > 1 ? L10n.tr("shelf.popover_contains_files", stack.count) : L10n.tr("shelf.popover_file_details"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))

                Spacer()

                Text(formattedTotalSize)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            LiquidGlassDivider()

            // File items list (≤ 5 个文件自适应完整展示，超过 5 个才启用滚动翻页)
            Group {
                if stack.files.count <= 5 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(stack.files) { fileRef in
                            if let url = fileRef.resolveURL() {
                                fileRowView(fileRef: fileRef, url: url)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(stack.files) { fileRef in
                                if let url = fileRef.resolveURL() {
                                    fileRowView(fileRef: fileRef, url: url)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }
                }
            }

            LiquidGlassDivider()

            // Footer / Hint
            HStack(spacing: 6) {
                Text("␣ Space")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .liquidGlassBadge(isCapsule: false, cornerRadius: 5)

                Text(L10n.tr("shelf.popover_hint"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .liquidGlassPanel(cornerRadius: 16, material: .hudWindow)
        .onHover { isInside in
            if isInside {
                ShelfHoverPopoverController.shared.notifyMouseEnteredPopover()
            } else {
                ShelfHoverPopoverController.shared.notifyMouseExitedPopover()
            }
        }
    }

    @ViewBuilder
    private func fileRowView(fileRef: ShelfFileReference, url: URL) -> some View {
        let isRowHovered = hoveredFileURL == url

        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(fileRef.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                if fileRef.fileSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: fileRef.fileSize, countStyle: .file))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 4)

            // 固定占位预览按钮，仅在悬停时平滑淡入，保证宽度绝对恒定，彻底避免文件名折行与高度跳变
            Button(action: {
                onPreviewSingleFile(url)
            }) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .padding(4)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("shelf.popover_preview_help"))
            .opacity(isRowHovered ? 1.0 : 0.0)
            .allowsHitTesting(isRowHovered)
            .animation(.easeInOut(duration: 0.12), value: isRowHovered)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .liquidGlassCard(cornerRadius: 10, isHovered: isRowHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredFileURL = hovering ? url : nil
            if hovering {
                ShelfQuickLookController.shared.startHoverKeyMonitoring {
                    [url]
                }
            } else {
                ShelfQuickLookController.shared.startHoverKeyMonitoring {
                    self.stack.resolvedURLs
                }
            }
        }
    }

    private var formattedTotalSize: String {
        guard stack.totalSize > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: stack.totalSize, countStyle: .file)
    }
}
