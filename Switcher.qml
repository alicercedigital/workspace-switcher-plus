import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// The bar pill: DMS's workspace switcher for Hyprland (same settings and colors),
// plus the empty-workspace button on hover, the app context menu and middle-click close.
Item {
    id: root

    property var host: null
    property bool vertical: false

    readonly property string pluginId: "workspaceSwitcherPlus"
    // The plugin's own settings (Settings.qml); the stock workspace options stay in DMS's Workspaces page
    property var options: SettingsData.getPluginSettingsForPlugin(pluginId)

    // The stock switcher's options live in each widget's own entry since DMS 2.0, with its defaults as the fallback
    function stock(key) {
        return SettingsData.widgetOption("workspaceSwitcher", host?.widgetData, key);
    }

    function opt(key, fallback) {
        const value = options?.[key];
        return value === undefined || value === null ? fallback : value;
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root.options = SettingsData.getPluginSettingsForPlugin(root.pluginId);
        }
    }

    onOptionsChanged: schedule()

    readonly property string screenName: host?.parentScreen?.name ?? ""
    readonly property real thickness: host?.widgetThickness ?? 30
    readonly property var barConfig: host?.barConfig ?? null
    // The bar's "widget transparency" setting, as the other widgets' backgrounds use it
    readonly property real backgroundOpacity: barConfig?.widgetTransparency ?? 1.0
    readonly property bool showApps: root.stock("showWorkspaceApps")
    readonly property real appIconSize: Theme.barIconSize(host?.barThickness ?? 48, -6 + root.stock("workspaceAppIconSizeOffset"), barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
    readonly property real pillLong: Math.max(thickness * 0.7, appIconSize * 1.2)
    // Space between a pill's edge and its icons
    readonly property real pillPadding: Math.round(appIconSize * opt("padding", 35) / 100)
    readonly property real pillShort: showApps ? Math.max(thickness * 0.7, appIconSize + Theme.spacingXS * 2) : thickness * 0.5

    // What the pills show; rebuilt, debounced, by rebuild()
    property var ids: []
    property var byId: ({})
    property int activeId: 1
    // The workspace after the highest one, where the button goes; -1 hides it
    property int emptyTarget: -1
    readonly property bool showAdd: (hover.hovered || popHover.hovered || dragging) && emptyTarget > 0 && opt("showAddButton", true)

    // An icon being dragged to another workspace: dragTarget is the workspace under it,
    // or emptyTarget over the + button, or -1
    property bool dragging: false
    property var dragApp: null
    property int dragTarget: -1

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function modeColor(mode, fallback, custom) {
        switch (mode) {
        case "primary":
        case "pri":
            return Theme.primary;
        case "primaryContainer":
            return Theme.primaryContainer;
        case "secondary":
        case "sec":
            return Theme.secondary;
        case "secondaryContainer":
            return Theme.secondaryContainer;
        case "tertiary":
        case "ter":
            return Theme.tertiary;
        case "tertiaryContainer":
            return Theme.tertiaryContainer;
        case "surfaceText":
            return Theme.surfaceText;
        case "s":
            return Theme.surface;
        case "sc":
            return Theme.surfaceContainer;
        case "sch":
            return Theme.surfaceContainerHigh;
        case "schh":
            return Theme.surfaceContainerHighest;
        case "error":
        case "err":
            return Theme.error;
        case "custom":
            return Theme.safeColor(custom, fallback);
        default:
            return fallback;
        }
    }

    readonly property color unfocusedColor: modeColor(root.stock("workspaceUnfocusedColorMode"), Theme.surfaceTextAlpha, root.stock("workspaceUnfocusedCustomColor"))
    readonly property color activeColor: {
        const mode = root.stock("workspaceColorMode");
        return mode === "none" ? unfocusedColor : modeColor(mode, Theme.primary, root.stock("workspaceFocusedCustomColor"));
    }
    readonly property color occupiedColor: {
        const mode = root.stock("workspaceOccupiedColorMode");
        return mode === "none" ? unfocusedColor : modeColor(mode, unfocusedColor, root.stock("workspaceOccupiedCustomColor"));
    }
    readonly property color urgentColor: modeColor(root.stock("workspaceUrgentColorMode"), Theme.error, root.stock("workspaceUrgentCustomColor"))
    readonly property color borderColor: modeColor(root.stock("workspaceFocusedBorderColor"), Theme.primary, root.stock("workspaceFocusedBorderCustomColor"))

    // The accent when it stands out from the pill under it, else a plain dark or light
    function contrastOn(accent, base) {
        const baseLight = Theme.isLightColor(base, 0.4);
        if (Theme.isLightColor(accent, 0.4) !== baseLight)
            return accent;
        return baseLight ? Qt.rgba(0.15, 0.15, 0.15, 1) : Qt.rgba(0.9, 0.9, 0.9, 1);
    }

    function appKey(w) {
        return Paths.moddedAppId(w.appId || "unknown");
    }

    function rebuild() {
        const toplevels = Array.from(Hyprland.toplevels?.values || []);
        const occupiedIds = {};
        toplevels.forEach(tl => {
            if (tl.workspace)
                occupiedIds[tl.workspace.id] = true;
        });

        const monitors = Array.from(Hyprland.monitors?.values || []);
        const own = monitors.find(m => m.name === screenName);
        const global = !screenName || root.stock("workspaceFollowFocus");
        const active = (global ? Hyprland.focusedWorkspace?.id : own?.activeWorkspace?.id) || 1;

        // Named workspaces have negative ids and are left to the stock switcher
        const real = Array.from(Hyprland.workspaces?.values || []).filter(ws => ws.id > 0);
        const wsById = {};
        real.forEach(ws => wsById[ws.id] = ws);

        let list = global ? real : real.filter(ws => ws.monitor?.name === screenName);
        let order = list.map(ws => ws.id).sort((a, b) => a - b);
        if (!order.length)
            order = [active];
        if (root.stock("showOccupiedWorkspacesOnly"))
            order = order.filter(id => id === active || occupiedIds[id]);
        if (root.stock("showWorkspacePadding")) {
            let next = Math.max(...order);
            while (order.length < 3)
                order.push(++next);
        }

        const entries = {};
        order.forEach(id => {
            entries[id] = {
                "id": id,
                "active": id === active,
                "occupied": !!occupiedIds[id],
                "urgent": wsById[id]?.urgent ?? false,
                "icons": []
            };
        });

        if (showApps) {
            const perApp = {};
            // DMS's sorted list keeps the order; each window is matched to Hyprland's by the window
            // itself, since the `address` DMS stamps on it can still be empty a while after startup
            (CompositorService.sortedToplevels || []).forEach(w => {
                const hypr = toplevels.find(t => t.wayland === w);
                const wsId = hypr?.workspace?.id;
                const entry = entries[wsId];
                if (!entry)
                    return;
                const address = hypr.address;
                const modded = appKey(w);
                const grouped = root.stock("groupWorkspaceApps") && (!entry.active || root.stock("groupActiveWorkspaceApps"));
                const key = wsId + "|" + (grouped ? modded : address);
                let app = perApp[key];
                if (!app) {
                    const desktopEntry = DesktopEntries.heuristicLookup(modded);
                    app = {
                        "key": key,
                        "appId": modded,
                        "name": Paths.getAppName(modded, desktopEntry) || modded,
                        "icon": Paths.getAppIcon(modded, desktopEntry),
                        "isQuickshell": modded === "org.quickshell" || modded === "com.danklinux.dms",
                        "isSteamApp": Paths.isSteamApp(modded),
                        "active": false,
                        "windows": []
                    };
                    perApp[key] = app;
                    entry.icons.push(app);
                }
                app.windows.push({
                    "address": address,
                    "title": w.title || "",
                    "activated": !!w.activated
                });
                if (w.activated)
                    app.active = true;
            });
        }

        // "end": after the highest workspace in use, so a new one always lands at the end;
        // hidden when the active workspace is itself the empty one at the end.
        // "next": the first workspace right of the active one with no windows, shown nowhere.
        let last = 0;
        real.forEach(ws => last = Math.max(last, ws.id));
        Object.keys(occupiedIds).forEach(id => last = Math.max(last, Number(id)));
        monitors.forEach(m => last = Math.max(last, m.activeWorkspace?.id ?? 0));
        let target = last + 1;
        let usable = occupiedIds[active] || active < last;
        if (opt("addTarget", "end") === "next") {
            const shown = {};
            monitors.forEach(m => shown[m.activeWorkspace?.id] = true);
            target = active + 1;
            while (occupiedIds[target] || shown[target])
                target++;
            usable = !!occupiedIds[active];
        }

        byId = entries;
        activeId = active;
        emptyTarget = usable ? target : -1;
        ids = order;
    }

    Timer {
        id: debounce
        interval: 40
        onTriggered: root.rebuild()
    }

    function schedule() {
        debounce.restart();
    }

    Component.onCompleted: rebuild()

    // Anything that changes the pills; the settings read by rebuild() are joined in one key
    readonly property string settingsKey: [root.stock("showWorkspaceApps"), root.stock("groupWorkspaceApps"), root.stock("groupActiveWorkspaceApps"), root.stock("workspaceFollowFocus"), root.stock("showOccupiedWorkspacesOnly"), root.stock("showWorkspacePadding")].join()
    onSettingsKeyChanged: schedule()

    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() {
            root.schedule();
        }
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            root.schedule();
        }
    }

    // A window's workspace, and its link to the Wayland window, arrive from Hyprland a moment
    // after the window itself, without the list changing: rebuild when any of them lands or moves
    Instantiator {
        model: Hyprland.toplevels

        delegate: QtObject {
            required property var modelData
            readonly property var workspace: modelData?.workspace
            readonly property var wayland: modelData?.wayland
            onWorkspaceChanged: root.schedule()
            onWaylandChanged: root.schedule()
        }
    }

    // And once more shortly after loading, in case the first rebuild ran before any of that
    Timer {
        interval: 1500
        running: true
        onTriggered: root.rebuild()
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            root.schedule();
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.schedule();
        }
        function onRawEvent(event) {
            switch (event.name) {
            case "activewindowv2":
            case "workspacev2":
            case "focusedmonv2":
            case "movewindowv2":
            case "urgent":
                root.schedule();
            }
        }
    }

    function focusWorkspace(id) {
        HyprlandService.focusWorkspace(id);
    }

    // Left-click on an icon: focus its window; on a group, the next window after the focused one
    function focusApp(app) {
        if (!app || !app.windows.length)
            return;
        const at = app.windows.findIndex(w => w.activated);
        HyprlandService.focusWindow(app.windows[(at + 1) % app.windows.length].address);
    }

    // Middle-click on an icon: close that app's window; on a group, only the focused one
    function closeApp(app) {
        if (!app || !app.windows.length || !opt("middleClickClose", true))
            return;
        if (opt("groupClose", "focused") === "all") {
            app.windows.forEach(w => HyprlandService.closeWindow(w.address));
            return;
        }
        HyprlandService.closeWindow((app.windows.find(w => w.activated) ?? app.windows[0]).address);
    }

    function pointIn(item, x, y) {
        const p = root.mapToItem(item, x, y);
        return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height;
    }

    // The icon follows the pointer; the pill or + button under it becomes the drop target
    function dragStep(app, x, y, fromWorkspace) {
        dragApp = app;
        dragging = true;
        dragProxy.x = x - dragProxy.width / 2;
        dragProxy.y = y - dragProxy.height / 2;
        let target = -1;
        for (let i = 0; i < pillRepeater.count; i++) {
            const item = pillRepeater.itemAt(i);
            if (item && item.modelData !== fromWorkspace && pointIn(item, x, y)) {
                target = item.modelData;
                break;
            }
        }
        if (target < 0 && showAdd && emptyTarget !== fromWorkspace && pointIn(addButton, x, y))
            target = emptyTarget;
        dragTarget = target;
    }

    function dragCancel() {
        dragging = false;
        dragApp = null;
        dragTarget = -1;
    }

    // Dropped on a workspace: every window of the icon goes there
    function dragDrop() {
        const app = dragApp;
        const target = dragTarget;
        dragCancel();
        if (!app || target < 0)
            return;
        const follow = target === emptyTarget;
        app.windows.forEach(w => HyprlandService.moveToWorkspace(target, w.address, follow));
    }

    function openMenu(app, item) {
        if (!opt("contextMenu", true))
            return;
        menuLoader.active = true;
        const menu = menuLoader.item;
        if (!menu)
            return;
        menu.open(app, item);
    }

    Loader {
        id: menuLoader
        active: false
        sourceComponent: WindowMenu {
            host: root.host
            switcher: root
            onDismissed: Qt.callLater(() => menuLoader.active = false)
        }
    }

    HoverHandler {
        id: hover
    }

    // The icon under the pointer while dragging
    Item {
        id: dragProxy
        visible: root.dragging
        width: root.appIconSize * 1.15
        height: width
        z: 100
        opacity: 0.9

        IconImage {
            anchors.fill: parent
            source: root.dragApp?.icon ?? ""
        }
    }

    Grid {
        id: layout
        columns: 1
        spacing: 0

        Grid {
            id: pills
            columns: root.vertical ? 1 : Math.max(1, root.ids.length)
            spacing: Theme.spacingS

            Repeater {
                id: pillRepeater
                model: ScriptModel {
                    values: root.ids
                }

                delegate: Item {
                    id: pill

                    required property int modelData

                    readonly property var entry: root.byId[modelData] ?? null
                    readonly property bool isActive: entry?.active ?? false
                    readonly property bool isOccupied: entry?.occupied ?? false
                    readonly property bool isUrgent: entry?.urgent ?? false
                    readonly property var iconKeys: (entry?.icons ?? []).slice(0, root.stock("maxWorkspaceIcons")).map(i => i.key)
                    readonly property bool hasLabel: root.stock("showWorkspaceIndex")
                    readonly property bool isDropTarget: root.dragging && root.dragTarget === modelData

                    // Same size active or not: the icons plus an even padding. An empty workspace is a plain pill.
                    readonly property real contentLong: root.vertical ? content.implicitHeight : content.implicitWidth
                    readonly property real visualLong: contentLong <= 0 ? root.pillLong : contentLong + root.pillPadding * 2
                    readonly property real visualShort: root.pillShort

                    readonly property color requestedColor: isActive ? root.activeColor : isUrgent ? root.urgentColor : isOccupied ? root.occupiedColor : root.unfocusedColor
                    readonly property color labelColor: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : Theme.surfaceTextMedium

                    width: root.vertical ? root.thickness : visualLong
                    height: root.vertical ? visualLong : root.thickness

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Rectangle {
                        id: body
                        anchors.centerIn: parent
                        width: root.vertical ? pill.visualShort : pill.width
                        height: root.vertical ? pill.height : pill.visualShort
                        radius: Theme.cornerRadius
                        color: Theme.blendAlpha(pill.requestedColor, root.backgroundOpacity)
                        border.width: pill.isDropTarget ? 2 : (root.stock("workspaceFocusedBorderEnabled") && pill.isActive ? root.stock("workspaceFocusedBorderThickness") : 0)
                        border.color: pill.isDropTarget ? Theme.primary : root.borderColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }

                    // Clicking the pill outside its icons goes to the workspace
                    MouseArea {
                        id: slot
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWorkspace(pill.modelData)
                    }

                    Grid {
                        id: content
                        anchors.centerIn: body
                        columns: root.vertical ? 1 : Math.max(1, pill.iconKeys.length + (pill.hasLabel ? 1 : 0))
                        spacing: Theme.spacingXS

                        StyledText {
                            visible: pill.hasLabel
                            text: pill.modelData
                            color: pill.labelColor
                            font.pixelSize: Theme.barTextSize(host?.barThickness ?? 48, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                            font.weight: pill.isActive ? Math.max(Theme.fontWeight, Font.DemiBold) : Theme.fontWeight
                        }

                        Repeater {
                            model: ScriptModel {
                                values: pill.iconKeys
                            }

                            delegate: Item {
                                id: appItem

                                required property string modelData

                                readonly property var app: pill.entry?.icons.find(i => i.key === modelData) ?? null
                                readonly property real appOpacity: app?.active || !root.opt("dimInactiveApps", true) ? 1.0 : appArea.containsMouse ? 0.8 : 0.6

                                // How the focused app is marked: none, dot, bar, ring, background or larger
                                readonly property string mark: root.opt("activeIndicator", "dot")
                                readonly property bool marked: (app?.active ?? false) && mark !== "none"
                                readonly property color markColor: root.contrastOn(Theme.primary, pill.requestedColor)
                                readonly property real markThickness: Math.max(3, Math.round(root.appIconSize / 8))

                                width: root.appIconSize
                                height: root.appIconSize
                                scale: marked && mark === "larger" ? 1.15 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }

                                // background: a soft chip behind the icon
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 6
                                    height: parent.height + 6
                                    radius: Theme.cornerRadius * (root.appIconSize / 40) + 2
                                    color: Theme.isLightColor(pill.requestedColor, 0.4) ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.16)
                                    opacity: appItem.marked && appItem.mark === "background" ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                        }
                                    }
                                }

                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: appItem.app?.icon ?? ""
                                    opacity: appItem.appOpacity
                                    visible: !(appItem.app?.isQuickshell ?? false) && status === Image.Ready
                                }

                                IconImage {
                                    anchors.fill: parent
                                    source: appItem.app?.icon ?? ""
                                    opacity: appItem.appOpacity
                                    visible: appItem.app?.isQuickshell ?? false
                                    layer.enabled: visible
                                    layer.effect: MultiEffect {
                                        saturation: 0
                                        colorization: 1
                                        colorizationColor: Theme.isLightColor(pill.requestedColor, 0.4) ? Qt.rgba(0.15, 0.15, 0.15, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                                    }
                                }

                                // No icon file: a steam controller, or the app's first letter
                                DIcon {
                                    anchors.centerIn: parent
                                    size: root.appIconSize
                                    name: "sports_esports"
                                    color: Theme.primary
                                    opacity: appItem.appOpacity
                                    visible: !(appItem.app?.isQuickshell ?? false) && appIcon.status !== Image.Ready && (appItem.app?.isSteamApp ?? false)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: !(appItem.app?.isQuickshell ?? false) && appIcon.status !== Image.Ready && !(appItem.app?.isSteamApp ?? false)
                                    color: Theme.surfaceContainer
                                    radius: Theme.cornerRadius * (root.appIconSize / 40)
                                    border.width: 1
                                    border.color: Theme.primarySelected
                                    opacity: appItem.appOpacity

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: (appItem.app?.name || "?").charAt(0).toUpperCase()
                                        font.pixelSize: parent.width * 0.45
                                        color: Theme.primary
                                        font.weight: Font.Bold
                                    }
                                }

                                // dot and bar: in the pill's padding, under the icon (beside it on a vertical bar)
                                Rectangle {
                                    readonly property bool bar: appItem.mark === "bar"

                                    x: root.vertical ? parent.width + 1 : (parent.width - width) / 2
                                    y: root.vertical ? (parent.height - height) / 2 : parent.height + 1
                                    width: root.vertical ? appItem.markThickness : (bar ? Math.round(root.appIconSize * 0.45) : appItem.markThickness)
                                    height: root.vertical ? (bar ? Math.round(root.appIconSize * 0.45) : appItem.markThickness) : appItem.markThickness
                                    radius: Math.min(width, height) / 2
                                    color: appItem.markColor
                                    opacity: appItem.marked && (appItem.mark === "dot" || appItem.mark === "bar") ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                        }
                                    }
                                }

                                // ring: a border around the icon, in the color DMS uses for the focused border
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 4
                                    height: parent.height + 4
                                    radius: Theme.cornerRadius * (root.appIconSize / 40) + 2
                                    color: "transparent"
                                    border.width: Math.max(1, Math.round(root.appIconSize / 14))
                                    border.color: root.contrastOn(root.borderColor, pill.requestedColor)
                                    opacity: appItem.marked && appItem.mark === "ring" ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: (appItem.app?.windows.length ?? 0) > 1 && !pill.isActive
                                    width: root.appIconSize * 0.67
                                    height: root.appIconSize * 0.67
                                    radius: root.appIconSize * 0.33
                                    color: "black"
                                    border.color: "white"
                                    border.width: 1
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    z: 2

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: appItem.app?.windows.length ?? ""
                                        font.pixelSize: root.appIconSize * 0.44
                                        color: "white"
                                    }
                                }

                                MouseArea {
                                    id: appArea

                                    property bool pressedLeft: false
                                    property bool moved: false
                                    property point start

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onPressed: mouse => {
                                        pressedLeft = mouse.button === Qt.LeftButton;
                                        moved = false;
                                        start = mapToItem(root, mouse.x, mouse.y);
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressedLeft || !appItem.app || !root.opt("dragToMove", true))
                                            return;
                                        const at = mapToItem(root, mouse.x, mouse.y);
                                        if (!moved && Math.hypot(at.x - start.x, at.y - start.y) < 6)
                                            return;
                                        moved = true;
                                        root.dragStep(appItem.app, at.x, at.y, pill.modelData);
                                    }
                                    onReleased: {
                                        if (moved)
                                            root.dragDrop();
                                        pressedLeft = false;
                                    }
                                    onCanceled: {
                                        root.dragCancel();
                                        pressedLeft = false;
                                    }
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton)
                                            root.openMenu(appItem.app, appItem);
                                        else if (mouse.button === Qt.MiddleButton)
                                            root.closeApp(appItem.app);
                                        else if (!moved)
                                            root.focusApp(appItem.app);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Pops out past the widget's end on hover, drawn over the bar's free space, so the
    // widget itself never changes size. It starts flush against the widget: the first
    // spacingS is transparent, so crossing to the button never leaves the hover.
    Item {
        id: addPop

        x: root.vertical ? (root.width - width) / 2 : root.width
        y: root.vertical ? root.height : (root.height - height) / 2
        width: root.vertical ? root.thickness : Theme.spacingS + root.pillLong
        height: root.vertical ? Theme.spacingS + root.pillLong : root.thickness
        // Always there (but only the hover is live while the button is hidden), so
        // pointing straight at where the button appears is enough to bring it out
        visible: root.emptyTarget > 0 && root.opt("showAddButton", true)

        HoverHandler {
            id: popHover
        }

        Rectangle {
            id: addButton
            x: root.vertical ? (parent.width - width) / 2 : Theme.spacingS
            y: root.vertical ? Theme.spacingS : (parent.height - height) / 2
            width: root.vertical ? root.pillShort : root.pillLong
            height: root.vertical ? root.pillLong : root.pillShort
            radius: Theme.cornerRadius
            opacity: root.showAdd ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            color: Theme.blendAlpha(root.dragTarget === root.emptyTarget && root.dragging ? root.activeColor : root.unfocusedColor, root.backgroundOpacity)
            border.width: root.dragging && root.dragTarget === root.emptyTarget ? 2 : 0
            border.color: Theme.primary

            DIcon {
                anchors.centerIn: parent
                name: "add"
                size: Math.min(root.appIconSize, Math.min(parent.width, parent.height) - 4)
                color: root.dragging && root.dragTarget === root.emptyTarget ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : Theme.surfaceTextMedium
            }

            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.showAdd
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusWorkspace(root.emptyTarget)
            }
        }
    }

    // Wheel over the widget steps through this monitor's workspaces. A handler, not a MouseArea
    // over everything: a MouseArea on top would take over the cursor from the buttons below it.
    Timer {
        id: cooldown
        interval: 100
        onTriggered: wheelHandler.cooling = false
    }

    WheelHandler {
        id: wheelHandler

        property real accumulated: 0
        property bool cooling: false

        enabled: root.opt("wheelSwitch", true)
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) || cooling)
                return;
            accumulated += event.angleDelta.y * (root.stock("reverseScrolling") ? -1 : 1);
            if (Math.abs(accumulated) < 120)
                return;
            HyprlandService.focusWorkspace(accumulated > 0 ? "e-1" : "e+1");
            accumulated = 0;
            cooling = true;
            cooldown.restart();
        }
    }
}
