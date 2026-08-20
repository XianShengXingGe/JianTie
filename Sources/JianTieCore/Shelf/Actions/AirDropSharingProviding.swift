import Foundation
import AppKit

/// AirDrop 系统分享服务协议，解耦具体 AppKit 实现以支持无头单元测试
@MainActor
public protocol AirDropSharingProviding: AnyObject, Sendable {
    /// 执行 AirDrop 分享
    /// - Parameters:
    ///   - urls: 需要分享的文件 URL 列表
    ///   - onCompletion: 分享完成回调（true 表示成功分享，false 表示取消或失败）
    func performAirDrop(urls: [URL], onCompletion: @escaping @MainActor (Bool) -> Void)
}

/// 基于 AppKit NSSharingService 的原生 AirDrop 分享服务实现
@MainActor
public final class SystemAirDropService: NSObject, AirDropSharingProviding, NSSharingServiceDelegate, @unchecked Sendable {
    private var completionHandler: (@MainActor (Bool) -> Void)?
    private var activeService: NSSharingService?

    public override init() {
        super.init()
    }

    public func performAirDrop(urls: [URL], onCompletion: @escaping @MainActor (Bool) -> Void) {
        guard !urls.isEmpty else {
            onCompletion(false)
            return
        }

        guard let airDropService = NSSharingService(named: .sendViaAirDrop) else {
            onCompletion(false)
            return
        }

        self.completionHandler = onCompletion
        airDropService.delegate = self
        self.activeService = airDropService

        if airDropService.canPerform(withItems: urls) {
            airDropService.perform(withItems: urls)
        } else {
            self.completionHandler = nil
            self.activeService = nil
            onCompletion(false)
        }
    }

    // MARK: - NSSharingServiceDelegate

    nonisolated public func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        Task { @MainActor in
            let handler = self.completionHandler
            self.completionHandler = nil
            self.activeService = nil
            handler?(true)
        }
    }

    nonisolated public func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        Task { @MainActor in
            let handler = self.completionHandler
            self.completionHandler = nil
            self.activeService = nil
            handler?(false)
        }
    }
}
