---
name: quickshell-systemtray-patterns
description: "QuickShell SystemTray: UseQApplication pragma for menus, icon property is pre-resolved"
user-invocable: false
origin: auto-extracted
---

# QuickShell SystemTray Patterns

**Extracted:** 2026-03-25
**Context:** Implementing a system tray module in QuickShell bar

## Problem 1: Tray context menus silently fail
`SystemTrayItem.display()` (right-click menu) does nothing. Logs show:
```
ERROR: Cannot display PlatformMenuEntry as quickshell was not started in QApplication mode.
```

## Solution 1: Add UseQApplication pragma
Add to the **root QML file** (e.g., `shell.qml`):
```qml
//@ pragma UseQApplication
```
This must be at the top of the file, before imports. Requires a **full restart** of QuickShell (not just `qs reload`).

## Problem 2: Tray icons show fallback text instead of images
Using `Quickshell.iconPath()` or `"image://icon/" + icon` on `SystemTrayItem.icon` breaks rendering.

## Solution 2: Use icon property directly
`SystemTrayItem.icon` is already a fully resolved image provider URI. Use it directly:
```qml
Image {
    source: trayItem.modelData.icon ?? ""
    // Do NOT wrap in Quickshell.iconPath() or prefix with "image://icon/"
}
```
QuickShell internally resolves IconName → theme lookup and IconPixmap → data URI.

## Problem 3: display() coordinates are wrong
`trayItem.x` is relative to the Row parent, not the panel window, so the menu appears at the wrong position.

## Solution 3: Map coordinates to window space
```qml
let mapped = trayItem.mapToItem(null, 0, 0);
trayItem.modelData.display(panelWindow, mapped.x, barHeight);
```

## When to Use
- Implementing system tray in QuickShell
- Debugging missing tray icons or broken context menus
- Any QuickShell feature requiring platform menus (not just tray)
