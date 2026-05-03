import QtQuick
import QtQuick.Controls

/*
    BottomTabBar — нижняя панель вкладок (стиль бигтехов).
    Лежит поверх контента, поэтому существующие страницы не приходится
    переписывать. Активная вкладка подсвечивается акцентным цветом.
*/
Rectangle {
    id: root

    height: 64 + safeBottom
    color: "#0A1229"

    property int  currentIndex: 0
    property real safeBottom: 0

    signal tabClicked(int index)

    // Тонкая граница сверху
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: "#1F2937"
    }

    Row {
        anchors.fill: parent
        anchors.bottomMargin: root.safeBottom

        Repeater {
            model: [
                { label: "Банк",   letter: "\u20BD" },
                { label: "Крипто", letter: "\u25C8" }
            ]

            delegate: Item {
                width: root.width / 2
                height: parent.height

                required property var modelData
                required property int index

                readonly property bool active: root.currentIndex === index
                readonly property color activeColor: "#20a9bc"
                readonly property color inactiveColor: "#9CA3AF"

                Rectangle {
                    width: 28; height: 3; radius: 2
                    color: active ? activeColor : "transparent"
                    anchors.top: parent.top
                    anchors.topMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.letter
                        font.pixelSize: 22
                        font.bold: true
                        color: active ? activeColor : inactiveColor
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize: 11
                        font.bold: active
                        color: active ? activeColor : inactiveColor
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "white"
                    opacity: tabMouse.pressed ? 0.04 : 0
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    onClicked: root.tabClicked(index)
                }
            }
        }
    }
}
