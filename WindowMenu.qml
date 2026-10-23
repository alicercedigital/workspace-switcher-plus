import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// Right-click menu of an app icon. Covers the screen so a click outside closes it.
PanelWindow {
    id: win

    property var host: null
    property var switcher: null

    signal dismissed

    // The icon's group: { name, icon, appId, windows: [{ address, title, activated }] }
    property var app: null
    property point anchorPos: Qt.point(0, 0)
    property bool isVertical: false
    property string edge: "top"
    property bool shown: false

    // The window every action but "close all" acts on: the focused one of the group, else its first
    readonly property var target: app ? (app.windows.find(w => w.activated) ?? app.windows[0]) : null
    readonly property var toplevel: target ? Array.from(Hyprland.toplevels?.values || []).find(t => t.address === target.address) : null
    readonly property var ipc: toplevel?.lastIpcObject ?? ({})
    readonly property bool floating: ipc.floating === true
    readonly property bool pinned: ipc.pinned === true
    readonly property bool fullscreen: (ipc.fullscreen ?? 0) > 0
    readonly property int currentWorkspace: toplevel?.workspace?.id ?? -1
    readonly property var desktopEntry: app ? DesktopEntries.heuristicLookup(app.appId) : null
    readonly property var otherWorkspaces: (switcher?.ids ?? []).filter(id => id > 0 && id !== currentWorkspace)
    readonly property real menuHeight: card.height

    WlrLayershell.namespace: "dms:workspace-switcher-plus-menu"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"
    visible: false

    WindowBlur {
        targetWindow: win
        blurX: card.x
        blurY: card.y
        blurWidth: win.shown ? card.width : 0
        blurHeight: win.shown ? card.height : 0
        blurRadius: Theme.cornerRadius
    }

    function open(appData, item) {
        const pos = item.mapToItem(null, item.width / 2, item.height / 2);
        const bar = (host?.barThickness ?? 0) + (host?.barSpacing ?? 0) + Theme.spacingXS;
        const screenWidth = host?.parentScreen?.width ?? Screen.width;
        const screenHeight = host?.parentScreen?.height ?? Screen.height;
        edge = host?.axis?.edge ?? "top";
        isVertical = host?.axis?.isVertical ?? false;
        app = appData;
        if (isVertical)
            anchorPos = Qt.point(edge === "left" ? bar : screenWidth - bar, pos.y);
        else
            anchorPos = Qt.point(pos.x, edge === "bottom" ? screenHeight - bar : bar);
        if (host?.parentScreen)
            screen = host.parentScreen;
        shown = true;
        visible = true;
        if (screen)
            TrayMenuManager.registerMenu(screen.name, win);
    }

    function close() {
        shown = false;
        visible = false;
        if (screen)
            TrayMenuManager.unregisterMenu(screen.name);
        dismissed();
    }

    Component.onDestruction: {
        if (screen)
            TrayMenuManager.unregisterMenu(screen.name);
    }

    Connections {
        target: PopoutManager
        function onPopoutOpening() {
            win.close();
        }
    }

    // Hyprland dispatchers, in Lua and in the classic syntax
    function dispatch(lua, classic) {
        Hyprland.dispatch(HyprlandService.luaConfigActive ? lua : classic);
    }

    function selector() {
        return HyprlandService.windowSelector(target.address);
    }

    function quoted() {
        return HyprlandService.luaString(selector());
    }

    function toggleFloating() {
        dispatch(`hl.dsp.window.float({ action = "toggle", window = ${quoted()} })`, `togglefloating ${selector()}`);
    }

    function togglePinned() {
        dispatch(`hl.dsp.window.pin({ action = "toggle", window = ${quoted()} })`, `pin ${selector()}`);
    }

    function toggleFullscreen() {
        if (HyprlandService.luaConfigActive) {
            Hyprland.dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = ${quoted()} })`);
        } else {
            HyprlandService.focusWindow(target.address);
            Hyprland.dispatch("fullscreen 0");
        }
    }

    function moveTo(id, follow) {
        HyprlandService.moveToWorkspace(id, target.address, follow);
    }

    function forceQuit() {
        const pid = ipc.pid ?? 0;
        if (pid > 0)
            Quickshell.execDetached(["kill", pid.toString()]);
    }

    function closeAll() {
        app.windows.forEach(w => HyprlandService.closeWindow(w.address));
    }

    // Each row: { text, icon, run, danger?, visible? }; a row with `divider` is a rule
    readonly property var rows: {
        if (!app || !target)
            return [];
        const list = [];
        if (desktopEntry) {
            list.push({
                "text": I18n.tr("Open App"),
                "icon": "open_in_new",
                "run": () => desktopEntry.execute()
            });
            (desktopEntry.actions || []).forEach(action => list.push({
                    "text": action.name,
                    "icon": "play_arrow",
                    "run": () => action.execute()
                }));
            list.push({
                "divider": true
            });
        }
        list.push({
            "text": floating ? I18n.tr("Tile") : I18n.tr("Float"),
            "icon": floating ? "grid_view" : "picture_in_picture",
            "run": toggleFloating
        });
        list.push({
            "text": I18n.tr("Fullscreen"),
            "icon": fullscreen ? "fullscreen_exit" : "fullscreen",
            "run": toggleFullscreen
        });
        if (floating)
            list.push({
                "text": pinned ? I18n.tr("Unpin") : I18n.tr("Pin"),
                "icon": "keep",
                "run": togglePinned
            });
        list.push({
            "divider": true
        });
        list.push({
            "text": app.windows.length > 1 ? I18n.tr("Close Window") : I18n.tr("Close"),
            "icon": "close",
            "run": () => HyprlandService.closeWindow(target.address)
        });
        if (app.windows.length > 1)
            list.push({
                "text": I18n.tr("Close All Windows"),
                "icon": "close",
                "run": closeAll
            });
        list.push({
            "text": I18n.tr("Kill Process"),
            "icon": "dangerous",
            "danger": true,
            "visible": (ipc.pid ?? 0) > 0 && (switcher?.opt("killProcess", true) ?? true),
            "run": forceQuit
        });
        return list;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: win.close()
    }

    Rectangle {
        id: card

        readonly property real margin: 10

        x: {
            if (win.isVertical)
                return win.edge === "left" ? Math.min(win.width - width - margin, win.anchorPos.x) : Math.max(margin, win.anchorPos.x - width);
            return Math.max(margin, Math.min(win.width - width - margin, win.anchorPos.x - width / 2));
        }
        y: {
            if (win.isVertical)
                return Math.max(margin, Math.min(win.height - height - margin, win.anchorPos.y - height / 2));
            return win.edge === "bottom" ? win.anchorPos.y - height : win.anchorPos.y;
        }
        width: 230
        height: column.height + Theme.spacingXS * 2
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.width: BlurService.borderWidth
        border.color: BlurService.borderColor

        // Swallows clicks on the card so they don't reach the closing area behind it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        Column {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingXS
            width: parent.width - Theme.spacingXS * 2
            spacing: 1

            Row {
                width: parent.width
                height: 36
                spacing: Theme.spacingS
                leftPadding: Theme.spacingS

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    source: win.app?.icon ?? ""
                    asynchronous: true
                    mipmap: true
                    smooth: true
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - Theme.spacingS * 2

                    StyledText {
                        width: parent.width
                        text: win.app?.name ?? ""
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: win.target?.title ?? ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 2
                        elide: Text.ElideRight
                    }
                }
            }

            Repeater {
                model: win.rows

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property bool isDivider: modelData.divider === true
                    readonly property color tone: modelData.danger ? Theme.error : Theme.widgetTextColor

                    visible: modelData.visible !== false
                    width: column.width
                    height: !visible ? 0 : (isDivider ? 1 + Theme.spacingXS : 28)

                    Rectangle {
                        visible: row.isDivider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    Rectangle {
                        visible: !row.isDivider
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: rowArea.containsMouse ? (row.modelData.danger ? Theme.errorHover : BlurService.hoverColor(Theme.widgetBaseHoverColor)) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.icon ?? ""
                                size: 16
                                color: row.tone
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: row.tone
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                row.modelData.run();
                                win.close();
                            }
                        }
                    }
                }
            }

            // Move the window to another workspace, or to the first empty one on the right
            Item {
                width: column.width
                height: 1 + Theme.spacingXS
                visible: win.otherWorkspaces.length > 0 || (win.switcher?.emptyTarget ?? -1) > 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Theme.outlineVariant
                }
            }

            Item {
                width: column.width
                height: moveFlow.height + Theme.spacingXS * 2
                visible: win.otherWorkspaces.length > 0 || (win.switcher?.emptyTarget ?? -1) > 0

                Flow {
                    id: moveFlow
                    x: Theme.spacingS
                    y: Theme.spacingXS
                    width: parent.width - Theme.spacingS * 2
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Workspaces")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 2
                    }

                    Repeater {
                        model: win.otherWorkspaces

                        delegate: Rectangle {
                            id: chip

                            required property int modelData

                            width: 28
                            height: 24
                            radius: Theme.cornerRadius
                            color: chipArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(Theme.surfaceVariant, 0.5)

                            StyledText {
                                anchors.centerIn: parent
                                text: chip.modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.widgetTextColor
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.moveTo(chip.modelData, false);
                                    win.close();
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: (win.switcher?.emptyTarget ?? -1) > 0 && win.switcher.emptyTarget !== win.currentWorkspace
                        width: 28
                        height: 24
                        radius: Theme.cornerRadius
                        color: newArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(Theme.surfaceVariant, 0.5)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: 16
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: newArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.moveTo(win.switcher.emptyTarget, true);
                                win.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
