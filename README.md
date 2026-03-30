<h1 align="center">
  <img src="docs/icon.png" alt="copippe" width="128">
  <br>
  copippe
  <br>
  <br>
</h1>

<p align="center">
  A simple, lightweight clipboard tool for macOS that lives in your menu bar.
</p>

<p align="center">
  <a href="https://github.com/yoshidashingo/copippe/releases/latest"><img src="https://img.shields.io/github/v/release/yoshidashingo/copippe?v=1" alt="release"></a>
  <a href="https://github.com/yoshidashingo/copippe/blob/main/LICENSE"><img src="https://img.shields.io/github/license/yoshidashingo/copippe?v=1" alt="license"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="platform">
  <img src="https://img.shields.io/badge/swift-6-orange" alt="swift">
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README-ja.md">日本語</a>
</p>

## Features

### Clipboard
- **Plain Text Paste** — When activated, automatically strips rich text formatting (HTML, RTF) on copy, so you always paste clean, plain text
- **Clipboard History** — Access up to 30 recent clipboard entries (text and images) from the menu bar dropdown. Limit is configurable in Preferences.
- **Image Support** — Copied images are saved as PNG thumbnails and can be restored to the clipboard
- **Persistent History** — Clipboard history is saved and restored across app restarts

### Snippets
- **Snippet Manager** — Register, edit, and organize frequently used text snippets
- **Folder Organization** — Group snippets into folders for easy access
- **Menu Bar Access** — Quickly paste snippets from the menu bar dropdown via folder submenus

### Search & Quick Access
- **Global Hotkey** — Press Ctrl+Option+V from any app to open the floating search popup
- **Popup Window** — A floating panel with incremental search across history and snippets, keyboard navigation, and tab switching
- **Per-Snippet Hotkeys** — Assign individual global hotkeys to paste specific snippets instantly

### General
- **Menu Bar Resident** — Runs quietly in the menu bar with no Dock icon
- **Preferences** — Configure history limit, hotkeys, startup behavior, and manage snippets from a dedicated settings window
- **Auto Launch** — Optionally starts at login via macOS Login Items
- **Minimal Footprint** — Built with Swift and SwiftUI for low memory usage

## Requirements

- macOS 14 (Sonoma) or later

## Installation

1. Download the latest version from the **[Releases page](https://github.com/yoshidashingo/copippe/releases/latest)**:
   - [`copippe-v0.2-macOS.zip`](https://github.com/yoshidashingo/copippe/releases/latest/download/copippe-v0.2-macOS.zip) — Zip archive
   - [`copippe-v0.2-macOS.dmg`](https://github.com/yoshidashingo/copippe/releases/latest/download/copippe-v0.2-macOS.dmg) — Disk image
2. Open the `.zip` or `.dmg` and move `copippe.app` to your Applications folder
3. Launch copippe

> **Note**: This app is not notarized. On first launch, macOS will block it. To open it:
>
> **Option A** (Terminal):
> ```
> xattr -cr /Applications/copippe.app
> ```
> Then launch the app normally.
>
> **Option B** (System Settings):
> 1. Try to open `copippe.app` (it will be blocked)
> 2. Open **System Settings** → **Privacy & Security**
> 3. Scroll down to find the blocked app message and click **Open Anyway**

## Usage

1. Launch copippe — a clipboard icon appears in the menu bar
2. Click the icon to open the dropdown menu
3. **Activate/Deactivate** — Toggle plain text mode on or off
4. **History** — Click any history entry (text or image) to copy it back to your clipboard, then paste with ⌘V
5. **Snippets** — Expand folder submenus to paste registered snippets
6. **Preferences** — Open the settings window to configure hotkeys, history limit, and manage snippets
7. **Ctrl+Option+V** — Open the floating popup from any app to search history and snippets
8. **Clear History** — Remove all saved entries
9. **Quit** — Exit the app

### Menu Bar Icon

| State | Icon |
|-------|------|
| Active | Filled clipboard icon |
| Inactive | Outline clipboard icon |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+Option+V | Open history/snippet popup |
| Esc | Close popup |
| Up/Down | Navigate popup items |
| Enter | Select and paste |

## Building from Source

```bash
git clone https://github.com/yoshidashingo/copippe.git
cd copippe
xcodebuild -project copippe.xcodeproj -scheme copippe -configuration Release build
```

Or open `copippe.xcodeproj` in Xcode and build with ⌘B.

## License

MIT
