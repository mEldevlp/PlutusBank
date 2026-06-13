import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: root

    property var depositData: ({})
    signal backToList()

    property string mode: "view"      // view | topup | claim
    property double inputAmount: 0
    property int    selectedAccountId: -1
    property string errorText: ""
    property bool   isProcessing: false

    // Свежие данные из контроллера (модель может обновиться)
    readonly property var liveData: {
        for (var i = 0; i < depositController.deposits.length; i++) {
            if (depositController.deposits[i].id === depositData.id)
                return depositController.deposits[i]
        }
        return depositData
    }

    Component.onCompleted: {
        depositController.loadAccounts()
        depositController.loadDeposits()
    }

    Connections {
        target: depositController
        function onOperationFailed(error) {
            errorText = error
            isProcessing = false
        }
        function onOperationSuccess(message) {
            isProcessing = false
            errorText = ""
            mode = "view"
        }
        function onDepositClaimed() { root.backToList() }
        function onAccountsChanged() {
            if (depositController.accounts.length > 0 && selectedAccountId === -1)
                selectedAccountId = depositController.accounts[0].id
        }
    }

    onModeChanged: {
        inputAmount = 0
        errorText = ""
    }

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

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
        contentHeight: mainCol.height + 60
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 18

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
                        anchors.fill: parent
                        onClicked: {
                            if (mode === "view") root.backToList()
                            else                 mode = "view"
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Вклад"
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

            // Карточка вклада
            Rectangle {
                id: depositCard
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 22
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#374151" }
                    GradientStop { position: 1.0; color: "#111827" }
                }
                border.color: Theme.card
                height: cardCol.height + 32
                visible: mode === "view"

                Column {
                    id: cardCol
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Row {
                        spacing: 8
                        Text {
                            text: "Вклад на " + (liveData.term_months ?? 0) + " мес"
                            font { pixelSize: 14; bold: true }
                            color: "#9CA3AF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            visible: liveData.is_replenishable
                            width: replLbl.width + 12; height: 20; radius: 10
                            color: Theme.info
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                id: replLbl; anchors.centerIn: parent
                                text: "Пополняемый"
                                font { pixelSize: 10; bold: true }
                                color: "#FFFFFF"
                            }
                        }
                        Rectangle {
                            visible: liveData.can_claim
                            width: claimLbl.width + 12; height: 20; radius: 10
                            color: Theme.success
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                id: claimLbl; anchors.centerIn: parent
                                text: "Срок истёк"
                                font { pixelSize: 10; bold: true }
                                color: "#0A1229"
                            }
                        }
                    }

                    Text {
                        text: "Текущий баланс"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Text {
                        text: Number(liveData.current_balance ?? 0)
                                .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font { pixelSize: 32; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }

                    Text {
                        text: "+" + Number(liveData.total_interest ?? 0)
                                .toLocaleString(Qt.locale("ru_RU"), 'f', 2)
                              + " ₽ · " + Number(liveData.annual_rate ?? 0)
                                .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + "%"
                        font { pixelSize: 13; bold: true }
                        color: Theme.success
                    }

                    Rectangle { width: parent.width; height: 1; color: "#374151"; opacity: 0.5 }

                    Grid {
                        columns: 2
                        columnSpacing: 24
                        rowSpacing: 10
                        width: parent.width

                        Column {
                            spacing: 2
                            Text { text: "Открыт"; font.pixelSize: 11; color: "#9CA3AF" }
                            Text {
                                text: liveData.opened_at ?? "—"
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                            }
                        }
                        Column {
                            spacing: 2
                            Text { text: "Дата окончания"; font.pixelSize: 11; color: "#9CA3AF" }
                            Text {
                                text: liveData.matures_at ?? "—"
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                            }
                        }
                        Column {
                            spacing: 2
                            Text { text: "Начальная сумма"; font.pixelSize: 11; color: "#9CA3AF" }
                            Text {
                                text: Number(liveData.principal ?? 0)
                                        .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                            }
                        }
                        Column {
                            spacing: 2
                            Text { text: "Пополнено"; font.pixelSize: 11; color: "#9CA3AF" }
                            Text {
                                text: Number(liveData.total_topups ?? 0)
                                        .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                            }
                        }
                        Column {
                            spacing: 2
                            visible: !liveData.can_claim
                            Text { text: "Осталось"; font.pixelSize: 11; color: "#9CA3AF" }
                            Text {
                                text: (liveData.days_remaining ?? 0) + " дн."
                                font { pixelSize: 13; bold: true }
                                color: Theme.warning
                            }
                        }
                    }
                }
            }

            // Кнопки действий (view-mode)
            Column {
                id: actionsBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                visible: mode === "view"

                // ЗАБРАТЬ — крупная, активна только если can_claim
                Rectangle {
                    width: parent.width
                    height: 56; radius: 28
                    color: liveData.can_claim ? Theme.success : "#374151"

                    Text {
                        anchors.centerIn: parent
                        text: liveData.can_claim
                              ? "Забрать " + Number(liveData.current_balance ?? 0)
                                    .toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                              : "Забрать (по окончании срока)"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: liveData.can_claim ? "#0A1229" : "#9CA3AF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: liveData.can_claim ?? false
                        onClicked: mode = "claim"
                    }
                }

                // Пополнить (если разрешено и срок не истёк)
                Rectangle {
                    width: parent.width
                    height: 52; radius: 26
                    color: "#374151"
                    border.color: Theme.cardBorder
                    visible: (liveData.is_replenishable ?? false) && !(liveData.can_claim ?? false)

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "+"
                            font { pixelSize: 22; bold: true }
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Пополнить"
                            font { pixelSize: 14; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: mode = "topup" }
                }

                // Подсказка для НЕпополняемого
                Text {
                    visible: !(liveData.is_replenishable ?? false) && !(liveData.can_claim ?? false)
                    text: "💡 Этот вклад нельзя пополнять. Деньги вернутся на карту в день окончания срока."
                    color: "#9CA3AF"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            // ============ Topup mode ============
            Column {
                id: topupBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                visible: mode === "topup"

                Text {
                    text: "Сумма пополнения"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Rectangle {
                    width: parent.width
                    height: 64; radius: 16
                    color: "#1F2937"
                    border.color: Theme.card

                    TextField {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        background: null
                        color: "#FFFFFF"
                        font { pixelSize: 22; bold: true; family: manropeFont.name }
                        placeholderText: "0 ₽"
                        placeholderTextColor: "#6B7280"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        text: root.inputAmount > 0
                              ? Number(root.inputAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                              : ""

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                text = root.inputAmount > 0 ? String(root.inputAmount) : ""
                            } else {
                                text = root.inputAmount > 0
                                        ? Number(root.inputAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        : ""
                            }
                        }
                        onTextEdited: {
                            var clean = text.replace(/[^\d]/g, "")
                            root.inputAmount = clean === "" ? 0 : parseFloat(clean)
                        }
                    }
                }

                Text {
                    text: "Списать с карты"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Repeater {
                    model: depositController.accounts
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 56; radius: 12
                        color: modelData.id === root.selectedAccountId ? "#1F2937" : "#0F172A"
                        border.color: modelData.id === root.selectedAccountId ? Theme.success : "transparent"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            Text {
                                text: "**** " + (modelData.card_number ? modelData.card_number.slice(-4) : "----")
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Item { width: parent.width - 220; height: 1 }
                            Text {
                                text: Number(modelData.balance ?? 0)
                                        .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                font { pixelSize: 13; bold: true }
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.selectedAccountId = modelData.id }
                    }
                }

                Text {
                    visible: errorText.length > 0
                    text: errorText
                    color: Theme.error
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Rectangle {
                    width: parent.width
                    height: 56; radius: 28
                    color: enabled_ ? Theme.success : "#374151"
                    readonly property bool enabled_: inputAmount > 0 && selectedAccountId > 0 && !isProcessing

                    Text {
                        anchors.centerIn: parent
                        text: isProcessing ? "Обработка..." : "Пополнить"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: parent.enabled_ ? "#0A1229" : "#9CA3AF"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.enabled_
                        onClicked: {
                            errorText = ""
                            isProcessing = true
                            depositController.topUpDeposit(liveData.id, selectedAccountId, inputAmount)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 48; radius: 24
                    color: "transparent"
                    border.color: Theme.cardBorder
                    Text { anchors.centerIn: parent; text: "Отмена"; font.pixelSize: 14; color: "#9CA3AF" }
                    MouseArea { anchors.fill: parent; onClicked: mode = "view" }
                }
            }

            // ============ Claim mode ============
            Column {
                id: claimBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                visible: mode === "claim"

                Text {
                    text: "Куда зачислить"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                Repeater {
                    model: depositController.accounts
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 56; radius: 12
                        color: modelData.id === root.selectedAccountId ? "#1F2937" : "#0F172A"
                        border.color: modelData.id === root.selectedAccountId ? Theme.success : "transparent"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            Text {
                                text: "**** " + (modelData.card_number ? modelData.card_number.slice(-4) : "----")
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Item { width: parent.width - 220; height: 1 }
                            Text {
                                text: Number(modelData.balance ?? 0)
                                        .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                font { pixelSize: 13; bold: true }
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.selectedAccountId = modelData.id }
                    }
                }

                Rectangle {
                    width: parent.width
                    radius: 14
                    color: "#111827"
                    border.color: Theme.card
                    height: receiveCol.height + 24

                    Column {
                        id: receiveCol
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text { text: "Вы получите"; font.pixelSize: 12; color: "#9CA3AF" }
                        Text {
                            text: Number(liveData.current_balance ?? 0)
                                    .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            font { pixelSize: 24; bold: true; family: manropeFont.name }
                            color: Theme.success
                        }
                    }
                }

                Text {
                    visible: errorText.length > 0
                    text: errorText
                    color: Theme.error
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Rectangle {
                    width: parent.width
                    height: 56; radius: 28
                    color: enabled_ ? Theme.success : "#374151"
                    readonly property bool enabled_: selectedAccountId > 0 && !isProcessing

                    Text {
                        anchors.centerIn: parent
                        text: isProcessing ? "Обработка..." : "Забрать вклад"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: parent.enabled_ ? "#0A1229" : "#9CA3AF"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.enabled_
                        onClicked: {
                            errorText = ""
                            isProcessing = true
                            depositController.claimDeposit(liveData.id, selectedAccountId)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 48; radius: 24
                    color: "transparent"
                    border.color: Theme.cardBorder
                    Text { anchors.centerIn: parent; text: "Отмена"; font.pixelSize: 14; color: "#9CA3AF" }
                    MouseArea { anchors.fill: parent; onClicked: mode = "view" }
                }
            }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "depositDetail"
        steps: mode === "topup" ? [
            { target: topupBlock, flickable: pageFlick, title: "Пополнение вклада",
              text: "Укажите сумму и карту списания — деньги добавятся к телу вклада и тоже начнут приносить проценты." }
        ] : mode === "claim" ? [
            { target: claimBlock, flickable: pageFlick, title: "Забрать вклад",
              text: "Выберите карту — на неё поступит вся сумма вклада вместе с начисленными процентами." }
        ] : [
            { target: depositCard, flickable: pageFlick, title: "Ваш вклад",
              text: "Текущий баланс, начисленные проценты, срок и ставка. Когда срок истечёт, появится отметка «Срок истёк»." },
            { target: actionsBlock, flickable: pageFlick, title: "Действия",
              text: "«Забрать» станет активной по окончании срока. «Пополнить» доступно, если вклад пополняемый и срок ещё идёт." }
        ]
    }
}
