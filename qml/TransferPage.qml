import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: transferPage
    //anchors.fill: parent

    signal backToMain()

    // 0 = выбор режима, 1 = между счетами, 2 = другому человеку, 3 = успех
    property int currentStep: 0
    property string successMessage: ""

    // Данные для перевода между счетами
    property int fromAccountId: -1
    property int toAccountId: -1
    property int fromIndex: -1
    property int toIndex: -1

    // Данные для перевода другому
    property string recipientPhone: ""
    property string recipientName: ""
    property bool recipientSearching: false
    property bool recipientValid: false

    // Общее
    property string errorMessage: ""
    property bool showError: false
    property bool isLoading: false

    Component.onCompleted: {
        transferController.loadAccounts()
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
        anchors.fill: parent
        contentHeight: contentColumn.height + 40
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: 20
            anchors.horizontalCenter: parent.horizontalCenter

            Item { width: 1; height: 20 }

            // Шапка
            Row {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: "#1F2937"
                    visible: currentStep <= 2

                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(24, 24)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (currentStep === 0) {
                                backToMain()
                            } else {
                                resetError()
                                currentStep = 0
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - 60
                    spacing: 4

                    Text {
                        text: "Переводы"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                    }

                    Text {
                        text: currentStep === 0 ? "Выберите тип перевода" :
                              currentStep === 1 ? "Между своими счетами" :
                              currentStep === 2 ? "Другому человеку" :
                              "Перевод выполнен!"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#F7F7FB"
                    }
                }
            }

            // ====== Блок ошибки ======
            Rectangle {
                width: parent.width - 32
                height: showError ? 56 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 12
                color: "#7F1D1D"
                border.color: "#DC2626"
                border.width: 1
                visible: showError
                clip: true

                Behavior on height { NumberAnimation { duration: 200 } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20
                        source: "assets/warning.svg"
                        sourceSize: Qt.size(20, 20)
                    }

                    Text {
                        width: parent.width - 70
                        text: errorMessage
                        font.pixelSize: 13
                        color: "#FCA5A5"
                        wrapMode: Text.WordWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 18; height: 18
                            source: "assets/cross.svg"
                            sourceSize: Qt.size(18, 18)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: resetError()
                        }
                    }
                }
            }

            // ====== ШАГ 0: Выбор типа перевода ======
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: currentStep === 0

                // Между своими счетами
                Rectangle {
                    width: parent.width
                    height: 100
                    radius: 16
                    color: "#1F2937"
                    border.color: "#374151"
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Rectangle {
                            width: 56; height: 56; radius: 16
                            color: "#1E40AF"
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.centerIn: parent
                                width: 28; height: 28
                                source: "assets/transfer.svg"
                                sourceSize: Qt.size(28, 28)
                            }
                        }

                        Column {
                            width: parent.width - 88
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: "Между своими счетами"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#F3F4F6"
                            }

                            Text {
                                text: "Мгновенный перевод без комиссии"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            resetState()
                            currentStep = 1
                        }
                    }
                }

                // Другому человеку
                Rectangle {
                    width: parent.width
                    height: 100
                    radius: 16
                    color: "#1F2937"
                    border.color: "#374151"
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Rectangle {
                            width: 56; height: 56; radius: 16
                            color: "#7C3AED"
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.centerIn: parent
                                width: 28; height: 28
                                source: "assets/user.svg"
                                sourceSize: Qt.size(28, 28)
                            }
                        }

                        Column {
                            width: parent.width - 88
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: "Другому человеку"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#F3F4F6"
                            }

                            Text {
                                text: "По номеру телефона получателя"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            resetState()
                            currentStep = 2
                        }
                    }
                }
            }

            // ====== ШАГ 1: Между своими счетами ======
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: currentStep === 1

                // Откуда
                Text {
                    text: "Откуда"
                    font.pixelSize: 13
                    color: "#9CA3AF"
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: transferController.accounts

                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12

                            property bool isFrozenOrBlocked: !(modelData.is_active ?? true) || (modelData.is_blocked ?? false)

                            color: isFrozenOrBlocked ? "#111827" :
                                   (fromAccountId === modelData.id ? "#1E3A5F" : "#1F2937")
                            border.color: isFrozenOrBlocked ? "#374151" :
                                          (fromAccountId === modelData.id ? "#3B82F6" : "#374151")
                            border.width: fromAccountId === modelData.id && !isFrozenOrBlocked ? 2 : 1
                            opacity: isFrozenOrBlocked ? 0.5 : 1.0

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    width: 40; height: 40; radius: 10
                                    color: "#111827"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.card_brand === "visa" ? "V" :
                                              modelData.card_brand === "mastercard" ? "M" :
                                              modelData.card_brand === "mir" ? "М" : "₽"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: modelData.card_brand === "visa" ? "#3B82F6" :
                                               modelData.card_brand === "mastercard" ? "#EF4444" : "#10B981"
                                    }
                                }

                                Column {
                                    width: parent.width - 140
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: {
                                            var type = modelData.account_type === "credit" ? "Кредитный" : "Дебетовый"
                                            var card = modelData.card_number ? " •••• " + modelData.card_number.slice(-4) : ""
                                            return type + card
                                        }
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: isFrozenOrBlocked ? "#6B7280" : "#F3F4F6"
                                    }

                                    Row {
                                        spacing: 4

                                        Image {
                                            width: 12; height: 12
                                            source: (modelData.is_blocked ?? false)
                                                    ? "assets/lock.svg"
                                                    : "assets/snowflake.svg"
                                            sourceSize: Qt.size(12, 12)
                                            visible: isFrozenOrBlocked
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isFrozenOrBlocked
                                                  ? ((modelData.is_blocked ?? false) ? "Заблокирована" : "Заморожена")
                                                  : modelData.balance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                            font.pixelSize: 12
                                            color: isFrozenOrBlocked
                                                   ? ((modelData.is_blocked ?? false) ? "#EF4444" : "#60A5FA")
                                                   : "#9CA3AF"
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: fromAccountId === modelData.id && !isFrozenOrBlocked ? "#3B82F6" : "transparent"
                                    border.width: 2
                                    border.color: fromAccountId === modelData.id && !isFrozenOrBlocked ? "#3B82F6" : "#4B5563"
                                    opacity: isFrozenOrBlocked ? 0.3 : 1.0

                                    Image {
                                        anchors.centerIn: parent
                                        width: 12; height: 12
                                        source: "assets/check-mark.svg"
                                        sourceSize: Qt.size(12, 12)
                                        visible: fromAccountId === modelData.id && !isFrozenOrBlocked
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !isFrozenOrBlocked
                                onClicked: {
                                    fromAccountId = modelData.id
                                    fromIndex = index
                                }
                            }
                        }
                    }
                }

                // Разделитель со стрелкой
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: "#27D6C5"
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: "assets/arrow-down.svg"
                        sourceSize: Qt.size(22, 22)
                    }
                }

                // Куда
                Text {
                    text: "Куда"
                    font.pixelSize: 13
                    color: "#9CA3AF"
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: transferController.accounts

                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12

                            property bool isFrozenOrBlocked: !(modelData.is_active ?? true) || (modelData.is_blocked ?? false)

                            visible: modelData.id !== fromAccountId
                            color: isFrozenOrBlocked ? "#111827" :
                                   (toAccountId === modelData.id ? "#1A3A2F" : "#1F2937")
                            border.color: isFrozenOrBlocked ? "#374151" :
                                          (toAccountId === modelData.id ? "#10B981" : "#374151")
                            border.width: toAccountId === modelData.id && !isFrozenOrBlocked ? 2 : 1
                            opacity: isFrozenOrBlocked ? 0.5 : 1.0

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    width: 40; height: 40; radius: 10
                                    color: "#111827"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.card_brand === "visa" ? "V" :
                                              modelData.card_brand === "mastercard" ? "M" :
                                              modelData.card_brand === "mir" ? "М" : "₽"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: modelData.card_brand === "visa" ? "#3B82F6" :
                                               modelData.card_brand === "mastercard" ? "#EF4444" : "#10B981"
                                    }
                                }

                                Column {
                                    width: parent.width - 140
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: {
                                            var type = modelData.account_type === "credit" ? "Кредитный" : "Дебетовый"
                                            var card = modelData.card_number ? " •••• " + modelData.card_number.slice(-4) : ""
                                            return type + card
                                        }
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: isFrozenOrBlocked ? "#6B7280" : "#F3F4F6"
                                    }

                                    Row {
                                        spacing: 4

                                        Image {
                                            width: 12; height: 12
                                            source: (modelData.is_blocked ?? false)
                                                    ? "assets/lock.svg"
                                                    : "assets/snowflake.svg"
                                            sourceSize: Qt.size(12, 12)
                                            visible: isFrozenOrBlocked
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isFrozenOrBlocked
                                                  ? ((modelData.is_blocked ?? false) ? "Заблокирована" : "Заморожена")
                                                  : modelData.balance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                            font.pixelSize: 12
                                            color: isFrozenOrBlocked
                                                   ? ((modelData.is_blocked ?? false) ? "#EF4444" : "#60A5FA")
                                                   : "#9CA3AF"
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: toAccountId === modelData.id && !isFrozenOrBlocked ? "#10B981" : "transparent"
                                    border.width: 2
                                    border.color: toAccountId === modelData.id && !isFrozenOrBlocked ? "#10B981" : "#4B5563"
                                    opacity: isFrozenOrBlocked ? 0.3 : 1.0

                                    Image {
                                        anchors.centerIn: parent
                                        width: 12; height: 12
                                        source: "assets/check-mark.svg"
                                        sourceSize: Qt.size(12, 12)
                                        visible: toAccountId === modelData.id && !isFrozenOrBlocked
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !isFrozenOrBlocked
                                onClicked: {
                                    toAccountId = modelData.id
                                    toIndex = index
                                }
                            }
                        }
                    }
                }

                // Поле суммы
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Сумма перевода"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 12
                        color: "#0F172A"
                        border.color: internalAmountInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            TextInput {
                                id: internalAmountInput
                                width: parent.width - 40
                                height: parent.height
                                font.pixelSize: 20
                                font.bold: true
                                color: "#F7F7FB"
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhFormattedNumbersOnly

                                validator: DoubleValidator {
                                    bottom: 0.01
                                    top: 99999999.99
                                    decimals: 2
                                    notation: DoubleValidator.StandardNotation
                                }

                                Text {
                                    text: "0.00"
                                    font.pixelSize: 20
                                    color: "#4B5563"
                                    visible: !internalAmountInput.text && !internalAmountInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: "₽"
                                font.pixelSize: 20
                                font.bold: true
                                color: "#9CA3AF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Кнопка перевода
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16

                    property bool canTransfer: fromAccountId > 0 && toAccountId > 0 &&
                                               internalAmountInput.text.length > 0 &&
                                               parseFloat(internalAmountInput.text) > 0 &&
                                               !isLoading

                    color: canTransfer ? "#27D6C5" : "#374151"

                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: isLoading ? "Выполняется..." : "Перевести"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: parent.canTransfer ? "#050B1A" : "#6B7280"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canTransfer
                        onClicked: {
                            isLoading = true
                            resetError()
                            var amount = parseFloat(internalAmountInput.text.replace(",", "."))
                            transferController.transferInternal(fromAccountId, toAccountId, amount)
                        }
                    }
                }
            }

            // ====== ШАГ 2: Другому человеку ======
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: currentStep === 2

                // Откуда
                Text {
                    text: "Списать со счёта"
                    font.pixelSize: 13
                    color: "#9CA3AF"
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: transferController.accounts

                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12

                            property bool isFrozenOrBlocked: !(modelData.is_active ?? true) || (modelData.is_blocked ?? false)

                            visible: modelData.account_type === "debit"
                            color: isFrozenOrBlocked ? "#111827" :
                                   (fromAccountId === modelData.id ? "#1E3A5F" : "#1F2937")
                            border.color: isFrozenOrBlocked ? "#374151" :
                                          (fromAccountId === modelData.id ? "#3B82F6" : "#374151")
                            border.width: fromAccountId === modelData.id && !isFrozenOrBlocked ? 2 : 1
                            opacity: isFrozenOrBlocked ? 0.5 : 1.0

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    width: 40; height: 40; radius: 10
                                    color: "#111827"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.card_brand === "visa" ? "V" :
                                              modelData.card_brand === "mastercard" ? "M" :
                                              modelData.card_brand === "mir" ? "М" : "₽"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: modelData.card_brand === "visa" ? "#3B82F6" :
                                               modelData.card_brand === "mastercard" ? "#EF4444" : "#10B981"
                                    }
                                }

                                Column {
                                    width: parent.width - 140
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "•••• " + (modelData.card_number ? modelData.card_number.slice(-4) : "")
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: isFrozenOrBlocked ? "#6B7280" : "#F3F4F6"
                                    }

                                    Row {
                                        spacing: 4

                                        Image {
                                            width: 12; height: 12
                                            source: (modelData.is_blocked ?? false)
                                                    ? "assets/lock.svg"
                                                    : "assets/snowflake.svg"
                                            sourceSize: Qt.size(12, 12)
                                            visible: isFrozenOrBlocked
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isFrozenOrBlocked
                                                  ? ((modelData.is_blocked ?? false) ? "Заблокирована" : "Заморожена")
                                                  : modelData.balance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                            font.pixelSize: 12
                                            color: isFrozenOrBlocked
                                                   ? ((modelData.is_blocked ?? false) ? "#EF4444" : "#60A5FA")
                                                   : "#9CA3AF"
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: fromAccountId === modelData.id && !isFrozenOrBlocked ? "#3B82F6" : "transparent"
                                    border.width: 2
                                    border.color: fromAccountId === modelData.id && !isFrozenOrBlocked ? "#3B82F6" : "#4B5563"
                                    opacity: isFrozenOrBlocked ? 0.3 : 1.0

                                    Image {
                                        anchors.centerIn: parent
                                        width: 12; height: 12
                                        source: "assets/check-mark.svg"
                                        sourceSize: Qt.size(12, 12)
                                        visible: fromAccountId === modelData.id && !isFrozenOrBlocked
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !isFrozenOrBlocked
                                onClicked: fromAccountId = modelData.id
                            }
                        }
                    }
                }

                // Разделитель
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: "#7C3AED"
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: "assets/arrow-right.svg"
                        sourceSize: Qt.size(22, 22)
                    }
                }

                // Номер телефона получателя
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Номер телефона получателя"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: extPhoneInput.activeFocus ? "#7C3AED" : "#1F2937"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            Text {
                                text: "+7"
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextInput {
                                id: extPhoneInput
                                width: parent.width - 40
                                height: parent.height
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhDigitsOnly
                                maximumLength: 10

                                property string cleanDigits: ""

                                onTextChanged: {
                                    cleanDigits = text.replace(/\D/g, '').substring(0, 10)
                                    recipientValid = false
                                    recipientName = ""

                                    if (cleanDigits.length === 10) {
                                        recipientSearching = true
                                        searchTimer.restart()
                                    }
                                }

                                Text {
                                    text: "9001234567"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !extPhoneInput.text && !extPhoneInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Результат поиска получателя
                    Rectangle {
                        width: parent.width
                        height: recipientName.length > 0 ? 44 : 0
                        radius: 10
                        color: "#052E16"
                        border.color: "#10B981"
                        border.width: 1
                        visible: recipientName.length > 0
                        clip: true

                        Behavior on height { NumberAnimation { duration: 200 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            /*
                            Text {
                                text: "✓"
                                font.pixelSize: 16
                                color: "#10B981"
                                anchors.verticalCenter: parent.verticalCenter
                            }*/

                            Image {
                                width: 16; height: 16
                                source: "assets/check-mark.svg"
                                sourceSize: Qt.size(16, 16)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: recipientName
                                font.pixelSize: 14
                                font.bold: true
                                color: "#A7F3D0"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Поиск...
                    Text {
                        text: "Поиск получателя..."
                        font.pixelSize: 12
                        color: "#9CA3AF"
                        visible: recipientSearching
                    }
                }

                // Сумма
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Сумма перевода"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 12
                        color: "#0F172A"
                        border.color: externalAmountInput.activeFocus ? "#7C3AED" : "#1F2937"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            TextInput {
                                id: externalAmountInput
                                width: parent.width - 40
                                height: parent.height
                                font.pixelSize: 20
                                font.bold: true
                                color: "#F7F7FB"
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhFormattedNumbersOnly

                                validator: DoubleValidator {
                                    bottom: 0.01
                                    top: 99999999.99
                                    decimals: 2
                                    notation: DoubleValidator.StandardNotation
                                }

                                Text {
                                    text: "0.00"
                                    font.pixelSize: 20
                                    color: "#4B5563"
                                    visible: !externalAmountInput.text && !externalAmountInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: "₽"
                                font.pixelSize: 20
                                font.bold: true
                                color: "#9CA3AF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Кнопка перевода
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16

                    property bool canTransfer: fromAccountId > 0 && recipientValid &&
                                               externalAmountInput.text.length > 0 &&
                                               parseFloat(externalAmountInput.text) > 0 &&
                                               !isLoading

                    color: canTransfer ? "#7C3AED" : "#374151"

                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: isLoading ? "Выполняется..." : "Перевести"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: parent.canTransfer ? "#FFFFFF" : "#6B7280"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.canTransfer
                        onClicked: {
                            isLoading = true
                            resetError()
                            var amount = parseFloat(externalAmountInput.text.replace(",", "."))
                            transferController.transferExternal(
                                fromAccountId,
                                extPhoneInput.cleanDigits,
                                amount
                            )
                        }
                    }
                }
            }

            // ====== ШАГ 3: Успех ======
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24
                visible: currentStep === 3

                Item { width: 1; height: 20 }

                // Иконка успеха
                Rectangle {
                    width: 80; height: 80; radius: 40
                    color: "#11a24d"
                    anchors.horizontalCenter: parent.horizontalCenter

                    /*
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.pixelSize: 40
                        font.bold: true
                        color: "#10B981"
                    }*/

                    Image {
                        anchors.centerIn: parent
                        width: 40; height: 40
                        source: "assets/check-mark.svg"
                        sourceSize: Qt.size(40, 40)
                    }
                }

                Text {
                    text: "Перевод выполнен!"
                    font.pixelSize: 22
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: successMessage
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item { width: 1; height: 12 }

                // Кнопки
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: "#27D6C5"

                    Text {
                        anchors.centerIn: parent
                        text: "Новый перевод"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#050B1A"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            resetState()
                            currentStep = 0
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: "transparent"
                    border.color: "#374151"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "На главную"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#E5E7EB"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: backToMain()
                    }
                }
            }

            Item { width: 1; height: 20 }
        }
    }

    // Таймер для дебаунса поиска получателя
    Timer {
        id: searchTimer
        interval: 500
        onTriggered: {
            if (extPhoneInput.cleanDigits.length === 10) {
                transferController.findRecipientName(extPhoneInput.cleanDigits)
            }
        }
    }

    Timer {
        id: errorHideTimer
        interval: 5000
        onTriggered: resetError()
    }

    // Обработчики сигналов
    Connections {
        target: transferController

        function onTransferSuccess(message) {
            isLoading = false
            successMessage = message
            currentStep = 3
        }

        function onTransferFailed(error) {
            isLoading = false
            errorMessage = error
            showError = true
            errorHideTimer.restart()
        }

        function onRecipientFound(name) {
            recipientSearching = false
            recipientName = name
            recipientValid = true
        }

        function onRecipientNotFound() {
            recipientSearching = false
            recipientName = ""
            recipientValid = false
            errorMessage = "Получатель с таким номером не найден"
            showError = true
            errorHideTimer.restart()
        }
    }

    function resetError() {
        showError = false
        errorMessage = ""
    }

    function resetState() {
        fromAccountId = -1
        toAccountId = -1
        fromIndex = -1
        toIndex = -1
        recipientPhone = ""
        recipientName = ""
        recipientValid = false
        recipientSearching = false
        internalAmountInput.text = ""
        externalAmountInput.text = ""
        extPhoneInput.text = ""
        isLoading = false
        resetError()
        transferController.loadAccounts()
    }
}
