import QtQuick
import QtQuick.Layouts
import "../"
import "../config.js" as Config

ColumnLayout {
    id: root
    required property var dashboard

    spacing: Config.gap.lg

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.gap.lg

        GreetingCard { dashboard: root.dashboard }
        SystemInfoCard { dashboard: root.dashboard }
        QuickTogglesCard { dashboard: root.dashboard }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.gap.lg

        MusicMiniCard { dashboard: root.dashboard }
        HardwareCard { dashboard: root.dashboard }
        WeatherCard { dashboard: root.dashboard }
    }

    NotificationHistoryCard { dashboard: root.dashboard }
}
