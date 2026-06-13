import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    signal backToCatalog()
    signal openSchedule(var loanData)

    Component.onCompleted: {
        loanController.loadClosedLoans()
    }

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width                 // <-- ВАЖНО: фиксируем contentWidth, иначе parent.width у детей нестабилен
        contentHeight: mainCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainCol
            width: flick.width              // <-- привязываемся к Flickable, а не parent.width
            spacing: 20

            // Шапка
            Item {
                width: mainCol.width
                height: 56

                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: "transparent"
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(24, 24)
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        onClicked: root.backToCatalog()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "История кредитов"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
                GuideButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: guide.open()
                }
            }

            // Итоговая карточка
            Rectangle {
                id: summaryCard
                width: mainCol.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: summaryCol.implicitHeight + 28
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Column {
                    id: summaryCol
                    width: summaryCard.width - 28
                    x: 14                          // <-- было anchors.centerIn — заменено на x/y чтобы избежать петли биндинга по высоте
                    y: 14
                    spacing: 8

                    Text {
                        text: "Всего выплачено по кредитам"
                        font { pixelSize: 13; family: manropeFont.name }
                        color: "#9CA3AF"
                    }

                    Text {
                        text: Number(loanController.totalPaidAll).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font { pixelSize: 26; bold: true; family: manropeFont.name }
                        color: Theme.accent
                    }

                    Rectangle { width: summaryCol.width; height: 1; color: "#374151" }

                    Row {
                        spacing: 6
                        Text {
                            text: "Закрыто кредитов:"
                            font.pixelSize: 12; color: "#6B7280"
                        }
                        Text {
                            text: String(loanController.closedLoans.length)   // <-- явно строка, не голое число
                            font { pixelSize: 12; bold: true }
                            color: "#E5E7EB"
                        }
                    }
                }
            }

            // Пусто
            Column {
                id: emptyBlock
                width: mainCol.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: loanController.closedLoans.length === 0

                Rectangle {
                    id: emptyCard
                    width: emptyBlock.width
                    height: 110
                    radius: 16
                    color: "#111827"
                    border.color: "#374151"; border.width: 1

                    // Внутренняя колонка — даём ЯВНУЮ ширину, иначе anchors.horizontalCenter
                    // у дочерних Text'ов завязывается на childrenRect.width,
                    // что на Windows/D3D11 раскачивает ресайз сценграфа -> device removed.
                    Column {
                        width: emptyCard.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: "📭"
                            font.pixelSize: 40
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Нет закрытых кредитов"
                            font.pixelSize: 14
                            color: "#9CA3AF"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            // Список закрытых кредитов
            Column {
                id: listBlock
                width: mainCol.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: loanController.closedLoans.length > 0

                Repeater {
                    model: loanController.closedLoans

                    delegate: Rectangle {
                        id: loanCard
                        width: listBlock.width
                        height: itemCol.implicitHeight + 28
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        required property var modelData
                        required property int index

                        readonly property string iconSource: {
                            var cat = modelData.category ?? ""
                            if (cat === "mortgage")    return "assets/house.svg"
                            if (cat === "auto")        return "assets/car.svg"
                            if (cat === "electronics") return "assets/laptop.svg"
                            return "assets/money.svg"
                        }

                        Column {
                            id: itemCol
                            width: loanCard.width - 28
                            x: 14
                            y: 14
                            spacing: 10

                            // Заголовок
                            RowLayout {
                                width: itemCol.width
                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    source: loanCard.iconSource
                                    sourceSize: Qt.size(24, 24)
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Column {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: loanCard.modelData.product_name ?? ""
                                        font { pixelSize: 15; bold: true; family: manropeFont.name }
                                        color: "#F7F7FB"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: "Оформлен " + (loanCard.modelData.issued_at ?? "")
                                        font.pixelSize: 11; color: "#6B7280"
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: closedLabel.implicitWidth + 16
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: Qt.rgba(0.42, 0.44, 0.50, 0.15)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: closedLabel
                                        anchors.centerIn: parent
                                        text: "Погашен"
                                        font { pixelSize: 11; bold: true }
                                        color: "#6B7280"
                                    }
                                }
                            }

                            Rectangle { width: itemCol.width; height: 1; color: "#374151" }

                            // Инфо
                            Row {
                                width: itemCol.width
                                Column {
                                    width: itemCol.width / 3; spacing: 2
                                    Text { text: "Сумма"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: Number(loanCard.modelData.principal ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                                Column {
                                    width: itemCol.width / 3; spacing: 2
                                    Text { text: "Выплачено"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: Number(loanCard.modelData.total_paid ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                                Column {
                                    width: itemCol.width / 3; spacing: 2
                                    Text { text: "Закрыт"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: loanCard.modelData.closed_at ? loanCard.modelData.closed_at : "—"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                            }

                            // Переплата
                            Row {
                                width: itemCol.width
                                spacing: 4
                                Text { text: "Переплата:"; font.pixelSize: 12; color: "#6B7280" }
                                Text {
                                    readonly property double overpay:
                                        Number(loanCard.modelData.total_paid ?? 0) - Number(loanCard.modelData.principal ?? 0)
                                    text: Number(Math.max(0, overpay)).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                    font { pixelSize: 12; bold: true }
                                    color: Theme.textMuted
                                }
                            }

                            // Кнопка
                            Rectangle {
                                width: itemCol.width; height: 42; radius: 12
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "История платежей"
                                    font { pixelSize: 13; bold: true; family: manropeFont.name }
                                    color: Theme.textSubtle
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var loanData = loanCard.modelData
                                        loanData["status"] = "closed"
                                        loanData["remaining_balance"] = 0
                                        root.openSchedule(loanData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 20 }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "loanHistory"
        steps: [
            { target: summaryCard, flickable: flick, title: "Итоги",
              text: "Сколько всего выплачено по кредитам и сколько кредитов закрыто." },
            { target: listBlock, flickable: flick, title: "Закрытые кредиты",
              text: "По каждому — сумма, переплата и даты. Кнопка «История платежей» откроет полный график выплат." }
        ]
    }
}
