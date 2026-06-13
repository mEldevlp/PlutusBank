import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var product: ({})

    signal backToCatalog()
    signal goToMyLoans()

    // Состояние
    property double loanAmount:  product.min_amount ?? 100000
    property int    loanMonths:  product.min_term_months ?? 6
    property int    selectedAccountId: -1
    property bool   isProcessing: false
    property string resultMessage: ""
    property bool   resultSuccess: false
    property bool   showSuccess: false
    property var    approvedAccount: ({})

    // Рассчитанные значения
    property double monthlyPayment: 0
    property double totalAmount: 0
    property double overpayment: 0

    // Лимиты из продукта
    readonly property double minAmount: product.min_amount ?? 10000
    readonly property double maxAmount: product.max_amount ?? 1000000
    readonly property int    minTerm:   product.min_term_months ?? 3
    readonly property int    maxTerm:   product.max_term_months ?? 60

    function recalc() {
        var r = loanController.calculatePayment(loanAmount, loanMonths, product.annual_rate ?? 10)
        monthlyPayment = r.monthlyPayment
        totalAmount    = r.totalAmount
        overpayment    = r.overpayment
    }

    function clampAmount(val) {
        return Math.max(minAmount, Math.min(maxAmount, val))
    }

    function clampTerm(val) {
        return Math.max(minTerm, Math.min(maxTerm, val))
    }

    Component.onCompleted: {
        loanController.loadAccounts()
        recalc()
    }

    Connections {
        target: loanController
        function onLoanApproved(message) {
            isProcessing = false
            resultSuccess = true
            resultMessage = message
            // Перезагружаем счета чтобы получить актуальный баланс
            loanController.loadAccounts()
            // Находим карту куда зачислили
            for (var i = 0; i < loanController.accounts.length; i++) {
                if (loanController.accounts[i].id === selectedAccountId) {
                    approvedAccount = loanController.accounts[i]
                    break
                }
            }
            showSuccess = true
        }
        function onLoanFailed(error) {
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
        id: pageFlick
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
                    text: product.name ?? "Калькулятор"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
                GuideButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: guide.open()
                }
            }

            // Сумма
            Column {
                id: amountBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    text: "Сумма кредита"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                // Поле ввода суммы
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 12
                    color: "#111827"
                    border.color: amountInput.activeFocus ? Theme.accent : "#374151"
                    border.width: amountInput.activeFocus ? 2 : 1

                    TextInput {
                        id: amountInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 40
                        verticalAlignment: TextInput.AlignVCenter
                        font { pixelSize: 24; bold: true; family: manropeFont.name }
                        color: "#F7F7FB"
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: Number(loanAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0)

                        property bool updating: false

                        onTextChanged: {
                            if (updating) return
                            var raw = text.replace(/[^\d]/g, "")
                            var num = parseInt(raw) || 0
                            if (num > 0) {
                                loanAmount = clampAmount(num)
                                amountSlider.value = loanAmount
                                recalc()
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus) {
                                loanAmount = clampAmount(loanAmount)
                                amountSlider.value = loanAmount
                                updating = true
                                text = Number(loanAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0)
                                updating = false
                                recalc()
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "₽"
                        font { pixelSize: 20; bold: true }
                        color: "#6B7280"
                    }
                }

                Slider {
                    id: amountSlider
                    width: parent.width
                    from: minAmount
                    to: maxAmount
                    stepSize: {
                        var range = to - from
                        if (range >= 10000000) return 100000
                        if (range >= 1000000)  return 50000
                        if (range >= 100000)   return 10000
                        return 1000
                    }
                    value: loanAmount

                    onValueChanged: {
                        loanAmount = value
                        amountInput.updating = true
                        amountInput.text = Number(loanAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0)
                        amountInput.updating = false
                        recalc()
                    }

                    background: Rectangle {
                        x: amountSlider.leftPadding
                        y: amountSlider.topPadding + amountSlider.availableHeight / 2 - height / 2
                        width: amountSlider.availableWidth
                        height: 4; radius: 2
                        color: "#374151"

                        Rectangle {
                            width: amountSlider.visualPosition * parent.width
                            height: parent.height; radius: 2
                            color: Theme.accent
                        }
                    }

                    handle: Rectangle {
                        x: amountSlider.leftPadding + amountSlider.visualPosition * (amountSlider.availableWidth - width)
                        y: amountSlider.topPadding + amountSlider.availableHeight / 2 - height / 2
                        width: 24; height: 24; radius: 12
                        color: amountSlider.pressed ? Qt.lighter(Theme.accent, 1.2) : Theme.accent
                        border.color: "#FFFFFF"; border.width: 2
                    }
                }

                Row {
                    id: amountLabelsRow
                    width: parent.width

                    Text {
                        id: amountMinLabel
                        text: Number(minAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                        font.pixelSize: 11; color: "#6B7280"
                    }
                    Item {
                        width: amountLabelsRow.width - amountMinLabel.width - amountMaxLabel.width
                        height: 1
                    }
                    Text {
                        id: amountMaxLabel
                        text: Number(maxAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                        font.pixelSize: 11; color: "#6B7280"
                    }
                }
            }

            // ═══════ Срок ═══════
            Column {
                id: termBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    text: "Срок кредита"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                // Поле ввода срока в месяцах
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 12
                    color: "#111827"
                    border.color: termInput.activeFocus ? Theme.accent : "#374151"
                    border.width: termInput.activeFocus ? 2 : 1

                    TextInput {
                        id: termInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 50
                        verticalAlignment: TextInput.AlignVCenter
                        font { pixelSize: 24; bold: true; family: manropeFont.name }
                        color: "#F7F7FB"
                        inputMethodHints: Qt.ImhDigitsOnly

                        property bool updating: false

                        function formatTerm(m) {
                            var years = Math.floor(m / 12)
                            var months = m % 12
                            var s = ""
                            if (years > 0) s += years + " " + (years === 1 ? "год" : years < 5 ? "года" : "лет")
                            if (months > 0) {
                                if (s.length > 0) s += " "
                                s += months + " мес"
                            }
                            return s || m + " мес"
                        }

                        text: formatTerm(loanMonths)

                        onTextChanged: {
                            if (updating) return
                            var raw = text.replace(/[^\d]/g, "")
                            var num = parseInt(raw) || 0
                            if (num > 0) {
                                loanMonths = clampTerm(num)
                                termSlider.value = loanMonths
                                recalc()
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                // При фокусе показываем только число месяцев для удобства ввода
                                updating = true
                                text = String(loanMonths)
                                updating = false
                            } else {
                                loanMonths = clampTerm(loanMonths)
                                termSlider.value = loanMonths
                                updating = true
                                text = formatTerm(loanMonths)
                                updating = false
                                recalc()
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "мес"
                        font { pixelSize: 14; bold: true }
                        color: "#6B7280"
                        visible: termInput.activeFocus
                    }
                }

                Slider {
                    id: termSlider
                    width: parent.width
                    from: minTerm
                    to: maxTerm
                    stepSize: 1
                    value: loanMonths

                    onValueChanged: {
                        loanMonths = value
                        termInput.updating = true
                        termInput.text = termInput.activeFocus
                            ? String(loanMonths)
                            : termInput.formatTerm(loanMonths)
                        termInput.updating = false
                        recalc()
                    }

                    background: Rectangle {
                        x: termSlider.leftPadding
                        y: termSlider.topPadding + termSlider.availableHeight / 2 - height / 2
                        width: termSlider.availableWidth
                        height: 4; radius: 2
                        color: "#374151"

                        Rectangle {
                            width: termSlider.visualPosition * parent.width
                            height: parent.height; radius: 2
                            color: Theme.accent
                        }
                    }

                    handle: Rectangle {
                        x: termSlider.leftPadding + termSlider.visualPosition * (termSlider.availableWidth - width)
                        y: termSlider.topPadding + termSlider.availableHeight / 2 - height / 2
                        width: 24; height: 24; radius: 12
                        color: termSlider.pressed ? Qt.lighter(Theme.accent, 1.2) : Theme.accent
                        border.color: "#FFFFFF"; border.width: 2
                    }
                }

                Row {
                    id: termLabelsRow
                    width: parent.width

                    Text {
                        id: termMinLabel
                        text: minTerm + " мес"
                        font.pixelSize: 11; color: "#6B7280"
                    }
                    Item {
                        width: termLabelsRow.width - termMinLabel.width - termMaxLabel.width
                        height: 1
                    }
                    Text {
                        id: termMaxLabel
                        text: maxTerm + " мес"
                        font.pixelSize: 11; color: "#6B7280"
                    }
                }
            }

            // Результат расчёта
            Rectangle {
                id: resultBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: resultCol.height + 28
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Column {
                    id: resultCol
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 14

                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "Ежемесячный платёж"
                            font.pixelSize: 13; color: "#9CA3AF"
                        }
                        Text {
                            text: Number(monthlyPayment).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            font { pixelSize: 26; bold: true; family: manropeFont.name }
                            color: Theme.accent
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#374151" }

                    Row {
                        width: parent.width

                        Column {
                            width: parent.width / 3
                            spacing: 2
                            Text { text: "Ставка"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(product.annual_rate ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 1) + "%"
                                font { pixelSize: 14; bold: true }
                                color: Theme.accent
                            }
                        }

                        Column {
                            width: parent.width / 3
                            spacing: 2
                            Text { text: "Переплата"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(overpayment).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                font { pixelSize: 14; bold: true }
                                color: Theme.textMuted
                            }
                        }

                        Column {
                            width: parent.width / 3
                            spacing: 2
                            Text { text: "Итого"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(totalAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                font { pixelSize: 14; bold: true }
                                color: "#E5E7EB"
                            }
                        }
                    }
                }
            }

            // Выбор счёта
            Rectangle {
                id: accountPick
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: accountsCol.height + 32
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockAltPosEnd }
                }
                border.color: Theme.card

                Column {
                    id: accountsCol
                    width: parent.width - 32
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Зачислить на счёт"
                        font { pixelSize: 14; bold: true; family: manropeFont.name }
                        color: "#9CA3AF"
                    }

                    Repeater {
                        model: loanController.accounts

                        Rectangle {
                            id: accItem
                            width: accountsCol.width
                            height: 72
                            radius: 12

                            required property var modelData

                            property int accId: modelData.id
                            property bool isSelected: root.selectedAccountId === accId
                            property bool isBlocked: (modelData.is_blocked ?? false)
                            property bool isFrozen:  !(modelData.is_active ?? true) && !isBlocked
                            property bool isDisabled: isBlocked || isFrozen

                            color: isSelected ? "#112B3C" : "#111827"
                            border.color: isSelected ? Theme.accent : "#374151"
                            border.width: isSelected ? 2 : 1

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on color        { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // Радиокнопка
                                Rectangle {
                                    width: 26; height: 26; radius: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    border.color: accItem.isSelected ? Theme.accent : "#6B7280"
                                    border.width: 2
                                    opacity: accItem.isDisabled ? 0.3 : 1.0

                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        anchors.centerIn: parent
                                        color: Theme.accent
                                        scale: accItem.isSelected ? 1.0 : 0.0
                                        visible: scale > 0

                                        Behavior on scale {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                        }
                                    }
                                }

                                // Иконка бренда карты
                                Rectangle {
                                    width: 44; height: 44; radius: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: modelData.card_brand === "visa"
                                                    ? Theme.grVisaPosStart
                                                    : modelData.card_brand === "mastercard"
                                                        ? Theme.grMSPosStart
                                                        : Theme.grMirPosStart
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: modelData.card_brand === "visa"
                                                    ? Theme.grVisaPosEnd
                                                    : modelData.card_brand === "mastercard"
                                                        ? Theme.grMSPosEnd
                                                        : Theme.grMirPosEnd
                                        }
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        width: 28; height: 28
                                        sourceSize: Qt.size(28, 28)
                                        fillMode: Image.PreserveAspectFit
                                        source: modelData.card_brand === "visa"
                                                ? "assets/visa.svg"
                                                : modelData.card_brand === "mastercard"
                                                    ? "assets/mastercard.svg"
                                                    : "assets/mir.svg"
                                    }
                                }

                                // Информация о карте
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    width: parent.width - 26 - 44 - 36

                                    Text {
                                        text: "Дебетовая •••• " + (modelData.card_number ?? "").slice(-4)
                                        font { pixelSize: 14; bold: true }
                                        color: accItem.isDisabled ? "#6B7280" : "#F7F7FB"
                                    }

                                    Row {
                                        spacing: 4

                                        Image {
                                            width: 12; height: 12
                                            source: accItem.isBlocked
                                                    ? "assets/lock.svg"
                                                    : "assets/snowflake.svg"
                                            sourceSize: Qt.size(12, 12)
                                            visible: accItem.isBlocked || accItem.isFrozen
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: accItem.isBlocked
                                                  ? "Заблокирована"
                                                  : (accItem.isFrozen
                                                     ? "Заморожена"
                                                     : Number(modelData.balance ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽")
                                            font.pixelSize: 12
                                            color: accItem.isBlocked ? "#EF4444"
                                                   : (accItem.isFrozen ? "#60A5FA" : "#9CA3AF")
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !accItem.isDisabled
                                onClicked: {
                                    if (root.selectedAccountId === accItem.accId)
                                        root.selectedAccountId = -1
                                    else
                                        root.selectedAccountId = accItem.accId
                                }
                            }
                        }
                    }

                    // Нет счетов
                    Text {
                        visible: loanController.accounts.length === 0
                        text: "У вас пока нет дебетовых карт"
                        font.pixelSize: 14
                        color: "#6B7280"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Ошибка (инлайн)
            Text {
                visible: resultMessage.length > 0 && !resultSuccess
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: resultMessage
                font { pixelSize: 14; bold: true }
                color: "#EF4444"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // Кнопка Оформить
            Rectangle {
                id: applyBtn
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 52
                radius: 16
                color: (selectedAccountId > 0 && !isProcessing) ? Theme.accent : "#374151"
                opacity: (selectedAccountId > 0 && !isProcessing) ? 1.0 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: isProcessing ? "Оформление..." : "Оформить кредит"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#FFFFFF"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: selectedAccountId > 0 && !isProcessing
                    onClicked: {
                        resultMessage = ""
                        isProcessing = true
                        loanController.applyForLoan(
                            product.id,
                            loanAmount,
                            loanMonths,
                            selectedAccountId
                        )
                    }
                }
            }

            Item { width: 1; height: 20 }
        }
    }

    // Оверлей «Кредит одобрен»
    Item {
        id: successOverlay
        anchors.fill: parent
        visible: false
        opacity: 0
        scale: 0.85
        z: 100

        property bool isActive: showSuccess

        states: [
            State {
                name: "active"; when: successOverlay.isActive
                PropertyChanges { target: successOverlay; opacity: 1.0; visible: true; scale: 1.0 }
            },
            State {
                name: "inactive"; when: !successOverlay.isActive
                PropertyChanges { target: successOverlay; opacity: 0.0; scale: 0.85 }
            }
        ]

        transitions: [
            Transition {
                to: "active"
                SequentialAnimation {
                    PropertyAction { target: successOverlay; property: "visible"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: successOverlay; property: "opacity"; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { target: successOverlay; property: "scale"; duration: 400; easing.type: Easing.OutBack }
                    }
                }
            },
            Transition {
                to: "inactive"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: successOverlay; property: "opacity"; duration: 200; easing.type: Easing.InCubic }
                        NumberAnimation { target: successOverlay; property: "scale"; duration: 200; easing.type: Easing.InCubic }
                    }
                    PropertyAction { target: successOverlay; property: "visible"; value: false }
                }
            }
        ]

        // Затемнённый фон
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0A1229" }
                GradientStop { position: 1.0; color: "#000000" }
            }
        }

        Column {
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24

            // Иконка успеха
            Rectangle {
                width: 80; height: 80; radius: 40
                color: "#11a24d"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    anchors.centerIn: parent
                    width: 40; height: 40
                    source: "assets/check-mark.svg"
                    sourceSize: Qt.size(40, 40)
                }
            }

            Text {
                text: "Кредит одобрен!"
                font { pixelSize: 22; bold: true; family: manropeFont.name }
                color: "#F7F7FB"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: resultMessage
                font.pixelSize: 14
                color: "#9CA3AF"
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // Мини-блок банковской карты
            Rectangle {
                width: parent.width
                height: 64
                radius: 12
                visible: approvedAccount.card_number !== undefined
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Лого бренда
                    Rectangle {
                        width: 40; height: 40; radius: 10
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: (approvedAccount.card_brand ?? "") === "visa"
                                        ? Theme.grVisaPosStart
                                        : (approvedAccount.card_brand ?? "") === "mastercard"
                                            ? Theme.grMSPosStart
                                            : Theme.grMirPosStart
                            }
                            GradientStop {
                                position: 1.0
                                color: (approvedAccount.card_brand ?? "") === "visa"
                                        ? Theme.grVisaPosEnd
                                        : (approvedAccount.card_brand ?? "") === "mastercard"
                                            ? Theme.grMSPosEnd
                                            : Theme.grMirPosEnd
                            }
                        }
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 28; height: 20
                            sourceSize: Qt.size(28, 20)
                            fillMode: Image.PreserveAspectFit
                            source: (approvedAccount.card_brand ?? "") === "visa"
                                    ? "assets/visa.svg"
                                    : (approvedAccount.card_brand ?? "") === "mastercard"
                                        ? "assets/mastercard.svg"
                                        : "assets/mir.svg"
                        }
                    }

                    // Номер и баланс
                    Column {
                        width: parent.width - 64
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "•••• " + (approvedAccount.card_number ?? "").slice(-4)
                            font { pixelSize: 14; bold: true; family: manropeFont.name }
                            color: "#F7F7FB"
                        }

                        Text {
                            text: Number(approvedAccount.balance ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            font { pixelSize: 13; bold: true }
                            color: Theme.accent
                        }
                    }
                }
            }

            // Детали кредита
            Rectangle {
                width: parent.width
                height: detailsCol.height + 24
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Column {
                    id: detailsCol
                    width: parent.width - 24
                    anchors.centerIn: parent
                    spacing: 12

                    Row {
                        width: parent.width
                        Text { text: "Сумма"; font.pixelSize: 13; color: "#6B7280"; width: parent.width * 0.4 }
                        Text {
                            text: Number(loanAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                            font { pixelSize: 13; bold: true }
                            color: "#E5E7EB"
                        }
                    }
                    Row {
                        width: parent.width
                        Text { text: "Срок"; font.pixelSize: 13; color: "#6B7280"; width: parent.width * 0.4 }
                        Text {
                            text: {
                                var m = loanMonths
                                var y = Math.floor(m / 12)
                                var mo = m % 12
                                var s = ""
                                if (y > 0) s += y + " " + (y === 1 ? "год" : y < 5 ? "года" : "лет")
                                if (mo > 0) { if (s.length > 0) s += " "; s += mo + " мес" }
                                return s || m + " мес"
                            }
                            font { pixelSize: 13; bold: true }
                            color: "#E5E7EB"
                        }
                    }
                    Row {
                        width: parent.width
                        Text { text: "Ставка"; font.pixelSize: 13; color: "#6B7280"; width: parent.width * 0.4 }
                        Text {
                            text: Number(product.annual_rate ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 1) + "%"
                            font { pixelSize: 13; bold: true }
                            color: "#E5E7EB"
                        }
                    }
                    Row {
                        width: parent.width
                        Text { text: "Ежемесячно"; font.pixelSize: 13; color: "#6B7280"; width: parent.width * 0.4 }
                        Text {
                            text: Number(monthlyPayment).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                            font { pixelSize: 13; bold: true }
                            color: Theme.accent
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }

            // Кнопка «К каталогу»
            Rectangle {
                width: parent.width
                height: 54
                radius: 16
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "К каталогу кредитов"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#050B1A"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        showSuccess = false
                        root.backToCatalog()
                    }
                }
            }

            // Кнопка «Мои кредиты»
            Rectangle {
                width: parent.width
                height: 54
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Text {
                    anchors.centerIn: parent
                    text: "Мои кредиты"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#E5E7EB"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        showSuccess = false
                        root.goToMyLoans()
                    }
                }
            }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "loanCalc"
        steps: [
            { target: amountBlock, flickable: pageFlick, title: "Сумма кредита",
              text: "Введите желаемую сумму в пределах лимитов продукта — они указаны под полем." },
            { target: termBlock, flickable: pageFlick, title: "Срок",
              text: "Укажите срок в месяцах. Чем дольше срок — тем меньше ежемесячный платёж, но больше переплата." },
            { target: resultBlock, flickable: pageFlick, title: "Расчёт",
              text: "Калькулятор сразу показывает аннуитетный ежемесячный платёж и итоговую переплату — меняйте сумму и срок, чтобы подобрать комфортные условия." },
            { target: accountPick, flickable: pageFlick, title: "Куда зачислить",
              text: "Выберите дебетовую карту — на неё поступят деньги сразу после одобрения." },
            { target: applyBtn, flickable: pageFlick, title: "Оформление",
              text: "Нажмите, когда всё готово. Кредит оформляется мгновенно, график платежей появится в разделе «Мои кредиты»." }
        ]
    }
}
