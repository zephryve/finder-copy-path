# PRD: Finder Copy Path

## 背景

macOS Finder 原生不提供直接右键复制路径的功能。虽然可以通过 Option+右键 显示「拷贝为路径名」，但：
1. 需要额外按键，不直觉
2. 只支持绝对路径，不支持相对路径
3. 很多开发场景需要相对路径（git、终端命令、代码引用）

## 目标用户

日常使用 Finder 管理文件的开发者，需要频繁复制文件路径到终端、编辑器或文档中。

## 功能需求

### F1: 复制绝对路径

| 项目 | 说明 |
|------|------|
| 触发方式 | 右键 → 快速操作 → 复制绝对路径 |
| 输入 | Finder 中选中的一个或多个文件/文件夹 |
| 输出 | 剪贴板写入完整的 POSIX 路径 |
| 多选行为 | 多个路径以换行符 `\n` 分隔 |
| 示例 | `/Users/zephryve/Documents/project/main.py` |

### F2: 复制相对路径

| 项目 | 说明 |
|------|------|
| 触发方式 | 右键 → 快速操作 → 复制相对路径 |
| 输入 | Finder 中选中的一个或多个文件/文件夹 |
| 基准路径 | Finder 当前打开的文件夹（insertion location） |
| 输出 | 剪贴板写入相对于基准路径的相对路径 |
| 多选行为 | 多个路径以换行符 `\n` 分隔 |
| 降级策略 | 如果无法获取 Finder 当前目录，回退为绝对路径 |
| 示例 | 当前在 `/Users/zephryve/Documents/project/`，选中 `src/main.py` → 复制 `src/main.py` |

## 技术方案

### 实现方式：Automator Quick Action

选择 Automator 而非 Finder Extension（APPEX）的原因：
- 无需 Xcode 开发和签名
- 无需 App Store 分发
- 部署简单，直接复制 `.workflow` 到 `~/Library/Services/`
- 对于"运行脚本并写剪贴板"这个需求，Automator 完全够用

### 构建流程

workflow 文件无法通过手写 XML 可靠创建（格式未公开文档化，手写容易导致系统不识别）。实际采用的构建流程：

1. **AppleScript 调 Automator 创建 workflow**：通过 `osascript` 驱动 Automator.app，用 `make new workflow` + `add automator action id "com.apple.RunShellScript"` 创建格式正确的 `.workflow` bundle
2. **plutil 修改元数据**：Automator 默认创建普通 workflow 类型，需要用 `plutil` 修改两个文件：
   - `document.wflow`：将 `workflowMetaData.workflowTypeIdentifier` 从 `com.apple.Automator.workflow` 改为 `com.apple.Automator.servicesMenu`，并补充 `serviceInputTypeIdentifier`、`serviceApplicationBundleID` 等字段
   - `Info.plist`：添加 `NSServices` 数组，声明菜单名称、消息选择器、文件类型过滤和应用限定
3. **刷新服务缓存**：执行 `/System/Library/CoreServices/pbs -flush` 让系统重新扫描注册的 Services

### 架构

项目提供中英文两套 workflow，安装脚本通过 `defaults read -g AppleLanguages` 检测系统语言，自动选择对应版本安装。

```
~/Library/Services/
├── Copy Absolute Path.workflow/        # 英文系统
├── Copy Relative Path.workflow/        # 英文系统
├── 复制绝对路径.workflow/                # 中文系统
└── 复制相对路径.workflow/                # 中文系统
```

每个 workflow 内部结构相同：

```
*.workflow/
└── Contents/
    ├── Info.plist              # 服务注册声明
    ├── document.wflow          # workflow 定义（含 shell script）
    └── QuickLook/
        └── Thumbnail.png       # Automator 自动生成的缩略图
```

### 核心逻辑

**复制绝对路径：**
```bash
# Automator 将选中文件的路径作为 $@ 参数传入
paths=""
for f in "$@"; do
    if [ -n "$paths" ]; then
        paths="$paths
$f"
    else
        paths="$f"
    fi
done
osascript -e "set the clipboard to \"$paths\""
```

**复制相对路径：**
```bash
# 1. 通过 AppleScript 获取 Finder 当前目录
base_dir=$(osascript -e 'tell application "Finder" to get POSIX path of (insertion location as alias)')
base_dir="${base_dir%/}"

# 2. 用 python3 计算相对路径（比 bash 字符串处理更可靠）
for f in "$@"; do
    rel=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$f" "$base_dir")
    ...
done

# 3. 通过 AppleScript 写入剪贴板
osascript -e "set the clipboard to \"$paths\""
```

### 关键设计决策

**为什么用 `osascript` 写剪贴板而不是 `pbcopy`：**
Automator Quick Action 在沙箱环境中执行 shell script，`pbcopy` 无法写入系统剪贴板（写入后 Cmd+V 粘贴为空）。`osascript -e "set the clipboard to ..."` 走的是 AppleScript 通道，不受此限制。

**为什么用 `python3 os.path.relpath` 而不是 bash 字符串处理：**
`os.path.relpath` 能正确处理跨层级路径（如 `../../other/dir`），bash 的 `${f#$base_dir}` 只能处理简单的前缀剥离。

**为什么 `inputMethod` 设为 1（作为参数）而不是 0（作为 stdin）：**
作为参数传入时，每个选中文件的完整 POSIX 路径作为独立参数，处理多选更直观，不需要额外分隔符解析。

### workflow 关键配置

**Info.plist** - 向系统注册服务：
- `NSMenuItem.default`：菜单显示名称
- `NSSendFileTypes: [public.item]`：接受任何文件/文件夹
- `NSRequiredContext.NSApplicationIdentifier: com.apple.finder`：仅在 Finder 中显示
- `NSMessage: runWorkflowAsService`：系统调用 workflow 的消息选择器

**document.wflow** - Automator workflow 定义：
- `workflowTypeIdentifier: com.apple.Automator.servicesMenu`：声明为服务菜单类型
- `serviceInputTypeIdentifier: com.apple.Automator.fileSystemObject`：输入类型为文件系统对象
- `serviceApplicationBundleID: com.apple.finder`：限定 Finder 应用
- Run Shell Script action，`inputMethod: 1`（作为参数传入），`shell: /bin/bash`

## 安装与分发

提供 `install.command` 脚本一键安装：自动检测系统语言，复制对应语言版本的 workflow 到 `~/Library/Services/`，刷新服务缓存。安装前会清理中英文两个版本的旧文件，避免残留。

也可手动从 `workflows/en/` 或 `workflows/zh-CN/` 中选择对应版本 `cp -r` 安装。

## 已知限制

1. 出现在「快速操作」子菜单中，不是右键菜单顶层（macOS 限制，只有 Finder Sync Extension 才能做到顶层，但需要 Xcode 签名和完整 App 包装）
2. 相对路径依赖 `python3`（macOS 自带，但理论上用户可能卸载了 Command Line Tools）
3. 首次使用可能弹出权限请求（Automator 访问 Finder）
4. 路径中包含双引号 `"` 时可能导致 AppleScript 剪贴板写入异常（极少见场景）

## 兼容性

- macOS 12 Monterey 及以上
- 已在 macOS 15 Sequoia 验证通过
