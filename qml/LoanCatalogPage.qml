import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: root

    signal backToMain()
    signal openCalculator(var product)
    signal openMyLoans()
    signal openLoanHistory()

    Component.onCompleted: {
        loanController.loadProducts()
        loanController.loadUserLoans()
    }

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    // Фон
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    Flickable {
        id: flickable
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
                        onClicked: root.backToMain()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Кредиты"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
            }

            // Мои кредиты
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: myLoansCol.height + 28
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                visible: {
                    for (var i = 0; i < loanController.userLoans.length; i++) {
                        if (loanController.userLoans[i].status === "active") return true
                    }
                    return false
                }

                Column {
                    id: myLoansCol
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 8

                        Image {
                            width: 24; height: 24
                            source: "assets/clipboard.svg"
                            sourceSize: Qt.size(24, 24)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Мои кредиты"
                            font { pixelSize: 16; bold: true; family: manropeFont.name }
                            color: "#F7F7FB"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { Layout.fillWidth: true; width: 10 }

                        Rectangle {
                            width: activeCountText.width + 16
                            height: 24; radius: 12
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: activeCountText
                                anchors.centerIn: parent
                                text: {
                                    var count = 0
                                    for (var i = 0; i < loanController.userLoans.length; i++) {
                                        if (loanController.userLoans[i].status === "active") count++
                                    }
                                    return count
                                }
                                font { pixelSize: 12; bold: true }
                                color: "#0A1229"
                            }
                        }
                    }

                    // Превью активных кредитов (макс 2)
                    Repeater {
                        model: {
                            var active = []
                            for (var i = 0; i < loanController.userLoans.length && active.length < 2; i++) {
                                if (loanController.userLoans[i].status === "active")
                                    active.push(loanController.userLoans[i])
                            }
                            return active
                        }

                        delegate: Rectangle {
                            width: myLoansCol.width
                            height: 52
                            radius: 12
                            color: "#111827"

                            required property var modelData

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.product_name
                                        font { pixelSize: 13; bold: true }
                                        color: "#E5E7EB"
                                    }
                                    Text {
                                        text: "Остаток: " + Number(modelData.remaining_balance).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                        font.pixelSize: 11
                                        color: "#9CA3AF"
                                    }
                                }
                            }
                        }
                    }

                    // Кнопка «Все кредиты»
                    Rectangle {
                        width: parent.width
                        height: 42
                        radius: 12
                        color: Theme.accent
                        border.color: Theme.card

                        Text {
                            anchors.centerIn: parent
                            text: "Все мои кредиты"
                            font { pixelSize: 13; bold: true; family: manropeFont.name }
                            color: Theme.textSubtle
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openMyLoans()
                        }
                    }
                }
            }

            // История кредитов
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: historyRow.height + 28
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Row {
                    id: historyRow
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        width: 24; height: 24
                        source: "assets/history.svg"
                        sourceSize: Qt.size(24, 24)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Посмотреть историю кредитов"
                            font { pixelSize: 15; bold: true; family: manropeFont.name }
                            color: "#F7F7FB"
                        }
                        Text {
                            text: "Закрытые кредиты и статистика"
                            font.pixelSize: 11; color: "#6B7280"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.openLoanHistory()
                }
            }

            // Каталог продуктов
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Text {
                    text: "Оформить кредит"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Repeater {
                    model: loanController.products

                    delegate: Rectangle {
                        width: parent.width
                        height: productCol.height + 32
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
                            id: productCol
                            width: parent.width - 32
                            anchors.centerIn: parent
                            spacing: 10

                            // Иконка + название
                            Row {
                                spacing: 10

                                Image {
                                    width: 28; height: 28
                                    source: iconSource
                                    sourceSize: Qt.size(28, 28)
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                                        color: "#F7F7FB"
                                    }
                                    Text {
                                        text: modelData.description ?? ""
                                        font.pixelSize: 12
                                        color: "#9CA3AF"
                                        width: productCol.width - 50
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            // Параметры
                            Row {
                                width: parent.width
                                spacing: 0

                                // Ставка
                                Column {
                                    width: parent.width / 3
                                    spacing: 2
                                    Text {
                                        text: "Ставка"
                                        font.pixelSize: 11
                                        color: "#6B7280"
                                    }
                                    Text {
                                        text: "от " + Number(modelData.annual_rate).toLocaleString(Qt.locale("ru_RU"), 'f', 1) + "%"
                                        font { pixelSize: 14; bold: true }
                                        color: Theme.accent
                                    }
                                }

                                // Сумма
                                Column {
                                    width: parent.width / 3
                                    spacing: 2
                                    Text {
                                        text: "Сумма"
                                        font.pixelSize: 11
                                        color: "#6B7280"
                                    }
                                    Text {
                                        text: {
                                            var max = modelData.max_amount
                                            if (max >= 1000000)
                                                return "до " + (max / 1000000) + " млн"
                                            return "до " + (max / 1000) + " тыс"
                                        }
                                        font { pixelSize: 14; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }

                                // Срок
                                Column {
                                    width: parent.width / 3
                                    spacing: 2
                                    Text {
                                        text: "Срок"
                                        font.pixelSize: 11
                                        color: "#6B7280"
                                    }
                                    Text {
                                        text: {
                                            var m = modelData.max_term_months
                                            if (m >= 12) return "до " + Math.floor(m / 12) + " лет"
                                            return "до " + m + " мес"
                                        }
                                        font { pixelSize: 14; bold: true }
                                        color: "#E5E7EB"
                                    }
                                }
                            }

                            // Кнопка «Рассчитать»
                            Rectangle {
                                width: parent.width
                                height: 44
                                radius: 12
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Рассчитать"
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.openCalculator(modelData)
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
