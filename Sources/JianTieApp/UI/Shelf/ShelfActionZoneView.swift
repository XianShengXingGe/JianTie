import SwiftUI
import UniformTypeIdentifiers
import JianTieCore

/// Shelf 底部快捷动作区视图（垂直堆叠：上方 AirDrop，下方 Copy Path）
public struct ShelfActionZoneView: View {
    @ObservedObject public var engine: ShelfEngine

    @State private var isAirDropTargeted: Bool = false
    @State private var isCopyPathTargeted: Bool = false

    public init(engine: ShelfEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 6) {
            airDropActionView
            copyPathActionView
        }
        .padding(.top, 4)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
    }

    // MARK: - AirDrop Action Card

    private var airDropActionView: some View {
        HStack(spacing: 6) {
            Image(systemName: "airdrop")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isAirDropTargeted ? .accentColor : .primary)

            Text("AirDrop")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isAirDropTargeted ? .accentColor : .primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAirDropTargeted ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isAirDropTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: isAirDropTargeted ? [] : [3, 3])
                )
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isAirDropTargeted) { providers in
            handleActionDrop(providers: providers) { urls, stackId in
                engine.handleAirDrop(urls: urls, sourceStackId: stackId)
            }
            return true
        }
    }

    // MARK: - Copy Path Action Card

    private var copyPathActionView: some View {
        HStack(spacing: 6) {
            if let feedback = engine.actionFeedback {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)

                Text(feedback)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isCopyPathTargeted ? .accentColor : .primary)

                Text("Copy Path")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isCopyPathTargeted ? .accentColor : .primary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    engine.actionFeedback != nil
                        ? Color.green.opacity(0.15)
                        : (isCopyPathTargeted ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    engine.actionFeedback != nil
                        ? Color.green.opacity(0.6)
                        : (isCopyPathTargeted ? Color.accentColor : Color.primary.opacity(0.12)),
                    style: StrokeStyle(lineWidth: 1, dash: (isCopyPathTargeted || engine.actionFeedback != nil) ? [] : [3, 3])
                )
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isCopyPathTargeted) { providers in
            handleActionDrop(providers: providers) { urls, stackId in
                engine.handleCopyPath(urls: urls, sourceStackId: stackId)
            }
            return true
        }
    }

    // MARK: - Drop Handling

    private func handleActionDrop(
        providers: [NSItemProvider],
        action: @escaping @MainActor ([URL], UUID?) -> Void
    ) {
        extractURLs(from: providers) { urls in
            let effectiveURLs = !urls.isEmpty ? urls : (engine.activeDraggingStack?.resolvedURLs ?? [])
            guard !effectiveURLs.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                action(effectiveURLs, engine.activeDraggingStack?.id)
            }
        }
    }

    private func extractURLs(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        let group = DispatchGroup()
        var extractedURLs: [URL] = []
        let lock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        lock.lock()
                        extractedURLs.append(url)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(extractedURLs)
        }
    }
}
