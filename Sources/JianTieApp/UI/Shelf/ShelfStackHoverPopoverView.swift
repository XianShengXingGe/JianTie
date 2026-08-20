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
                    .foregroundColor(.secondary)

                Spacer()

                Text(formattedTotalSize)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Divider()
                .background(Color.primary.opacity(0.08))

            // File items list
            ScrollView(.vertical, showsIndicators: stack.files.count > 4) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stack.files) { fileRef in
                        if let url = fileRef.resolveURL() {
                            fileRowView(fileRef: fileRef, url: url)
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 220)

            Divider()
                .background(Color.primary.opacity(0.08))

            // Footer / Hint
            HStack(spacing: 6) {
                Text("␣ Space")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .liquidGlassBadge(isCapsule: false, cornerRadius: 4)

                Text(L10n.tr("shelf.popover_hint"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
        .liquidGlassPanel(cornerRadius: 14, material: .popover)
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
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(fileRef.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                if fileRef.fileSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: fileRef.fileSize, countStyle: .file))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)

            if isRowHovered {
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
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .liquidGlassCard(cornerRadius: 6, isHovered: isRowHovered)
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
