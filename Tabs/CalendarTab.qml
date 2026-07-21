import QtQuick
import QtQuick.Layouts
import "../"
import "../config.js" as Config

ColumnLayout {
    id: root
    required property var dashboard

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 20
        Text {
            text: "‹"
            color: Colors.subtext
            font.family: Config.bar.fontFamily
            font.pixelSize: Config.bar.fontSize + 20
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
            color: Colors.text
            font.family: Config.bar.fontFamily
            font.pixelSize: Config.bar.fontSize + 20
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: "›"
            color: Colors.subtext
            font.family: Config.bar.fontFamily
            font.pixelSize: Config.bar.fontSize + 10
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
            text: "Week"
            color: Colors.accent
            font.family: Config.bar.fontFamily
            font.pixelSize: Config.bar.fontSize + 4
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            Text {
                Layout.fillWidth: true
                text: modelData
                color: Colors.subtext
                font.family: Config.bar.fontFamily
                font.pixelSize: Config.bar.fontSize + 10
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Day cells (week-number sentinels interleaved at col 0)
    GridLayout {
        Layout.fillWidth: true
        columns: 8
        columnSpacing: 25
        rowSpacing: 25
        Layout.bottomMargin: 100
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
                    color: Colors.accent
                    font.family: Config.bar.fontFamily
                    font.pixelSize: Config.bar.fontSize + 4
                    font.bold: true
                    opacity: 0.7
                }

                // Today highlight circle
                Rectangle {
                    visible: !isWeek
                    anchors.centerIn: parent
                    width: 60; height: 60; radius: 20
                    color: isToday ? Colors.accent : "transparent"
                }

                // Day number
                Text {
                    visible: !isWeek
                    anchors.centerIn: parent
                    text: !isWeek ? modelData.d : ""
                    color: isToday
                        ? Colors.onAccent
                        : modelData.cur
                            ? Colors.text
                            : Colors.subtext
                    font.family: Config.bar.fontFamily
                    font.pixelSize: Config.bar.fontSize + 10
                    font.bold: isToday
                }
            }
        }
    }

    // ── To-do list ──
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Config.radius.xl
        color: Colors.card

        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 10

            Text {
                text: "TO-DO"
                color: Colors.subtext
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
                    radius: Config.radius.lg
                    color: Colors.border

                    TextInput {
                        id: todoInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        color: Colors.text
                        font.family: Config.bar.fontFamily
                        font.pixelSize: Config.bar.fontSize - 4
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Text {
                            visible: todoInput.text === ""
                            anchors.fill: parent
                            text: "Add new task…"
                            color: Colors.subtext
                            font: todoInput.font
                            verticalAlignment: Text.AlignVCenter
                        }

                        Keys.onReturnPressed: {
                            if (text.trim() !== "") {
                                dashboard.todoList.append({ taskText: text.trim(), done: false })
                                text = ""
                                dashboard.saveTodos()
                            }
                        }
                    }
                }

                Rectangle {
                    width: 34; height: 34
                    radius: Config.radius.lg
                    color: Colors.accent

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Colors.onAccent
                        font.family: Config.bar.fontFamily
                        font.pixelSize: Config.bar.fontSize + 4
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (todoInput.text.trim() !== "") {
                                dashboard.todoList.append({ taskText: todoInput.text.trim(), done: false })
                                todoInput.text = ""
                                dashboard.saveTodos()
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
                        model: dashboard.todoList
                        delegate: Rectangle {
                            required property int index
                            required property string taskText
                            required property bool done

                            Layout.fillWidth: true
                            height: 38
                            radius: Config.radius.lg
                            color: done ? Qt.rgba(1,1,1,0.03) : Qt.rgba(1,1,1,0.07)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 18; height: 18; radius: Config.radius.sm
                                    color: done ? Colors.accent : "transparent"
                                    border.width: 2
                                    border.color: done ? Colors.accent : Colors.subtext

                                    Text {
                                        visible: done
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: Colors.onAccent
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            dashboard.todoList.setProperty(index, "done", !done)
                                            dashboard.saveTodos()
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: taskText
                                    color: done ? Colors.subtext : Colors.text
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 4
                                    font.strikeout: done
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "󰅖"
                                    color: Colors.subtext
                                    font.family: Config.bar.fontFamily
                                    font.pixelSize: Config.bar.fontSize - 4

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            dashboard.todoList.remove(index, 1)
                                            dashboard.saveTodos()
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
