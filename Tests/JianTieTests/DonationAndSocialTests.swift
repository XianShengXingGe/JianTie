import XCTest
@testable import JianTieCore

final class DonationAndSocialTests: XCTestCase {

    func test_donationChannels_haveExpectedIdentifiersAndTitles() {
        let channels = DonationChannel.allCases
        XCTAssertEqual(channels.count, 2)

        let wechat = DonationChannel.wechat
        XCTAssertEqual(wechat.id, "wechat")
        XCTAssertEqual(wechat.title, "微信支付")
        XCTAssertEqual(wechat.resourceBaseName, "wechat_qr")
        XCTAssertFalse(wechat.subtitle.isEmpty)
        XCTAssertFalse(wechat.iconSystemName.isEmpty)

        let alipay = DonationChannel.alipay
        XCTAssertEqual(alipay.id, "alipay")
        XCTAssertEqual(alipay.title, "支付宝")
        XCTAssertEqual(alipay.resourceBaseName, "alipay_qr")
        XCTAssertFalse(alipay.subtitle.isEmpty)
        XCTAssertFalse(alipay.iconSystemName.isEmpty)
    }

    func test_socialLinkItems_standardList_containsExpectedEntries() {
        let items = SocialLinkItem.standardItems
        XCTAssertEqual(items.count, 3)

        // Xiaohongshu
        guard let xhs = items.first(where: { $0.id == "xiaohongshu" }) else {
            XCTFail("Missing xiaohongshu entry")
            return
        }
        XCTAssertEqual(xhs.platform, "小红书")
        XCTAssertEqual(xhs.displayText, "先声行歌")
        XCTAssertEqual(xhs.copyValue, "先声行歌")
        XCTAssertNotNil(xhs.openURL)
        XCTAssertTrue(xhs.openURL?.absoluteString.contains("xiaohongshu.com") == true)

        // Weibo
        guard let weibo = items.first(where: { $0.id == "weibo" }) else {
            XCTFail("Missing weibo entry")
            return
        }
        XCTAssertEqual(weibo.platform, "微博")
        XCTAssertEqual(weibo.displayText, "@先声行歌")
        XCTAssertEqual(weibo.copyValue, "https://weibo.com/u/3207903867")
        XCTAssertEqual(weibo.openURL?.absoluteString, "https://weibo.com/u/3207903867")

        // Email
        guard let email = items.first(where: { $0.id == "email" }) else {
            XCTFail("Missing email entry")
            return
        }
        XCTAssertEqual(email.platform, "合作邮箱")
        XCTAssertEqual(email.displayText, "xianshengxingge@163.com")
        XCTAssertEqual(email.copyValue, "xianshengxingge@163.com")
        XCTAssertEqual(email.openURL?.scheme, "mailto")
        XCTAssertEqual(email.openURL?.absoluteString, "mailto:xianshengxingge@163.com")
    }

    func test_socialLinkItem_equality() {
        let item1 = SocialLinkItem(
            id: "custom",
            platform: "测试",
            displayText: "测试文本",
            iconSystemName: "star",
            openURL: URL(string: "https://example.com"),
            copyValue: "https://example.com"
        )
        let item2 = SocialLinkItem(
            id: "custom",
            platform: "测试",
            displayText: "测试文本",
            iconSystemName: "star",
            openURL: URL(string: "https://example.com"),
            copyValue: "https://example.com"
        )
        let item3 = SocialLinkItem(
            id: "other",
            platform: "测试2",
            displayText: "测试文本2",
            iconSystemName: "star.fill",
            openURL: nil,
            copyValue: "val"
        )

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }
}
