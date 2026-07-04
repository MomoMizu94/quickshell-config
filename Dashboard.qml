import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Effects

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
    property string currentTime: Qt.formatTime(new Date(), "h:mm AP")
    property string currentDate: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")

    property string userName: Quickshell.env("USER")

    property string weatherTemp: "--"
    property string weatherDesc: ""
    property string weatherLocation: ""
    property string weatherHigh: "--"
    property string weatherLow: "--"
    property string weatherHumidity: "--"
    property string weatherWindSpeed: "--"
    property string weatherWindDir: ""

    property string sysOs: ""
    property string sysKernel: ""
    property string sysWm: Quickshell.env("XDG_CURRENT_DESKTOP")
    property string sysUptime: ""

    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property bool dndEnabled: false
    property bool nightEnabled: false

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
            dashboard.currentTime = Qt.formatTime(new Date(), "h:mm AP")
            dashboard.currentDate = Qt.formatDate(new Date(), "dddd, d MMMM yyyy")

            // Only update stats when on correct tab
            if (dashboard.activeTab === 3) {
                if (!cpuProc.running) cpuProc.running = true
                if (!ramProc.running) ramProc.running = true
                if (!diskProc.running) diskProc.running = true
                if (!uptimeProc.running) uptimeProc.running = true
            }
        }
    }

    // ── System info ──
    Process {
        id: osProc
        command: ["bash", "-c", "grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2"]
        stdout: StdioCollector { id: osOut }
        onExited: dashboard.sysOs = osOut.text.trim()
    }
    Process {
        id: kernelProc
        command: ["uname", "-r"]
        stdout: StdioCollector { id: kernelOut }
        onExited: dashboard.sysKernel = kernelOut.text.trim()
    }
    Process {
        id: uptimeProc
        command: ["bash", "-c", "awk '{h=int($1/3600);m=int(($1%3600)/60);print h\"h \"m\"m\"}' /proc/uptime"]
        stdout: StdioCollector { id: uptimeOut }
        onExited: dashboard.sysUptime = uptimeOut.text.trim()
    }
    Process {
        id: wifiCheckProc
        command: ["bash", "-c", "nmcli radio wifi"]
        stdout: StdioCollector { id: wifiCheckOut }
        onExited: dashboard.wifiEnabled = wifiCheckOut.text.trim() === "enabled"
    }
    Process {
        id: btCheckProc
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        stdout: StdioCollector { id: btCheckOut }
        onExited: dashboard.bluetoothEnabled = btCheckOut.text.trim() === "yes"
    }
    Process {
        id: nightCheckProc
        command: ["bash", "-c", "pgrep -x wlsunset > /dev/null && echo yes || echo no"]
        stdout: StdioCollector { id: nightCheckOut }
        onExited: dashboard.nightEnabled = nightCheckOut.text.trim() === "yes"
    }
    Process { id: actionProc; command: ["echo"] }

    Component.onCompleted: {
        osProc.running = true
        kernelProc.running = true
        uptimeProc.running = true
        wifiCheckProc.running = true
        btCheckProc.running = true
        nightCheckProc.running = true
    }

    // ── Weather ──
    Process {
        id: weatherProc
        command: ["bash", "-c", "curl -sf 'https://wttr.in?format=j1'"]
        stdout: StdioCollector { id: weatherOut }
        onExited: {
            try {
                const d = JSON.parse(weatherOut.text)
                const cur = d.current_condition[0]
                const area = d.nearest_area[0]
                const today = d.weather[0]
                dashboard.weatherTemp = cur.temp_C
                dashboard.weatherDesc = cur.weatherDesc[0].value
                dashboard.weatherLocation = area.areaName[0].value
                dashboard.weatherHigh = today.maxtempC
                dashboard.weatherLow = today.mintempC
                dashboard.weatherHumidity = cur.humidity
                dashboard.weatherWindSpeed = (parseFloat(cur.windspeedKmph) / 3.6).toFixed(1)
                dashboard.weatherWindDir = cur.winddir16Point
            } catch(e) {}
        }
    }

    Timer {
        interval: 600000
        running: dashboard.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!weatherProc.running) weatherProc.running = true
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

    function toggleWifi() {
        actionProc.command = wifiEnabled
            ? ["nmcli", "radio", "wifi", "off"]
            : ["nmcli", "radio", "wifi", "on"]
        actionProc.startDetached()
        wifiEnabled = !wifiEnabled
    }
    function toggleBluetooth() {
        actionProc.command = bluetoothEnabled
            ? ["bluetoothctl", "power", "off"]
            : ["bluetoothctl", "power", "on"]
        actionProc.startDetached()
        bluetoothEnabled = !bluetoothEnabled
    }
    function toggleNight() {
        actionProc.command = nightEnabled
            ? ["pkill", "wlsunset"]
            : ["wlsunset", "-T", "4500"]
        actionProc.startDetached()
        nightEnabled = !nightEnabled
    }

    function weatherIcon(desc) {
        const d = (desc || "").toLowerCase()
        if (d.includes("thunder") || d.includes("storm")) return "󰙾"
        if (d.includes("snow") || d.includes("sleet") || d.includes("blizzard")) return "󰼶"
        if (d.includes("rain") || d.includes("drizzle") || d.includes("shower")) return "󰖗"
        if (d.includes("fog") || d.includes("mist") || d.includes("haze")) return "󰖑"
        if (d.includes("overcast")) return "󰅣"
        if (d.includes("cloud")) return ""
        if (d.includes("clear") || d.includes("sunny") || d.includes("sun")) return "󰖨"
        return ""
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
                        { icon: "󰕮", label: "Dashboard"   },
                        { icon: "󰃭", label: "Calendar" },
                        { icon: "󰝚", label: "Media"    },
                        { icon: "󰈸", label: "Stats"    }
                        // Workspaces??
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

                // ── Tab 0: Dashboard ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 0
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            id: greetingCard
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

                        Rectangle {
                            Layout.preferredWidth: 500
                            implicitHeight: greetingCard.implicitHeight * 2
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                Text {
                                    text: "WEATHER"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 8
                                    font.bold: true
                                    font.letterSpacing: 1.5
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: dashboard.weatherTemp + "°"
                                        color: Config.colors.DarkTeal
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 50
                                        font.bold: true
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: dashboard.weatherIcon(dashboard.weatherDesc)
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 80
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: dashboard.weatherLocation !== ""
                                    text: dashboard.weatherLocation
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 5
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: dashboard.weatherDesc !== "" ? dashboard.weatherDesc : "Loading…"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 5
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "H: " + dashboard.weatherHigh + "°  L: " + dashboard.weatherLow
                                        + "°  ·  " + dashboard.weatherHumidity + "% humidity"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 5
                                }

                                Text {
                                    text: "Wind: " + dashboard.weatherWindSpeed + " m/s " + dashboard.weatherWindDir
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 5
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        // ── System info ──
                        Rectangle {
                            //Layout.fillWidth: true
                            width: 500
                            height: 160
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                // Profile picture
                                Item {
                                    width: 120; height: 120

                                    Image {
                                        id: profileImg
                                        anchors.fill: parent
                                        source: "file://" + Quickshell.env("HOME") + "/Pictures/ProfilePics/momo.png"
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        visible: false
                                    }

                                    Rectangle {
                                        id: circleMask
                                        anchors.fill: parent
                                        radius: width / 2
                                        visible: false
                                        layer.enabled: true
                                    }

                                    MultiEffect {
                                        source: profileImg
                                        anchors.fill: profileImg
                                        maskEnabled: true
                                        maskSource: circleMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                }

                                // Stats column
                                ColumnLayout {
                                    //Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { icon: "󰣇",    value: dashboard.sysOs     },
                                            { icon: "󰌢",    value: dashboard.sysKernel },
                                            { icon: "󱂬",    value: dashboard.sysWm     },
                                            { icon: "󰅐",    value: "up " + dashboard.sysUptime },
                                        ]
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: modelData.icon
                                                color: Config.colors.Orange
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 2
                                            }
                                            Text {
                                                text: modelData.label
                                                color: Config.colors.Grey
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 5
                                                font.bold: true
                                                font.letterSpacing: 1
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: modelData.value || "…"
                                                color: Config.colors.DarkTeal
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 4
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Quick toggles ──
                        Rectangle {
                            Layout.preferredWidth: 320
                            height: 140
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                Text {
                                    text: "QUICK TOGGLES"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 8
                                    font.bold: true
                                    font.letterSpacing: 1.5
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    columns: 2
                                    rowSpacing: 6
                                    columnSpacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                                        color: dashboard.wifiEnabled ? Qt.rgba(0.82, 0.53, 0.44, 0.3) : Qt.rgba(0,0,0,0.05)
                                        ColumnLayout { anchors.centerIn: parent; spacing: 2
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "󰤨"
                                                color: dashboard.wifiEnabled ? Config.colors.Orange : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize + 2 }
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "Wi-Fi"
                                                color: dashboard.wifiEnabled ? Config.colors.DarkTeal : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize - 6 }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: dashboard.toggleWifi() }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                                        color: dashboard.bluetoothEnabled ? Qt.rgba(0.82, 0.53, 0.44, 0.3) : Qt.rgba(0,0,0,0.05)
                                        ColumnLayout { anchors.centerIn: parent; spacing: 2
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "󰂯"
                                                color: dashboard.bluetoothEnabled ? Config.colors.Orange : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize + 2 }
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "Bluetooth"
                                                color: dashboard.bluetoothEnabled ? Config.colors.DarkTeal : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize - 6 }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: dashboard.toggleBluetooth() }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                                        color: dashboard.dndEnabled ? Qt.rgba(0.82, 0.53, 0.44, 0.3) : Qt.rgba(0,0,0,0.05)
                                        ColumnLayout { anchors.centerIn: parent; spacing: 2
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "󰍷"
                                                color: dashboard.dndEnabled ? Config.colors.Orange : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize + 2 }
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "DND"
                                                color: dashboard.dndEnabled ? Config.colors.DarkTeal : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize - 6 }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: dashboard.dndEnabled = !dashboard.dndEnabled }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                                        color: dashboard.nightEnabled ? Qt.rgba(0.82, 0.53, 0.44, 0.3) : Qt.rgba(0,0,0,0.05)
                                        ColumnLayout { anchors.centerIn: parent; spacing: 2
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "󰌵"
                                                color: dashboard.nightEnabled ? Config.colors.Orange : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize + 2 }
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "Night"
                                                color: dashboard.nightEnabled ? Config.colors.DarkTeal : Config.colors.Grey
                                                font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize - 6 }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: dashboard.toggleNight() }
                                    }
                                }
                            }
                        }

                        // ── Now Playing mini widget ──
                        Rectangle {
                            id: musicCard
                            Layout.fillWidth: true
                            height: 160
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

                            function fmtTime(us) {
                                var s = Math.floor((us || 0) / 1000000)
                                return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
                            }

                            Text {
                                visible: !musicCard.player
                                anchors.centerIn: parent
                                text: "No media playing"
                                color: Config.colors.Grey
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize - 4
                            }

                            ColumnLayout {
                                visible: !!musicCard.player
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Item {
                                        width: 80; height: 80

                                        Image {
                                            id: miniAlbumImg
                                            anchors.fill: parent
                                            source: musicCard.player ? (musicCard.player.trackArtUrl || "") : ""
                                            fillMode: Image.PreserveAspectCrop
                                            layer.enabled: true
                                            visible: false
                                        }
                                        Rectangle {
                                            id: miniAlbumMask
                                            anchors.fill: parent
                                            radius: width / 2
                                            visible: false
                                            layer.enabled: true
                                        }
                                        MultiEffect {
                                            source: miniAlbumImg
                                            anchors.fill: miniAlbumImg
                                            maskEnabled: true
                                            maskSource: miniAlbumMask
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: Config.colors.DarkTeal
                                            visible: !musicCard.player || !musicCard.player.trackArtUrl
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰝚"
                                                color: Config.colors.Yellow
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: 32
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: musicCard.player ? (musicCard.player.trackTitle || "—") : "—"
                                            color: Config.colors.DarkTeal
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 4
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: musicCard.player ? (musicCard.player.trackArtist || "—") : "—"
                                            color: Config.colors.Grey
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 6
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: musicCard.player ? (musicCard.player.trackAlbum || "") : ""
                                            color: Config.colors.Orange
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 8
                                            elide: Text.ElideRight
                                            visible: musicCard.player && musicCard.player.trackAlbum !== ""
                                        }
                                        AnimatedImage {
                                            visible: !!musicCard.player
                                            source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/visualizer.gif"
                                            playing: musicCard.player && musicCard.player.isPlaying
                                            width: 60; height: 24
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 24

                                    Text {
                                        text: "⏮"
                                        color: musicCard.player && musicCard.player.canGoPrevious ? Config.colors.DarkTeal : Config.colors.Grey
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize
                                        opacity: musicCard.player && musicCard.player.canGoPrevious ? 1.0 : 0.4
                                        MouseArea { anchors.fill: parent; onClicked: if (musicCard.player && musicCard.player.canGoPrevious) musicCard.player.previous() }
                                    }
                                    Text {
                                        text: musicCard.player && musicCard.player.isPlaying ? "⏸" : "⏵"
                                        color: Config.colors.Orange
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 8
                                        MouseArea { anchors.fill: parent; onClicked: if (musicCard.player) musicCard.player.togglePlaying() }
                                    }
                                    Text {
                                        text: "⏭"
                                        color: musicCard.player && musicCard.player.canGoNext ? Config.colors.DarkTeal : Config.colors.Grey
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize
                                        opacity: musicCard.player && musicCard.player.canGoNext ? 1.0 : 0.4
                                        MouseArea { anchors.fill: parent; onClicked: if (musicCard.player && musicCard.player.canGoNext) musicCard.player.next() }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    visible: musicCard.player && musicCard.player.positionSupported && musicCard.player.lengthSupported && musicCard.player.length > 0

                                    Item {
                                        Layout.fillWidth: true
                                        height: 5
                                        Rectangle { anchors.fill: parent; radius: 3; color: Qt.rgba(0,0,0,0.1) }
                                        Rectangle {
                                            width: parent.width * Math.min(1, musicCard.player && musicCard.player.length > 0
                                                ? musicCard.player.position / musicCard.player.length : 0)
                                            height: parent.height; radius: 3; color: Config.colors.Orange
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: musicCard.fmtTime(musicCard.player ? musicCard.player.position : 0)
                                            color: Config.colors.Grey; font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize - 8
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: musicCard.fmtTime(musicCard.player ? musicCard.player.length : 0)
                                            color: Config.colors.Grey; font.family: Config.bar.fontFamily; font.pixelSize: Config.bar.fontSize - 8
                                        }
                                    }
                                }
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
