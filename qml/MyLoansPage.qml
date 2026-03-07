import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    signal backToCatalog()
    signal openSchedule(var loanData)

    Component.onCompleted: {
        loanController.loadUserLoans()
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

            // Шапка
            Item {
                width: parent.width
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
                    text: "Мои кредиты"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
            }

            // Пусто
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: loanController.userLoans.length === 0

                Rectangle {
                    width: parent.width; height: 130; radius: 16
                    color: "#111827"
                    border.color: "#374151"; border.width: 1

                    Column {
                        anchors.centerIn: parent; spacing: 10
                        Text { text: "📭"; font.pixelSize: 44; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "У вас нет кредитов"; font.pixelSize: 14; color: "#9CA3AF"; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // Список
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: loanController.userLoans.length > 0

                Repeater {
                    model: loanController.userLoans

                    delegate: Rectangle {
                        width: parent.width
                        height: loanItemCol.height + 28
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

                        readonly property color statusColor: {
                            var s = modelData.status ?? ""
                            if (s === "active")  return Theme.accent
                            if (s === "closed")  return "#6B7280"
                            if (s === "overdue") return "#EF4444"
                            return "#F59E0B"
                        }

                        readonly property string statusText: {
                            var s = modelData.status ?? ""
                            if (s === "active")  return "Активен"
                            if (s === "closed")  return "Погашен"
                            if (s === "overdue") return "Просрочен"
                            return "Дефолт"
                        }

                        Column {
                            id: loanItemCol
                            width: parent.width - 28
                            anchors.centerIn: parent
                            spacing: 10

                            // Заголовок
                            RowLayout {
                                width: parent.width
                                spacing: 10

                                Image {
                                    width: 24; height: 24
                                    source: iconSource
                                    sourceSize: Qt.size(24, 24)
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

                                // Статус бейдж
                                Rectangle {
                                    width: statusLabel.width + 16
                                    height: 24; radius: 12
                                    color: Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.15)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: statusLabel
                                        anchors.centerIn: parent
                                        text: statusText
                                        font { pixelSize: 11; bold: true }
                                        color: statusColor
                                    }
                                }
                            }

                            // Разделитель
                            Rectangle { width: parent.width; height: 1; color: "#374151" }

                            // Инфо-строка
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
                                    Text { text: "Платёж"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: Number(modelData.monthly_payment ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽/мес"
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                                Column {
                                    width: parent.width / 3; spacing: 2
                                    Text { text: "Остаток"; font.pixelSize: 11; color: "#6B7280" }
                                    Text {
                                        text: Number(modelData.remaining_balance ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        font { pixelSize: 13; bold: true }
                                        color: (modelData.status === "closed") ? "#6B7280" : "#EF4444"
                                    }
                                }
                            }

                            // Прогресс-бар
                            Column {
                                width: parent.width
                                spacing: 4
                                visible: modelData.status !== "closed"

                                Rectangle {
                                    width: parent.width; height: 6; radius: 3
                                    color: "#111827"

                                    Rectangle {
                                        height: parent.height; radius: 3
                                        color: Theme.accent
                                        width: {
                                            var total = Number(modelData.principal ?? 1)
                                            var paid  = Number(modelData.total_paid ?? 0)
                                            var remaining = Number(modelData.remaining_balance ?? 0)
                                            // Процент = total_paid / (total_paid + remaining)
                                            var denom = paid + remaining
                                            if (denom <= 0) return 0
                                            return parent.width * (paid / denom)
                                        }
                                    }
                                }
                                Text {
                                    text: {
                                        var paid = Number(modelData.total_paid ?? 0)
                                        var remaining = Number(modelData.remaining_balance ?? 0)
                                        var denom = paid + remaining
                                        if (denom <= 0) return "0%"
                                        return "Погашено " + Math.round(paid / denom * 100) + "%"
                                    }
                                    font.pixelSize: 11; color: "#6B7280"
                                }
                            }

                            // Кнопка «Подробнее»
                            Rectangle {
                                width: parent.width; height: 42; radius: 12
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.status === "closed" ? "История платежей" : "График и оплата"
                                    font { pixelSize: 13; bold: true; family: manropeFont.name }
                                    color: Theme.textSubtle
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.openSchedule(modelData)
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
