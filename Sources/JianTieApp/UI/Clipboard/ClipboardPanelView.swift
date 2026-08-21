//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import SwiftUI
import AppKit
import JianTieCore

/// 剪贴板历史浮层主视图
public struct ClipboardPanelView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject public var viewModel: ClipboardViewModel
    public let onSelectAndPaste: (ClipboardItem) -> Void

    @FocusState private var isSearchFocused: Bool

    public init(
        viewModel: ClipboardViewModel,
        onSelectAndPaste: @escaping (ClipboardItem) -> Void
    ) {
        self.viewModel = viewModel
        self.onSelectAndPaste = onSelectAndPaste
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchHeaderView
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            LiquidGlassDivider()

            listContentView
        }
        .frame(width: 580, height: 440)
        .liquidGlassPanel(cornerRadius: 16, material: .hudWindow)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: viewModel.presentationCount) { _ in
            isSearchFocused = true
        }
    }

    // MARK: - Search Header

    private var searchHeaderView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            TextField(L10n.tr("clipboard.search_placeholder"), text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 6) {
                keyBadge(L10n.tr("clipboard.shortcut_esc"))
                keyBadge(L10n.tr("clipboard.shortcut_navigate"))
                keyBadge(L10n.tr("clipboard.shortcut_paste"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlassInput(cornerRadius: 10)
    }

    private func keyBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .liquidGlassBadge(isCapsule: false, cornerRadius: 5)
    }

    // MARK: - List Content

    private var listContentView: some View {
        ScrollViewReader { proxy in
            if viewModel.filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemCardView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                onSelect: {
                                    onSelectAndPaste(item)
                                },
                                onDelete: {
                                    viewModel.deleteItem(id: item.id)
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: viewModel.selectedIndex) { _ in
                    if let selectedId = viewModel.selectedItem?.id {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(selectedId, anchor: nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: viewModel.searchText.isEmpty ? "tray" : "text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))

            Text(viewModel.searchText.isEmpty ? L10n.tr("clipboard.empty_state") : L10n.tr("clipboard.search_no_results", viewModel.searchText))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
