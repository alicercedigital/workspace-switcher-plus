# Workspace Switcher Plus

The [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) workspace switcher for Hyprland, plus three things the stock widget lacks.

- **Hover the widget, or the spot where it appears,** and a `+` pops out past its end, over the bar's free space, without a backing strip and without resizing the widget. It goes to the workspace after the highest one, so a new workspace always lands at the end. It is hidden while the active workspace is already the empty one at the end.
- **Right-click an app icon** for a menu: open app and its own `.desktop` actions, float or tile, fullscreen, pin (floating windows), move to another workspace or to the first empty one, close, kill process.
- **Middle-click an app icon** to close that app. When icons are grouped (one icon for several windows of the same app), it closes the focused window of the group, or the first one; the menu has "Close all".

**Drag an app icon** onto another workspace's pill, or onto the `+`, to move the app there: every window the icon stands for goes along. Left-click an icon focuses its window (and cycles through a group), left-click elsewhere on a pill goes to the workspace, the wheel steps through workspaces.

It reads the stock switcher's settings, so Settings → Workspaces still applies: show apps, group apps, icon size and count, index, colors, padding, occupied only, follow focus, and the focused border. Not covered: named workspaces, drag to reorder, and the separate look for unfocused monitors. Hyprland only.

## Settings

Settings → Plugins → Workspace Switcher Plus. Every option is on by default.

- **Empty workspace button**, and **where it goes**: after the last workspace, or the first empty one right of the active workspace.
- **Focused app indicator**: a dot or a bar under the icon, a ring around it, a soft background behind it, a larger icon, or none. Dot by default.
- **Dim inactive apps**: icons of apps that are not focused are translucent, or all solid.
- **Menu on right-click**, and whether it offers **Kill Process**.
- **Close with middle-click**, and what it does on a grouped icon: close the focused window, or all of them.
- **Drag icons to move apps**, and **scroll to switch workspaces**.
- **Pill padding**, as a share of the icon size.

The strings are translated through the DMS translations when it has them, and through `translations/pt.json` otherwise.

## Install

Clone into the plugins folder:

```sh
git clone https://github.com/alicercedigital/workspace-switcher-plus \
  "${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/workspaceSwitcherPlus"
```

You can also link an existing checkout to that path. Scan for the plugin:

```sh
dms ipc call plugin-scan scan
```

After the scan finishes, enable it:

```sh
dms ipc call plugins enable workspaceSwitcherPlus
```

Add **Workspace Switcher Plus** to the bar in Settings → Dank Bar, in place of the stock Workspace Switcher. After editing the QML, run `dms restart`.

Tested on Hyprland with DMS 1.6.2. Check the QML syntax with the `qmllint` from your Qt 6 installation.

## Files

- `WorkspaceSwitcherPlus.qml`: the widget, for horizontal and vertical bars.
- `Switcher.qml`: the pills, the `+` button, the click handling.
- `Settings.qml`: the options above.
- `WindowMenu.qml`: the right-click menu, a layer window like the one in DMS's running apps widget.
