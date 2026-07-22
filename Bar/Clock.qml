import QtQuick
import QtQuick.Layouts
import "../"
import "../config.js" as Config

ColumnLayout {
    id: root
    Layout.alignment: Qt.AlignHCenter
    spacing: 0

    property string time: ""

    Timer {
        interval: Config.timer.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.time = Qt.formatTime(new Date(), "HH:mm")
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.time
        color: Colors.text
        font.family: Config.bar.fontFamily
        font.pixelSize: Config.type.sm
        font.bold: true
    }
}
