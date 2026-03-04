import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: cardDetailPage
    //anchors.fill: parent

    // Входные данные — передаются из MainPage при открытии
    property var cardData: ({})

    signal backToMain()
    signal openTopUp(int accountId)        // Пополнить (перевод между своими)
    signal openPayOrTransfer(int accountId) // Оплатить или перевести

    // Внутренние состояния
    property bool showRequisites: false
    property bool showTransactions: false
    property bool confirmBlockVisible: false
    property bool confirmFreezeVisible: false

    // Обновлённые данные карты (после freeze/block)
    property bool cardIsBlocked: cardData.is_blocked ?? false
    property bool cardIsActive: cardData.is_active ?? true
    property bool cardIsFrozen: !cardIsActive && !cardIsBlocked

    Component.onCompleted: {
        if (cardData.account_id !== undefined) {
            cardController.loadCardTransactions(cardData.account_id)
        }
    }

    Connections {
        target: cardController

        function onCardBlocked() {
            cardIsBlocked = true
            cardIsActive = false
            confirmBlockVisible = false
        }

        function onCardFrozen(isFrozen) {
            cardIsFrozen = isFrozen
            cardIsActive = !isFrozen
            confirmFreezeVisible = false
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
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.height + 40
        clip: true

        Column {
            id: mainColumn
            width: parent.width
            spacing: 20

            // ═══════════ Шапка с кнопкой назад ═══════════
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    id: backBtn
                    width: 40; height: 40
                    radius: 20
                    color: backBtnArea.pressed ? "#374151" : "#1F2937"
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
                        id: backBtnArea
                        anchors.fill: parent
                        onClicked: backToMain()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: (cardData.card_type === "credit" ? "Кредитная" : "Дебетовая") + " карта"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                }
            }

            // ═══════════ Визуализация карты ═══════════
            Rectangle {
                width: parent.width - 32
                height: 180
                radius: 20
                anchors.horizontalCenter: parent.horizontalCenter

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: cardData.card_brand === "visa" ? "#1E3A8A" :
                               cardData.card_brand === "mastercard" ? "#7C3AED" : "#059669"
                    }
                    GradientStop {
                        position: 1.0
                        color: cardData.card_brand === "visa" ? "#3B82F6" :
                               cardData.card_brand === "mastercard" ? "#A78BFA" : "#10B981"
                    }
                }

                // Оверлей для заблокированных/замороженных карт
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: "#000000"
                    opacity: cardIsBlocked ? 0.6 : (cardIsFrozen ? 0.4 : 0)
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    // Строка 1: Баланс + логотип
                    Row {
                        width: parent.width

                        Text {
                            text: (cardData.balance !== undefined ?
                                   cardData.balance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) :
                                   "0.00") + " ₽"
                            font.pixelSize: 28
                            font.bold: true
                            font.family: manropeFont.name
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: parent.width - parent.children[0].width - brandLogo.width; height: 1 }

                        Image {
                            id: brandLogo
                            width: 50; height: 30
                            source: cardData.card_brand === "visa" ? "assets/visa.svg" :
                                    cardData.card_brand === "mastercard" ? "assets/mastercard.svg" :
                                    "assets/mir.svg"
                            sourceSize: Qt.size(50, 30)
                            fillMode: Image.PreserveAspectFit
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                        }
                    }

                    Item { width: 1; height: 16 }

                    // Строка 2: Номер карты
                    Text {
                        text: "•••• " + (cardData.card_number ? cardData.card_number.slice(-4) : "")
                        font.pixelSize: 22
                        font.family: "Courier"
                        font.bold: true
                        color: "#FFFFFF"
                    }

                    // Строка 3: Тип + срок
                    Row {
                        width: parent.width

                        Text {
                            text: (cardData.card_type === "credit" ? "Кредитная" : "Дебетовая")
                            font.pixelSize: 12
                            color: "#FFFFFF"
                            opacity: 0.8
                        }

                        Item { width: parent.width - parent.children[0].width - expiryLabel.width; height: 1 }

                        Text {
                            id: expiryLabel
                            text: cardData.expiry_date ?? ""
                            font.pixelSize: 12
                            color: "#FFFFFF"
                            opacity: 0.8
                        }
                    }

                    // Статус
                    Row {
                        visible: cardIsBlocked || cardIsFrozen
                        spacing: 6

                        Image {
                            width: 14; height: 14
                            source: cardIsBlocked
                                    ? "assets/lock.svg"
                                    : "assets/snowflake.svg"
                            sourceSize: Qt.size(14, 14)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: cardIsBlocked ? "Карта заблокирована" : "Карта заморожена"
                            font.pixelSize: 13
                            font.bold: true
                            color: cardIsBlocked ? "#EF4444" : "#60A5FA"
                        }
                    }
                }
            }

            // ═══════════ Кнопки Блокировать / Заморозить ═══════════
            Rectangle {
                width: parent.width - 32
                height: 56
                radius: 16
                color: "#1F2937"
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    anchors.fill: parent

                    // Блокировать
                    Item {
                        width: parent.width / 2
                        height: parent.height

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Image {
                                width: 20; height: 20
                                source: "assets/lock.svg"
                                sourceSize: Qt.size(20, 20)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: cardIsBlocked ? "Заблокирована" : "Блокировать"
                                font.pixelSize: 12
                                font.bold: true
                                color: cardIsBlocked ? "#EF4444" : "#F7F7FB"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !cardIsBlocked
                            onClicked: confirmBlockVisible = true
                        }
                    }

                    // Разделитель
                    Rectangle {
                        width: 1
                        height: parent.height - 16
                        color: "#374151"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Заморозить
                    Item {
                        width: parent.width / 2 - 1
                        height: parent.height

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Image {
                                width: 20; height: 20
                                source: "assets/snowflake.svg"
                                sourceSize: Qt.size(20, 20)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: cardIsFrozen ? "Разморозить" : "Заморозить"
                                font.pixelSize: 12
                                font.bold: true
                                color: cardIsFrozen ? "#60A5FA" : "#F7F7FB"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !cardIsBlocked
                            onClicked: confirmFreezeVisible = true
                        }
                    }
                }
            }

            // ═══════════ Пополнить / Оплатить или перевести ═══════════
            Row {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 80
                    radius: 16
                    color: (cardIsFrozen || cardIsBlocked) ? "#111827" : "#1F2937"
                    opacity: (cardIsFrozen || cardIsBlocked) ? 0.5 : 1.0

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Image {
                            width: 24; height: 24
                            source: "assets/money-recive.svg"
                            sourceSize: Qt.size(24, 24)
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: (cardIsFrozen || cardIsBlocked) ? 0.4 : 1.0
                        }

                        Text {
                            text: "Пополнить"
                            font.pixelSize: 13
                            font.bold: true
                            color: (cardIsFrozen || cardIsBlocked) ? "#6B7280" : "#E5E7EB"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !(cardIsFrozen || cardIsBlocked)
                        onClicked: openTopUp(cardData.account_id ?? -1)
                    }
                }

                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 80
                    radius: 16
                    color: (cardIsFrozen || cardIsBlocked) ? "#111827" : "#1F2937"
                    opacity: (cardIsFrozen || cardIsBlocked) ? 0.5 : 1.0

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Image {
                            width: 24; height: 24
                            source: "assets/money-send.svg"
                            sourceSize: Qt.size(24, 24)
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: (cardIsFrozen || cardIsBlocked) ? 0.4 : 1.0
                        }

                        Text {
                            text: "Перевести"
                            font.pixelSize: 13
                            font.bold: true
                            color: (cardIsFrozen || cardIsBlocked) ? "#6B7280" : "#E5E7EB"
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !(cardIsFrozen || cardIsBlocked)
                        onClicked: openPayOrTransfer(cardData.account_id ?? -1)
                    }
                }
            }

            // ═══════════ Операции по карте ═══════════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 16
                color: "#1F2937"
                height: transactionsColumn.height + 32

                Column {
                    id: transactionsColumn
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    spacing: 12

                    // Заголовок
                    Row {
                        width: parent.width

                        Text {
                            text: "Операции по карте"
                            font.pixelSize: 16
                            font.bold: true
                            font.family: manropeFont.name
                            color: "#F7F7FB"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: parent.width - parent.children[0].width - expandBtn.width; height: 1 }

                        Text {
                            id: expandBtn
                            text: showTransactions ? "Скрыть" : "Показать"
                            font.pixelSize: 13
                            color: "#27D6C5"
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showTransactions = !showTransactions
                            }
                        }
                    }

                    // Краткий текст, если транзакций нет или свёрнуто
                    Text {
                        visible: !showTransactions
                        text: {
                            var count = cardController.cardTransactions.length
                            if (count === 0) return "Нет операций"
                            return count + " " + (count === 1 ? "операция" :
                                   (count >= 2 && count <= 4) ? "операции" : "операций")
                        }
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    // Список транзакций
                    Column {
                        width: parent.width
                        spacing: 1
                        visible: showTransactions

                        Repeater {
                            model: cardController.cardTransactions

                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 12

                                    // Иконка направления
                                    Rectangle {
                                        width: 36; height: 36
                                        radius: 18
                                        color: modelData.direction === "in" ? "#064E3B" :
                                               modelData.direction === "out" ? "#7F1D1D" : "#1E3A5F"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.centerIn: parent
                                            width: 18; height: 18
                                            source: modelData.direction === "in"
                                                    ? "assets/arrow-down.svg"
                                                    : (modelData.direction === "out"
                                                       ? "assets/arrow-up.svg"
                                                       : "assets/transfer.svg")
                                            sourceSize: Qt.size(18, 18)
                                        }
                                    }

                                    // Описание
                                    Column {
                                        width: parent.width - 36 - 12 - amountText.width - 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Text {
                                            text: {
                                                if (modelData.direction === "in")
                                                    return "От " + (modelData.from_name || "неизвестно")
                                                if (modelData.direction === "out")
                                                    return "Кому " + (modelData.to_name || "неизвестно")
                                                return "Между своими счетами"
                                            }
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: "#F7F7FB"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: modelData.created_at ?? ""
                                            font.pixelSize: 11
                                            color: "#9CA3AF"
                                        }
                                    }

                                    // Сумма
                                    Text {
                                        id: amountText
                                        text: (modelData.direction === "out" ? "- " : "+ ") +
                                              modelData.amount.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: modelData.direction === "out" ? "#EF4444" :
                                               modelData.direction === "in" ? "#10B981" : "#60A5FA"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Разделитель
                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: "#374151"
                                    anchors.bottom: parent.bottom
                                }
                            }
                        }

                        // Пусто
                        Text {
                            visible: cardController.cardTransactions.length === 0
                            text: "Нет операций по этой карте"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                            topPadding: 8
                            bottomPadding: 8
                        }
                    }
                }
            }

            // ═══════════ Реквизиты ═══════════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 16
                color: "#1F2937"
                height: requisitesColumn.height + 32

                Column {
                    id: requisitesColumn
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    spacing: 12

                    // Заголовок
                    Row {
                        width: parent.width

                        Text {
                            text: "Реквизиты"
                            font.pixelSize: 16
                            font.bold: true
                            font.family: manropeFont.name
                            color: "#F7F7FB"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: parent.width - parent.children[0].width - showReqBtn.width; height: 1 }

                        Text {
                            id: showReqBtn
                            text: showRequisites ? "Скрыть" : "Показать"
                            font.pixelSize: 13
                            color: "#27D6C5"
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showRequisites = !showRequisites
                            }
                        }
                    }

                    // Скрытые реквизиты
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: !showRequisites

                        // Номер карты замаскированный
                        RequisiteField {
                            label: "Номер карты"
                            value: "•••• •••• •••• " + (cardData.card_number ? cardData.card_number.slice(-4) : "")
                        }

                        RequisiteField {
                            label: "Срок действия"
                            value: "••/••"
                        }
                    }

                    // Открытые реквизиты
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: showRequisites

                        RequisiteField {
                            label: "Номер карты"
                            value: formatCardNumber(cardData.card_number ?? "")
                            copyable: true
                        }

                        RequisiteField {
                            label: "Срок действия"
                            value: cardData.expiry_date ?? ""
                            copyable: true
                        }

                        RequisiteField {
                            label: "CVV"
                            value: "000"
                            copyable: true
                        }

                        RequisiteField {
                            label: "Держатель карты"
                            value: cardData.card_holder_name ?? ""
                            copyable: true
                        }

                        RequisiteField {
                            label: "Номер счёта"
                            value: cardData.account_number ?? ""
                            copyable: true
                        }

                        RequisiteField {
                            label: "Тип карты"
                            value: (cardData.card_type === "credit" ? "Кредитная" : "Дебетовая") +
                                   " / " + (cardData.card_brand ?? "").toUpperCase()
                            copyable: true
                        }
                    }
                }
            }

            // ═══════════ Перевыпустить карту ═══════════
            Rectangle {
                width: parent.width - 32
                height: 54
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: "#374151"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Перевыпустить карту"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#9CA3AF"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Кнопка-пустышка
                        console.log("Перевыпуск карты — функционал не реализован")
                    }
                }
            }

            // Нижний отступ
            Item { width: 1; height: 20 }
        }
    }

    // ═══════════ Диалог подтверждения блокировки ═══════════
    Rectangle {
        id: blockDialog
        anchors.fill: parent
        color: "#80000000"
        visible: confirmBlockVisible
        z: 100

        MouseArea { anchors.fill: parent; onClicked: confirmBlockVisible = false }

        Rectangle {
            width: parent.width - 64
            height: dialogBlockCol.height + 48
            radius: 20
            color: "#1F2937"
            anchors.centerIn: parent

            MouseArea { anchors.fill: parent }  // Поглощаем клик

            Column {
                id: dialogBlockCol
                width: parent.width - 48
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "Заблокировать карту?"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: "Карта будет заблокирована навсегда. Операции по ней станут невозможны. Для восстановления потребуется перевыпуск."
                    font.pixelSize: 13
                    color: "#9CA3AF"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: "#374151"

                        Text {
                            anchors.centerIn: parent
                            text: "Отмена"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: confirmBlockVisible = false
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: "#DC2626"

                        Text {
                            anchors.centerIn: parent
                            text: "Заблокировать"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: cardController.blockCard(cardData.id)
                        }
                    }
                }
            }
        }
    }

    // ═══════════ Диалог подтверждения заморозки ═══════════
    Rectangle {
        id: freezeDialog
        anchors.fill: parent
        color: "#80000000"
        visible: confirmFreezeVisible
        z: 100

        MouseArea { anchors.fill: parent; onClicked: confirmFreezeVisible = false }

        Rectangle {
            width: parent.width - 64
            height: dialogFreezeCol.height + 48
            radius: 20
            color: "#1F2937"
            anchors.centerIn: parent

            MouseArea { anchors.fill: parent }

            Column {
                id: dialogFreezeCol
                width: parent.width - 48
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: cardIsFrozen ? "Разморозить карту?" : "Заморозить карту?"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: cardIsFrozen
                        ? "Карта снова станет активной. Все операции будут доступны."
                        : "Операции по карте будут временно приостановлены. Вы сможете разморозить карту в любое время."
                    font.pixelSize: 13
                    color: "#9CA3AF"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: "#374151"

                        Text {
                            anchors.centerIn: parent
                            text: "Отмена"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: confirmFreezeVisible = false
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: cardIsFrozen ? "#10B981" : "#3B82F6"

                        Text {
                            anchors.centerIn: parent
                            text: cardIsFrozen ? "Разморозить" : "Заморозить"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: cardController.freezeCard(cardData.id)
                        }
                    }
                }
            }
        }
    }

    // ═══════════ Вспомогательный компонент — поле реквизита ═══════════
    component RequisiteField: Column {
        property string label: ""
        property string value: ""
        property bool copyable: false

        width: parent.width
        spacing: 4

        Text {
            text: label
            font.pixelSize: 11
            color: "#6B7280"
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 10
            color: "#111827"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: copyBtn.visible ? copyBtn.left : parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: value
                font.pixelSize: 14
                font.family: "Courier"
                color: "#E5E7EB"
                elide: Text.ElideRight
            }

            Image {
                id: copyBtn
                visible: copyable
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                source: "assets/copy.svg"
                sourceSize: Qt.size(18, 18)
                opacity: copyArea.pressed ? 0.5 : 1.0

                MouseArea {
                    id: copyArea
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cardController.copyToClipboard(value)
                        copiedToast.show()
                    }
                }
            }

            // Мини-тост «Скопировано»
            Rectangle {
                id: copiedToast
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                width: copiedLabel.width + 16
                height: 24
                radius: 8
                color: "#10B981"
                opacity: 0
                visible: opacity > 0

                Text {
                    id: copiedLabel
                    anchors.centerIn: parent
                    text: "Скопировано"
                    font.pixelSize: 11
                    color: "#FFFFFF"
                }

                function show() {
                    opacity = 1
                    hideTimer.restart()
                }

                Timer {
                    id: hideTimer
                    interval: 1200
                    onTriggered: copiedToast.opacity = 0
                }

                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    // Хелпер для форматирования номера карты
    function formatCardNumber(num) {
        if (!num) return ""
        var clean = num.replace(/\s/g, "")
        if (clean.length < 16) return clean
        return clean.substring(0, 4) + " " + clean.substring(4, 8) + " " +
               clean.substring(8, 12) + " " + clean.substring(12, 16)
    }
}
