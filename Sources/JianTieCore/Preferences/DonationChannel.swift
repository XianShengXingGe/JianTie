//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 打赏支付渠道枚举
public enum DonationChannel: String, CaseIterable, Identifiable {
    case wechat = "wechat"
    case alipay = "alipay"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wechat:
            return L10n.tr("donation.channel_wechat")
        case .alipay:
            return L10n.tr("donation.channel_alipay")
        }
    }

    public var subtitle: String {
        switch self {
        case .wechat:
            return L10n.tr("donation.channel_wechat_hint")
        case .alipay:
            return L10n.tr("donation.channel_alipay_hint")
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
