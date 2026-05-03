import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

/*
    CryptoTransferPage — перевод монет между кошельками по адресу.
    Пользователь вставляет адрес получателя (0x… 40 hex), указывает
    количество монет, видит суммарную рублёвую оценку (для информации,
    реальные деньги при transfer не списываются).
*/
Item {
    id: root

    signal backToMain()

    property var  currency: ({})
    property real currentBalance: 0      // сколько монет у отправителя
    property real coinAmount: 0
    property string recipientAddress: ""

    FontLoader { id: manropeFont; source: "assets/fonts/Manrope-Bold.ttf" }

    Connections {
        target: cryptoController
        function onTransferSuccess(message) {
            successDialog.message = message
            successDialog.visible = true
        }
        function onTransferFailed(error) {
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

    function isAddressLikelyValid(addr) {
        // Базовая проверка формы: 0x + 40 hex символов.
        // Сервер всё равно валидирует строго, это только для UX.
        if (!addr) return false
        var s = addr.trim()
        return /^0x[0-9a-fA-F]{40}$/.test(s)
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
            text: "Перевод " + (root.currency.symbol || "")
            font { pixelSize: 17; bold: true; family: manropeFont.name }
            color: "#FFFFFF"
        }
    }

    Flickable {
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

            // --- Адрес получателя ---
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "Адрес получателя"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 14
                    color: "#111827"
                    border.color: addressField.activeFocus
                                  ? Theme.accent
                                  : (root.recipientAddress.length > 0 && !isAddressLikelyValid(root.recipientAddress)
                                     ? Theme.error
                                     : Theme.card)
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 8
                        spacing: 6

                        TextField {
                            id: addressField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - pasteBtn.width - clearBtn.width - parent.spacing * 2
                            placeholderText: "0x…"
                            placeholderTextColor: "#6B7280"
                            font { pixelSize: 14; bold: true; family: "Courier" }
                            color: "#FFFFFF"
                            background: null
                            selectByMouse: true
                            onTextChanged: root.recipientAddress = text.trim()
                        }

                        Rectangle {
                            id: pasteBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64; height: 36; radius: 10
                            color: pasteMouse.pressed ? "#374151" : "#1F2937"
                            border.color: Theme.cardBorder
                            Text {
                                anchors.centerIn: parent
                                text: "Вставить"
                                font.pixelSize: 11
                                color: "#E5E7EB"
                            }
                            MouseArea {
                                id: pasteMouse
                                anchors.fill: parent
                                onClicked: addressField.paste()
                            }
                        }

                        Rectangle {
                            id: clearBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36; radius: 10
                            color: clearMouse.pressed ? "#374151" : "#1F2937"
                            border.color: Theme.cardBorder
                            visible: addressField.text.length > 0
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 13
                                color: "#9CA3AF"
                            }
                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                onClicked: addressField.text = ""
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.recipientAddress.length > 0 && !isAddressLikelyValid(root.recipientAddress)
                    text: "Адрес должен начинаться с 0x и содержать 40 hex-символов"
                    font.pixelSize: 11
                    color: Theme.errorLight
                    wrapMode: Text.WordWrap
                }
            }

            // --- Сколько перевести ---
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "Сколько перевести"
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
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 96
                radius: 14
                color: "#0F172A"
                border.color: Theme.card

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "К отправке"
                        font.pixelSize: 12
                        color: "#9CA3AF"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Number(root.coinAmount).toFixed(8).replace(/0+$/, "").replace(/\.$/, "")
                              + " " + (root.currency.symbol || "")
                        font { pixelSize: 22; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "≈ " + previewRub().toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽ по курсу "
                              + livePrice().toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font.pixelSize: 11
                        color: "#6B7280"
                    }
                }
            }

            // --- Кнопка "Перевести" ---
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 56
                radius: 16

                readonly property bool canTransfer:
                    root.coinAmount > 0
                    && root.coinAmount <= root.currentBalance
                    && isAddressLikelyValid(root.recipientAddress)
                    && !cryptoController.isLoading

                color: canTransfer ? Theme.accent : "#1F2937"
                opacity: canTransfer ? 1.0 : 0.6

                Text {
                    anchors.centerIn: parent
                    text: cryptoController.isLoading ? "Отправляем…" : "Перевести"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: parent.canTransfer ? "#050B1A" : "#6B7280"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.canTransfer
                    onClicked: cryptoController.transfer(
                                   root.currency.id,
                                   root.coinAmount,
                                   root.recipientAddress)
                }
            }

            Text {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Перевод бесплатный и мгновенный. Транзакция между кошельками, рубли не списываются."
                font.pixelSize: 11
                color: "#6B7280"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
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
                    color: Theme.accent
                    anchors.horizontalCenter: parent.horizontalCenter
                    //Text { anchors.centerIn: parent; text: "→"; font { pixelSize: 28; bold: true }; color: "#050B1A" }
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 28; font.bold: true; color: "#050B1A" }
                }
                Text {
                    width: parent.width; text: "Перевод выполнен"
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
}
