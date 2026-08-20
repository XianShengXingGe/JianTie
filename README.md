<p align="center">
  <img src="icon.png" width="112" height="112" alt="简贴 AppIcon" style="filter: drop-shadow(0 10px 20px rgba(0,0,0,0.12));" />
</p>

<h1 align="center">简贴 (JianTie)</h1>

<p align="center">
  <strong>一款轻巧顺手的 macOS 屏幕暂存架与剪贴板小助手</strong><br>
  苹果原生质感 · 几乎不占内存 · 像系统自带一样自然
</p>

<p align="center">
  <a href="https://github.com/XianShengXingGe/JianTie/releases/latest"><img src="https://img.shields.io/github/v/release/XianShengXingGe/JianTie?color=007AFF&label=下载最新版" alt="Release"></a>
  <img src="https://img.shields.io/badge/支持系统-macOS%2013%2B-000000.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/支持机型-M1~M4%20%2F%20Intel-success.svg" alt="Universal">
  <img src="https://img.shields.io/badge/免费开源-MIT-blue.svg" alt="License: MIT">
</p>

---

## 💡 它能帮你做什么？

平时用 Mac 办公、写文档或聊天时，你是否也遇到过这些小烦恼：

- 📁 **拖拽文件找窗口太费劲**：想把桌面文件发给微信好友，需要一手按住鼠标不放，另一只手手忙脚乱切换窗口，中途一松手就前功尽弃。  
  👉 **简贴帮你**：顺手把文件往屏幕边缘一放即可暂存；切换好窗口后再轻松拖出来，还支持按**空格键**秒开大图预览！

- 📋 **刚复制的内容不小心被覆盖了**：系统自带的剪贴板只能记最后一条，复制了新文字，前面的重要内容就弄丢了。  
  👉 **简贴帮你**：自动记录你复制过的文字、图片和文件；连按两次 **⌘ (Command)** 键随时唤出，选中按回车还能直接帮你自动粘贴！

- 🍃 **讨厌臃肿发热的软件**：很多工具动辄占用几百兆内存，后台还偷偷耗电。  
  👉 **简贴帮你**：纯原生打造，内存仅占用 ~20MB，平时安静常驻，绝不打扰。

---

## 🚀 30 秒轻松上手

### 1. 暂存文件（屏幕边栏）
- **放入**：拖动任意文件往屏幕左边（或右边）一靠，边栏自动滑出，松开鼠标就存好了。
- **看大图**：鼠标停在文件上，按一下 **空格键** 就能直接查看大图和文档。
- **发送**：打开聊天软件或邮件，直接把文件从边栏拖进去即可。
- **移除**：点击卡片右上角 ✕，或者把文件拖到边栏下方的红色区域。

### 2. 剪贴板历史
- **调出**：键盘上 **快速按两次 ⌘ (Command)** 键即可打开历史面板。
- **自动粘贴**：按方向键选中内容，按 **回车键 (Enter)** 自动帮你粘贴到当前光标处。
- **搜索**：直接打字即可秒搜历史记录，也可以点上方标签只看图片或文字。

---

## 📦 下载与安装

1. 点击前往 [**下载页面 (GitHub Releases)**](https://github.com/XianShengXingGe/JianTie/releases/latest)，下载 `JianTie-v1.0.0.dmg`。
2. 双击打开安装包，把 **简贴** 图标拖进 **应用程序 (Applications)** 文件夹。
3. 打开软件，根据提示在 Mac「系统设置 $\rightarrow$ 隐私与安全性 $\rightarrow$ 辅助功能」中勾选允许（用于实现回车自动帮你粘贴）。

> 💡 **小贴士（首次打开若提示“无法验证开发者”）**：  
> 打开 Mac 自带的「终端」App，复制粘贴下面这行命令并按回车即可正常打开：
> ```bash
> xattr -cr /Applications/JianTie.app
> ```

---

## ☕ 请作者喝杯咖啡

「简贴」是由个人独立开发的免费开源工具。如果你觉得它为你带来了便利、节省了时间，欢迎请作者喝杯咖啡 ☕，你的鼓励是持续维护更新的最大动力！

<p align="center">
  <img src="Sources/JianTieApp/Resources/alipay_qr.jpg" width="180" alt="支付宝赞赏码" style="border-radius: 10px; margin: 8px;" />
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Sources/JianTieApp/Resources/wechat_qr.jpg" width="180" alt="微信赞赏码" style="border-radius: 10px; margin: 8px;" />
</p>

- **反馈与建议**：使用中遇到任何问题或有好想法，欢迎在 [GitHub Issues](https://github.com/XianShengXingGe/JianTie/issues) 留言交流。

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 协议开源。
