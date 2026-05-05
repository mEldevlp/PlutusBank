import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: root

    signal backToCatalog()
    signal goToMyDeposits()

    // Состояние
    property int    selectedTerm: 6                 // месяцев
    property double depositAmount: 100000
    property bool   replenishable: false
    property int    selectedAccountId: -1
    property bool   isProcessing: false
    property string errorText: ""
    property bool   showSuccess: false

    // Расчёт
    property double calcRate: 0
    property double calcFinal: 0
    property double calcIncome: 0
    property double calcEffective: 0

    // Лимиты
    readonly property double minAmount: 1000
    readonly property double maxAmount: 10000000

    function recalc() {
        var r = depositController.calculateDeposit(depositAmount, selectedTerm)
        calcRate      = r.rate
        calcFinal     = r.finalAmount
        calcIncome    = r.income
        calcEffective = r.effectiveYield
    }

    Component.onCompleted: {
        depositController.loadAccounts()
        recalc()
    }

    onSelectedTermChanged: recalc()
    onDepositAmountChanged: recalc()

    Connections {
        target: depositController
        function onOperationFailed(error) {
            errorText = error
            isProcessing = false
        }
        function onDepositOpened() {
            isProcessing = false
            errorText = ""
            showSuccess = true
        }
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
                    MouseArea { anchors.fill: parent; onClicked: root.backToCatalog() }
                }
            }

            // Большой заголовок «Вклад»
            Text {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Вклад"
                font { pixelSize: 34; bold: true; family: manropeFont.name }
                color: "#FFFFFF"
            }

            // ===== Подберите условия =====
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 24
                color: "#1F2937"
                border.color: Theme.card
                height: condCol.height + 32

                Column {
                    id: condCol
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Text {
                        text: "Подберите условия"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }

                    // Период (горизонтальный список)
                    ListView {
                        width: parent.width
                        height: 44
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        model: [
                            { label: "1 мес",  value: 1 },
                            { label: "2 мес",  value: 2 },
                            { label: "3 мес",  value: 3 },
                            { label: "6 мес",  value: 6 },
                            { label: "9 мес",  value: 9 },
                            { label: "12 мес", value: 12 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 78; height: 44; radius: 22
                            color: modelData.value === root.selectedTerm
                                   ? Theme.success
                                   : "#374151"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font { pixelSize: 14; bold: true }
                                color: modelData.value === root.selectedTerm
                                       ? "#0A1229"
                                       : "#E5E7EB"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.selectedTerm = modelData.value
                            }
                        }
                    }

                    // Ряд: Валюта (заглушка) + Ставка
                    Row {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 86; radius: 18
                            color: "#374151"

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "Рубли"
                                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Валюта"
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 86; radius: 18
                            color: "#374151"

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: root.calcRate.toFixed(2).replace(".", ",") + "%"
                                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Ставка"
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    // Пополняемый вклад — переключатель
                    Rectangle {
                        width: parent.width
                        height: 56; radius: 28
                        color: "#374151"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "Пополняемый вклад"
                                font.pixelSize: 14
                                color: "#E5E7EB"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item { width: parent.width - 200; height: 1 }

                            Switch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.replenishable
                                onToggled: root.replenishable = checked
                            }
                        }
                    }
                }
            }

            // ===== Калькулятор =====
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 24
                color: "#1F2937"
                border.color: Theme.card
                height: calcCol.height + 32

                Column {
                    id: calcCol
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Text {
                        text: "Вклад калькулятор"
                        font { pixelSize: 22; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }

                    Text {
                        text: "Укажите сумму, а мы рассчитаем доход"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    // Поле суммы
                    Rectangle {
                        width: parent.width
                        height: 64; radius: 16
                        color: "#374151"

                        TextField {
                            id: amountField
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            background: null
                            color: "#FFFFFF"
                            font { pixelSize: 22; bold: true; family: manropeFont.name }
                            placeholderText: "Сумма"
                            placeholderTextColor: "#6B7280"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            text: root.depositAmount > 0
                                  ? Number(root.depositAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                  : ""

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    text = root.depositAmount > 0
                                            ? String(root.depositAmount)
                                            : ""
                                } else {
                                    text = root.depositAmount > 0
                                            ? Number(root.depositAmount)
                                                  .toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                            : ""
                                }
                            }

                            onTextEdited: {
                                var clean = text.replace(/[^\d]/g, "")
                                root.depositAmount = clean === "" ? 0 : parseFloat(clean)
                            }
                        }
                    }

                    // Доходность
                    Row {
                        width: parent.width
                        Text {
                            text: "Доходность"
                            font.pixelSize: 14
                            color: "#E5E7EB"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 240; height: 1 }
                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                border.color: Theme.success
                                border.width: 3
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: Theme.success
                                    anchors.centerIn: parent
                                }
                            }
                            Text {
                                text: root.calcEffective.toFixed(2).replace(".", ",") + "%"
                                font { pixelSize: 16; bold: true; family: manropeFont.name }
                                color: "#FFFFFF"
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#374151" }

                    // В конце срока
                    Row {
                        width: parent.width
                        Text {
                            text: "В конце срока"
                            font.pixelSize: 14
                            color: "#9CA3AF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 280; height: 1 }
                        Text {
                            text: Number(root.calcFinal).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                            font { pixelSize: 16; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Заработаете
                    Row {
                        width: parent.width
                        Text {
                            text: "Вы заработаете"
                            font.pixelSize: 14
                            color: "#9CA3AF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 280; height: 1 }
                        Text {
                            text: "+" + Number(root.calcIncome).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                            font { pixelSize: 16; bold: true; family: manropeFont.name }
                            color: Theme.success
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ===== Выбор счёта списания =====
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 16
                color: "#111827"
                border.color: Theme.card
                height: accCol.height + 24
                visible: depositController.accounts.length > 0

                Column {
                    id: accCol
                    width: parent.width - 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

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
                            color: modelData.id === root.selectedAccountId
                                   ? "#1F2937"
                                   : "#0F172A"
                            border.color: modelData.id === root.selectedAccountId
                                          ? Theme.success
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
                        visible: depositController.accounts.length === 0
                        text: "Нет доступных карт. Сначала выпустите дебетовую карту."
                        font.pixelSize: 13
                        color: Theme.error
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            // Ошибка
            Text {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                visible: errorText.length > 0
                text: errorText
                color: Theme.error
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            // Кнопка «Открыть вклад»
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 56; radius: 28
                color: canOpen ? Theme.success : "#374151"

                readonly property bool canOpen:
                    depositAmount >= minAmount &&
                    depositAmount <= maxAmount &&
                    selectedTerm >= 1 && selectedTerm <= 12 &&
                    selectedAccountId > 0 &&
                    !isProcessing

                Text {
                    anchors.centerIn: parent
                    text: isProcessing ? "Обработка..." : "Открыть вклад"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: parent.canOpen ? "#0A1229" : "#9CA3AF"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.canOpen
                    onClicked: {
                        errorText = ""
                        isProcessing = true
                        depositController.openDeposit(
                            selectedAccountId,
                            depositAmount,
                            selectedTerm,
                            replenishable
                        )
                    }
                }
            }
        }
    }

    // ===== Оверлей успеха =====
    Rectangle {
        id: successOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        visible: false

        states: State {
            name: "shown"; when: showSuccess
            PropertyChanges { target: successOverlay; opacity: 0.96; visible: true }
        }
        transitions: Transition { NumberAnimation { property: "opacity"; duration: 250 } }

        Column {
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 24

            Rectangle {
                width: 80; height: 80; radius: 40
                color: Theme.success
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font { pixelSize: 44; bold: true }
                    color: "#0A1229"
                }
            }

            Text {
                text: "Вклад открыт!"
                font { pixelSize: 22; bold: true; family: manropeFont.name }
                color: "#FFFFFF"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Сумма: " + Number(depositAmount).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽\n"
                      + "Срок: " + selectedTerm + " мес\n"
                      + "Ставка: " + calcRate.toFixed(2).replace(".", ",") + "%"
                color: "#9CA3AF"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width
                height: 56; radius: 28
                color: Theme.success
                Text {
                    anchors.centerIn: parent
                    text: "К моим вкладам"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#0A1229"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { showSuccess = false; root.goToMyDeposits() }
                }
            }

            Text {
                text: "Готово"
                color: "#9CA3AF"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: { showSuccess = false; root.backToCatalog() }
                }
            }
        }
    }
}
