import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: historyPage

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
            visible: !historyController.isLoading && transactionList.count === 0

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
            visible: transactionList.count > 0

            model: historyController
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
                height: 96
                color: delegateArea.pressed ? "#1F2937" : "transparent"

                MouseArea {
                    id: delegateArea
                    anchors.fill: parent
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    // Иконка направления
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignVCenter
                        radius: 22
                        color: {
                            if (model.direction === "in") return "#064E3B"
                            if (model.direction === "out") return "#7F1D1D"
                            return "#1E3A5F"
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            source: {
                                if (model.direction === "in") return "assets/arrow-down-white.svg"
                                if (model.direction === "out") return "assets/arrow-up-white.svg"
                                return "assets/transfer.svg"
                            }
                            sourceSize: Qt.size(22, 22)
                        }
                    }

                    // Описание транзакции
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                            text: {
                                if (model.direction === "self") {
                                    return "Между своими счетами"
                                } else if (model.direction === "out") {
                                    var toName = model.to_name || ""
                                    var toLast4 = model.to_card_last4 || ""
                                    if (toName) return "Перевод → " + toName
                                    if (toLast4) return "Перевод → •••• " + toLast4
                                    return "Исходящий перевод"
                                } else {
                                    var fromName = model.from_name || ""
                                    var fromLast4 = model.from_card_last4 || ""
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
                            visible: !!model.description
                            text: model.description || ""
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: "#6B7280"
                            text: model.transaction_type === "internal" ? "Внутренний" : "Внешний"
                        }

                        Text {
                            width: parent.width
                            font.pixelSize: 12
                            color: "#6B7280"
                            visible: {
                                var time = model.created_at || ""
                                return time.length > 10
                            }
                            text: {
                                var time = model.created_at || ""
                                if (time.length > 10) return time.substring(11)
                                return ""
                            }
                        }
                    }

                    // Сумма — прижата вправо
                    Column {
                        id: amountColumn
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: implicitWidth

                        Text {
                            id: amountText
                            font.pixelSize: 15
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            color: {
                                if (model.direction === "in") return "#10B981"
                                if (model.direction === "out") return "#EF4444"
                                return "#60A5FA"
                            }
                            text: {
                                var prefix = ""
                                if (model.direction === "in") prefix = "+"
                                else if (model.direction === "out") prefix = "-"
                                return prefix + Number(model.amount).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            }
                        }

                        Text {
                            font.pixelSize: 11
                            color: {
                                if (model.status === "completed") return "#6B7280"
                                if (model.status === "pending") return "#F59E0B"
                                return "#EF4444"
                            }
                            horizontalAlignment: Text.AlignRight
                            anchors.right: parent.right
                            text: {
                                if (model.status === "completed") return "Выполнен"
                                if (model.status === "pending") return "В обработке"
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
                height: 60
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
            running: historyController.isLoading && transactionList.count === 0
            visible: running
            palette.dark: "#27D6C5"
        }
    }
}
