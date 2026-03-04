import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: topUpPage
    // БЕЗ anchors.fill: parent — StackView сам управляет размером

    // Если задан — карта уже выбрана (вызов из CardDetailPage)
    property int preselectedAccountId: -1

    signal backToMain()

    // Внутреннее состояние: выбран ровно один счёт (-1 = ничего)
    property int selectedAccountId: -1
    property string amountText: ""
    property bool isProcessing: false
    property string resultMessage: ""
    property bool resultSuccess: false

    Component.onCompleted: {
        userSession.loadCards()

        if (preselectedAccountId > 0) {
            selectedAccountId = preselectedAccountId
        }
    }

    Connections {
        target: cardController

        function onTopUpSuccess(totalAmount, cardCount) {
            isProcessing = false
            resultSuccess = true
            resultMessage = "Успешно пополнено: " +
                            totalAmount.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
            amountText = ""
            userSession.loadCards()
        }

        function onTopUpFailed(error) {
            isProcessing = false
            resultSuccess = false
            resultMessage = error
        }
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

            // ═══════ Шапка ═══════
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    width: 40; height: 40
                    radius: 20
                    color: backArea.pressed ? "#374151" : "#1F2937"
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(20, 20)
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        onClicked: backToMain()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Пополнение"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                }
            }

            // ═══════ Сумма ═══════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: amountCol.height + 32
                radius: 16
                color: "#1F2937"

                Column {
                    id: amountCol
                    width: parent.width - 32
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Сумма пополнения"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#9CA3AF"
                    }

                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 12
                        color: "#111827"
                        border.color: amountInput.activeFocus ? "#27D6C5" : "#374151"
                        border.width: amountInput.activeFocus ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            TextInput {
                                id: amountInput
                                width: parent.width - currencyLabel.width - 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: amountText
                                onTextChanged: amountText = text
                                font.pixelSize: 24
                                font.bold: true
                                font.family: manropeFont.name
                                color: "#F7F7FB"
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                validator: DoubleValidator {
                                    bottom: 0.01
                                    top: 999999999.99
                                    decimals: 2
                                    notation: DoubleValidator.StandardNotation
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "0.00"
                                    font: parent.font
                                    color: "#4B5563"
                                    visible: !parent.text
                                }
                            }

                            Text {
                                id: currencyLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: "₽"
                                font.pixelSize: 24
                                font.bold: true
                                color: "#6B7280"
                            }
                        }
                    }

                    // Быстрые суммы
                    Row {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: [100, 500, 1000, 5000]

                            Rectangle {
                                width: (parent.width - 24) / 4
                                height: 36
                                radius: 10
                                color: quickArea.pressed ? "#374151" : "#111827"
                                border.color: "#374151"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.toLocaleString(Qt.locale("ru_RU"))
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#27D6C5"
                                }

                                MouseArea {
                                    id: quickArea
                                    anchors.fill: parent
                                    onClicked: {
                                        amountText = modelData.toString()
                                        amountInput.text = amountText
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══════ Выбор карты (радиокнопки) ═══════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: cardsCol.height + 32
                radius: 16
                color: "#1F2937"

                Column {
                    id: cardsCol
                    width: parent.width - 32
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Выберите карту для пополнения"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#9CA3AF"
                    }

                    Repeater {
                        model: userSession.cards

                        Rectangle {
                            id: cardItem
                            width: cardsCol.width
                            height: 72
                            radius: 12

                            property int accId: modelData.account_id
                            property bool isSelected: topUpPage.selectedAccountId === accId
                            property bool isBlocked: (modelData.is_blocked ?? false)
                            property bool isFrozen: !(modelData.is_active ?? true) && !isBlocked
                            property bool isDisabled: isBlocked || isFrozen

                            color: isSelected ? "#112B3C" : "#111827"
                            border.color: isSelected ? "#27D6C5" : "#374151"
                            border.width: isSelected ? 2 : 1

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // Радиокнопка (кружок)
                                Rectangle {
                                    width: 26; height: 26
                                    radius: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    border.color: cardItem.isSelected ? "#27D6C5" : "#6B7280"
                                    border.width: 2
                                    opacity: cardItem.isDisabled ? 0.3 : 1.0

                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    // Внутренний заполненный кружок
                                    Rectangle {
                                        width: 14; height: 14
                                        radius: 7
                                        anchors.centerIn: parent
                                        color: "#27D6C5"
                                        scale: cardItem.isSelected ? 1.0 : 0.0
                                        visible: scale > 0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutBack
                                            }
                                        }
                                    }
                                }

                                // Цветной индикатор бренда
                                Rectangle {
                                    width: 44; height: 44
                                    radius: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: modelData.card_brand === "visa" ? "#1E3A8A" :
                                                   modelData.card_brand === "mastercard" ? "#7C3AED" : "#059669"
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: modelData.card_brand === "visa" ? "#3B82F6" :
                                                   modelData.card_brand === "mastercard" ? "#A78BFA" : "#10B981"
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.card_brand === "visa" ? "V" :
                                              modelData.card_brand === "mastercard" ? "MC" : "М"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#FFFFFF"
                                    }
                                }

                                // Инфо
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    width: parent.width - 26 - 44 - 36

                                    Text {
                                        text: (modelData.card_type === "credit" ? "Кредитная" : "Дебетовая") +
                                              " •••• " + modelData.card_number.slice(-4)
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: cardItem.isDisabled ? "#6B7280" : "#F7F7FB"
                                    }

                                    Row {
                                        spacing: 4

                                        Image {
                                            width: 12; height: 12
                                            source: cardItem.isBlocked
                                                    ? "assets/lock.svg"
                                                    : "assets/snowflake.svg"
                                            sourceSize: Qt.size(12, 12)
                                            visible: cardItem.isBlocked || cardItem.isFrozen
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: cardItem.isBlocked
                                                  ? "Заблокирована"
                                                  : (cardItem.isFrozen
                                                     ? "Заморожена"
                                                     : (modelData.balance !== undefined
                                                        ? modelData.balance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                                        : "0.00 ₽"))
                                            font.pixelSize: 12
                                            color: cardItem.isBlocked ? "#EF4444"
                                                   : (cardItem.isFrozen ? "#60A5FA" : "#9CA3AF")
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !cardItem.isDisabled
                                onClicked: {
                                    if (topUpPage.selectedAccountId === cardItem.accId) {
                                        topUpPage.selectedAccountId = -1
                                    } else {
                                        topUpPage.selectedAccountId = cardItem.accId
                                    }
                                }
                            }
                        }
                    }

                    // Нет карт
                    Text {
                        visible: !userSession.hasCards
                        text: "У вас пока нет карт"
                        font.pixelSize: 14
                        color: "#6B7280"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // ═══════ Сообщение результата ═══════
            Rectangle {
                width: parent.width - 32
                height: 48
                radius: 12
                anchors.horizontalCenter: parent.horizontalCenter
                color: resultSuccess ? "#064E3B" : "#7F1D1D"
                visible: resultMessage !== ""
                opacity: visible ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    text: resultMessage
                    font.pixelSize: 13
                    font.bold: true
                    color: resultSuccess ? "#34D399" : "#FCA5A5"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Timer {
                    running: resultMessage !== ""
                    interval: 3000
                    onTriggered: resultMessage = ""
                }
            }

            // ═══════ Кнопка ═══════
            Rectangle {
                id: topUpBtn
                width: parent.width - 32
                height: 56
                radius: 14
                anchors.horizontalCenter: parent.horizontalCenter

                property bool canTopUp: !isProcessing
                                        && selectedAccountId > 0
                                        && amountText.length > 0
                                        && parseFloat(amountText) > 0

                color: canTopUp ? (topUpBtnArea.pressed ? "#1FA89A" : "#27D6C5") : "#374151"

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: isProcessing ? "Пополнение..." : "Пополнить"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: manropeFont.name
                    color: topUpBtn.canTopUp ? "#050B1A" : "#6B7280"
                }

                MouseArea {
                    id: topUpBtnArea
                    anchors.fill: parent
                    enabled: topUpBtn.canTopUp

                    onClicked: {
                        resultMessage = ""
                        isProcessing = true
                        cardController.topUpAccounts([selectedAccountId], parseFloat(amountText))
                    }
                }
            }

            Item { width: 1; height: 20 }
        }
    }
}
