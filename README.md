# Finder Copy Path

[中文文档](./README.zh-CN.md)

A macOS Finder context menu extension for copying file paths with one click. Supports both absolute and relative paths.

By default, macOS requires Option+Right Click to copy a path, and only supports absolute paths. With this tool:

- Right Click → Quick Actions → **Copy Absolute Path** (e.g. `/Users/you/Documents/file.txt`)
- Right Click → Quick Actions → **Copy Relative Path** (e.g. `subfolder/file.txt`, relative to the current Finder directory)

Supports multiple selection — paths are separated by newlines. Just Cmd+V to paste.

## Installation

### Option 1: Command Line (Recommended)

```bash
git clone https://github.com/zephryve/finder-copy-path.git
bash finder-copy-path/install.command
```

Or double-click `install.command` in Finder — it will open Terminal and run the installer automatically.

### Option 2: Manual Installation

1. Download and extract this repository
2. In Finder, press **Cmd+Shift+G**, type `~/Library/Services/` and hit Enter
3. Drag the two `.workflow` folders from `workflows/` into that directory
4. Open Terminal and run:

```bash
/System/Library/CoreServices/pbs -flush
```

If the options don't appear in the context menu, log out and back in.

## Usage

Select files or folders in Finder → **Right Click** → **Quick Actions** → Choose "Copy Absolute Path" or "Copy Relative Path".

The path is now on your clipboard. Cmd+V to paste.

## Uninstall

```bash
rm -rf ~/Library/Services/复制绝对路径.workflow
rm -rf ~/Library/Services/复制相对路径.workflow
```

## FAQ

**No "Quick Actions" in the context menu?**

Make sure both `.workflow` files are in `~/Library/Services/`, then run `/System/Library/CoreServices/pbs -flush` in Terminal. If that doesn't work, log out and back in.

**Nothing happens after clicking, clipboard is empty?**

The first time you use it, macOS may prompt for permissions — allow it. If no prompt appears, go to System Settings → Privacy & Security → Automation, and manually enable Automator's access to Finder.

**Relative path seems wrong?**

The relative path is based on the current Finder window's directory. If you navigated via search results, Finder's "current directory" may not be what you expect.

## Compatibility

- macOS 12 Monterey and above (verified on macOS 15 Sequoia)
- Relative path feature uses the built-in `python3`
- No third-party software required

<details>
<summary><strong>Technical Details</strong></summary>

### How It Works

Built on macOS Automator Quick Actions (Services menu). The workflows are created natively by Automator (not hand-written XML), then metadata is modified via `plutil` to convert regular workflows into Quick Action type.

### Key Design Decisions

**Clipboard write uses `osascript` instead of `pbcopy`:** Automator Quick Actions run shell scripts in a sandboxed environment where `pbcopy` cannot write to the system-wide clipboard. `osascript -e "set the clipboard to ..."` uses the AppleScript channel, which is not affected by this limitation.

**Relative path uses `python3 os.path.relpath`:** Correctly handles cross-level paths (e.g. `../../other/dir`), more reliable than bash string prefix stripping.

**Shell script input method set to "as arguments" (inputMethod: 1):** Each selected file's full POSIX path is passed as a separate argument, making multi-selection handling more straightforward.

### Project Structure

```
finder-copy-path/
├── README.md               # English documentation
├── README.zh-CN.md         # Chinese documentation
├── PRD.md                  # Product requirements doc
├── DEVLOG.md               # Development log
├── install.command
└── workflows/
    ├── 复制绝对路径.workflow/
    │   └── Contents/
    │       ├── Info.plist
    │       ├── document.wflow
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

## Contact

Issues or suggestions: zephryve@gmail.com
