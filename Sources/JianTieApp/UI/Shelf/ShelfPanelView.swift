import SwiftUI
import JianTieCore

/// Shelf 暂存架主视图，支持空状态提示、多 Stack 列表展示与底部动态 Action Zone
public struct ShelfPanelView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject public var engine: ShelfEngine
    public var onPanelDragStart: (() -> Void)?
    public var onPanelDragMove: (() -> Void)?
    public var onPanelDragEnd: (() -> Void)?

    public init(
        engine: ShelfEngine,
        onPanelDragStart: (() -> Void)? = nil,
        onPanelDragMove: (() -> Void)? = nil,
        onPanelDragEnd: (() -> Void)? = nil
    ) {
        self.engine = engine
        self.onPanelDragStart = onPanelDragStart
        self.onPanelDragMove = onPanelDragMove
        self.onPanelDragEnd = onPanelDragEnd
    }

    public var body: some View {
        VStack(spacing: 6) {
            // 顶部专属拖拽手柄条
            ShelfGrabberView(
                isDragging: engine.isPanelDragging,
                onDragStart: onPanelDragStart,
                onDragMove: onPanelDragMove,
                onDragEnd: onPanelDragEnd
            )

            if engine.stacks.isEmpty {
                emptyStateView
            } else {
                multiStackScrollView
            }

            // 仅在拖拽活动中动态附着展示于 Shelf 列表正下方
            if engine.isActionZoneVisible {
                ShelfActionZoneView(engine: engine)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPanel(cornerRadius: 16, material: .hudWindow)
        .opacity(engine.isPanelDragging ? 0.92 : 1.0)
        .shadow(
            color: Color.black.opacity(engine.isPanelDragging ? 0.35 : 0.12),
            radius: engine.isPanelDragging ? 22 : 8,
            x: 0,
            y: engine.isPanelDragging ? 8 : 2
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: engine.isActionZoneVisible)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: engine.isPanelDragging)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { _ in
                    if !engine.isPanelDragging && !engine.isStackDragging {
                        onPanelDragStart?()
                    }
                    if engine.isPanelDragging {
                        onPanelDragMove?()
                    }
                }
                .onEnded { _ in
                    if engine.isPanelDragging {
                        onPanelDragEnd?()
                    }
                }
        )
    }

    // MARK: - Multi Stack Content

    private var multiStackScrollView: some View {
        VStack(spacing: 6) {
            // 当处于拖拽进入状态且已有 Stacks 时，在顶部给出轻量拖入提示
            if case .revealedDragging = engine.state {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.tr("shelf.release_to_add_stack"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .liquidGlassBadge(isCapsule: true, tintColor: .accentColor)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(engine.stacks) { stack in
                        ShelfDraggableStackView(
                            stack: stack,
                            edge: engine.edge,
                            isDragging: engine.isStackDragging || engine.state.isDragging,
                            onDragStart: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    engine.notifyStackDragStarted(stack: stack)
                                }
                            },
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
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)

                    Text(L10n.tr("shelf.empty_drop_hint"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 空 Shelf 悬停唤出时的极简占位
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.8))

                    Text(L10n.tr("shelf.empty_state"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
