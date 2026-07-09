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
    property real gpuValue: 0

    // Performance tab details
    property real cpuFreqGhz: 0
    property real cpuTemp: 0
    property real gpuTemp: 0
    property string gpuName: ""
    property var coreLoads: []
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real netUpMbs: 0
    property real netDownMbs: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property int processCount: 0

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
    property var weatherForecast: []

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

    function isoWeek(year, month, day) {
        const d = new Date(year, month - 1, day)
        const dow = d.getDay() || 7
        d.setDate(d.getDate() + 4 - dow)
        const yearStart = new Date(d.getFullYear(), 0, 1)
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
    }

    function calendarDays() {
        const fw      = (new Date(calYear, calMonth - 1, 1).getDay() + 6) % 7
        const dim     = new Date(calYear, calMonth, 0).getDate()
        const prevDim = new Date(calYear, calMonth - 1, 0).getDate()
        const days = []
        for (let i = fw - 1; i >= 0; i--)
            days.push({ d: prevDim - i, cur: false })
        for (let i = 1; i <= dim; i++)
            days.push({ d: i, cur: true })
        const rem = (7 - days.length % 7) % 7
        for (let i = 1; i <= rem; i++)
            days.push({ d: i, cur: false })

        // Interleave a week-number sentinel at the start of each 7-day row
        const result = []
        const rows = days.length / 7
        for (let row = 0; row < rows; row++) {
            const slice = days.slice(row * 7, row * 7 + 7)
            let wy = calYear, wm = calMonth, wd = slice[0].d
            for (const c of slice) { if (c.cur) { wd = c.d; break } }
            if (!slice.some(c => c.cur)) {
                if (row === 0) { wm = calMonth === 1 ? 12 : calMonth - 1; wy = calMonth === 1 ? calYear - 1 : calYear }
                else           { wm = calMonth === 12 ? 1 : calMonth + 1; wy = calMonth === 12 ? calYear + 1 : calYear }
            }
            result.push({ type: 'week', num: isoWeek(wy, wm, wd) })
            for (const c of slice) result.push(c)
        }
        return result
    }

    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ── System stats processes ──
    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep '^%Cpu' | awk '{printf \"%d\", $2+$4}'"]
        stdout: StdioCollector { id: cpuOut }
        onExited: { var v = parseFloat(cpuOut.text.trim()); if (!isNaN(v)) dashboard.cpuValue = v }
    }

    Process {
        id: ramProc
        command: ["bash", "-c", "free -m | awk 'NR==2{printf \"%d\", $3*100/$2}'"]
        stdout: StdioCollector { id: ramOut }
        onExited: { var v = parseFloat(ramOut.text.trim()); if (!isNaN(v)) dashboard.ramValue = v }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df / | awk 'NR==2{print $5}' | tr -d '%'"]
        stdout: StdioCollector { id: diskOut }
        onExited: { var v = parseFloat(diskOut.text.trim()); if (!isNaN(v)) dashboard.diskValue = v }
    }

    Process {
        id: gpuProc
        command: ["bash", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"]
        stdout: StdioCollector { id: gpuOut }
        onExited: { var v = parseFloat(gpuOut.text.trim()); if (!isNaN(v)) dashboard.gpuValue = v }
    }

    Process {
        id: perfProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/perf.sh"]
        stdout: StdioCollector { id: perfOut }
        onExited: {
            try {
                const d = JSON.parse(perfOut.text)
                dashboard.cpuValue = d.cpu
                dashboard.coreLoads = d.cores
                dashboard.cpuFreqGhz = d.freq
                dashboard.cpuTemp = d.ctemp
                dashboard.gpuValue = d.gpu
                dashboard.gpuTemp = d.gtemp
                dashboard.gpuName = d.gname
                dashboard.ramValue = d.ramT > 0 ? 100 * d.ramU / d.ramT : 0
                dashboard.ramUsedGb = d.ramU
                dashboard.ramTotalGb = d.ramT
                dashboard.netUpMbs = d.up
                dashboard.netDownMbs = d.down
                dashboard.diskUsedGb = d.diskU
                dashboard.diskTotalGb = d.diskT
                dashboard.processCount = d.procs
            } catch (e) {}
        }
    }

    Timer {
        interval: Config.timer.interval
        running: dashboard.visible
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // Clock
            dashboard.currentTime = Qt.formatTime(new Date(), "h:mm AP")
            dashboard.currentDate = Qt.formatDate(new Date(), "dddd, d MMMM yyyy")

            // Only update stats when on correct tab
            if (dashboard.activeTab === 3) {
                if (!perfProc.running) perfProc.running = true
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
                dashboard.weatherForecast = d.weather.map(w => ({
                    day: Qt.formatDate(new Date(w.date), "ddd").toUpperCase(),
                    desc: w.hourly[4].weatherDesc[0].value,
                    high: w.maxtempC,
                    low: w.mintempC
                }))
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

    Timer {
        interval: 2000
        running: dashboard.visible && dashboard.activeTab === 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running)  cpuProc.running  = true
            if (!ramProc.running)  ramProc.running  = true
            if (!diskProc.running) diskProc.running = true
            if (!gpuProc.running)  gpuProc.running  = true
        }
    }

    ListModel { id: todoList }

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
            : ["wlsunset", "-T", "5000"]
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
        anchors.horizontalCenter: parent.horizontalCenter
        width: 1500
        height: 1200

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
                        { icon: "󰕮", label: "Dashboard"     },
                        { icon: "󰃭", label: "Calendar"      },
                        { icon: "󰝚", label: "Media"         },
                        { icon: "󰓅", label: "Performance"   }
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
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        Rectangle {
                            id: greetingCard
                            Layout.fillWidth: true
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal
                            implicitHeight: quicktoggleContent.implicitHeight + 24

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
                                    font.pixelSize: Config.bar.fontSize + 50
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

                        // ── System info ──
                        Rectangle {
                            implicitHeight: quicktoggleContent.implicitHeight + 24
                            implicitWidth: systeminfoContent.implicitWidth + 24
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            RowLayout {
                                id: systeminfoContent
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 200

                                // Profile picture
                                Item {
                                    width: 140; height: 140

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
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { icon: "󰣇", value: dashboard.sysOs     },
                                            { icon: "󰌢", value: dashboard.sysKernel },
                                            { icon: "󱂬", value: dashboard.sysWm     },
                                            { icon: "󰅐", value: "up " + dashboard.sysUptime },
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
                            Layout.fillWidth: true
                            implicitHeight: quicktoggleContent.implicitHeight + 24
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            ColumnLayout {
                                id: quicktoggleContent
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
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
                                    columns: 2
                                    rowSpacing: 6
                                    columnSpacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 68; radius: 8
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
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 68; radius: 8
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
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 68; radius: 8
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
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 68; radius: 8
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
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        // ── Now Playing mini widget ──
                        Rectangle {
                            id: musicCard
                            //Layout.fillWidth: true
                            Layout.preferredWidth: 400
                            implicitHeight: musicContent.implicitHeight + 32
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

                            function fmtTime(secs) {
                                var s = Math.floor(secs || 0)
                                return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
                            }

                            Timer {
                                interval: 1000
                                running: !!musicCard.player && musicCard.player.isPlaying
                                repeat: true
                                onTriggered: progressRing.requestPaint()
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
                                id: musicContent
                                visible: !!musicCard.player
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 16
                                spacing: 8

                                // ── Album art with circular progress ring ──
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 250; height: 250

                                    Canvas {
                                        id: progressRing
                                        anchors.fill: parent
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width / 2, cy = height / 2
                                            var r = cx - 6
                                            var lw = 8

                                            // Read position directly — bypasses QML property cache
                                            var progress = 0
                                            var p = musicCard.player
                                            if (p && p.lengthSupported && p.length > 0)
                                                progress = Math.min(1, p.position / p.length)

                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                            ctx.strokeStyle = "rgba(0,0,0,0.12)"
                                            ctx.lineWidth = lw
                                            ctx.lineCap = "round"
                                            ctx.stroke()
                                            if (progress > 0) {
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + progress * Math.PI * 2)
                                                ctx.strokeStyle = "#D18870"
                                                ctx.lineWidth = lw
                                                ctx.lineCap = "round"
                                                ctx.stroke()
                                            }
                                        }
                                    }

                                    Item {
                                        width: 220; height: 220
                                        anchors.centerIn: parent

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
                                                font.pixelSize: 48
                                            }
                                        }
                                    }
                                }

                                // ── Track info ──
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: musicCard.player ? (musicCard.player.trackTitle || "—") : "—"
                                    color: Config.colors.DarkTeal
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 2
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: musicCard.player ? (musicCard.player.trackArtist || "—") : "—"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 6
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: musicCard.player ? (musicCard.player.trackAlbum || "") : ""
                                    color: Config.colors.Orange
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 8
                                    elide: Text.ElideRight
                                    visible: musicCard.player && musicCard.player.trackAlbum !== ""
                                }

                                // ── Playback controls ──
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 28

                                    Text {
                                        text: ""
                                        color: musicCard.player && musicCard.player.canGoPrevious ? Config.colors.DarkTeal : Config.colors.Grey
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 2
                                        opacity: musicCard.player && musicCard.player.canGoPrevious ? 1.0 : 0.4
                                        MouseArea { anchors.fill: parent; onClicked: if (musicCard.player && musicCard.player.canGoPrevious) musicCard.player.previous() }
                                    }
                                    Text {
                                        text: musicCard.player && musicCard.player.isPlaying ? "" : ""
                                        color: Config.colors.Orange
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 12
                                        MouseArea { anchors.fill: parent; onClicked: if (musicCard.player) musicCard.player.togglePlaying() }
                                    }
                                    Text {
                                        text: ""
                                        color: musicCard.player && musicCard.player.canGoNext ? Config.colors.DarkTeal : Config.colors.Grey
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 2
                                        opacity: musicCard.player && musicCard.player.canGoNext ? 1.0 : 0.4
                                        MouseArea { anchors.fill: parent; onClicked: if (musicCard.player && musicCard.player.canGoNext) musicCard.player.next() }
                                    }
                                }

                                // ── GIF visualizer ──
                                AnimatedImage {
                                    Layout.alignment: Qt.AlignHCenter
                                    source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/bongocat.gif"
                                    playing: musicCard.player && musicCard.player.isPlaying
                                    width: 80; height: 32
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }

                        // ── Hardware stats ──
                        Rectangle {
                            implicitHeight: musicContent.implicitHeight + 32
                            //Layout.fillWidth: true
                            Layout.preferredWidth: 400
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 20

                                Text {
                                    text: "HARDWARE"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 8
                                    font.bold: true
                                    font.letterSpacing: 1.5
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 20

                                    Repeater {
                                        // Static data only — no live values in the model so delegates are never recreated
                                        model: [
                                            { icon: "", color: Config.colors.Teal   },
                                            { icon: "󰾲", color: Config.colors.Purple },
                                            { icon: "", color: Config.colors.Black   },
                                            { icon: "", color: Config.colors.Orange },
                                        ]
                                        delegate: ColumnLayout {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 20

                                            // Read live value directly from dashboard by index
                                            property real value: index === 0 ? dashboard.cpuValue
                                                               : index === 1 ? dashboard.gpuValue
                                                               : index === 2 ? dashboard.ramValue
                                                               : dashboard.diskValue

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                Rectangle { anchors.fill: parent; radius: 4; color: Qt.rgba(0,0,0,0.1) }
                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: Math.max(0, parent.height * parent.parent.value / 100)
                                                    radius: 4
                                                    color: modelData.color
                                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                                }
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.icon
                                                color: modelData.color
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize + 16
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Weather stats
                        Rectangle {
                            implicitHeight: musicCard.implicitHeight
                            //implicitWidth: weatherContent.implicitWidth + 24
                            Layout.fillWidth: true
                            radius: 10
                            color: Config.colors.Yellow
                            border.width: 4
                            border.color: Config.colors.DarkTeal
                            clip: true

                            ColumnLayout {
                                id: weatherContent
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
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
                                    Layout.bottomMargin: 24
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
                                        font.pixelSize: Config.bar.fontSize + 50
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
                                        + "°"
                                    color: Config.colors.Grey
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 5
                                }

                                Text {
                                    text: dashboard.weatherHumidity + "% humidity"
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

                                // 3-day forecast strip
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.bottomMargin: 20
                                    Text {
                                        text: "WEATHER FORECAST"
                                        color: Config.colors.Grey
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize
                                        font.bold: true
                                        font.letterSpacing: 1.5
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 20
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 100

                                    Repeater {
                                        model: 3
                                        delegate: ColumnLayout {
                                            required property int index
                                            property var fc: dashboard.weatherForecast[index] || null
                                            Layout.fillWidth: true
                                            spacing: 2
                                            visible: fc !== null

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: fc ? fc.day : ""
                                                color: Config.colors.Grey
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 4
                                                font.bold: true
                                                font.letterSpacing: 1
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: fc ? dashboard.weatherIcon(fc.desc) : ""
                                                color: Config.colors.DarkTeal
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize + 12
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: fc ? fc.high + "° / " + fc.low + "°" : ""
                                                color: Config.colors.Grey
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize - 4
                                            }
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
                            color: Config.colors.DarkTeal
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
                        color: Config.colors.Teal
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
                            color: Config.colors.subtext
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize + 8
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
                            color: Config.colors.text
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize + 4
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: "›"
                            color: Config.colors.subtext
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize + 8
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

                    // Day-of-week headers (8 columns: Wk + Mon…Sun)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 8
                        columnSpacing: 0
                        rowSpacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: "Wk"
                            color: Config.colors.Orange
                            font.family: Config.bar.fontFamily
                            font.pixelSize: Config.bar.fontSize - 8
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Config.colors.subtext
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize - 4
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Day cells (week-number sentinels interleaved at col 0)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 8
                        columnSpacing: 0
                        rowSpacing: 0
                        Repeater {
                            model: dashboard.calendarDays()
                            delegate: Item {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56

                                readonly property bool isWeek: modelData.type === 'week'
                                readonly property bool isToday:
                                    !isWeek && modelData.cur &&
                                    modelData.d === new Date().getDate() &&
                                    dashboard.calMonth === (new Date().getMonth() + 1) &&
                                    dashboard.calYear === new Date().getFullYear()

                                // Week number label
                                Text {
                                    visible: isWeek
                                    anchors.centerIn: parent
                                    text: isWeek ? modelData.num : ""
                                    color: Config.colors.Orange
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 6
                                    font.bold: true
                                    opacity: 0.7
                                }

                                // Today highlight circle
                                Rectangle {
                                    visible: !isWeek
                                    anchors.centerIn: parent
                                    width: 42; height: 42; radius: 21
                                    color: isToday ? Config.colors.Orange : "transparent"
                                }

                                // Day number
                                Text {
                                    visible: !isWeek
                                    anchors.centerIn: parent
                                    text: !isWeek ? modelData.d : ""
                                    color: isToday
                                        ? Config.colors.panel
                                        : modelData.cur
                                            ? Config.colors.text
                                            : Config.colors.subtext
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize
                                    font.bold: isToday
                                }
                            }
                        }
                    }

                    // ── To-do list ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: Config.colors.Green

                        ColumnLayout {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            spacing: 10

                            Text {
                                text: "TO-DO"
                                color: Config.colors.subtext
                                font.family: Config.bar.fontFamily
                                font.pixelSize: Config.bar.fontSize - 8
                                font.bold: true
                                font.letterSpacing: 1.5
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: 8
                                    color: Config.colors.DarkTeal

                                    TextInput {
                                        id: todoInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        color: Config.colors.text
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize - 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true

                                        Text {
                                            visible: todoInput.text === ""
                                            anchors.fill: parent
                                            text: "Add new task…"
                                            color: Config.colors.subtext
                                            font: todoInput.font
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Keys.onReturnPressed: {
                                            if (text.trim() !== "") {
                                                todoList.append({ taskText: text.trim(), done: false })
                                                text = ""
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 34; height: 34
                                    radius: 8
                                    color: Config.colors.Orange

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: Config.colors.panel
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 4
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (todoInput.text.trim() !== "") {
                                                todoList.append({ taskText: todoInput.text.trim(), done: false })
                                                todoInput.text = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: todoItemsCol.implicitHeight
                                clip: true

                                ColumnLayout {
                                    id: todoItemsCol
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: todoList
                                        delegate: Rectangle {
                                            required property int index
                                            required property string taskText
                                            required property bool done

                                            Layout.fillWidth: true
                                            height: 38
                                            radius: 8
                                            color: done ? Qt.rgba(1,1,1,0.03) : Qt.rgba(1,1,1,0.07)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 10

                                                Rectangle {
                                                    width: 18; height: 18; radius: 4
                                                    color: done ? Config.colors.Orange : "transparent"
                                                    border.width: 2
                                                    border.color: done ? Config.colors.Orange : Config.colors.subtext

                                                    Text {
                                                        visible: done
                                                        anchors.centerIn: parent
                                                        text: "✓"
                                                        color: Config.colors.panel
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: todoList.setProperty(index, "done", !done)
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: taskText
                                                    color: done ? Config.colors.subtext : Config.colors.text
                                                    font.family: Config.bar.fontFamily
                                                    font.pixelSize: Config.bar.fontSize - 4
                                                    font.strikeout: done
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: "󰅖"
                                                    color: Config.colors.subtext
                                                    font.family: Config.bar.fontFamily
                                                    font.pixelSize: Config.bar.fontSize - 4

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: todoList.remove(index, 1)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Tab 2: Media ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 2
                    spacing: 12

                    Text {
                        visible: Mpris.players.values.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: "No media playing"
                        color: Config.colors.DarkTeal
                        font.family: Config.bar.fontFamily
                        font.pixelSize: Config.bar.fontSize - 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Repeater {
                        model: Mpris.players.values
                        delegate: Rectangle {
                            id: mediaCard
                            required property var modelData
                            required property int index
                            property var player: modelData

                            property real mediaProgress: 0
                            property string mediaCurrentTime: "0:00"

                            function fmtTime(secs) {
                                var s = Math.floor(secs || 0)
                                return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
                            }

                            Timer {
                                interval: 1000
                                running: mediaCard.player && mediaCard.player.isPlaying
                                repeat: true
                                triggeredOnStart: true
                                onTriggered: {
                                    var p = mediaCard.player
                                    if (p && p.lengthSupported && p.length > 0)
                                        mediaCard.mediaProgress = Math.min(1, p.position / p.length)
                                    mediaCard.mediaCurrentTime = mediaCard.fmtTime(p ? p.position : 0)
                                }
                            }

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: Config.colors.Sand
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                // ── Left: album art + rotating radial rays ──
                                Item {
                                    id: artArea
                                    Layout.preferredWidth: Math.round(mediaCard.width * 0.32)
                                    Layout.fillHeight: true
                                    property real artSize: Math.min(width, height) * 0.5

                                    Canvas {
                                        id: raysCanvas
                                        property real breathePhase: 0
                                        anchors.fill: parent
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width / 2, cy = height / 2
                                            var halfDiag = (artArea.artSize / 2) * Math.SQRT2
                                            var innerR = halfDiag + 4
                                            var outerR = innerR + artArea.artSize * 0.12
                                            var longDelta = artArea.artSize * 0.04
                                            var breathe = 0.5 + 0.5 * Math.sin(raysCanvas.breathePhase)
                                            var growth = artArea.artSize * 0.05 * breathe
                                            var numRays = 36
                                            ctx.strokeStyle = "#D18870"
                                            ctx.lineWidth = Math.max(2, artArea.artSize * 0.02)
                                            ctx.globalAlpha = 0.6
                                            ctx.lineCap = "round"
                                            for (var i = 0; i < numRays; i++) {
                                                var angle = (i / numRays) * Math.PI * 2 - Math.PI / 2
                                                var iR = (i % 3 === 0) ? innerR - longDelta : innerR
                                                var oR = ((i % 3 === 0) ? outerR + longDelta : outerR) + growth
                                                ctx.beginPath()
                                                ctx.moveTo(cx + iR * Math.cos(angle), cy + iR * Math.sin(angle))
                                                ctx.lineTo(cx + oR * Math.cos(angle), cy + oR * Math.sin(angle))
                                                ctx.stroke()
                                            }
                                        }

                                        // One revolution every 30s + ~2.4s breathe cycle while playing; freezes in place on pause
                                        FrameAnimation {
                                            running: mediaCard.player && mediaCard.player.isPlaying
                                            onTriggered: {
                                                raysCanvas.rotation = (raysCanvas.rotation + frameTime * 12) % 360
                                                raysCanvas.breathePhase = (raysCanvas.breathePhase + frameTime * 2.6) % (Math.PI * 2)
                                                raysCanvas.requestPaint()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: artArea.artSize; height: artArea.artSize
                                        anchors.centerIn: parent
                                        radius: artArea.artSize * 0.1
                                        clip: true
                                        color: Config.colors.Orange

                                        Image {
                                            anchors.fill: parent
                                            source: mediaCard.player ? (mediaCard.player.trackArtUrl || "") : ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: source.toString() !== ""
                                        }

                                        Text {
                                            visible: !mediaCard.player || !mediaCard.player.trackArtUrl
                                            anchors.centerIn: parent
                                            text: "󰝚"
                                            color: Config.colors.panel
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: artArea.artSize * 0.4
                                        }
                                    }
                                }

                                // ── Center: info + controls + progress ──
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.leftMargin: 24
                                    Layout.rightMargin: 24
                                    spacing: 10

                                    Item { Layout.fillHeight: true }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: mediaCard.player ? (mediaCard.player.trackTitle || "—") : "—"
                                        color: Config.colors.text
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize + 8
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: mediaCard.player ? (mediaCard.player.trackArtist || "—") : "—"
                                        color: Config.colors.subtext
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize - 4
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        visible: mediaCard.player && mediaCard.player.trackAlbum !== ""
                                        text: mediaCard.player ? (mediaCard.player.trackAlbum || "") : ""
                                        color: Config.colors.Orange
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize - 4
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 28

                                        Text {
                                            text: ""
                                            color: Config.colors.text
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize + 8
                                            opacity: mediaCard.player && mediaCard.player.canGoPrevious ? 1.0 : 0.3
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: if (mediaCard.player && mediaCard.player.canGoPrevious) mediaCard.player.previous()
                                            }
                                        }

                                        Rectangle {
                                            width: 56; height: 56; radius: 28
                                            color: Config.colors.Orange
                                            Text {
                                                anchors.centerIn: parent
                                                text: mediaCard.player && mediaCard.player.isPlaying ? "" : ""
                                                color: Config.colors.panel
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: Config.bar.fontSize + 10
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: if (mediaCard.player) mediaCard.player.togglePlaying()
                                            }
                                        }

                                        Text {
                                            text: ""
                                            color: Config.colors.text
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize + 8
                                            opacity: mediaCard.player && mediaCard.player.canGoNext ? 1.0 : 0.3
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: if (mediaCard.player && mediaCard.player.canGoNext) mediaCard.player.next()
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 6
                                        visible: mediaCard.player && mediaCard.player.lengthSupported && mediaCard.player.length > 0
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 3
                                            color: Qt.rgba(1, 1, 1, 0.10)
                                        }
                                        Rectangle {
                                            width: parent.width * mediaCard.mediaProgress
                                            height: parent.height
                                            radius: 3
                                            color: Config.colors.Orange
                                            Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: mediaCard.player && mediaCard.player.lengthSupported && mediaCard.player.length > 0
                                        Text {
                                            text: mediaCard.mediaCurrentTime
                                            color: Config.colors.subtext
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 6
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: mediaCard.fmtTime(mediaCard.player ? mediaCard.player.length : 0)
                                            color: Config.colors.subtext
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 6
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                // ── Right: GIF ──
                                Item {
                                    Layout.preferredWidth: Math.round(mediaCard.width * 0.16)
                                    Layout.fillHeight: true

                                    AnimatedImage {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width * 0.8, 160); height: width
                                        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/kurukuru.gif"
                                        playing: mediaCard.player && mediaCard.player.isPlaying
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Tab 3: Performance ──
                ColumnLayout {
                    anchors.fill: parent
                    visible: dashboard.activeTab === 3
                    spacing: 14

                    // ── Top: CPU / RAM / GPU donut gauges ──
                    RowLayout {
                        Layout.fillWidth: true
                        //Layout.preferredHeight: Math.round(contentArea.height * 0.48)
                        spacing: 14

                        Repeater {
                            model: [
                                { label: "CPU", icon: "󰍛" },
                                { label: "RAM", icon: "󰘚" },
                                { label: "GPU", icon: "󰢮" }
                            ]
                            delegate: Rectangle {
                                id: gaugeCard
                                required property var modelData
                                required property int index
                                property real value: index === 0 ? dashboard.cpuValue
                                                   : index === 1 ? dashboard.ramValue
                                                   : dashboard.gpuValue
                                property string subline: index === 0
                                        ? dashboard.cpuFreqGhz.toFixed(1) + "GHz · " + Math.round(dashboard.cpuTemp) + "°C"
                                    : index === 1
                                        ? dashboard.ramUsedGb.toFixed(1) + " / " + Math.round(dashboard.ramTotalGb) + " GB"
                                        : Math.round(dashboard.gpuTemp) + "°C · " + dashboard.gpuName

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: Config.colors.card

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Item {
                                        id: gauge
                                        property real size: Math.min(gaugeCard.width, gaugeCard.height) * 0.55
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: size
                                        Layout.preferredHeight: size

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: gauge.size * 0.78; height: width
                                            radius: width / 2
                                            color: Config.colors.panel
                                        }

                                        Canvas {
                                            anchors.fill: parent
                                            property real value: gaugeCard.value
                                            onValueChanged: requestPaint()
                                            onWidthChanged: requestPaint()
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                var cx = width / 2, cy = height / 2
                                                var lw = gauge.size * 0.11
                                                var r = (gauge.size - lw) / 2
                                                ctx.lineWidth = lw
                                                ctx.lineCap = "round"
                                                ctx.strokeStyle = Config.colors.Grey
                                                ctx.globalAlpha = 0.35
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                                ctx.stroke()
                                                ctx.globalAlpha = 1.0
                                                ctx.strokeStyle = Config.colors.Orange
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, value / 100))
                                                ctx.stroke()
                                            }
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: -2

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: Math.round(gaugeCard.value)
                                                color: Config.colors.CreamyWhite
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: gauge.size * 0.28
                                                font.bold: true
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "%"
                                                color: Config.colors.subtext
                                                font.family: Config.bar.fontFamily
                                                font.pixelSize: gauge.size * 0.11
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 8
                                        Text {
                                            text: gaugeCard.modelData.icon
                                            color: Config.colors.Orange
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 2
                                        }
                                        Text {
                                            text: gaugeCard.modelData.label
                                            color: Config.colors.Orange
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 2
                                            font.bold: true
                                            font.letterSpacing: 1.5
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: gaugeCard.subline
                                        color: Config.colors.subtext
                                        font.family: Config.bar.fontFamily
                                        font.pixelSize: Config.bar.fontSize - 6
                                    }
                                }
                            }
                        }
                    }

                    // ── Bottom: per-core bars + network/disk/process info ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: Config.colors.card

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    text: "CPU CORES"
                                    color: Config.colors.subtext
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 6
                                    font.bold: true
                                    font.letterSpacing: 1.5
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 6

                                        Repeater {
                                            model: dashboard.coreLoads.length
                                            delegate: Item {
                                                required property int index
                                                property real load: dashboard.coreLoads[index] || 0
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    height: Math.max(4, parent.height * parent.load / 100)
                                                    radius: 4
                                                    color: parent.load > 66 ? Config.colors.Red
                                                         : parent.load > 33 ? Config.colors.Orange
                                                         : Config.colors.Sand
                                                    Behavior on height {
                                                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: Math.round(contentArea.width * 0.26)
                            Layout.fillHeight: true
                            radius: 10
                            color: Config.colors.card

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 0

                                Repeater {
                                    model: [
                                        { icon: "", label: "upload" },
                                        { icon: "", label: "download" },
                                        { icon: "", label: "disk /" },
                                        { icon: "", label: "processes" }
                                    ]
                                    delegate: RowLayout {
                                        id: infoRow
                                        required property var modelData
                                        required property int index
                                        property string value: index === 0 ? dashboard.netUpMbs.toFixed(1) + " MB/s"
                                                             : index === 1 ? dashboard.netDownMbs.toFixed(1) + " MB/s"
                                                             : index === 2 ? Math.round(dashboard.diskUsedGb) + " / " + Math.round(dashboard.diskTotalGb) + " GB"
                                                             : "" + dashboard.processCount

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 10

                                        Text {
                                            text: infoRow.modelData.icon
                                            color: Config.colors.Orange
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 4
                                        }
                                        Text {
                                            text: infoRow.modelData.label
                                            color: Config.colors.subtext
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 4
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: infoRow.value
                                            color: Config.colors.CreamyWhite
                                            font.family: Config.bar.fontFamily
                                            font.pixelSize: Config.bar.fontSize - 4
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
