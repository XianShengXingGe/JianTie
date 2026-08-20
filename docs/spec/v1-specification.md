# 简贴 (JianTie) V1 Product & Interaction Specification

> **Status**: `ready-for-agent`  
> **Target Platform**: macOS 13.0+ (Ventura / Sonoma / Sequoia)  
> **Application Mode**: Menu Bar Agent (`LSUIElement = true`)  
> **Domain Glossary**: [CONTEXT.md](../../CONTEXT.md)  
> **Architectural Decisions**: [ADR-0001](../../docs/adr/0001-shelf-lifecycle-and-triggers.md), [ADR-0002](../../docs/adr/0002-clipboard-activation-and-paste-workflow.md), [ADR-0003](../../docs/adr/0003-clipboard-storage-retention-and-interaction.md), [ADR-0004](../../docs/adr/0004-shelf-action-zone-layout-and-app-agent-mode.md), [ADR-0005](../../docs/adr/0005-accessibility-permission-and-manual-dismissal.md)

---

## Problem Statement

macOS 用户在日常跨应用与文件协同中面临两大高频痛点：
1. **文件拖拽与跨窗口搬运摩擦大**：用户从 Finder 拖拽文件到聊天软件、邮件或网页时，经常因为目标窗口被遮挡、跨桌面/Space 切换繁琐，导致拖拽途中松手失败；同时需要频繁对拖拽文件执行 AirDrop 发送或复制路径，原生操作链路层级较多。
2. **剪贴板上下文丢失与回贴割裂**：用户频繁在多个应用间复制文本、富文本和截图，原生剪贴板仅保留最后一次复制；主流剪贴板工具往往过于臃肿或快捷键冲突，回贴时需要鼠标切换窗口并手动粘贴，打断纯键盘工作流。

---

## Solution

「简贴」是一款极致轻量、零干扰的 macOS 效率工具，将能力收敛为两个物理与心智完全独立的子系统：
- **Shelf（文件暂存架，Mouse-first）**：Finder 拖拽开始时自动在当前屏幕边缘滑出，作为文件的临时停靠站；仅持有原文件引用而不复制文件；下方附带垂直排布的 AirDrop 与 Copy Path 快捷动作区；支持多 Stack 垂直流排布与悬停左上角一键清除。
- **Clipboard（剪贴板历史面板，Keyboard-first）**：全局双击 `⌘` 瞬间唤出浮层列表，按时间倒序真实完整记录 1000 条富文本、文本与图片历史；支持实时全文搜索；方向键选定后 `Enter`（或鼠标单击）直接自动回贴到上一个前台应用并关闭面板。

---

## User Stories

### A. Shelf 触发与展示 (Reveal & Layout)
1. As a macOS user, I want the Shelf to automatically slide out from the screen edge when I start dragging files in Finder, so that I have an immediate drop target without pressing any buttons.
2. As a macOS user, I want the Shelf to remain completely hidden when it is empty and no drag is active, so that it never clutters my screen space.
3. As a macOS user, I want the Shelf to stay visible once it holds at least one file stack, so that I can switch apps, navigate spaces, or find destination folders without losing my files.
4. As a macOS user, I want the Shelf to automatically slide back and hide when the last file stack is removed, so that I don't have to manually dismiss it.
5. As a macOS user, I want to reveal the empty Shelf by hovering my cursor against the configured screen edge for 150ms, so that I can inspect the shelf without accidental triggers during normal mouse flicks.
6. As a macOS user, I want the empty Shelf to smoothly retract if I move my cursor away for 600ms without dropping anything, so that it cleans itself up automatically.
7. As a macOS user with multiple monitors, I want the Shelf to appear on the edge of the specific monitor where my cursor is currently dragging or hovering, so that I never have to drag across physical screens.
8. As a macOS user, I want to configure the Shelf edge position between Left and Right in Settings, so that it adapts to my dock and window placement preferences.

### B. Shelf 暂存与生命周期 (Stack & Storage)
9. As a macOS user, I want a single drag-and-drop session from Finder to form a single atomic Stack in the Shelf, so that multi-file selections remain grouped.
10. As a macOS user, I want the Shelf to store only non-destructive file references (bookmarks/URLs) without copying raw file payloads, so that dropping a 50GB file consumes negligible memory and disk space.
11. As a macOS user, I want to drop multiple successive drag batches into the Shelf to create multiple vertically stacked Stacks, so that I can gather different assets sequentially.
12. As a macOS user, I want the Shelf to smoothly scroll vertically when the number of Stacks exceeds the screen height, so that all my temporary files remain accessible.
13. As a macOS user, I want to drag an entire Stack out of the Shelf into a destination application (or Finder), so that all files in that stack are received together.
14. As a macOS user, I want the Stack to be automatically removed from the Shelf upon a successful external drop, so that I know the transfer is complete.
15. As a macOS user, I want the Stack to remain safely in the Shelf if I cancel the drag (e.g. press ESC or drop in an invalid target), so that I don't lose my references.
16. As a macOS user, I want a micro "✕" discard button to appear on the top-left of a Stack card when I hover over it with my mouse, so that I can manually discard and remove that stack with a single click.
17. As a macOS user, I want the Shelf to silently and automatically prune any Stack whose underlying files have been deleted, moved, or disconnected, so that I am never left with broken/zombie cards.

### C. Shelf 快捷动作区 (Action Zone)
18. As a macOS user, I want the Action Zone (AirDrop on top, Copy Path on bottom) to dynamically reveal below the Shelf items only while a drag session is actively in progress, so that it doesn't take up space during idle viewing.
19. As a macOS user, I want to drop Finder files directly onto the AirDrop zone, so that the native macOS sharing dialog opens immediately without first staging on the shelf.
20. As a macOS user, I want to drag a Stack from the Shelf and drop it onto the AirDrop zone, so that I can share previously staged files.
21. As a macOS user, I want the Stack to be removed from the Shelf if the AirDrop transfer succeeds, so that completed shares are automatically cleared.
22. As a macOS user, I want the Stack to remain in the Shelf if the AirDrop transfer is cancelled or fails, so that I can retry or use the files elsewhere.
23. As a macOS user, I want to drop Finder files or an existing Shelf Stack onto the Copy Path zone, so that the absolute file paths (newline-separated for multiple files) are instantly copied to my system clipboard.
24. As a macOS user, I want the Stack to be immediately removed from the Shelf once dropped onto the Copy Path zone, so that one-shot path extraction is clean and fast.
25. As a macOS user, I want a lightweight inline visual feedback ("✓ Path copied") upon copying paths, without intrusive modal alerts.

### D. Clipboard 记录与容量 (Capture & Retention)
26. As a macOS user, I want the app to faithfully capture all copied plain text, rich text (RTF/HTML), and images in the background, so that my recent copy history is preserved.
27. As a macOS user, I want the clipboard history to ignore copied Finder file objects, so that large file drag/copy operations don't pollute text and image history.
28. As a macOS user, I want duplicate copies to be recorded as separate chronological entries rather than deduplicated, so that the latest copy is always at the very top.
29. As a macOS user, I want the clipboard history to retain up to 1000 items with a FIFO eviction policy and no automatic time expiration, so that my history is predictable and persistent.

### E. Clipboard 唤出、搜索与直接回贴 (Recall, Search & Direct Paste)
30. As a macOS user, I want to double-tap the `⌘` (Command) key anywhere to instantly pop up the Clipboard history panel, so that I have a fast, single-key muscle memory trigger.
31. As a macOS user, I want the Clipboard panel to automatically focus on the search input and highlight the first (most recent) item upon opening, so that I can act immediately.
32. As a macOS user, I want to navigate items up and down using the `↑` and `↓` arrow keys, so that I don't need to reach for the mouse.
33. As a macOS user, I want to type keywords into the search box to filter text history in real time, so that I can locate past snippets instantly.
34. As a macOS user, I want copied images to display with large, clear previews in the list, so that I can recognize graphics visually without OCR search.
35. As a macOS user, I want pressing `Enter` on any selected item to instantly close the panel, restore focus to my previous active app, and directly paste the content (preserving rich text formats), so that my typing flow is uninterrupted.
36. As a macOS user, I want clicking any item with my mouse to perform the exact same Direct Paste action as pressing `Enter`, so that mouse users have a frictionless one-click experience.
37. As a macOS user, I want hovering over a clipboard item to reveal a subtle delete button, so that I can remove sensitive or unwanted entries on demand.
38. As a macOS user, I want pressing `ESC` or clicking outside the Clipboard panel to dismiss it immediately and return focus to the previous app without pasting.

### F. 系统常驻与权限管理 (App Lifecycle & Permissions)
39. As a macOS user, I want the app to run strictly as a Menu Bar Agent without appearing in the Dock or `⌘Tab` switcher, so that it remains lightweight and unobtrusive.
40. As a macOS user, I want the app to clearly guide me to grant macOS Accessibility permissions upon first launch, so that Direct Paste functionality operates reliably.

---

## Implementation Decisions

### 1. Architectural Modules & Seams
- **`AppHost` / `AppDelegate`**: Configures `LSUIElement = true`, manages the Menu Bar status item, handles lifecycle events, and requests Accessibility permissions via `AXIsProcessTrustedWithOptions`.
- **`ShelfEngine` & `ShelfCoordinator`**:
  - Encapsulates the complete Shelf state machine (Hidden ↔ Revealed ↔ Stored ↔ DragActive).
  - Uses `NSDraggingDestination` and system drag tracking to detect Finder drag sessions.
  - Monitors cursor screen geometry via `NSScreen.screens` and `NSEvent.mouseLocation` to bind the Shelf window to the active screen edge.
  - Manages `ShelfStack` collections (array of Security-Scoped Bookmarks / file URLs).
  - Handles Action Zone subviews (AirDrop via `NSSharingService(named: .sendViaAirDrop)` and Copy Path via `NSPasteboard.general`).
- **`ClipboardEngine` & `ClipboardCoordinator`**:
  - Polls/observes system `NSPasteboard` change count (`pasteboard.changeCount`).
  - Stores up to 1000 items in SQLite or binary cache (text payload, rich text data representation, thumbnail/image data representation).
  - `DoubleTapMonitor`: Global event tap listening for two consecutive `NSEvent.ModifierFlags.command` presses within 300ms window without other intervening key events.
  - `DirectPasteService`: Restores previous active `NSRunningApplication.activate()`, places selected representation onto `NSPasteboard.general`, and simulates synthetic `⌘V` key events via `CGEvent(keyboardEventSource: ...)`.

### 2. State Machines

#### Shelf State Machine
```
[HIDDEN]
  │  ├── Finder Drag Detected ──────────→ [REVEALED_DRAGGING]
  │  │                                      │ (Shows Shelf + Action Zone)
  │  │                                      ├── Drop on Shelf ──→ [STORED]
  │  │                                      ├── Drop on AirDrop ─→ Trigger AirDrop ─→ [HIDDEN]
  │  │                                      ├── Drop on CopyPath → Copy & Feedback ──→ [HIDDEN]
  │  │                                      └── Drag Exit/Cancel ───────────────→ [HIDDEN]
  │  └── Edge Hover (150ms dwell) ──────→ [REVEALED_EMPTY]
  │                                         └── Mouse Leave (600ms idle) ──────→ [HIDDEN]
[STORED]
  ├── Multi-Stack present, stays visible across app switches
  ├── Hover Stack → Shows Top-Left '✕' → Click '✕' → Remove Stack → If 0 left → [HIDDEN]
  ├── Drag Stack Out ──→ [REVEALED_DRAGGING]
  │                        ├── External Drop Success ─→ Remove Stack → If 0 left → [HIDDEN]
  │                        ├── AirDrop Success ────────→ Remove Stack → If 0 left → [HIDDEN]
  │                        ├── Copy Path ─────────────→ Remove Stack → If 0 left → [HIDDEN]
  │                        └── Drag Cancel ───────────→ Return to [STORED]
  └── Background Timer ─→ Prune unreachable file references → If 0 left → [HIDDEN]
```

#### Clipboard State Machine
```
[HIDDEN]
  │  └── Double-tap `⌘` ────────────────→ [ACTIVE_PANEL]
[ACTIVE_PANEL]
  ├── Focus Search Field & Select Item 0
  ├── Search text input ───────────────→ Filters List & Updates Selection
  ├── `↑` / `↓` Keys ─────────────────→ Updates Selection Index
  ├── `Enter` Key / Mouse Click ───────→ [DIRECT_PASTE] ─→ [HIDDEN]
  ├── `ESC` Key / Resign Key Focus ────→ [HIDDEN] (Restore previous app focus)
  └── Click Item '✕' ──────────────────→ Delete Item from Storage & Update List
```

### 3. Motion & Timing Parameters
- **Shelf Edge Hover Dwell**: 150ms to reveal, 600ms mouse-out to auto-retract.
- **Shelf Slide Animation**: 180ms ease-out curve for entry; 220ms ease-in curve for retraction.
- **Double-tap Command Threshold**: Max 300ms interval between two releases/presses.
- **Direct Paste Delay**: 30ms yield after `runningApp.activate(options: .activateIgnoringOtherApps)` before firing synthetic `CGEvent` `⌘V`.

---

## Testing Decisions

### Test Strategy & Seams
We will test the system through two primary, high-level seams without coupling to macOS UI window rendering:
1. **`ShelfCoordinatorSeam`**:
   - Accepts synthetic input events: `onFinderDragStart(files, screen)`, `onEdgeHover(screen, duration)`, `onDrop(target: .shelf | .airdrop | .copyPath)`, `onStackDragOut(stackId, dropSuccess: Bool)`, `onManualDismiss(stackId)`.
   - Asserts external state transitions: View visibility state, active screen identifier, stack collection contents, clipboard outputs, and AirDrop service invocations.
2. **`ClipboardCoordinatorSeam`**:
   - Accepts synthetic pasteboard events: Text strings, RTF/HTML blobs, PNG/JPEG images, file URL pasteboard items (to verify ignoring), and double-tap trigger events.
   - Asserts external behavior: Ring buffer eviction at 1000 items, search query matching accuracy, chronological order preservation, and target app direct paste payload construction.

---

## Out of Scope (Strictly Excluded for V1)
- OCR extraction, vision indexing, or image text search.
- AI summaries, translations, or smart actions.
- Finder `⌘C` file copy entering Clipboard history.
- Safari web image / URL / raw text dragging into Shelf (Shelf strictly handles Finder files).
- File operations (compression, resizing, conversion, PDF merging).
- Stack splitting, merging, or individual file removal from within a multi-file Stack.
- Cloud synchronization, accounts, or iOS/Windows companion apps.

---

## Further Notes
- The specification conforms directly to ADRs 0001 through 0005.
- All implementation components will be verified via high-seam automated unit and integration test harnesses before UI integration.
