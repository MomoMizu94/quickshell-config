import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick


Scope {
    id: root

    property bool centerOpen: false

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
            //soundPlayer.startDetached()
            if (root.playNotificationSound(n))
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

    NotificationPopup {
        notifModel: server.trackedNotifications
    }

    Dashboard {
        visible: root.centerOpen
        historyModel: history
        onCloseRequested: root.centerOpen = false
    }
}
