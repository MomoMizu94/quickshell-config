import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../"
import "../config.js" as Config

Item {
    id: root
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: Config.sidebar.trayIconSize + Config.gap.sm
    Layout.preferredHeight: Config.sidebar.trayIconSize + Config.gap.sm

    property bool enabled: false

    Process {
        id: proc
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        stdout: StdioCollector { id: out }
        onExited: root.enabled = out.text.trim() === "yes"
    }

    Timer {
        interval: Config.timer.bluetoothRefresh
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    Text {
        anchors.centerIn: parent
        text: "󰂯"
        color: root.enabled ? Colors.accent : Colors.subtext
        font.family: Config.bar.fontFamily
        font.pixelSize: Config.type.md
    }
}
