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
        anchors.fill: parent
        contentHeight: mainCol.height + 40
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 20

            // ═══════ Шапка ═══════
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: backArea.pressed ? "#374151" : "#1F2937"
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent; text: "‹"
                        font { pixelSize: 22; bold: true }
                        color: "#E5E7EB"
                    }
                    MouseArea { id: backArea; anchors.fill: parent; onClicked: root.backToCatalog() }
                }

                Text {
                    anchors.centerIn: parent
                    text: "История кредитов"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
            }

            // ═══════ Итоговая карточка ═══════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: summaryCol.height + 28
                radius: 16
                color: "#1F2937"

                Column {
                    id: summaryCol
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "Всего выплачено по кредитам"
                        font { pixelSize: 13; family: manropeFont.name }
                        color: "#9CA3AF"
                    }

                    Text {
                        text: Number(loanController.totalPaidAll).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font { pixelSize: 26; bold: true; family: manropeFont.name }
                        color: "#27D6C5"
                    }

                    Rectangle { width: parent.width; height: 1; color: "#374151" }

                    Row {
                        spacing: 6
                        Text {
                            text: "Закрыто кредитов:"
                            font.pixelSize: 12; color: "#6B7280"
                        }
                        Text {
                            text: loanController.closedLoans.length
                            font { pixelSize: 12; bold: true }
                            color: "#E5E7EB"
                        }
                    }
                }
            }

            // ═══════ Пусто ═══════
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: loanController.closedLoans.length === 0

                Rectangle {
                    width: parent.width; height: 110; radius: 16
                    color: "#111827"
                    border.color: "#374151"; border.width: 1

                    Column {
                        anchors.centerIn: parent; spacing: 10
                        Text { text: "📭"; font.pixelSize: 40; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "Нет закрытых кредитов"; font.pixelSize: 14; color: "#9CA3AF"; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // ═══════ Список закрытых кредитов ═══════
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: loanController.closedLoans.length > 0

                Repeater {
                    model: loanController.closedLoans

                    delegate: Rectangle {
                        width: parent.width
                        height: itemCol.height + 28
                        radius: 16
                        color: "#1F2937"

                        required property var modelData
                        required property int index

                        readonly property string icon: {
                            var cat = modelData.category ?? ""
                            if (cat === "mortgage")    return "🏠"
                            if (cat === "auto")        return "🚗"
                            if (cat === "electronics") return "💻"
                            return "💰"
                        }

                        Column {
                            id: itemCol
                            width: parent.width - 28
                            anchors.centerIn: parent
                            spacing: 10

                            // Заголовок
                            RowLayout {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: icon; font.pixelSize: 24
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Column {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.product_name ?? ""
                                        font { pixelSize: 15; bold: true; family: manropeFont.name }
                                        color: "#F7F7FB"
                                    }
                                    Text {
                                        text: "Оформлен " + (modelData.issued_at ?? "")
                                        font.pixelSize: 11; color: "#6B7280"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: closedLabel.width + 16
                                    height: 24; radius: 12
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

                            Rectangle { width: parent.width; height: 1; color: "#374151" }

                            // Инфо
                            Row {
                                width: parent.width
                                Column {
                                    width: parent.width / 3; spacing: 2
                                    Text { text: "Сумма"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: Number(modelData.principal ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                                Column {
                                    width: parent.width / 3; spacing: 2
                                    Text { text: "Выплачено"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: Number(modelData.total_paid ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                                Column {
                                    width: parent.width / 3; spacing: 2
                                    Text { text: "Закрыт"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: modelData.closed_at ?? "—"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                            }

                            // Переплата
                            Row {
                                width: parent.width
                                spacing: 4
                                Text { text: "Переплата:"; font.pixelSize: 12; color: "#6B7280" }
                                Text {
                                    property double overpay: Number(modelData.total_paid ?? 0) - Number(modelData.principal ?? 0)
                                    text: Number(Math.max(0, overpay)).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                    font { pixelSize: 12; bold: true }
                                    color: "#F59E0B"
                                }
                            }

                            // Кнопка
                            Rectangle {
                                width: parent.width; height: 42; radius: 12
                                color: "#111827"
                                border.color: "#374151"; border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "История платежей"
                                    font { pixelSize: 13; bold: true; family: manropeFont.name }
                                    color: "#27D6C5"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var loanData = modelData
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
}
