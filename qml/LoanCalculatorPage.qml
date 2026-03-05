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

    readonly property color accentColor: {
        var cat = product.category ?? ""
        if (cat === "mortgage")    return "#3B82F6"
        if (cat === "auto")        return "#F59E0B"
        if (cat === "electronics") return "#8B5CF6"
        return "#27D6C5"
    }

    Flickable {
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
                    width: 40; height: 40; radius: 20
                    color: backArea.pressed ? "#374151" : "#1F2937"
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        font { pixelSize: 22; bold: true }
                        color: "#E5E7EB"
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
            }

            // ═══════ Сумма ═══════
            Column {
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
                    border.color: amountInput.activeFocus ? accentColor : "#374151"
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
                            color: accentColor
                        }
                    }

                    handle: Rectangle {
                        x: amountSlider.leftPadding + amountSlider.visualPosition * (amountSlider.availableWidth - width)
                        y: amountSlider.topPadding + amountSlider.availableHeight / 2 - height / 2
                        width: 24; height: 24; radius: 12
                        color: amountSlider.pressed ? Qt.lighter(accentColor, 1.2) : accentColor
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
                    border.color: termInput.activeFocus ? accentColor : "#374151"
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
                            color: accentColor
                        }
                    }

                    handle: Rectangle {
                        x: termSlider.leftPadding + termSlider.visualPosition * (termSlider.availableWidth - width)
                        y: termSlider.topPadding + termSlider.availableHeight / 2 - height / 2
                        width: 24; height: 24; radius: 12
                        color: termSlider.pressed ? Qt.lighter(accentColor, 1.2) : accentColor
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

            // ═══════ Результат расчёта ═══════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: resultCol.height + 28
                radius: 16
                color: "#1F2937"

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
                            color: accentColor
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
                                color: "#E5E7EB"
                            }
                        }

                        Column {
                            width: parent.width / 3
                            spacing: 2
                            Text { text: "Переплата"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(overpayment).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                font { pixelSize: 14; bold: true }
                                color: "#EF4444"
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

            // ═══════ Выбор счёта ═══════
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "Зачислить на счёт"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Repeater {
                    model: loanController.accounts

                    delegate: Rectangle {
                        width: parent.width
                        height: 56
                        radius: 12
                        color: selectedAccountId === modelData.id ? "#27D6C520" : "#111827"
                        border.color: selectedAccountId === modelData.id ? accentColor : "#374151"
                        border.width: selectedAccountId === modelData.id ? 2 : 1

                        required property var modelData

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.color: selectedAccountId === modelData.id ? accentColor : "#4B5563"
                                border.width: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: accentColor
                                    visible: selectedAccountId === modelData.id
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: {
                                        var num = modelData.card_number ?? ""
                                        return num.length > 4 ? "•••• " + num.slice(-4) : "Счёт"
                                    }
                                    font { pixelSize: 14; bold: true }
                                    color: "#E5E7EB"
                                }
                                Text {
                                    text: Number(modelData.balance ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    font.pixelSize: 12; color: "#9CA3AF"
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: selectedAccountId = modelData.id
                        }
                    }
                }
            }

            // ═══════ Ошибка (инлайн) ═══════
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

            // ═══════ Кнопка «Оформить» ═══════
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 52
                radius: 16
                color: (selectedAccountId > 0 && !isProcessing) ? accentColor : "#374151"
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

    // ═══════ Оверлей «Кредит одобрен» ═══════
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

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font { pixelSize: 36; bold: true }
                    color: "#FFFFFF"
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

            // Детали кредита
            Rectangle {
                width: parent.width
                height: detailsCol.height + 24
                radius: 16
                color: "#1F2937"

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
                            text: Number(monthlyPayment).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            font { pixelSize: 13; bold: true }
                            color: accentColor
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
                color: accentColor

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
                color: "transparent"
                border.color: "#374151"
                border.width: 2

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
}
