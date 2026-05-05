import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

Item {
    id: root

    signal openCreateCard()
    signal openTransfer()
    signal openHistory()
    signal openCardDetail(var cardData)
    signal openTopUp()
    signal openSettings()
    signal openLoan()
    signal openDeposits()   

    Component.onCompleted: {
        userSession.loadCards()
        userSession.refreshBalance()
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

    // Обновить страницу (потянуть)
    Rectangle {
        id: pullIndicator
        width: 46; height: 46; radius: 23
        color: Theme.accent
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(-60, Math.min(40, -flick.contentY - 16))
        opacity: flick.contentY < -16 ? Math.min(1, Math.abs(flick.contentY) / 70) : 0
        visible: opacity > 0
        z: 10

        Image {
            anchors.centerIn: parent
            width: 24; height: 24
            source: "assets/update.svg"
            sourceSize: Qt.size(24, 24)
            visible: !userSession.isRefreshing
            rotation: flick.contentY < -16 ? Math.abs(flick.contentY) * 2.5 : 0
        }

        Image {
            anchors.centerIn: parent
            width: 24; height: 24
            source: "assets/update.svg"
            sourceSize: Qt.size(24, 24)
            visible: userSession.isRefreshing
            RotationAnimation on rotation {
                running: userSession.isRefreshing
                from: 0; to: 360; duration: 800
                loops: Animation.Infinite
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: mainCol.height + 32
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds

        property bool readyToRefresh: false

        onContentYChanged: {
            if (contentY < -70 && !userSession.isRefreshing && atYBeginning)
                readyToRefresh = true
            else if (contentY >= -70)
                readyToRefresh = false
        }

        onDraggingChanged: {
            if (!dragging && readyToRefresh) {
                userSession.refreshAll()
                readyToRefresh = false
            }
        }

        Column {
            id: mainCol
            width: parent.width
            spacing: 28
            topPadding: 24
            bottomPadding: 24

            // Приветствие 
            Item {
                width: parent.width - 32
                height: 52
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Добро пожаловать,"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                    }

                    Text {
                        text: userSession.shortName
                        font { pixelSize: 22; bold: true; family: manropeFont.name }
                        color: "#F7F7FB"
                    }
                }

                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: Theme.accent
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: userSession.lastName.length > 0
                              ? userSession.lastName.charAt(0).toUpperCase()
                              : ""
                        font { pixelSize: 18; bold: true }
                        color: "#050B1A"
                    }
                }
            }

            //  Общий баланс
            Rectangle {
                width: parent.width - 32
                height: 140
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                // Левая часть: заголовок + сумма
                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 24
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Text {
                        text: "Общий баланс"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                        opacity: 0.7
                    }

                    Text {
                        text: userSession.totalBalance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font { pixelSize: 28; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }
                }

                // Правая часть: доход / расход
                Column {
                    anchors {
                        right: parent.right
                        rightMargin: 24
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 12

                    Column {
                        anchors.right: parent.right
                        spacing: 2

                        Text {
                            text: "Доход"
                            font.pixelSize: 11
                            color: "#9CA3AF"
                            opacity: 0.7
                            anchors.right: parent.right
                        }
                        Text {
                            text: "+" + userSession.dailyIncome.toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                            font { pixelSize: 14; bold: true }
                            color: "#10B981" // Сделать акцентом приложения?
                            anchors.right: parent.right
                        }
                    }

                    Column {
                        anchors.right: parent.right
                        spacing: 2

                        Text {
                            text: "Расход"
                            font.pixelSize: 11
                            color: "#9CA3AF"
                            opacity: 0.7
                            anchors.right: parent.right
                        }
                        Text {
                            text: "-" + userSession.dailyExpense.toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                            font { pixelSize: 14; bold: true }
                            color: "#EF4444"
                            anchors.right: parent.right
                        }
                    }
                }
            }

            // Мои карты
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Text {
                    text: "Мои карты"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                // Пустое состояние
                Column {
                    width: parent.width
                    spacing: 14
                    visible: !userSession.hasCards

                    Rectangle {
                        width: parent.width
                        height: 130
                        radius: 16
                        color: "#111827"
                        border.color: "#374151"
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 10


                            Image {
                                width: 44; height: 44
                                source: "assets/empty-wallet-remove.svg"
                                sourceSize: Qt.size(44, 44)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "У вас пока нет карт"
                                font.pixelSize: 14
                                color: "#9CA3AF"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "Выпустите свою первую карту"
                                font.pixelSize: 12
                                color: "#6B7280"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 18; height: 18
                                source: "assets/wallet-add.svg"
                                sourceSize: Qt.size(18, 18)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Выпустить карту"
                                font { pixelSize: 15; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openCreateCard()
                        }
                    }
                }

                // Список карт
                Column {
                    width: parent.width
                    spacing: 12
                    visible: userSession.hasCards

                    Repeater {
                        model: userSession.cards

                        delegate: Item {
                            id: cardDelegate
                            width: parent.width
                            height: 110

                            required property var modelData
                            required property int index

                            readonly property bool isFrozen: !(modelData.is_active ?? true) && !(modelData.is_blocked ?? false)
                            readonly property bool isBlocked: modelData.is_blocked ?? false

                            // Градиенты по бренду
                            readonly property color gradStart: {
                                var b = modelData.card_brand ?? ""
                                if (b === "visa")       return Theme.grVisaPosStart
                                if (b === "mastercard") return Theme.grMSPosStart
                                return Theme.grMirPosStart
                            }
                            readonly property color gradEnd: {
                                var b = modelData.card_brand ?? ""
                                if (b === "visa")       return Theme.grVisaPosEnd
                                if (b === "mastercard") return Theme.grMSPosEnd
                                return Theme.grMirPosEnd
                            }

                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                radius: 16
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: cardDelegate.gradStart }
                                    GradientStop { position: 1.0; color: cardDelegate.gradEnd }
                                }
                                border.color: Theme.card

                                // Затемнение при блокировке/заморозке
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "#000000"
                                    opacity: cardDelegate.isBlocked ? 0.55
                                           : cardDelegate.isFrozen  ? 0.4
                                           : 0
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 6

                                    // Тип + логотип
                                    Item {
                                        width: parent.width
                                        height: 28

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: cardDelegate.modelData.card_type === "credit"
                                                  ? "Кредитная" : "Дебетовая"
                                            font { pixelSize: 12; bold: true }
                                            color: "#D1D5DB"
                                        }

                                        Image {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 48; height: 28
                                            fillMode: Image.PreserveAspectFit
                                            source: {
                                                var b = cardDelegate.modelData.card_brand ?? ""
                                                if (b === "visa")       return "assets/visa.svg"
                                                if (b === "mastercard") return "assets/mastercard.svg"
                                                return "assets/mir.svg"
                                            }
                                            sourceSize: Qt.size(48, 28)
                                            asynchronous: true
                                        }
                                    }

                                    // Номер + срок
                                    Item {
                                        width: parent.width
                                        height: 24

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "•••• " + (cardDelegate.modelData.card_number ?? "").slice(-4)
                                            font { pixelSize: 20; family: "Courier"; bold: true }
                                            color: Theme.textSecondary
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: cardDelegate.modelData.expiry_date ?? ""
                                            font.pixelSize: 11
                                            color: Theme.textSecondary
                                            opacity: 0.8
                                        }
                                    }

                                    // Баланс + статус
                                    Row {
                                        spacing: 8

                                        Text {
                                            text: {
                                                var bal = cardDelegate.modelData.balance ?? 0
                                                return bal.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                            }
                                            font { pixelSize: 16; bold: true }
                                            color: "#FFFFFF"
                                        }

                                        // Бейдж статуса
                                        Rectangle {
                                            visible: cardDelegate.isBlocked || cardDelegate.isFrozen
                                            width: badgeRow.width + 16
                                            height: 24
                                            radius: 12
                                            // Полупрозрачный черный фон для любого цвета карты
                                            color: "#80000000" 
                                            // Тонкая рамка в цвет статуса
                                            border.color: cardDelegate.isBlocked ? "#EF4444" : "#3B82F6"
                                            border.width: 1
                                            anchors.verticalCenter: parent.children[0].verticalCenter

                                            Row {
                                                id: badgeRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Image {
                                                    width: 14; height: 14
                                                    source: cardDelegate.isBlocked
                                                            ? "assets/lock.svg"
                                                            : "assets/snowflake.svg"
                                                    sourceSize: Qt.size(14, 14)
                                                }

                                                Text {
                                                    text: cardDelegate.isBlocked ? "Заблокирована" : "Заморожена"
                                                    font { pixelSize: 10; bold: true }
                                                    // Яркие цвета текста для контраста на темном полупрозрачном фоне
                                                    color: cardDelegate.isBlocked ? "#FCA5A5" : "#93C5FD" 
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.openCardDetail(cardDelegate.modelData)
                                }
                            }
                        }
                    }

                    // Кнопка «Выпустить ещё карту»
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart; }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd; }
                        }
                        border.color: Theme.card

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 18; height: 18
                                source: "assets/wallet-add.svg"
                                sourceSize: Qt.size(18, 18)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Выпустить карту"
                                font { pixelSize: 15; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openCreateCard()
                        }
                    }
                }
            }

            // Быстрые действия
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Text {
                    text: "Быстрые действия"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12

                    // Перевод
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 90
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 28; height: 28
                                source: "assets/transfer.svg"
                                sourceSize: Qt.size(28, 28)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "Перевод"
                                font.pixelSize: 13
                                color: "#E5E7EB"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openTransfer()
                        }
                    }

                    // Пополнить
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 90
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Image {
                                width: 28; height: 28
                                source: "assets/money-recive.svg"
                                sourceSize: Qt.size(28, 28)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "Пополнить"
                                font.pixelSize: 13
                                color: "#E5E7EB"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openTopUp()
                        }
                    }

                    // История
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 90
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 28; height: 28
                                source: "assets/history.svg"
                                sourceSize: Qt.size(28, 28)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "История"
                                font.pixelSize: 13
                                color: "#E5E7EB"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openHistory()
                        }
                    }

                    // Настройки
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 90
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 28; height: 28
                                source: "assets/settings.svg"
                                sourceSize: Qt.size(28, 28)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "Настройки"
                                font.pixelSize: 13
                                color: "#E5E7EB"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openSettings()
                        }
                    }

                    // Кредит
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 90
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                width: 28; height: 28
                                source: "assets/purse.svg"
                                sourceSize: Qt.size(28, 28)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "Кредит"
                                font.pixelSize: 13
                                color: Theme.textSubtle
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openLoan()
                        }
                    }

                    // Вклады
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 90
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card
 
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
 
                            // Используется существующий ассет money-recive.svg.
                            // Если хочется отдельную иконку — добавьте, например, assets/savings.svg
                            // и поменяйте source ниже.
                            Image {
                                width: 28; height: 28
                                source: "assets/money-recive.svg"
                                sourceSize: Qt.size(28, 28)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
 
                            Text {
                                text: "Вклады"
                                font.pixelSize: 13
                                color: Theme.textSubtle
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openDeposits()
                        }
                    }
                }
            }
        }
    }
}
