# 简贴 (JianTie)

<p align="center">
  <img src="icon.png" width="128" height="128" alt="简贴 AppIcon" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />
</p>

<p align="center">
  <strong>轻量、极简的 macOS 文件暂存与智能剪贴板工具</strong><br>
  为 macOS 深度定制的 Liquid Glass 拟态设计，原生 Swift 构建，极速轻盈。
</p>

<p align="center">
  <a href="https://github.com/XianShengXingGe/JianTie/releases/latest"><img src="https://img.shields.io/github/v/release/XianShengXingGe/JianTie?color=007AFF&label=Release" alt="Release"></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-000000.svg" alt="Platform: macOS 13.0+">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-success.svg" alt="Universal Binary">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
</p>

---

## 💡 为什么需要「简贴」？（解决什么问题）

在日常使用 Mac 进行办公、设计、开发或写作时，你是否常遇到以下痛点：

1. **跨窗口/跨桌面拖拽文件手忙脚乱**：想把桌面或 Finder 的文件拖到聊天窗口或网页，往往需要一边按住鼠标一边切换窗口（⌘+Tab 或调度中心），一旦中途松手就得重来。
   - **简贴收益**：随手拖到屏幕边缘即可滑出**暂存架**，随放随走；切换到目标窗口后再从暂存架拖出，大幅提升多任务流转效率。
2. **复制了新内容，之前的记录就丢失了**：macOS 原生剪贴板只保留最后一条记录，经常遇到不小心复制覆盖了重要文本或图片。
   - **简贴收益**：后台毫秒级监听剪贴板历史，智能按文本、图片、文件分类存储，随时回溯找回。
3. **粘贴历史内容步骤繁琐**：很多剪贴板工具需要复制历史项后，再手动切回原窗口按 ⌘V。
   - **简贴收益**：支持**直接回贴（Direct Paste）**，双击或按回车键即可瞬间自动将内容注入到前一个获得焦点的输入框中。
4. **堆叠文件不知内容为何**：暂存了多张图片或文档，缩略图太小难以辨别。
   - **简贴收益**：悬停即可查看文件类型、大小与路径，按下 **空格键（Space）** 即可调用 macOS 原生 **Quick Look** 极速全尺寸预览。
5. **传统工具内存占用大、界面突兀**：Electron 包装的工具动辄占用几百兆内存，且与 macOS 系统风格格格不入。
   - **简贴收益**：纯原生 Swift + AppKit / SwiftUI 打造，内存占用仅约 20MB，搭配精心打磨的 **Liquid Glass 拟态毛玻璃** 界面，丝滑轻盈。

---

## ✨ 核心功能亮点

### 1. 边缘智能暂存架 (Edge Shelf)
- **贴边自适应吸附**：文件拖拽至屏幕边缘或鼠标贴边悬停 150ms 自动滑出，支持屏幕左侧/右侧自由切换。
- **多文件智能堆叠 (Multi-File Stack)**：多文件拖入时自动聚合成栈，保留独立信息并支持整体批量拖出。
- **空格键 Quick Look 极速预览**：选中卡片或悬停文件时按下空格键，即刻调起原生预览。
- **悬停信息浮层 (Hover Popover)**：鼠标悬停 350ms 自动展示详细元数据与文件列表。
- **文件状态感知与安全修剪**：自动监听本地文件删除与移动，失效文件自动清理。
- **底部动作区域**：暂存架底部设有快速移除/清空区域，拖拽即可丢弃。

### 2. 剪贴板历史面板 (Clipboard History)
- **多格式高保真支持**：支持纯文本、富文本、本地图片（带尺寸标记与图片缓存）、文件列表等格式。
- **智能去重与置顶**：基于文本内容与图片 SHA-256 哈希去重，重复复制自动更新时间戳并移至首位。
- **直接回贴 (Direct Paste)**：回车或双击任意记录，自动隐藏面板并模拟 ⌘V 粘贴至上一个活动应用。
- **实时分类与即时搜索**：支持「全部 / 文本 / 图片 / 文件」快速切换，毫秒级关键字模糊过滤。
- **容量与生命周期管理**：支持自定义历史上限（50 ~ 1000 条，FIFO 淘汰）与保存过期周期（3天 / 7天 / 30天 / 永久）。

### 3. 便捷快捷键与个性化配置 (Preferences)
- **全局呼出快捷键**：
  - 支持常用**双击修饰键**（双击 ⌘、⌥、⌃、⇧）。
  - 支持**点击录制自定义组合键**（如 ⌥V、⌘⇧V、F1 等），自带防冲突与非法按键校验。
- **开机自启**：基于 macOS 原生 `SMAppService`，开机无感静默常驻后台。
- **原生多语言支持**：原生简体中文支持与多语言扩展。

---

## 🚀 快速上手指南

### 1. 暂存架的使用
| 操作 | 说明 |
| :--- | :--- |
| **放入暂存** | 拖动 Finder 或应用中的文件向屏幕边缘（默认左侧）靠近，暂存架自动滑出，松开鼠标即可暂存。 |
| **贴边滑出** | 无需拖拽，鼠标直接移动至屏幕边缘悬停 150ms 亦可滑出暂存架。 |
| **空格预览** | 鼠标悬停在卡片上，按下 **空格键 (Space)** 开启原生 Quick Look 预览；再次按空格或 Esc 关闭。 |
| **取出使用** | 切换到目标应用（如微信、邮件、终端），直接从暂存架中将文件拖入即可。 |
| **单项/批量删除** | 点击卡片右上角的关闭按钮，或直接将卡片向下拖动至暂存架底部的红色删除区域。 |

### 2. 剪贴板历史的使用
| 操作 | 说明 |
| :--- | :--- |
| **唤出面板** | 默认**快速双击 ⌘ (Command) 键**，瞬间唤出剪贴板历史面板。 |
| **直接回贴** | 使用 **↑ / ↓ 方向键** 选择记录，按 **Enter (回车)** 或 **鼠标双击** 即可直接自动粘贴到目标输入框。 |
| **快速复制** | 按 **⌘C** 或点击卡片上的复制图标，将历史项重新置入系统剪贴板。 |
| **快速搜索** | 唤出面板后直接在搜索框输入文字或文件名，列表即时过滤。 |
| **分类过滤** | 点击顶部的「全部 / 文本 / 图片 / 文件」标签快速筛选。 |
| **退出面板** | 按 **Esc 键** 或在屏幕其他区域点击，面板自动隐藏。 |

### 3. 偏好设置调整
- 点击 macOS 顶部菜单栏的「简贴」图标 $\rightarrow$ 选择 **偏好设置 (Preferences)**（或按快捷键 ⌘,）。
- 你可以在此自由切换暂存架停靠边缘（左侧/右侧）、录制你的专属呼出快捷键、配置历史保留周期或清空缓存。

---

## 📦 安装与系统要求

### 系统要求
- **macOS 13.0 (Ventura)**、**macOS 14.0 (Sonoma)**、**macOS 15.0 (Sequoia)** 或更高版本。
- 原生支持 **Apple Silicon (M1/M2/M3/M4 系列)** 及 **Intel** 架构 Mac。

### 下载安装
1. 前往 [GitHub Releases](https://github.com/XianShengXingGe/JianTie/releases/latest) 下载最新的 `JianTie-v1.0.0.dmg`。
2. 双击打开 `.dmg` 镜像文件，将 **简贴** 图标拖拽至 **Applications (应用程序)** 文件夹。
3. 启动应用，根据指引在「系统设置 $\rightarrow$ 隐私与安全性 $\rightarrow$ 辅助功能」中授予权限（用于启用直接回贴功能）。

> 💡 **初次打开安全提示说明（绕过 Gatekeeper）**：  
> 若系统提示“无法打开，因为无法验证开发者”，请在终端（Terminal）中执行以下命令解除隔离属性即可：
> ```bash
> xattr -cr /Applications/JianTie.app
> ```
> 或前往「系统设置 $\rightarrow$ 隐私与安全性」，滑到底部点击「仍要打开」。

---

## 🛠️ 技术架构

- **语言框架**：Swift 5.9 + SwiftUI + AppKit
- **设计规范**：Apple Liquid Glass 拟态材质、NSVisualEffectView、动态光效与毛玻璃折射
- **系统集成**：
  - `CGEventTap` / `NSEvent` 毫秒级全局双击修饰键与快捷键捕获
  - `QLPreviewPanel` 原生 Quick Look 预览桥接
  - `SMAppService` 原生开机自启动管理
  - `Accessibility API` (AXUIElement) 智能前台焦点回溯与 ⌘V 模拟直接粘贴
- **工程质量**：全模块解耦架构，190+ 自动化单元测试保障稳定性。

---

## ☕ 支持与打赏

「简贴」是由独立开发者精心打造的开源项目。如果你觉得它为你带来了便利、提升了效率，欢迎通过打赏请作者喝一杯咖啡 ☕，你的鼓励是持续维护与迭代的最大动力！

<p align="center">
  <img src="Sources/JianTieApp/Resources/alipay_qr.jpg" width="220" alt="支付宝赞赏码" style="border-radius: 12px; margin: 10px;" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Sources/JianTieApp/Resources/wechat_qr.jpg" width="220" alt="微信赞赏码" style="border-radius: 12px; margin: 10px;" />
</p>

- **交流建议**：欢迎在 [GitHub Issues](https://github.com/XianShengXingGe/JianTie/issues) 提交反馈与功能建议。

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 许可证开源。
