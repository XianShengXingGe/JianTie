# 简贴 (JianTie)

一款轻量级 macOS 效率工具，提供 Mouse-first 的 Finder 文件临时暂存/中转（Shelf）与 Keyboard-first 的剪贴板历史与快速回贴（Clipboard）。

## 核心领域语言 (Domain Glossary)

### Shelf (暂存架)

**Shelf**:
Finder 文件的临时停靠与中转区域。仅持有原文件的引用，不产生物理副本；无内容且无拖拽时默认隐藏。
_Avoid_: 文件夹 (Folder)、侧边栏 (Sidebar)、收藏夹 (Favorites)、文件仓库 (Repository)

**Stack (文件堆/暂存项)**:
单次 Drag 动作（Drag Session）拖入 Shelf 的一个或多个文件所组成的不可拆分单元。
_Avoid_: 文件组 (File Group)、压缩包 (Archive)、批次 (Batch)

**Action Zone (快捷动作区)**:
仅在用户正在拖拽文件（Finder Drag 或 Shelf Stack Drag）期间动态附着在 Shelf 上的快捷触发区域（V1 包含 AirDrop 与 复制文件路径）。
_Avoid_: 工具栏 (Toolbar)、菜单栏 (Menubar)、操作面板 (Action Panel)

**Reference (文件引用)**:
Shelf 对磁盘上原始文件的非破坏性系统引用机制（如 Security-Scoped Bookmark 或文件 URL），原文件保持在原始路径不变。
_Avoid_: 文件副本 (Copy)、缓存文件 (Cache)、镜像 (Mirror)

### Clipboard (剪贴板历史)

**Clipboard (剪贴板历史面板)**:
独立于 Shelf 的全局键盘优先面板，按时间倒序真实记录剪贴板的文本（保留富文本）与图片历史，支持纯键盘检索与直接回贴。
_Avoid_: Snippet 管理器、知识库、永久收藏夹

**Item (剪贴板记录项)**:
剪贴板历史中的单条时间记录，可为纯文本/富文本或图片预览项。
_Avoid_: 笔记 (Note)、片段 (Snippet)、卡片 (Card)

**Direct Paste (直接回贴)**:
在剪贴板历史面板中通过 Enter 键确认后，面板关闭并将内容直接注入/粘贴到呼出前的前台活动 App 的行为。
_Avoid_: 仅重新复制 (Copy Only)
