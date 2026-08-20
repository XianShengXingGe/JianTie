# 0005. 辅助功能权限策略与 Shelf 手动清除交互

## 上下文

确立直接回贴 (Direct Paste) 功能对系统权限的依赖策略，以及用户在 Shelf 中主动放弃/清除已暂存 Stack 的微交互细节。

## 决策

1. **辅助功能权限强制 (Strict Accessibility Requirement)**：Direct Paste（回贴到之前活动 App）是 Clipboard 模块不可妥协的核心体验。应用启动与初始化时明确引导并要求系统「辅助功能权限 (Accessibility)」授权，确保纯键盘 `Enter` 与鼠标单击均能 100% 稳定实现直接粘贴，不做妥协式降级。
2. **Shelf 悬停左上角 ✕ 清除 (Top-Left Dismiss Button on Hover)**：在 Shelf 保持展示状态下，当鼠标悬停在某个待拖拽的 Stack / 文件卡片上（且当前未处于 Drag 状态）时，卡片左上角浮现微小的 ✕ 关闭按钮；单击该按钮即可直接放弃并清除该 Stack；清除后若 Shelf 已无其他 Stack，Shelf 自动平滑缩回隐藏。
