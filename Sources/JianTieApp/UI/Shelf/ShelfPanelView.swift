import SwiftUI
import JianTieCore

/// Shelf 暂存架主视图
public struct ShelfPanelView: View {
    @ObservedObject public var engine: ShelfEngine

    public init(engine: ShelfEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 12) {
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
        .padding(12)
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
}
