import Foundation

/// 开发者社交与合作渠道数据模型
public struct SocialLinkItem: Identifiable, Equatable {
    public let id: String
    public let platform: String
    public let displayText: String
    public let iconSystemName: String
    public let openURL: URL?
    public let copyValue: String

    public init(
        id: String,
        platform: String,
        displayText: String,
        iconSystemName: String,
        openURL: URL?,
        copyValue: String
    ) {
        self.id = id
        self.platform = platform
        self.displayText = displayText
        self.iconSystemName = iconSystemName
        self.openURL = openURL
        self.copyValue = copyValue
    }

    /// 预设官方互动平台列表
    public static let standardItems: [SocialLinkItem] = [
        SocialLinkItem(
            id: "xiaohongshu",
            platform: "小红书",
            displayText: "先声行歌",
            iconSystemName: "bookmark.circle.fill",
            openURL: URL(string: "https://www.xiaohongshu.com/search_result?keyword=%E5%85%88%E5%A3%B0%E8%A1%8C%E6%AD%8C"),
            copyValue: "先声行歌"
        ),
        SocialLinkItem(
            id: "weibo",
            platform: "微博",
            displayText: "@先声行歌",
            iconSystemName: "bubble.middle.bottom.fill",
            openURL: URL(string: "https://weibo.com/u/3207903867"),
            copyValue: "https://weibo.com/u/3207903867"
        ),
        SocialLinkItem(
            id: "email",
            platform: "合作邮箱",
            displayText: "xianshengxingge@163.com",
            iconSystemName: "envelope.circle.fill",
            openURL: URL(string: "mailto:xianshengxingge@163.com"),
            copyValue: "xianshengxingge@163.com"
        )
    ]
}
