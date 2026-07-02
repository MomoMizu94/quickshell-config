import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "config.js" as Config


PanelWindow {
    id: dashboard
    signal closeRequested()
    property var historyModel
    property int activeTab: 0

    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth() + 1

    property real cpuValue: 0
    property real ramValue: 0
    property real diskValue: 0

    // For clock
    property string currentTime: Qt.formatTime(new Date(), "HH:mm")
    property string currentDate: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")

    property string userName: Quickshell.env("USER")

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    function calendarDays() {
        const fw  = (new Date(calYear, calMonth - 1, 1).getDay() + 6) % 7
        const dim = new Date(calYear, calMonth, 0).getDate()
        const prevDim = new Date(calYear, calMonth - 1, 0).getDate()
        const cells = []
        for (let i = fw - 1; i >= 0; i--)
            cells.push({ d: prevDim - i, cur: false })
        for (let i = 1; i <= dim; i++)
            cells.push({ d: i, cur: true })
        const rem = (7 - cells.length % 7) % 7
        for (let i = 1; i <= rem; i++)
            cells.push({ d: i, cur: false })
        return cells
    }

    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal

    // ── System stats processes ──
    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep '^%Cpu' | awk '{printf \"%d\", $2+$4}'"]
        stdout: StdioCollector { id: cpuOut }
        onExited: dashboard.cpuValue = parseFloat(cpuOut.text.trim()) || 0
    }

    Process {
        id: ramProc 
        command: ["bash", "-c", "free -m | awk 'NR==2{printf \"%d\", $3*100/$2}'"]
        stdout: StdioCollector { id: ramOut }
        onExited: dashboard.ramValue = parseFloat(ramOut.text.trim()) || 0
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df / | awk 'NR==2{print $5}' | tr -d '%'"]
        stdout: StdioCollector { id: diskOut }
        onExited: dashboard.diskValue = parseFloat(diskOut.text.trim()) || 0
    }

    Timer {
        interval: Config.interval
        running: dashboard.visible
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // Clock
            dashboard.currentTime = Qt.formatTime(new Date(), "HH:mm")
            dashboard.currentDate = Qt.formatDate(new Date(), "dddd, d MMMM yyyy")

            // Only update stats when on correct tab
            if (dashboard.activeTab === 3) {
                if (!cpuProc.running) cpuProc.running = true
                if (!ramProc.running) ramProc.running = true
                if (!diskProc.running) diskProc.running = true
            }
        }
    }

    function greeting() {
        const hour = new Date().getHours();

        if (hour < 5)
            return "Good night";
        if (hour < 12)
            return "Good morning";
        if (hour < 18)
            return "Good afternoon";

        return "Good evening";
    }

    MouseArea {
        anchors.fill: parent
        onClicked: dashboard.closeRequested()
    }

    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 18
        anchors.rightMargin: 18
        width: 1560
        height: 680

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Config.colors.LightTeal
        border.width: 8
        border.color: Config.colors.DarkTeal
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // ══ Tab bar ══
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        { icon: "󰂚", label: "Dashboard"   },
                        { icon: "󰃭", label: "Calendar" },
                        { icon: "󰝚", label: "Media"    },
                        { icon: "󰈸", label: "Stats"    }
                    ]
                    delegate: Item {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 50

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: dashboard.activeTab === index
                                ? Qt.rgba(0.29, 0.33, 0.42, 0.12)
                                : "transparent"
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                color: dashboard.activeTab === index
                                    ? Config.colors.Black : Config.colors.DarkTeal
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                color: dashboard.activeTab === index
                                    ? Config.colors.Black : Config.colors.DarkTeal
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize - 5
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.5
                            height: 4
                            radius: 4
                            color: Config.colors.Grey
                            visible: dashboard.activeTab === index
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: dashboard.activeTab = index
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                color: Config.colors.DarkTeal
                opacity: 0.75
            }

            // ══ Content area ══
            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ── Tab 0: Notifications ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 0
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10

                        color: Config.colors.Yellow
                        border.width: 4
                        border.color: Config.colors.DarkTeal

                        implicitHeight: greetingLayout.implicitHeight + 24

                        ColumnLayout {
                            id: greetingLayout
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Text {
                                text: dashboard.greeting() + ", " + dashboard.userName + "!"
                                color: Config.colors.DarkTeal
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize + 4
                                font.bold: true
                            }

                            Text {
                                text: dashboard.currentTime
                                color: Config.colors.DarkTeal
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize + 12
                                font.bold: true
                            }

                            Text {
                                text: dashboard.currentDate
                                color: Config.colors.Grey
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize - 2
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Notifications"
                            color: Config.colors.Turqoise
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize
                            font.bold: true
                        }
                        Text {
                            text: "Clear all"
                            visible: historyModel && historyModel.count > 0
                            color: Config.colors.Cherry
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize - 4
                            font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: historyModel.clear()
                            }
                        }
                    }

                    Text {
                        visible: !historyModel || historyModel.count === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: "No notifications"
                        color: Config.colors.Cyan
                        font.family: Config.bar.fontFamily
                        font.pixelSize: Config.bar.fontSize - 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: notifsCol.implicitHeight
                        clip: true
                        visible: historyModel && historyModel.count > 0

                        ColumnLayout {
                            id: notifsCol
                            width: parent.width
                            spacing: 8

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
                                    color: Config.colors.Yellow
                                    border.width: 4
                                    border.color: Config.colors.DarkTeal
                                    implicitHeight: nc.implicitHeight + 24

                                    RowLayout {
                                        id: nc
                                        anchors {
                                            left: parent.left; right: parent.right
                                            top: parent.top; margins: 12
                                        }
                                        spacing: 8

                                        Item {
                                            Layout.preferredWidth: 48
                                            Layout.preferredHeight: 48
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
                                            spacing: 4
                                            Text {
                                                Layout.fillWidth: true
                                                text: summary
                                                color: Config.colors.DarkTeal
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 2
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: body !== ""
                                                text: body
                                                color: Config.colors.Grey
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 4
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        ColumnLayout {
                                            spacing: 4
                                            Text {
                                                text: time
                                                color: Config.colors.Grey 
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 6
                                            }
                                            Text {
                                                text: ""
                                                color: Config.colors.Cherry
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize
                                                font.bold: true
                                                Layout.alignment: Qt.AlignRight
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: historyModel.remove(index, 1)
                                                }
                                            }
                                            Component.onCompleted: {
                                                console.log("Dashboard image:", image)
                                                console.log("Dashboard appIcon:", appIcon)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Tab 1: Calendar ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 1
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "‹"
                            color: Config.colors.Sand
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize + 4
                            font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (dashboard.calMonth === 1) { dashboard.calMonth = 12; dashboard.calYear-- }
                                    else dashboard.calMonth--
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dashboard.monthNames[dashboard.calMonth - 1] + "  " + dashboard.calYear
                            color: Config.colors.CreamyWhite
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: "›"
                            color: Config.colors.Sand
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize + 4
                            font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (dashboard.calMonth === 12) { dashboard.calMonth = 1; dashboard.calYear++ }
                                    else dashboard.calMonth++
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0
                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Config.colors.Cyan
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize - 6
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 4
                        Repeater {
                            model: dashboard.calendarDays()
                            delegate: Item {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34

                                readonly property bool isToday:
                                    modelData.cur &&
                                    modelData.d === new Date().getDate() &&
                                    dashboard.calMonth === (new Date().getMonth() + 1) &&
                                    dashboard.calYear === new Date().getFullYear()

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28; height: 28; radius: 14
                                    color: isToday ? Config.colors.Turqoise : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.d
                                    color: isToday
                                        ? Config.colors.DarkBG
                                        : modelData.cur
                                            ? Config.colors.CreamyWhite
                                            : Config.colors.Cyan
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 4
                                    font.bold: isToday
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Tab 2: Media ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 2
                    spacing: 12

                    Text {
                        visible: Mpris.players.count === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: "No media playing"
                        color: Config.colors.Cyan
                        font.family: Config.bar.fontFamily
                        font.pixelSize: Config.bar.fontSize - 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Mpris.players.count > 0
                        contentHeight: mediaCol.implicitHeight
                        clip: true

                        ColumnLayout {
                            id: mediaCol
                            width: parent.width
                            spacing: 16

                            Repeater {
                                model: Mpris.players
                                delegate: ColumnLayout {
                                    required property var modelData
                                    property int playerIdx: index
                                    Layout.fillWidth: true
                                    spacing: 12 

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 14

                                        Item {
                                            width: 90; height: 90
                                            Image {
                                                anchors.fill: parent
                                                source: modelData.trackArtUrl || ""
                                                fillMode: Image.PreserveAspectFit
                                                visible: source.toString() !== ""
                                            }
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                color: Config.colors.DarkSurface
                                                visible: !modelData.trackArtUrl
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰝚"
                                                    color: Config.colors.Cyan
                                                    font.family: Config.bar.fontFamily
                                                    font.pixelSize: 42
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.identity || ""
                                                color: Config.colors.Cyan
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 6
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.trackTitle || "—"
                                                color: Config.colors.CreamyWhite
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.trackArtist || "—"
                                                color: Config.colors.Sand
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 2
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: modelData.trackAlbum !== ""
                                                text: modelData.trackAlbum
                                                color: Config.colors.Cyan
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 4
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 28
                                        Text {
                                            text: "⏮"
                                            color: modelData.canGoPrevious ? Config.colors.Sand : Config.colors.Cyan
                                            font.pixelSize: Config.bar.fontSize + 4
                                            opacity: modelData.canGoPrevious ? 1.0 : 0.35
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: if (modelData.canGoPrevious) modelData.previous()
                                            }
                                        }
                                        Text {
                                            text: modelData.isPlaying ? "⏸" : "⏵"
                                            color: Config.colors.Turqoise
                                            font.pixelSize: Config.bar.fontSize + 10
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: modelData.togglePlaying()
                                            }
                                        }
                                        Text {
                                            text: "⏭"
                                            color: modelData.canGoNext ? Config.colors.Sand : Config.colors.Cyan
                                            font.pixelSize: Config.bar.fontSize + 4
                                            opacity: modelData.canGoNext ? 1.0 : 0.35
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: if (modelData.canGoNext) modelData.next()
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 6
                                        visible: modelData.positionSupported && modelData.lengthSupported && modelData.length > 0
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 3
                                            color: Config.colors.DarkSurface
                                        }
                                        Rectangle {
                                            width: parent.width * Math.min(1, modelData.length > 0 ? modelData.position / modelData.length : 0)
                                            height: parent.height
                                            radius: 3
                                            color: Config.colors.Turqoise
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: Config.colors.Sand
                                        opacity: 0.2
                                        visible: playerIdx < Mpris.players.count - 1
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Tab 3: Stats ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 3
                    spacing: 24

                    Item { Layout.preferredHeight: 10 }

                    Repeater {
                        model: [
                            { label: "CPU",    icon: "󰍛", value: dashboard.cpuValue,  color: Config.colors.Turqoise },
                            { label: "RAM",    icon: "󰘚", value: dashboard.ramValue,  color: Config.colors.Sand     },
                            { label: "Disk /", icon: "󰋊", value: dashboard.diskValue, color: Config.colors.Orange   }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: modelData.icon
                                    color: modelData.color
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize
                                }
                                Text {
                                    text: modelData.label
                                    color: Config.colors.CreamyWhite
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 2
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(modelData.value) + "%"
                                    color: modelData.color
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 2
                                    font.bold: true
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 10
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 5
                                    color: Config.colors.DarkSurface
                                }
                                Rectangle {
                                    width: Math.max(0, parent.width * modelData.value / 100)
                                    height: parent.height
                                    radius: 5
                                    color: modelData.color
                                    Behavior on width {
                                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
        }
    }
}
