import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

/*
    CryptoSellPage — продажа крипты с зачислением рублей на карту.
*/
Item {
    id: root

    signal backToMain()

    property var  currency: ({})
    property real currentBalance: 0     // сколько монет у пользователя
    property real coinAmount: 0
    property var  selectedCard: null

    FontLoader { id: manropeFont; source: "assets/fonts/Manrope-Bold.ttf" }

    Component.onCompleted: {
        userSession.loadCards()
        var debit = userSession.getDebitCards()
        for (var i = 0; i < debit.length; i++) {
            var c = debit[i]
            if (c.is_active && !c.is_blocked) { selectedCard = c; break }
        }
        if (!selectedCard && debit.length > 0) selectedCard = debit[0]
    }

    Connections {
        target: cryptoController
        function onSellSuccess(message) {
            successDialog.message = message
            successDialog.visible = true
        }
        function onSellFailed(error) {
            errorDialog.message = error
            errorDialog.visible = true
        }
    }

    function livePrice() {
        for (var i = 0; i < cryptoController.currencies.length; i++) {
            var c = cryptoController.currencies[i]
            if (c.id === root.currency.id) return c.current_price
        }
        return root.currency.current_price || 0
    }

    function previewRub() {
        return Math.round(coinAmount * livePrice() * 100) / 100
    }

    // ----------- Header -----------
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 60
        color: "transparent"

        Rectangle {
            width: 36; height: 36; radius: 18
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "#1F2937"
            //Text { anchors.centerIn: parent; text: "←"; font { pixelSize: 18; bold: true }; color: "#E5E7EB" }
            Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 18; font.bold: true; color: "#E5E7EB" }
            MouseArea { anchors.fill: parent; onClicked: root.backToMain() }
        }

        Text {
            anchors.centerIn: parent
            text: "Продать " + (root.currency.symbol || "")
            font { pixelSize: 17; bold: true; family: manropeFont.name }
            color: "#FFFFFF"
        }
        GuideButton {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            onClicked: guide.open()
        }
    }

    Flickable {
        id: pageFlick
        anchors {
            top: header.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        contentHeight: col.height + 32
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: 22
            topPadding: 12
            bottomPadding: 24

            // --- Карточка с балансом и ценой ---
            Rectangle {
                id: balanceCard
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 110
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Rectangle {
                        width: 56; height: 56; radius: 28
                        color: root.currency.icon_color || Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: root.currency.icon_letter || "?"
                            font { pixelSize: 24; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Text {
                            text: "Доступно"
                            font.pixelSize: 12
                            color: "#9CA3AF"
                        }
                        Text {
                            text: Number(root.currentBalance).toFixed(8).replace(/0+$/, "").replace(/\.$/, "") + " " + (root.currency.symbol || "")
                            font { pixelSize: 18; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                        }
                        Text {
                            text: "≈ " + (Number(root.currentBalance) * livePrice()).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            font.pixelSize: 12
                            color: "#9CA3AF"
                        }
                    }
                }
            }

            // --- Сколько продать ---
            Column {
                id: amountBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "Сколько продать"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 14
                    color: "#111827"
                    border.color: amountField.activeFocus ? Theme.accent : Theme.card
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8

                        TextField {
                            id: amountField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - symLabel.width - parent.spacing
                            placeholderText: "0"
                            placeholderTextColor: "#6B7280"
                            font { pixelSize: 22; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                            background: null
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator { bottom: 0; top: 1e15; decimals: 8; locale: "en_US" }
                            onTextChanged: {
                                var n = parseFloat(text.replace(",", "."))
                                root.coinAmount = isNaN(n) ? 0 : n
                            }
                        }
                        Text {
                            id: symLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.currency.symbol || ""
                            font { pixelSize: 18; bold: true; family: manropeFont.name }
                            color: "#9CA3AF"
                        }
                    }
                }

                // Быстрые пресеты — доли от баланса
                Row {
                    spacing: 8
                    Repeater {
                        model: [0.25, 0.5, 0.75, 1.0]
                        delegate: Rectangle {
                            required property real modelData
                            width: (col.width - 32 - 24) / 4
                            height: 36
                            radius: 10
                            color: presetMouse.pressed ? "#374151" : "#1F2937"
                            border.color: Theme.cardBorder
                            Text {
                                anchors.centerIn: parent
                                text: (modelData * 100) + "%"
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                            }
                            MouseArea {
                                id: presetMouse
                                anchors.fill: parent
                                onClicked: {
                                    var v = root.currentBalance * modelData
                                    amountField.text = v.toFixed(8).replace(/0+$/, "").replace(/\.$/, "")
                                }
                            }
                        }
                    }
                }
            }

            // --- Превью результата ---
            Rectangle {
                id: previewBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 80
                radius: 14
                color: "#0F172A"
                border.color: Theme.card

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Вы получите"
                        font.pixelSize: 12
                        color: "#9CA3AF"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: previewRub().toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font { pixelSize: 22; bold: true; family: manropeFont.name }
                        color: Theme.success
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "по курсу " + livePrice().toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font.pixelSize: 11
                        color: "#6B7280"
                    }
                }
            }

            // --- Карта зачисления ---
            Column {
                id: cardPick
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "Зачислить на карту"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Repeater {
                    model: userSession.getDebitCards()

                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 64
                        radius: 14
                        color: "transparent"
                        border.color: (root.selectedCard && root.selectedCard.id === modelData.id) ? Theme.accent : Theme.card
                        border.width: (root.selectedCard && root.selectedCard.id === modelData.id) ? 2 : 1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 36; height: 36; radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#1F2937"
                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.card_brand || "").substring(0,1).toUpperCase()
                                    font { pixelSize: 14; bold: true }
                                    color: "#FFFFFF"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    text: "•••• " + (modelData.card_number || "").slice(-4)
                                    font { pixelSize: 14; bold: true; family: "Courier" }
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: (modelData.is_blocked ? "Заблокирована" :
                                          (!modelData.is_active ? "Заморожена" : "Активна"))
                                    font.pixelSize: 11
                                    color: modelData.is_blocked ? "#EF4444"
                                         : (!modelData.is_active ? "#3B82F6" : "#10B981")
                                }
                            }

                            Item {
                                width: parent.width - parent.children[0].width - parent.children[1].width - parent.spacing * 2
                                height: parent.height
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Number(modelData.balance || 0).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: "#9CA3AF"
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selectedCard = modelData
                        }
                    }
                }
            }

            // --- Кнопка "Продать" ---
            Rectangle {
                id: sellBtn
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 56
                radius: 16

                readonly property bool canSell:
                    root.coinAmount > 0
                    && root.coinAmount <= root.currentBalance
                    && root.selectedCard
                    && root.selectedCard.is_active
                    && !root.selectedCard.is_blocked
                    && !cryptoController.isLoading

                color: canSell ? Theme.success : "#1F2937"
                opacity: canSell ? 1.0 : 0.6

                Text {
                    anchors.centerIn: parent
                    text: cryptoController.isLoading
                          ? "Продаём…"
                          : "Продать за " + previewRub().toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: parent.canSell ? "#FFFFFF" : "#6B7280"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.canSell
                    onClicked: cryptoController.sell(root.currency.id, root.coinAmount, root.selectedCard.id)
                }
            }
        }
    }

    // ============ Диалоги ============
    Rectangle {
        id: successDialog
        anchors.fill: parent
        color: "#CC000000"
        visible: false; z: 100
        property string message: ""

        MouseArea { anchors.fill: parent; onClicked: { successDialog.visible = false; root.backToMain() } }
        Rectangle {
            width: parent.width - 64; anchors.centerIn: parent
            radius: 18; color: "#1F2937"; height: scol.height + 36
            MouseArea { anchors.fill: parent }
            Column {
                id: scol
                width: parent.width - 32; anchors.centerIn: parent; spacing: 12

                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: Theme.success
                    anchors.horizontalCenter: parent.horizontalCenter
                    //Text { anchors.centerIn: parent; text: "✓"; font { pixelSize: 28; bold: true }; color: "#FFFFFF" }
                    Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 28; font.bold: true; color: "#FFFFFF" }
                }
                Text {
                    width: parent.width; text: "Продажа выполнена"
                    font { pixelSize: 17; bold: true; family: manropeFont.name }
                    color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width; text: successDialog.message
                    font.pixelSize: 13; color: "#9CA3AF"
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Rectangle {
                    width: parent.width; height: 44; radius: 10
                    color: Theme.accent
                    //Text { anchors.centerIn: parent; text: "Готово"; font { pixelSize: 14; bold: true }; color: "#050B1A" }
                    Text { anchors.centerIn: parent; text: "Готово"; font.pixelSize: 14; font.bold: true; color: "#050B1A" }
                    MouseArea { anchors.fill: parent; onClicked: { successDialog.visible = false; root.backToMain() } }
                }
            }
        }
    }

    Rectangle {
        id: errorDialog
        anchors.fill: parent; color: "#CC000000"; visible: false; z: 100
        property string message: ""
        MouseArea { anchors.fill: parent; onClicked: errorDialog.visible = false }
        Rectangle {
            width: parent.width - 64; anchors.centerIn: parent
            radius: 18; color: "#1F2937"; height: ecol.height + 36
            MouseArea { anchors.fill: parent }
            Column {
                id: ecol
                width: parent.width - 32; anchors.centerIn: parent; spacing: 12
                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: Theme.errorBg
                    anchors.horizontalCenter: parent.horizontalCenter
                    //Text { anchors.centerIn: parent; text: "!"; font { pixelSize: 28; bold: true }; color: Theme.errorLight }
                    Text { anchors.centerIn: parent; text: "!"; font.pixelSize: 28; font.bold: true; color: Theme.errorLight }
                }
                Text {
                    width: parent.width; text: "Ошибка"
                    font { pixelSize: 17; bold: true; family: manropeFont.name }
                    color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width; text: errorDialog.message
                    font.pixelSize: 13; color: "#9CA3AF"
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Rectangle {
                    width: parent.width; height: 44; radius: 10
                    color: "#374151"
                    //Text { anchors.centerIn: parent; text: "Закрыть"; font { pixelSize: 14; bold: true }; color: "#E5E7EB" }
                    Text { anchors.centerIn: parent; text: "Закрыть"; font.pixelSize: 14; font.bold: true; color: "#E5E7EB" }
                    MouseArea { anchors.fill: parent; onClicked: errorDialog.visible = false }
                }
            }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "cryptoSell"
        steps: [
            { target: balanceCard, flickable: pageFlick, title: "Ваш баланс",
              text: "Сколько монет у вас есть и сколько это стоит в рублях по текущему курсу." },
            { target: amountBlock, flickable: pageFlick, title: "Сколько продать",
              text: "Введите количество монет или выберите долю от баланса: 25%, 50% или всё сразу." },
            { target: previewBlock, flickable: pageFlick, title: "Что вы получите",
              text: "Сумма в рублях по живому курсу на момент продажи." },
            { target: cardPick, flickable: pageFlick, title: "Карта зачисления",
              text: "Рубли поступят на выбранную карту сразу после продажи." },
            { target: sellBtn, flickable: pageFlick, title: "Продажа",
              text: "Подтвердите сделку — монеты спишутся, рубли зачислятся мгновенно." }
        ]
    }
}
