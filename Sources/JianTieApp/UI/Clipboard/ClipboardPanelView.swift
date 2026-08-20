import SwiftUI
import AppKit
import JianTieCore

/// 剪贴板历史浮层主视图
public struct ClipboardPanelView: View {
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

            Divider()
                .background(Color.primary.opacity(0.1))

            listContentView
        }
        .frame(width: 580, height: 440)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(12)
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Search Header

    private var searchHeaderView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            TextField("搜索剪贴板历史...", text: $viewModel.searchText)
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
                keyBadge("ESC 退出")
                keyBadge("↑↓ 切换")
                keyBadge("↵ 回贴")
            }
        }
    }

    private func keyBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
            )
    }

    // MARK: - List Content

    private var listContentView: some View {
        ScrollViewReader { proxy in
            if viewModel.filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
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

            Text(viewModel.searchText.isEmpty ? "暂无剪贴板历史记录" : "未找到匹配 \"\(viewModel.searchText)\" 的内容")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// macOS 毛玻璃材质背景辅助视图
public struct VisualEffectBackground: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
