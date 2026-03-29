# 开发踩坑记录

> 2026-03-30，macOS 15 Sequoia，用 Claude Code 辅助开发

## 目标

在 Finder 右键菜单中添加「复制绝对路径」和「复制相对路径」。技术方案选的是 Automator Quick Action。

看起来很简单的需求，实际踩了一连串的坑。核心问题是 Automator workflow 的文件格式没有公开文档，只能靠试。

---

## 坑 1：手写 .wflow XML，系统完全不认

### 现象

手动拼了 `Info.plist` 和 `document.wflow` 的 XML，放到 `~/Library/Services/` 后：
- `pbs -dump_pboard` 找不到注册的服务
- 右键菜单无任何变化

### 原因

`.wflow` 文件虽然是 XML/plist 格式，但内部结构复杂且没有官方文档。手写极易出错：
- action 的 UUID、InputUUID、OutputUUID 需要合法值
- `AMAccepts`、`AMProvides` 的 Types 需要和输入类型匹配
- `AMParameterProperties` 的嵌套结构必须完整
- 缺少 Automator 自动填充的隐含字段（如 `AMApplicationBuild`、`conversionLabel` 等）

少了任何一个，macOS 就静默忽略这个 workflow，不报错、不注册。

### 结论

**不要手写 .wflow 文件。** 必须让 Automator.app 自己生成，它会填充所有必要的隐含字段。

---

## 坑 2：AppleScript 操控 Automator 的 API 文档几乎为零

### 现象

尝试用 AppleScript 脚本化创建 Quick Action：

```applescript
make new document with properties {document type:"com.apple.Automator.servicesMenu"}
```

报错：`预期是","或"}"，却找到":"`。

### 原因

Automator 的 AppleScript 字典里，创建文档的命令是 `make new workflow`，不是 `make new document`。而且它不支持通过 `document type` 参数指定类型——只能创建普通 workflow，无法直接创建 Quick Action。

这个 API 极度精简，官方没有任何示例文档。最终只能通过 `plutil -p` 读 Automator 自己的 `.scriptSuite` 和 `.scriptTerminology` 文件来反推可用的命令和属性。

### 排查过程

1. 试了 `document type:"com.apple.Automator.servicesMenu"` → 语法错误
2. 试了 `document type:quick action type` → 语法错误
3. 换 JXA（JavaScript for Automation）→ `documentType: "Quick Action"` → 类型转换错误
4. 读 `/System/Applications/Automator.app/Contents/Resources/Automator.scriptSuite` → 发现正确的术语是 `workflow` 而非 `document`
5. 最终 `make new workflow` 成功

### 结论

Automator 的脚本接口只暴露了最基本的操作：创建 workflow、添加 action、设置 action 参数、保存。不支持设置 workflow 类型、不支持设置输入过滤。这些必须在保存后通过 plutil 修改。

---

## 坑 3：`add` 命令的语法在 AppleScript 和 JXA 中都不一样

### 现象

JXA 写法 `doc.add(app.automatorActions.byId("com.apple.RunShellScript"))` 报「缺少参数」。

### 原因

从 `.scriptTerminology` 读到的 `add` 命令签名是：`add <action> to <workflow>`，需要 `to` 参数指定目标 workflow。

正确的 AppleScript 语法：
```applescript
add automator action id "com.apple.RunShellScript" to myWF
```

JXA 里试了各种写法都有类型转换问题，最后放弃 JXA，纯用 AppleScript 搞定。

---

## 坑 4：`make new workflow` 创建的是普通 workflow，不是 Quick Action

### 现象

AppleScript 成功创建并保存了 `.workflow` 文件，但右键菜单里没有出现。`pbs -dump_pboard` 查不到注册。

### 原因

检查 Automator 生成的文件：

```
# document.wflow 里
workflowMetaData.workflowTypeIdentifier = "com.apple.Automator.workflow"

# Info.plist 里
只有 CFBundleName，没有 NSServices
```

Automator 通过 AppleScript 只能创建普通类型的 workflow。Quick Action（servicesMenu）、Folder Action、Calendar Alarm 等类型，只能通过 Automator GUI 选择。

### 解决

用 `plutil` 对两个文件做后期修改：

**document.wflow：**
```bash
plutil -replace workflowMetaData.workflowTypeIdentifier -string "com.apple.Automator.servicesMenu" "$WFLOW"
plutil -replace workflowMetaData.serviceInputTypeIdentifier -string "com.apple.Automator.fileSystemObject" "$WFLOW"
plutil -replace workflowMetaData.serviceOutputTypeIdentifier -string "com.apple.Automator.nothing" "$WFLOW"
plutil -replace workflowMetaData.serviceProcessesInput -integer 0 "$WFLOW"
plutil -replace workflowMetaData.serviceApplicationBundleID -string "com.apple.finder" "$WFLOW"
plutil -replace workflowMetaData.serviceApplicationPath -string "/System/Library/CoreServices/Finder.app" "$WFLOW"
```

**Info.plist：**
```bash
plutil -replace NSServices -json '[{
  "NSMenuItem": {"default": "复制绝对路径"},
  "NSMessage": "runWorkflowAsService",
  "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
  "NSSendFileTypes": ["public.item"]
}]' "$PLIST"
```

修改后 `pbs -flush`，服务成功注册。

---

## 坑 5：`pbcopy` 在 Automator Quick Action 沙箱里写不了系统剪贴板

### 现象

右键点了 Quick Action，没有报错，但 Cmd+V 粘贴为空。

### 排查

在终端用 `automator -i <file> <workflow>` 测试，`pbpaste` 能读到值。但从 Finder 右键触发时不行。

### 原因

Automator Quick Action 以服务（Service）身份运行，在一个受限的沙箱环境中。`pbcopy` 写入的是该进程的剪贴板上下文，不是系统全局剪贴板。从终端用 `automator` 命令运行时没有沙箱限制，所以测试通过了，但实际从 Finder 触发时就失败。

### 解决

把 `pbcopy` 换成 AppleScript 写剪贴板：

```bash
# 之前（不工作）
echo -n "$paths" | pbcopy

# 之后（工作）
osascript -e "set the clipboard to \"$paths\""
```

`osascript` 走的是 Apple Event 通道，不受沙箱限制，能写入系统全局剪贴板。

### 结论

**Automator Quick Action 里不要用 `pbcopy`/`pbpaste`。** 用 `osascript -e "set the clipboard to ..."` 代替。这是最隐蔽的坑，因为 CLI 测试完全正常，只有从 Finder 实际触发时才会暴露。

---

## 坑 6：服务缓存不会自动刷新

### 现象

`.workflow` 文件放对了、格式也对了，但右键菜单里就是没有。

### 原因

macOS 有一个 `pbs`（Pasteboard Server）进程负责扫描和缓存 `~/Library/Services/` 下的服务。它不会在文件变更时自动重新扫描。

### 解决

```bash
/System/Library/CoreServices/pbs -flush
```

如果还不行，`killall pbs` 让它重启。极端情况下需要注销登录。

---

## 最终有效的构建流程

```
AppleScript 创建基础 workflow（格式正确的 .wflow bundle）
    ↓
plutil 修改 document.wflow（workflow → servicesMenu，补充 service 元数据）
    ↓
plutil 修改 Info.plist（添加 NSServices 注册声明）
    ↓
pbs -flush 刷新服务缓存
    ↓
Finder 右键 → 快速操作 → 可用
```

手写 XML 的路是死路。Automator GUI 手动创建最简单但不可脚本化。上面这条路是唯一可脚本化且可靠的方案。
