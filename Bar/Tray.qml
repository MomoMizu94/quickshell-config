import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../"
import "../config.js" as Config

ColumnLayout {
    Layout.alignment: Qt.AlignHCenter
    spacing: Config.gap.xs

    Repeater {
        model: SystemTray.items

        delegate: IconImage {
            required property var modelData
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Config.sidebar.trayIconSize
            implicitHeight: Config.sidebar.trayIconSize
            source: modelData.icon
        }
    }
}
