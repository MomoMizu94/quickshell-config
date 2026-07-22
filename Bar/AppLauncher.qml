import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../"
import "../config.js" as Config

Item {
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: Config.sidebar.iconSize + Config.gap.md
    Layout.preferredHeight: Config.sidebar.iconSize + Config.gap.md

    Process {
        id: proc
        command: ["rofi", "-show-icons", "-show", "drun"]
    }

    Text {
        anchors.centerIn: parent
        text: "󰣇"
        color: Colors.text
        font.family: Config.bar.fontFamily
        font.pixelSize: Config.sidebar.iconSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: proc.startDetached()
    }
}
