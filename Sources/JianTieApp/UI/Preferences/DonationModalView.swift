import SwiftUI
import AppKit
import JianTieCore

/// 开发者打赏 Liquid Glass 弹窗
public struct DonationModalView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Binding public var isPresented: Bool
    @State private var selectedChannel: DonationChannel = .alipay
    @State private var wechatImage: NSImage?
    @State private var alipayImage: NSImage?

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            // 半透明毛玻璃暗色蒙层
            Color.black.opacity(0.45)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }

            // 主弹窗卡片
            VStack(spacing: 16) {
                // 顶部标题栏与关闭按钮
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 16, weight: .bold))

                            Text(L10n.tr("donation.modal_title"))
                                .font(.headline.weight(.bold))
                        }

                        Text(L10n.tr("donation.modal_subtitle"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("donation.close_tooltip"))
                }

                // 支付渠道切换 Tab
                HStack(spacing: 8) {
                    ForEach(DonationChannel.allCases) { channel in
                        let isSelected = selectedChannel == channel
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedChannel = channel
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: channel.iconSystemName)
                                    .font(.system(size: 13, weight: .semibold))

                                Text(channel.title)
                                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                            }
                            .foregroundColor(isSelected ? channel.brandColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlassCard(
                                cornerRadius: 8,
                                isSelected: isSelected,
                                tintColor: channel.brandColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 收款码展示容器
                VStack(spacing: 10) {
                    if let image = currentChannelImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    } else {
                        // 优雅占位兜底视图
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary.opacity(0.6))

                            Text(L10n.tr("donation.qr_preparing", selectedChannel.title))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary.opacity(0.8))

                            Text(L10n.tr("donation.qr_placeholder_desc", otherChannel.title))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedChannel = otherChannel
                                }
                            }) {
                                Text(L10n.tr("donation.switch_to_channel", otherChannel.title))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .liquidGlassBadge(isCapsule: true, tintColor: otherChannel.brandColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .liquidGlassCard(cornerRadius: 12)
                    }

                    Text(selectedChannel.subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                // 底部温暖致谢
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.pink)

                    Text(L10n.tr("donation.thank_you"))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .frame(width: 360)
            .liquidGlassPanel(cornerRadius: 18, material: .hudWindow)
            .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        }
        .onAppear {
            loadImages()
        }
    }

    private var currentChannelImage: NSImage? {
        switch selectedChannel {
        case .wechat:
            return wechatImage
        case .alipay:
            return alipayImage
        }
    }

    private var otherChannel: DonationChannel {
        selectedChannel == .wechat ? .alipay : .wechat
    }

    private func loadImages() {
        self.wechatImage = DonationQRCodeProvider.loadQRCodeImage(for: .wechat)
        self.alipayImage = DonationQRCodeProvider.loadQRCodeImage(for: .alipay)
        // 若默认选择的渠道没有图片而另一个有，则自动选中有图片的渠道
        if wechatImage != nil && alipayImage == nil {
            selectedChannel = .wechat
        } else if alipayImage != nil && wechatImage == nil {
            selectedChannel = .alipay
        }
    }
}
