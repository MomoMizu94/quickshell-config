import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "config.js" as Config


PanelWindow {
    property var notifModel
    property bool dndEnabled: false
    visible: !dndEnabled

    anchors { top: true; right: true }
    margins { top: 18; right: 18 }

    implicitWidth: 560
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"

    exclusionMode: ExclusionMode.Normal

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: notifModel
            delegate: Rectangle {
                id: card
                required property var modelData

                Timer {
                    running: card.modelData.urgency !== NotificationUrgency.Critical
                    interval: Config.notifications.timeout
                    onTriggered: card.modelData.dismiss()
                }

                Layout.fillWidth: true
                Layout.preferredHeight: layout.implicitHeight + 28
                radius: 8
                color: Colors.surface
                border.width: 8
                border.color: modelData.urgency === NotificationUrgency.Critical
                ? Colors.error : Colors.border

                RowLayout {
                    id: layout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 132
                        Layout.alignment: Qt.AlignTop

                        // Notification image
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            visible: card.modelData.image !== ""
                            source: card.modelData.image
                        }

                        // Fallback: Application icon
                        IconImage {
                            anchors.fill: parent
                            visible: card.modelData.image === "" && card.modelData.appIcon !== ""
                            source: Quickshell.iconPath(card.modelData.appIcon)
                        }
                    }

                    Component.onCompleted: {
                    console.log("=== Notification ===")
                    console.log("image:", modelData.image)
                    console.log("appIcon:", modelData.appIcon)
                    console.log("desktopEntry:", modelData.desktopEntry)
                    console.log("appName:", modelData.appName)
                    console.log("summary:", modelData.summary)
                }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.summary
                            color: Colors.border
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.modelData.body
                            color: Colors.subtext
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize - 4
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.modelData.dismiss()
                }
            }
        }
    }
}
