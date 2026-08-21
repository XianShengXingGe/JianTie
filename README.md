<p align="center">
  <img src="icon.png" width="112" height="112" alt="JianTie AppIcon" style="filter: drop-shadow(0 10px 20px rgba(0,0,0,0.12));" />
</p>

<h1 align="center">简贴 (JianTie)</h1>

<p align="center">
  <strong>A lightweight, native macOS shelf & clipboard assistant.</strong><br>
  Native feel · Ultra-low memory (~20MB) · Feels like a built-in Mac feature
</p>

<p align="center">
  <a href="#-english">English</a> | <a href="#-简体中文">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/XianShengXingGe/JianTie/releases/latest"><img src="https://img.shields.io/badge/Download-v1.2.0-007AFF.svg" alt="Download Latest Release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2F%20Intel-success.svg" alt="Universal">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
</p>

---

<a id="-english"></a>
## 🌟 English

### Why JianTie?

When working on a Mac, handling daily files and copied content often comes with small but frustrating interruptions. **JianTie** focuses on **two essential features** to make your daily workflow effortless.

---

### 1. 📁 Screen Shelf: Drag & Drop Without the Window Juggling

- **The Daily Frustration**:  
  You want to send desktop files to a chat or upload them to a website. You have to click and hold the files with one hand while struggling to switch windows or workspaces with the other. If your finger slips, you have to start all over.
- **How JianTie Helps**:  
  Just drag your files to the edge of the screen — a shelf slides out automatically. Drop your files there to park them temporarily. Switch to your target window at your own pace, then drag them right in.  
  *(Bonus: Hover over any file and press the **Spacebar** for an instant preview!)*

---

### 2. 📋 Clipboard History: Never Lose What You Copied

- **The Daily Frustration**:  
  The default Mac clipboard only remembers your last copy. If you copy a new link, the important note or address you copied a minute ago is overwritten and gone.
- **How JianTie Helps**:  
  JianTie automatically saves the text and images you copy. Whenever you need something from earlier, **double-tap the ⌘ (Command) key** to bring up your history.  
  *(New in v1.2.0: Press **⌘ + 1~9** to instantly paste any of the first 9 items without touching your mouse! Or search instantly and press **Enter** to paste).*

---

### 📥 Download & Setup

1. Go to [**Releases**](https://github.com/XianShengXingGe/JianTie/releases/latest) and download `JianTie-v1.2.0.dmg`.
2. Open the `.dmg` file and drag **JianTie** into your **Applications** folder.
3. Launch the app and grant **Accessibility** permission when prompted (required for automatic pasting upon pressing Enter or ⌘1-9).

> 💡 **Tip (If macOS says "App cannot be opened because developer cannot be verified")**:  
> Open the Mac built-in **Terminal** app, paste the following command, and press Enter:
> ```bash
> xattr -cr /Applications/简贴.app /Applications/JianTie.app 2>/dev/null || true
> ```

---

<a id="-简体中文"></a>
## 🇨🇳 简体中文

### 为什么需要「简贴」？

日常在 Mac 上办公、聊天或写文档时，很多琐碎操作常常让人感到手忙脚乱。「简贴」只专注做好 **2 个最常用的核心功能**，像系统自带功能一样轻巧顺手。

---

### 1. 📁 屏幕暂存架：跨窗口拖文件不再手忙脚乱

- **日常小烦恼**：  
  想把桌面上的文件发给微信好友或上传到网页，一手必须死死按住鼠标，另一只手狼狈地切换窗口。中途稍微松了一下手指，拖拽就失败了，又得从头再来。
- **简贴帮你**：  
  顺手把文件往屏幕边缘一靠，暂存架会自动滑出。松开鼠标把文件存放在这里，从容切换到你要发送的聊天窗口或网页，再一把拖进去即可。  
  *（小提示：鼠标悬停在文件上，按一下 **空格键** 还能秒开大图预览！）*

---

### 2. 📋 剪贴板历史：刚复制的内容再也不会被覆盖

- **日常小烦恼**：  
  系统自带的剪贴板只能记住最后一次复制的内容。刚复制了一段文字，接着又复制了一个网址，刚才那段重要文字就直接丢失了。
- **简贴帮你**：  
  后台自动为你记住最近复制过的文字和图片。需要使用之前的内容时，**快速连按两次 ⌘ (Command) 键** 唤出历史面板。  
  *（v1.2.0 升级：无需动鼠标，直接按 **⌘ + 1~9** 即可一键秒贴前 9 条记录！也可打字秒搜后按 **回车 (Enter)** 自动回贴）。*

---

### 📥 下载与安装

1. 前往 [**下载页面 (GitHub Releases)**](https://github.com/XianShengXingGe/JianTie/releases/latest) 下载最新安装包 `JianTie-v1.2.0.dmg`。
2. 打开安装包，将 **简贴** 拖入 **应用程序 (Applications)** 文件夹。
3. 打开软件，根据提示在 Mac「系统设置 $\rightarrow$ 隐私与安全性 $\rightarrow$ 辅助功能」中勾选允许（用于实现快捷键自动帮你粘贴）。

> 💡 **小贴士（首次打开若提示“无法验证开发者”）**：  
> 打开 Mac 自带的「终端 (Terminal)」App，粘贴运行以下命令即可：
> ```bash
> xattr -cr /Applications/简贴.app /Applications/JianTie.app 2>/dev/null || true
> ```

---

## ☕ 请作者喝杯咖啡 / Support the Project

「简贴」是由个人独立开发的免费开源工具。如果你觉得它为你带来了便利、节省了时间，欢迎请作者喝杯咖啡 ☕，你的鼓励是持续维护更新的最大动力！

<p align="center">
  <img src="Sources/JianTieApp/Resources/alipay_qr.jpg" width="180" alt="支付宝赞赏码" style="border-radius: 10px; margin: 8px;" />
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Sources/JianTieApp/Resources/wechat_qr.jpg" width="180" alt="微信赞赏码" style="border-radius: 10px; margin: 8px;" />
</p>

- **Feedback & Issues / 反馈交流**：[GitHub Issues](https://github.com/XianShengXingGe/JianTie/issues)

---

## 📄 License / 开源协议

本项目采用 [MIT License](LICENSE) 协议开源。
