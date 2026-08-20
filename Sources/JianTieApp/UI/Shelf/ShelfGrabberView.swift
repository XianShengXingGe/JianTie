import SwiftUI
import JianTieCore

/// Shelf 顶部轻量拖拽手柄条，提供视觉引导与拖拽手势
public struct ShelfGrabberView: View {
    public let isDragging: Bool
    public var onDragStart: (() -> Void)?
    public var onDragMove: (() -> Void)?
    public var onDragEnd: (() -> Void)?

    @State private var isHovering: Bool = false

    public init(
        isDragging: Bool = false,
        onDragStart: (() -> Void)? = nil,
        onDragMove: (() -> Void)? = nil,
        onDragEnd: (() -> Void)? = nil
    ) {
        self.isDragging = isDragging
        self.onDragStart = onDragStart
        self.onDragMove = onDragMove
        self.onDragEnd = onDragEnd
    }

    public var body: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(isHovering || isDragging ? Color.primary.opacity(0.4) : Color.primary.opacity(0.2))
                .frame(width: 34, height: 4)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
            Spacer()
        }
        .frame(height: 12)
        .contentShape(Rectangle())
        .help(L10n.tr("shelf.drag_handle_tooltip"))
        .onHover { hovering in
            self.isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { _ in
                    if !isDragging {
                        onDragStart?()
                    }
                    onDragMove?()
                }
                .onEnded { _ in
                    onDragEnd?()
                }
        )
    }
}
