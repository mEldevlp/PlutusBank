import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: historyPage
    //anchors.fill: parent

    signal backToMain()

    Component.onCompleted: {
        historyController.loadTransactions()
    }

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    // Градиентный фон
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    Column {
        id: rootColumn
        anchors.fill: parent
        spacing: 0

        // ========== Шапка ==========
        Rectangle {
            width: parent.width
            height: 60
            color: "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 16
                spacing: 8

                // Кнопка назад
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: backArea.pressed ? "#374151" : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(22, 22)
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        onClicked: backToMain()
                    }
                }

                Text {
                    text: "История операций"
                    font.pixelSize: 20
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ========== Пустое состояние ==========
        Item {
            width: parent.width
            height: parent.height - 60
            visible: !historyController.isLoading && historyController.transactions.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 16

                Image {
                        width: 64; height: 64
                        source: "assets/history.svg"
                        sourceSize: Qt.size(64, 64)
                        anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Операций пока нет"
                    font.pixelSize: 16
                    color: "#9CA3AF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Совершите первый перевод"
                    font.pixelSize: 13
                    color: "#6B7280"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ========== Список транзакций ==========
        ListView {
            id: transactionList
            width: parent.width
            height: parent.height - 60
            clip: true
            visible: historyController.transactions.length > 0

            model: historyController.transactions
            spacing: 0

            // Пагинация при скролле к концу
            onAtYEndChanged: {
                if (atYEnd && historyController.hasMore && !historyController.isLoading) {
                    historyController.loadMore()
                }
            }

            // Pull-to-refresh
            property real pullThreshold: -70
            onContentYChanged: {
                if (contentY < pullThreshold && !dragging && !historyController.isLoading) {
                    historyController.loadTransactions()
                }
            }

            // Разделитель с датой
            section.property: "date_group"
            section.delegate: Rectangle {
                width: transactionList.width
                height: 40
                color: "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        var today = new Date()
                        var todayStr = today.toLocaleDateString(Qt.locale("ru_RU"), "dd.MM.yyyy")
                        var yesterday = new Date(today.getTime() - 86400000)
                        var yesterdayStr = yesterday.toLocaleDateString(Qt.locale("ru_RU"), "dd.MM.yyyy")

                        if (section === todayStr) return "Сегодня"
                        if (section === yesterdayStr) return "Вчера"
                        return section
                    }
                    font.pixelSize: 14
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#9CA3AF"
                }
            }

            delegate: Rectangle {
                width: transactionList.width
                height: 76
                color: delegateArea.pressed ? "#1F2937" : "transparent"

                MouseArea {
                    id: delegateArea
                    anchors.fill: parent
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    // Иконка направления
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            if (modelData.direction === "in") return "#064E3B"
                            if (modelData.direction === "out") return "#7F1D1D"
                            return "#1E3A5F"  // self
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            source: {
                                if (modelData.direction === "in") return "assets/arrow-down.svg"
                                if (modelData.direction === "out") return "assets/arrow-up.svg"
                                return "assets/transfer.svg"
                            }
                            sourceSize: Qt.size(22, 22)
                        }
                    }

                    // Описание транзакции
                    Column {
                        width: parent.width - 44 - 14 - amountColumn.width - 14 - 40
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                            text: {
                                if (modelData.direction === "self") {
                                    return "Между своими счетами"
                                } else if (modelData.direction === "out") {
                                    var toName = modelData.to_name || ""
                                    var toLast4 = modelData.to_card_last4 || ""
                                    if (toName) return "Перевод → " + toName
                                    if (toLast4) return "Перевод → •••• " + toLast4
                                    return "Исходящий перевод"
                                } else {
                                    var fromName = modelData.from_name || ""
                                    var fromLast4 = modelData.from_card_last4 || ""
                                    if (fromName) return "Перевод от " + fromName
                                    if (fromLast4) return "Перевод от •••• " + fromLast4
                                    return "Входящий перевод"
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: "#6B7280"
                            text: {
                                var parts = []
                                if (modelData.description) parts.push(modelData.description)

                                var typeLabel = modelData.transaction_type === "internal" ? "Внутренний" : "Внешний"
                                parts.push(typeLabel)

                                var time = modelData.created_at || ""
                                if (time.length > 10) {
                                    parts.push(time.substring(11))  // только HH:mm
                                }
                                return parts.join(" · ")
                            }
                        }
                    }

                    // Сумма
                    Column {
                        id: amountColumn
                        anchors.verticalCenter: parent.verticalCenter
                        width: amountText.implicitWidth

                        Text {
                            id: amountText
                            font.pixelSize: 15
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            color: {
                                if (modelData.direction === "in") return "#10B981"
                                if (modelData.direction === "out") return "#EF4444"
                                return "#60A5FA"
                            }
                            text: {
                                var prefix = ""
                                if (modelData.direction === "in") prefix = "+"
                                else if (modelData.direction === "out") prefix = "-"

                                return prefix + Number(modelData.amount).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            }
                        }

                        Text {
                            font.pixelSize: 11
                            color: {
                                if (modelData.status === "completed") return "#6B7280"
                                if (modelData.status === "pending") return "#F59E0B"
                                return "#EF4444"
                            }
                            horizontalAlignment: Text.AlignRight
                            anchors.right: parent.right
                            text: {
                                if (modelData.status === "completed") return "Выполнен"
                                if (modelData.status === "pending") return "В обработке"
                                return "Ошибка"
                            }
                        }
                    }
                }

                // Разделительная линия
                Rectangle {
                    width: parent.width - 40
                    height: 1
                    color: "#1F2937"
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Индикатор загрузки внизу списка
            footer: Item {
                width: transactionList.width
                height: historyController.isLoading ? 60 : 0
                visible: historyController.isLoading

                BusyIndicator {
                    anchors.centerIn: parent
                    running: historyController.isLoading
                    palette.dark: "#27D6C5"
                }
            }
        }

        // Начальная загрузка
        BusyIndicator {
            anchors.centerIn: parent
            running: historyController.isLoading && historyController.transactions.length === 0
            visible: running
            palette.dark: "#27D6C5"
        }
    }
}
