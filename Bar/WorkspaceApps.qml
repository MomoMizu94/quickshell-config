import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../"
import "../config.js" as Config

// Lists every app open on the currently active workspace (not just the
// focused one), with the truly-focused window highlighted. Plain Column
// (not ColumnLayout) — its docs guarantee invisible children are excluded
// from positioning, which is what skips windows on other workspaces.
Column {
    id: root
    spacing: Config.gap.sm

    // DesktopEntries finishes scanning .desktop files asynchronously, after
    // this component is created — heuristicLookup() is a plain method call
    // with no notify signal to hook, so a delegate that calls it before the
    // scan finishes gets null permanently with no way to know to retry.
    // Bump a generation counter a handful of times over ~3s (comfortably
    // past the scan time observed during testing) and have each delegate's
    // `entry` binding read it, so they all recompute as entries come online.
    property int entriesGeneration: 0
    Timer {
        interval: 400
        running: true
        repeat: true
        property int attempts: 0
        onTriggered: {
            root.entriesGeneration++
            attempts++
            if (attempts >= 8) stop()
        }
    }

    Repeater {
        model: Hyprland.toplevels

        delegate: Item {
            required property var modelData
            readonly property string appId: (modelData.wayland ? modelData.wayland.appId
                : (modelData.lastIpcObject ? modelData.lastIpcObject.class : "")) || ""
            readonly property var entry: (appId && root.entriesGeneration >= 0) ? DesktopEntries.heuristicLookup(appId) : null

            visible: modelData.workspace && modelData.workspace.active
            width: Config.sidebar.workspaceAppIconSize + Config.gap.sm
            height: width

            Rectangle {
                anchors.fill: parent
                radius: Config.radius.md
                color: modelData.activated ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.30) : "transparent"
            }

            IconImage {
                anchors.centerIn: parent
                width: Config.sidebar.workspaceAppIconSize
                height: Config.sidebar.workspaceAppIconSize
                source: entry ? Quickshell.iconPath(entry.icon, true)
                    : (appId ? Quickshell.iconPath(appId, true) : "")
            }
        }
    }
}
