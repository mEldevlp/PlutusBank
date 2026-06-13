import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: transferPage

    signal backToMain()

    // 0 = выбор режима, 1 = между счетами, 2 = другому человеку, 3 = успех
    property int currentStep: 0
    property int _prevStep: 0
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

    function cardBrandIcon(brand) {
        if (brand === "visa") return "assets/visa.svg"
        if (brand === "mastercard") return "assets/mastercard.svg"
        if (brand === "mir") return "assets/mir.svg"
        return ""
    }

    function goToStep(step) {
        _prevStep = currentStep
        currentStep = step
    }

    Component.onCompleted: {
        transferController.loadAccounts()
        step0.visible = true
        step0.opacity = 1.0
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

    // Шапка
    Column {
        id: headerColumn
        width: parent.width
        z: 10

        Item { width: 1; height: 20 }

        Row {
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Rectangle {
                width: 44
                height: 44
                visible: currentStep <= 2
                color: "transparent" 

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
                            goToStep(0)
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
                    id: headerTitle
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

        // Блок ошибки
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

        Item { width: 1; height: 12 }
    }

    // Контейнер шагов с анимациями
    Item {
        id: stepsContainer
        anchors.top: headerColumn.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true


        // ШАГ 0: Выбор типа перевода
        Flickable {
            id: step0
            anchors.fill: parent
            contentHeight: step0Content.height + 40
            clip: true
            visible: false
            opacity: 0

            property bool isActive: currentStep === 0
            property real _dir: currentStep > _prevStep ? 1.0 : -1.0

            transform: Translate { id: step0Translate }

            states: [
                State {
                    name: "active"; when: step0.isActive
                    PropertyChanges { target: step0; opacity: 1.0; visible: true }
                    PropertyChanges { target: step0Translate; x: 0 }
                },
                State {
                    name: "inactive"; when: !step0.isActive
                    PropertyChanges { target: step0; opacity: 0.0 }
                    PropertyChanges { target: step0Translate; x: -step0._dir * stepsContainer.width * 0.3 }
                }
            ]

            transitions: [
                Transition {
                    to: "active"
                    SequentialAnimation {
                        PropertyAction { target: step0; property: "visible"; value: true }
                        ParallelAnimation {
                            NumberAnimation { target: step0; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                            NumberAnimation { target: step0Translate; property: "x"; from: step0._dir * stepsContainer.width * 0.3; to: 0; duration: 280; easing.type: Easing.OutCubic }
                        }
                    }
                },
                Transition {
                    to: "inactive"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: step0; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                            NumberAnimation { target: step0Translate; property: "x"; duration: 200; easing.type: Easing.InCubic }
                        }
                        PropertyAction { target: step0; property: "visible"; value: false }
                    }
                }
            ]

            Column {
                id: step0Content
                width: parent.width
                spacing: 16

                Column {
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // Между своими счетами
                    Rectangle {
                        id: optInternal
                        width: parent.width
                        height: 100
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

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
                                goToStep(1)
                            }
                        }
                    }

                    // Другому человеку
                    Rectangle {
                        id: optExternal
                        width: parent.width
                        height: 100
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16

                            Rectangle {
                                width: 56; height: 56; radius: 16
                                color: Theme.accent
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
                                goToStep(2)
                            }
                        }
                    }
                }
            }
        }

        // ШАГ 1: Между своими счетами
        Flickable {
            id: step1
            anchors.fill: parent
            contentHeight: step1Content.height + 40
            clip: true
            visible: false
            opacity: 0

            property bool isActive: currentStep === 1
            property real _dir: currentStep > _prevStep ? 1.0 : -1.0

            transform: Translate { id: step1Translate }

            states: [
                State {
                    name: "active"; when: step1.isActive
                    PropertyChanges { target: step1; opacity: 1.0; visible: true }
                    PropertyChanges { target: step1Translate; x: 0 }
                },
                State {
                    name: "inactive"; when: !step1.isActive
                    PropertyChanges { target: step1; opacity: 0.0 }
                    PropertyChanges { target: step1Translate; x: -step1._dir * stepsContainer.width * 0.3 }
                }
            ]

            transitions: [
                Transition {
                    to: "active"
                    SequentialAnimation {
                        PropertyAction { target: step1; property: "visible"; value: true }
                        ParallelAnimation {
                            NumberAnimation { target: step1; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                            NumberAnimation { target: step1Translate; property: "x"; from: step1._dir * stepsContainer.width * 0.3; to: 0; duration: 280; easing.type: Easing.OutCubic }
                        }
                    }
                },
                Transition {
                    to: "inactive"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: step1; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                            NumberAnimation { target: step1Translate; property: "x"; duration: 200; easing.type: Easing.InCubic }
                        }
                        PropertyAction { target: step1; property: "visible"; value: false }
                    }
                }
            ]

            Column {
                id: step1Content
                width: parent.width
                spacing: 16

                Column {
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // Откуда
                    Text {
                        text: "Откуда"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Column {
                        id: fromListInternal
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: transferController.accounts

                            Rectangle {
                                width: parent.width
                                height: 64
                                radius: 12

                                property bool isFrozenOrBlocked: !(modelData.is_active ?? true) || (modelData.is_blocked ?? false)

                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                                }

                                border.color: fromAccountId === modelData.id && !isFrozenOrBlocked ? Theme.accent : Theme.card
                                border.width: fromAccountId === modelData.id && !isFrozenOrBlocked ? 1.5 : 1
                                opacity: isFrozenOrBlocked ? 0.35 : 1.0

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Rectangle {
                                        width: 40; height: 40; radius: 10
                                        color: "#111827"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.centerIn: parent
                                            width: 28; height: 20
                                            source: cardBrandIcon(modelData.card_brand)
                                            sourceSize: Qt.size(28, 20)
                                            fillMode: Image.PreserveAspectFit
                                            visible: cardBrandIcon(modelData.card_brand) !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "₽"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: "#10B981"
                                            visible: cardBrandIcon(modelData.card_brand) === ""
                                        }
                                    }

                                    Column {
                                        width: parent.width - 86
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
                                        color: fromAccountId === modelData.id && !isFrozenOrBlocked ? Theme.accent : "transparent"
                                        border.width: 2
                                        border.color: fromAccountId === modelData.id && !isFrozenOrBlocked ? Theme.accent : "#4B5563"
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
                        color: Theme.accent
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
                        id: toListInternal
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

                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                                }
                                border.color: toAccountId === modelData.id && !isFrozenOrBlocked ? "#10B981" : Theme.card
                                border.width: toAccountId === modelData.id && !isFrozenOrBlocked ? 1.5 : 1
                                opacity: isFrozenOrBlocked ? 0.35 : 1.0

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Rectangle {
                                        width: 40; height: 40; radius: 10
                                        color: "#111827"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.centerIn: parent
                                            width: 28; height: 20
                                            source: cardBrandIcon(modelData.card_brand)
                                            sourceSize: Qt.size(28, 20)
                                            fillMode: Image.PreserveAspectFit
                                            visible: cardBrandIcon(modelData.card_brand) !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "₽"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: "#10B981"
                                            visible: cardBrandIcon(modelData.card_brand) === ""
                                        }
                                    }

                                    Column {
                                        width: parent.width - 86
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
                        id: internalAmountBlock
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
                            border.color: internalAmountInput.activeFocus ? Theme.accent: "#1F2937"
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
                        id: internalTransferBtn
                        width: parent.width
                        height: 54
                        radius: 16

                        property bool canTransfer: fromAccountId > 0 && toAccountId > 0 &&
                                                   internalAmountInput.text.length > 0 &&
                                                   parseFloat(internalAmountInput.text) > 0 &&
                                                   !isLoading

                        color: canTransfer ? Theme.accent : "#374151"

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
            }
        }

        // ШАГ 2: Другому человеку
        Flickable {
            id: step2
            anchors.fill: parent
            contentHeight: step2Content.height + 40
            clip: true
            visible: false
            opacity: 0

            property bool isActive: currentStep === 2
            property real _dir: currentStep > _prevStep ? 1.0 : -1.0

            transform: Translate { id: step2Translate }

            states: [
                State {
                    name: "active"; when: step2.isActive
                    PropertyChanges { target: step2; opacity: 1.0; visible: true }
                    PropertyChanges { target: step2Translate; x: 0 }
                },
                State {
                    name: "inactive"; when: !step2.isActive
                    PropertyChanges { target: step2; opacity: 0.0 }
                    PropertyChanges { target: step2Translate; x: -step2._dir * stepsContainer.width * 0.3 }
                }
            ]

            transitions: [
                Transition {
                    to: "active"
                    SequentialAnimation {
                        PropertyAction { target: step2; property: "visible"; value: true }
                        ParallelAnimation {
                            NumberAnimation { target: step2; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                            NumberAnimation { target: step2Translate; property: "x"; from: step2._dir * stepsContainer.width * 0.3; to: 0; duration: 280; easing.type: Easing.OutCubic }
                        }
                    }
                },
                Transition {
                    to: "inactive"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: step2; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                            NumberAnimation { target: step2Translate; property: "x"; duration: 200; easing.type: Easing.InCubic }
                        }
                        PropertyAction { target: step2; property: "visible"; value: false }
                    }
                }
            ]

            Column {
                id: step2Content
                width: parent.width
                spacing: 16

                Column {
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // Откуда
                    Text {
                        text: "Списать со счёта"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Column {
                        id: fromListExternal
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
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                                }
                                border.color: fromAccountId === modelData.id && !isFrozenOrBlocked ? Theme.accent : Theme.card
                                border.width: fromAccountId === modelData.id && !isFrozenOrBlocked ? 1.5 : 1
                                opacity: isFrozenOrBlocked ? 0.35 : 1.0

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Rectangle {
                                        width: 40; height: 40; radius: 10
                                        color: "#111827"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.centerIn: parent
                                            width: 28; height: 20
                                            source: cardBrandIcon(modelData.card_brand)
                                            sourceSize: Qt.size(28, 20)
                                            fillMode: Image.PreserveAspectFit
                                            visible: cardBrandIcon(modelData.card_brand) !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "₽"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: "#10B981"
                                            visible: cardBrandIcon(modelData.card_brand) === ""
                                        }
                                    }

                                    Column {
                                        width: parent.width - 86
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
                                        color: fromAccountId === modelData.id && !isFrozenOrBlocked ? Theme.accent : "transparent"
                                        border.width: 2
                                        border.color: fromAccountId === modelData.id && !isFrozenOrBlocked ? Theme.accent : "#4B5563"
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
                        color: Theme.accent
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
                        id: phoneBlock
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
                            border.color: extPhoneInput.activeFocus ? Theme.accent : "#1F2937"
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

                                Image {
                                    width: 16; height: 16
                                    source: "assets/check-mark-green.svg"
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
                        id: externalAmountBlock
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
                            border.color: externalAmountInput.activeFocus ? Theme.accent : "#1F2937"
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
                        id: externalTransferBtn
                        width: parent.width
                        height: 54
                        radius: 16

                        property bool canTransfer: fromAccountId > 0 && recipientValid &&
                                                   externalAmountInput.text.length > 0 &&
                                                   parseFloat(externalAmountInput.text) > 0 &&
                                                   !isLoading

                        color: canTransfer ? Theme.accent : "#374151"

                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: isLoading ? "Выполняется..." : "Перевести"
                            font.pixelSize: 16
                            font.bold: true
                            font.family: manropeFont.name
                            color: parent.canTransfer ? Theme.textMuted : "#6B7280"
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
            }
        }

        // ШАГ 3: Успех (scale + fade)
        Item {
            id: step3
            anchors.fill: parent
            visible: false
            opacity: 0
            scale: 0.85

            property bool isActive: currentStep === 3

            states: [
                State {
                    name: "active"; when: step3.isActive
                    PropertyChanges { target: step3; opacity: 1.0; visible: true; scale: 1.0 }
                },
                State {
                    name: "inactive"; when: !step3.isActive
                    PropertyChanges { target: step3; opacity: 0.0; scale: 0.85 }
                }
            ]

            transitions: [
                Transition {
                    to: "active"
                    SequentialAnimation {
                        PropertyAction { target: step3; property: "visible"; value: true }
                        ParallelAnimation {
                            NumberAnimation { target: step3; property: "opacity"; duration: 350; easing.type: Easing.OutCubic }
                            NumberAnimation { target: step3; property: "scale"; duration: 400; easing.type: Easing.OutBack }
                        }
                    }
                },
                Transition {
                    to: "inactive"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: step3; property: "opacity"; duration: 200; easing.type: Easing.InCubic }
                            NumberAnimation { target: step3; property: "scale"; duration: 200; easing.type: Easing.InCubic }
                        }
                        PropertyAction { target: step3; property: "visible"; value: false }
                    }
                }
            ]

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
                    text: "Перевод выполнен!"
                    font.pixelSize: 22
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { width: 1; height: 12 }

                // Кнопки
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: Theme.accent

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
                            goToStep(0)
                        }
                    }
                }

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
                        text: "На главную"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: Theme.textSubtle
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: backToMain()
                    }
                }
            }
        }
    }

    // Таймер для дебаунса поиска получателя
    Timer {
        id: searchTimer
        interval: 1000
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
            goToStep(3)
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
    GuideButton {
        anchors.top: parent.top
        anchors.topMargin: 25
        anchors.right: parent.right
        anchors.rightMargin: 16
        z: 11
        visible: currentStep <= 2
        onClicked: guide.open()
    }

    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "transfer"
        steps: currentStep === 1 ? [
            { target: fromListInternal, flickable: step1, title: "Откуда списать",
              text: "Выберите счёт, с которого спишутся деньги. Замороженные и заблокированные счета недоступны." },
            { target: toListInternal, flickable: step1, title: "Куда зачислить",
              text: "А здесь — счёт получения. Перевести можно только между двумя разными счетами." },
            { target: internalAmountBlock, flickable: step1, title: "Сумма",
              text: "Введите сумму перевода. Она не может превышать остаток на счёте списания." },
            { target: internalTransferBtn, flickable: step1, title: "Подтверждение",
              text: "Кнопка станет активной, когда выбраны оба счёта и указана сумма. Перевод выполняется мгновенно и без комиссии." }
        ] : currentStep === 2 ? [
            { target: fromListExternal, flickable: step2, title: "Счёт списания",
              text: "Выберите, с какого из ваших счетов отправить деньги." },
            { target: phoneBlock, flickable: step2, title: "Получатель",
              text: "Введите номер телефона получателя — приложение само найдёт его и покажет имя для проверки." },
            { target: externalAmountBlock, flickable: step2, title: "Сумма",
              text: "Укажите сумму перевода другому человеку." },
            { target: externalTransferBtn, flickable: step2, title: "Отправка",
              text: "Когда получатель найден и сумма введена — нажмите «Перевести». Деньги придут на основной счёт получателя." }
        ] : [
            { title: "Переводы",
              text: "Здесь можно перемещать деньги между своими счетами или отправлять их другим людям. Выберите тип перевода — и подсказка продолжится на следующем шаге." },
            { target: optInternal, flickable: step0, title: "Между своими счетами",
              text: "Мгновенный перевод между вашими картами и счетами. Без комиссии." },
            { target: optExternal, flickable: step0, title: "Другому человеку",
              text: "Перевод по номеру телефона: получатель должен быть клиентом PlutusBank. Кнопка «?» подскажет и на следующих шагах." }
        ]
    }
}
