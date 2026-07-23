import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../"
import "../config.js" as Config

ColumnLayout {
    Layout.alignment: Qt.AlignHCenter
    spacing: Config.gap.sm

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property var modelData
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Config.sidebar.trayIconSize
            implicitHeight: Config.sidebar.trayIconSize

            readonly property point windowPos: trayItem.QsWindow.contentItem.mapFromItem(trayItem, 0, 0)

            IconImage {
                anchors.fill: parent
                source: trayItem.modelData.icon
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                anchor.window: trayItem.QsWindow.window
                anchor.rect.x: trayItem.windowPos.x
                anchor.rect.y: trayItem.windowPos.y
                anchor.rect.width: trayItem.width
                anchor.rect.height: trayItem.height
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) trayItem.modelData.activate()
                    else if (mouse.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) menuAnchor.open()
                }
            }
        }
    }
}
