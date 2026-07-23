//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import "config.js" as Config


Scope {
    id: root

    property bool centerOpen: false
    property bool launcherOpen: false

    ListModel { id: history }

    // Silence music apps from notification sounds
    function playNotificationSound(n) {
        const app = (n.appName || "").toLowerCase();

        const silentApps = [
            "spotify",
            "spotify_player",
            "spotify-player"
        ];

        return !silentApps.includes(app);
    }

    Process {
        id: soundPlayer
        command: ["paplay", "/usr/share/sounds/freedesktop/stereo/message.oga"]
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: n => {
            if (!dash.dndEnabled && root.playNotificationSound(n))
                soundPlayer.startDetached()
            history.insert(0, {
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                urgency: n.urgency,
                time: Qt.formatDateTime(new Date(), "HH:mm"),
                image: n.image ? n.image.toString() : (
                    n.appIcon.startsWith("/") ? n.appIcon : ""
                ),
                appIcon: n.appIcon.startsWith("/") ? "" : (n.appIcon || "")
            })
            console.log("Stored image:", history.get(0).image)
            console.log("Stored appIcon:", history.get(0).appIcon)
            n.tracked = true
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.centerOpen = !root.centerOpen }
        function show(): void { root.centerOpen = true }
        function hide(): void { root.centerOpen = false }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.launcherOpen = !root.launcherOpen }
        function show(): void { root.launcherOpen = true }
        function hide(): void { root.launcherOpen = false }
    }

    NotificationPopup {
        notifModel: server.trackedNotifications
        dndEnabled: dash.dndEnabled
    }

    Dashboard {
        id: dash
        open: root.centerOpen
        historyModel: history
        onCloseRequested: root.centerOpen = false
    }

    AppLauncher {
        id: launcher
        open: root.launcherOpen
        onCloseRequested: root.launcherOpen = false
    }

    FrameReserve {}
    FrameShape {
        onHoverOpenRequested: root.centerOpen = true
        onLauncherHoverRequested: root.launcherOpen = true
    }
    Bar {}
}
