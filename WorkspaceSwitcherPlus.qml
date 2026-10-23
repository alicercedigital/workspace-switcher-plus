import QtQuick

// A bare Item, like the stock switcher, instead of a PluginComponent: PluginComponent wraps its
// content in a BasePill, which paints a strip behind the buttons. The bar host injects the
// properties below into any widget that declares them.
Item {
    id: root

    property var axis: null
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property var blurBarWindow: null
    property var widgetData: null

    readonly property bool isVertical: axis?.isVertical ?? false

    width: isVertical ? barThickness : switcher.width
    height: isVertical ? switcher.height : barThickness

    Switcher {
        id: switcher
        anchors.centerIn: parent
        host: root
        vertical: root.isVertical
    }
}
