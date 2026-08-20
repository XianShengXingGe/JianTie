# 0004. Shelf 动作区垂直布局与系统 Agent 驻留模式

## 上下文

确立 Shelf 拖拽时动态动作区 (Action Zone) 的空间排布方式，以及 App 在 macOS 系统中的驻留与展示形态。

## 决策

1. **动作区垂直堆叠布局**：在文件拖拽激活期间，Action Zone 紧贴在 Shelf 列表底部展示，采用上下垂直排列结构——上方为 `AirDrop` 区域，下方为 `Copy Path` 区域，与左侧/右侧贴边的纵向拖拽流向保持高度契合。
2. **纯后台常驻 Agent (LSUIElement)**：应用以纯 Menu Bar Agent（`Application is agent (UIElement) = YES`）模式运行，不占用 Dock 栏空间；用户通过 Menu Bar 托盘图标访问偏好设置、检查运行状态与退出应用。
