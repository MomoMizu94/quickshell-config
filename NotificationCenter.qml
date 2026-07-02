import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "config.js" as Config


PanelWindow {
    property var historyModel

    anchors { top: true; right: true }
    margins { top: 18; right: 18 }

    implicitWidth: 560
    implicitHeight: centerCol.implicitHeight + 24
    color: "transparent"

    exclusionMode: ExclusionMode.Normal

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Config.colors.Cyan
        border.width: 8
        border.color: Config.colors.Sand
    }

    ColumnLayout {
        id: centerCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: "Notifications"
                color: Config.colors.DarkBlue
                font.family: Config.bar.fontFamily
                font.pixelSize: Config.bar.fontSize + 4
                font.bold: true
            }
            Text {
                text: "Clear all"
                visible: historyModel.count > 0
                color: Config.colors.Red
                font.family: Config.bar.fontFamily
                font.pixelSize: Config.bar.fontSize - 1
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: historyModel.clear()
                }
            }
        }

        Text {
            visible: historyModel.count === 0
            Layout.fillWidth: true
            text: "No notifications"
            color: Config.colors.DarkBlue
            font.family: Config.bar.fontFamily
            font.pixelSize: Config.bar.fontSize - 1
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: historyModel
            delegate: Rectangle {
                required property string summary
                required property string body
                required property string time
                required property string image
                required property string appIcon
                required property int index

                Layout.fillWidth: true
                radius: 8
                color: Config.colors.LightCyan
                border.width: 5
                border.color: Config.colors.Sand
                implicitHeight: cardContent.implicitHeight + 24

                RowLayout {
                    id: cardContent
                    anchors {
                        left: parent.left; right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 8

                    Item {
                        Layout.preferredHeight: 56
                        Layout.preferredWidth: 56
                        Layout.alignment: Qt.AlignVCenter

                        // Notification image
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            visible: image !== ""
                            source: image
                        }

                        // Fallback: Application icon
                        IconImage {
                            anchors.fill: parent
                            visible: image === "" && appIcon !== ""
                            source: Quickshell.iconPath(appIcon)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: summary
                            color: Config.colors.Black
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize - 2
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: body !== ""
                            text: body
                            color: Config.colors.CreamyWhite
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize - 4
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        spacing: 4

                        Text {
                            text: time
                            color: Config.colors.Black
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize - 6
                        }

                        Text {
                            text: ""
                            color: Config.colors.Red
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize
                            font.bold: true
                            Layout.alignment: Qt.AlignRight

                            MouseArea {
                                anchors.fill: parent
                                onClicked: historyModel.remove(index, 1)
                            }
                        }
                    }
                }
            }
        }
    }
}
