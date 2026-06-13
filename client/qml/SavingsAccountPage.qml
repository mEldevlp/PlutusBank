import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: root

    signal backToMain()

    property string mode: "view"          // view | topup | withdraw | open
    property double inputAmount: 0
    property int    selectedAccountId: -1
    property string errorText: ""
    property bool   isProcessing: false

    Component.onCompleted: {
        depositController.loadAccounts()
        depositController.loadSavings()
    }

    onModeChanged: {
        inputAmount = 0
        errorText = ""
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
        function onSavingsOpened() { mode = "view" }
        function onAccountsChanged() {
            if (depositController.accounts.length > 0 && selectedAccountId === -1)
                selectedAccountId = depositController.accounts[0].id
        }
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

    // Жёлтый сияющий градиент сверху
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 280; height: 280
        radius: 140
        opacity: 0.25
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#F59E0B" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Flickable {
        id: flick
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
                            if (mode === "view")  root.backToMain()
                            else                  mode = "view"
                        }
                    }
                }
                GuideButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: guide.open()
                }
            }

            // Заголовок
            Text {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Накопительный счёт"
                font { pixelSize: 28; bold: true; family: manropeFont.name }
                color: "#FFFFFF"
                wrapMode: Text.WordWrap
            }

            // ============ View mode ============
            // Если счёт ещё не открыт
            Column {
                id: promoBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                visible: mode === "view" && !depositController.hasSavings

                Rectangle {
                    width: parent.width
                    height: 200; radius: 20
                    color: "#1F2937"
                    border.color: Theme.card

                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        width: parent.width - 32

                        Text {
                            text: "🪙"
                            font.pixelSize: 56
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "10% годовых"
                            font { pixelSize: 22; bold: true; family: manropeFont.name }
                            color: Theme.warning
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Снимайте деньги в любой момент\nбез потери процентов"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 56; radius: 28
                    color: Theme.warning

                    Text {
                        anchors.centerIn: parent
                        text: "Открыть счёт"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: "#0A1229"
                    }
                    MouseArea { anchors.fill: parent; onClicked: mode = "open" }
                }
            }

            // Если счёт открыт
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                visible: mode === "view" && depositController.hasSavings

                // Карточка баланса
                Rectangle {
                    id: balanceCard
                    width: parent.width
                    height: 170; radius: 20
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#374151" }
                        GradientStop { position: 1.0; color: "#111827" }
                    }
                    border.color: Theme.card

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        spacing: 8

                        Text {
                            text: "Баланс"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                        }

                        Text {
                            text: Number(depositController.savings.balance ?? 0)
                                    .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                            font { pixelSize: 32; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                        }

                        Row {
                            spacing: 16
                            width: parent.width

                            Column {
                                spacing: 2
                                Text {
                                    text: "Ставка"
                                    font.pixelSize: 11
                                    color: "#9CA3AF"
                                }
                                Text {
                                    text: Number(depositController.savings.annual_rate ?? 10)
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + "% годовых"
                                    font { pixelSize: 13; bold: true }
                                    color: Theme.warning
                                }
                            }

                            Column {
                                spacing: 2
                                Text {
                                    text: "Заработано"
                                    font.pixelSize: 11
                                    color: "#9CA3AF"
                                }
                                Text {
                                    text: "+" + Number(depositController.savings.total_interest ?? 0)
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    font { pixelSize: 13; bold: true }
                                    color: Theme.success
                                }
                            }
                        }
                    }
                }

                // Кнопки действий
                Row {
                    id: actionsRow
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 52; radius: 26
                        color: Theme.success

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "+"
                                font { pixelSize: 22; bold: true }
                                color: "#0A1229"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Пополнить"
                                font { pixelSize: 14; bold: true; family: manropeFont.name }
                                color: "#0A1229"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: mode = "topup" }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 52; radius: 26
                        color: "#374151"
                        border.color: Theme.cardBorder

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "↓"
                                font { pixelSize: 22; bold: true }
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Снять"
                                font { pixelSize: 14; bold: true; family: manropeFont.name }
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: mode = "withdraw" }
                    }
                }

                // Информация
                Rectangle {
                    id: infoBlock
                    width: parent.width
                    radius: 14
                    color: "#111827"
                    border.color: Theme.card
                    height: infoCol.height + 24

                    Column {
                        id: infoCol
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: "Как работают проценты"
                            font { pixelSize: 14; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                        }

                        Text {
                            text: "• Начисление ежедневное\n• Снимать можно в любой момент без потери процентов\n• Пополняйте на любую сумму"
                            font.pixelSize: 12
                            color: "#9CA3AF"
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }

            // ============ Open / Topup / Withdraw mode (общая форма) ============
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                visible: mode !== "view"

                Text {
                    text: mode === "open"     ? "Сумма открытия" :
                          mode === "topup"    ? "Сумма пополнения" :
                                                "Сумма снятия"
                    font { pixelSize: 14; bold: true }
                    color: "#9CA3AF"
                }

                // Поле суммы
                Rectangle {
                    id: amountBlock
                    width: parent.width
                    height: 64; radius: 16
                    color: "#1F2937"
                    border.color: Theme.card

                    TextField {
                        id: amountField
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
                                        ? Number(root.inputAmount)
                                              .toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                        : ""
                            }
                        }

                        onTextEdited: {
                            var clean = text.replace(/[^\d]/g, "")
                            root.inputAmount = clean === "" ? 0 : parseFloat(clean)
                        }
                    }
                }

                // Подсказка для снятия
                Text {
                    visible: mode === "withdraw"
                    text: "Доступно: " + Number(depositController.savings.balance ?? 0)
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                    font.pixelSize: 12
                    color: "#9CA3AF"
                }

                // Выбор счёта
                Text {
                    id: accountPick
                    text: mode === "withdraw" ? "Зачислить на карту" : "Списать с карты"
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
                        border.color: modelData.id === root.selectedAccountId
                                      ? Theme.warning
                                      : "transparent"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

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
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selectedAccountId = modelData.id
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

                // Подтвердить
                Rectangle {
                    id: confirmBtn
                    width: parent.width
                    height: 56; radius: 28
                    color: enabled_ ? Theme.warning : "#374151"

                    readonly property bool enabled_:
                        inputAmount > 0 &&
                        selectedAccountId > 0 &&
                        !isProcessing &&
                        (mode !== "withdraw" || inputAmount <= (depositController.savings.balance ?? 0))

                    Text {
                        anchors.centerIn: parent
                        text: isProcessing ? "Обработка..."
                              : mode === "open"     ? "Открыть"
                              : mode === "topup"    ? "Пополнить"
                                                    : "Снять"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: parent.enabled_ ? "#0A1229" : "#9CA3AF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.enabled_
                        onClicked: {
                            errorText = ""
                            isProcessing = true
                            if (mode === "open")
                                depositController.openSavings(selectedAccountId, inputAmount)
                            else if (mode === "topup")
                                depositController.topUpSavings(selectedAccountId, inputAmount)
                            else
                                depositController.withdrawSavings(selectedAccountId, inputAmount)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 48; radius: 24
                    color: "transparent"
                    border.color: Theme.cardBorder
                    Text {
                        anchors.centerIn: parent
                        text: "Отмена"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                    }
                    MouseArea { anchors.fill: parent; onClicked: mode = "view" }
                }
            }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "savings"
        steps: mode !== "view" ? [
            { target: amountBlock, flickable: flick, title: "Сумма",
              text: "Введите сумму операции. Для снятия доступный остаток показан под полем." },
            { target: accountPick, flickable: flick, title: "Счёт",
              text: "Выберите карту: с неё спишутся деньги при пополнении или на неё вернутся при снятии." },
            { target: confirmBtn, flickable: flick, title: "Подтверждение",
              text: "Проверьте данные и подтвердите операцию — она выполняется мгновенно." }
        ] : depositController.hasSavings ? [
            { target: balanceCard, flickable: flick, title: "Ваш накопительный счёт",
              text: "Текущий баланс, ставка и сумма уже заработанных процентов. Проценты начисляются ежедневно." },
            { target: actionsRow, flickable: flick, title: "Пополнение и снятие",
              text: "Пополняйте счёт на любую сумму и снимайте деньги в любой момент — проценты при этом не сгорают." },
            { target: infoBlock, flickable: flick, title: "Как это работает",
              text: "Краткая памятка об условиях накопительного счёта." }
        ] : [
            { target: promoBlock, flickable: flick, title: "Накопительный счёт",
              text: "10% годовых с ежедневным начислением. Снимайте деньги в любой момент без потери процентов. Нажмите «Открыть счёт», чтобы начать копить." }
        ]
    }
}
