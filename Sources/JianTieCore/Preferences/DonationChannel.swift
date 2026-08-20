import Foundation

/// 打赏支付渠道枚举
public enum DonationChannel: String, CaseIterable, Identifiable {
    case wechat = "wechat"
    case alipay = "alipay"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wechat:
            return "微信支付"
        case .alipay:
            return "支付宝"
        }
    }

    public var subtitle: String {
        switch self {
        case .wechat:
            return "使用微信扫一扫打赏"
        case .alipay:
            return "使用支付宝扫一扫打赏"
        }
    }

    public var resourceBaseName: String {
        return "\(rawValue)_qr"
    }

    public var iconSystemName: String {
        switch self {
        case .wechat:
            return "bubble.left.and.bubble.right.fill"
        case .alipay:
            return "creditcard.fill"
        }
    }
}
