import QtQuick
import PlutusBank
import "."

/*
    GuideButton — круглая кнопка «?» для запуска гида по экрану.
    Размещается в правом верхнем углу шапки страницы.

        GuideButton { onClicked: guide.open() }
*/

Rectangle {
    id: root

    signal clicked()

    width: 34
    height: 34
    radius: 17
    color: area.pressed ? Theme.cardLight : Theme.card
    border.color: Theme.cardBorder
    border.width: 1

    Accessible.role: Accessible.Button
    Accessible.name: "Справка по экрану"

    Text {
        anchors.centerIn: parent
        text: "?"
        font { pixelSize: 16; bold: true }
        color: Theme.accentLight
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
