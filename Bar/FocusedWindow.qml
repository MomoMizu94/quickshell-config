import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../"
import "../config.js" as Config

// Icon-only: the bar surface is exactly Config.frame.thick (64px) wide, so a
// hover-tooltip popup would render outside the window's actual buffer and
// simply be clipped by the compositor — not worth the half-working attempt.
Item {
    id: root
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: Config.sidebar.trayIconSize + Config.gap.sm
    Layout.preferredHeight: Config.sidebar.trayIconSize + Config.gap.sm

    readonly property var toplevel: ToplevelManager.activeToplevel

    IconImage {
        anchors.centerIn: parent
        width: Config.sidebar.trayIconSize
        height: Config.sidebar.trayIconSize
        source: root.toplevel ? Quickshell.iconPath(root.toplevel.appId, true) : ""
    }
}
