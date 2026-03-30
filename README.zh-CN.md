# Finder Copy Path

[English](./README.md)

macOS Finder 右键菜单扩展：选中文件后一键复制路径，支持绝对路径和相对路径。

macOS 原生需要 Option+右键 才能复制路径，而且只有绝对路径。装上这个小工具后：

- 右键 → 快速操作 → **复制绝对路径**（如 `/Users/you/Documents/file.txt`）
- 右键 → 快速操作 → **复制相对路径**（如 `subfolder/file.txt`，以当前 Finder 目录为基准）

支持多选，多个路径以换行分隔。复制后 Cmd+V 粘贴即可。

## 安装

### 方式一：命令行安装（推荐）

```bash
git clone https://github.com/zephryve/finder-copy-path.git
bash finder-copy-path/install.command
```

或者直接在 Finder 里双击 `install.command`，会自动打开终端执行安装。

### 方式二：手动安装

1. 下载本仓库，解压
2. 打开 Finder，按 **Cmd+Shift+G**，输入 `~/Library/Services/` 回车
3. 把 `workflows/` 下的两个 `.workflow` 文件夹拖进去
4. 打开终端，执行：

```bash
/System/Library/CoreServices/pbs -flush
```

如果右键菜单里没出现，注销重新登录一次即可。

## 使用

在 Finder 中选中文件或文件夹 → **右键** → **快速操作** → 选择「复制绝对路径」或「复制相对路径」。

路径已复制到剪贴板，Cmd+V 粘贴。

## 卸载

```bash
rm -rf ~/Library/Services/复制绝对路径.workflow
rm -rf ~/Library/Services/复制相对路径.workflow
```

## 常见问题

**右键没有「快速操作」菜单？**

确认两个 `.workflow` 在 `~/Library/Services/` 目录下，然后终端执行 `/System/Library/CoreServices/pbs -flush`。还不行就注销重新登录。

**点了没反应，粘贴为空？**

第一次使用可能弹出权限请求，允许即可。如果没弹窗，去 系统设置 → 隐私与安全性 → 自动化，手动开启 Automator 对 Finder 的访问权限。

**相对路径结果不对？**

相对路径以 Finder 当前打开的文件夹为基准。如果你是通过搜索结果点进去的，Finder 的"当前目录"可能不是你预期的位置。

## 兼容性

- macOS 12 Monterey 及以上（已在 macOS 15 Sequoia 验证通过）
- 相对路径功能依赖系统自带的 python3
- 不需要安装任何第三方软件

<details>
<summary><strong>技术实现</strong></summary>

### 原理

基于 macOS Automator Quick Action（服务菜单）。workflow 由 Automator 原生创建（非手写 XML），再通过 `plutil` 修改元数据将普通 workflow 转为 Quick Action 类型。

### 关键设计决策

**剪贴板写入用 `osascript` 而非 `pbcopy`：** Automator Quick Action 在沙箱环境中执行 shell script，`pbcopy` 无法写入系统全局剪贴板。`osascript -e "set the clipboard to ..."` 走 AppleScript 通道，不受此限制。

**相对路径用 `python3 os.path.relpath`：** 能正确处理跨层级路径（如 `../../other/dir`），比 bash 字符串前缀剥离更可靠。

**shell script 输入方式选 "作为参数"（inputMethod: 1）：** 每个选中文件的完整 POSIX 路径作为独立参数，处理多选更直观。

### 项目结构

```
finder-copy-path/
├── README.md               # English documentation
├── README.zh-CN.md         # 中文文档
├── PRD.md              # 产品需求文档
├── DEVLOG.md           # 开发踩坑记录
├── install.command
└── workflows/
    ├── 复制绝对路径.workflow/
    │   └── Contents/
    │       ├── Info.plist          # 服务注册（菜单名、触发条件、文件类型过滤）
    │       ├── document.wflow      # workflow 定义（含 shell script）
    │       └── QuickLook/
    │           └── Thumbnail.png
    └── 复制相对路径.workflow/
        └── Contents/
            ├── Info.plist
            ├── document.wflow
            └── QuickLook/
                └── Thumbnail.png
```

</details>

## 联系

问题或建议：zephryve@gmail.com
