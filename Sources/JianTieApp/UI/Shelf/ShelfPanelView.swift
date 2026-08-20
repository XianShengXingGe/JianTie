import SwiftUI
import JianTieCore

/// Shelf 暂存架主视图，支持空状态提示与多 Stack 垂直列表平滑滚动展示
public struct ShelfPanelView: View {
    @ObservedObject public var engine: ShelfEngine

    public init(engine: ShelfEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 8) {
            if engine.stacks.isEmpty {
                emptyStateView
            } else {
                multiStackScrollView
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Multi Stack Content

    private var multiStackScrollView: some View {
        VStack(spacing: 6) {
            // 当处于拖拽进入状态且已有 Stacks 时，在顶部给出轻量拖入提示
            if case .revealedDragging = engine.state {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    Text("松开以添加新 Stack")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .transition(.opacity)
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(engine.stacks) { stack in
                        ShelfDraggableStackView(
                            stack: stack,
                            onDiscard: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    engine.removeStack(id: stack.id)
                                }
                            },
                            onDragOutEnded: { success in
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    engine.handleStackDragOutCompleted(stackId: stack.id, success: success)
                                }
                            }
                        )
                        .frame(height: 52)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        Group {
            if case .revealedDragging = engine.state {
                // 拖拽文件进入时的放置提示
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)

                    Text("暂存至此")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 空 Shelf 悬停唤出时的极简占位
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    Text("暂存架为空")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
