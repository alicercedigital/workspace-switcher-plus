import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "workspaceSwitcherPlus"

    function tr(text) {
        return I18n.trFor("workspaceSwitcherPlus", text);
    }

    StyledText {
        width: parent.width
        text: "Workspace Switcher Plus"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: root.tr("Apps, grouping, icon size, colors and the other options of the stock switcher stay in Settings → Workspaces: this widget reads them too.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "showAddButton"
        label: root.tr("Empty workspace button")
        description: root.tr("Hover the widget, or the spot beside it, to bring out a + that goes to a new empty workspace.")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "addTarget"
        label: root.tr("Where the + goes")
        description: root.tr("The workspace after the highest one, or the first empty one to the right of the active workspace.")
        options: [
            {
                label: root.tr("After the last workspace"),
                value: "end"
            },
            {
                label: root.tr("Next to the active workspace"),
                value: "next"
            }
        ]
        defaultValue: "end"
    }

    SelectionSetting {
        settingKey: "activeIndicator"
        label: root.tr("Focused app indicator")
        description: root.tr("How the focused app is marked in its workspace.")
        options: [
            {
                label: root.tr("None"),
                value: "none"
            },
            {
                label: root.tr("Dot below the icon"),
                value: "dot"
            },
            {
                label: root.tr("Bar below the icon"),
                value: "bar"
            },
            {
                label: root.tr("Ring around the icon"),
                value: "ring"
            },
            {
                label: root.tr("Background behind the icon"),
                value: "background"
            },
            {
                label: root.tr("Larger icon"),
                value: "larger"
            }
        ]
        defaultValue: "dot"
    }

    ToggleSetting {
        settingKey: "dimInactiveApps"
        label: root.tr("Dim inactive apps")
        description: root.tr("App icons that are not focused are shown translucent; the focused one stays solid.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "contextMenu"
        label: root.tr("Menu on right-click")
        description: root.tr("Right-click an app icon for its actions, float, fullscreen, pin, move and close.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "killProcess"
        label: root.tr("Kill Process in the menu")
        description: root.tr("Hide it if you would rather not have it one click away.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "middleClickClose"
        label: root.tr("Close with middle-click")
        description: root.tr("Middle-click an app icon to close that app.")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "groupClose"
        label: root.tr("Middle-click on a grouped icon")
        description: root.tr("When one icon stands for several windows of the same app.")
        options: [
            {
                label: root.tr("Close the focused window"),
                value: "focused"
            },
            {
                label: root.tr("Close all its windows"),
                value: "all"
            }
        ]
        defaultValue: "focused"
    }

    ToggleSetting {
        settingKey: "dragToMove"
        label: root.tr("Drag icons to move apps")
        description: root.tr("Drag an app icon onto another workspace, or onto the +, to move it there.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "wheelSwitch"
        label: root.tr("Scroll to switch workspaces")
        description: root.tr("Use the mouse wheel over the widget.")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "padding"
        label: root.tr("Pill padding")
        description: root.tr("Space between a workspace's edge and its icons, as a share of the icon size.")
        defaultValue: 35
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
