import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../config.js" as Config

ColumnLayout {
    id: root
    Layout.alignment: Qt.AlignHCenter
    spacing: 0

    property real up: 0
    property real down: 0

    Process {
        id: proc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/netspeed.sh"]
        stdout: StdioCollector { id: out }
        onExited: {
            try {
                const d = JSON.parse(out.text)
                root.up = d.up
                root.down = d.down
            } catch (e) {}
        }
    }

    Timer {
        interval: Config.timer.netRefresh
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "󰅧 " + root.up.toFixed(1)
        color: Colors.subtext
        font.family: Config.bar.fontFamily
        font.pixelSize: Config.type.micro
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "󰅢 " + root.down.toFixed(1)
        color: Colors.subtext
        font.family: Config.bar.fontFamily
        font.pixelSize: Config.type.micro
    }
}
