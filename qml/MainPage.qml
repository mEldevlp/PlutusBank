import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "."

Item {
    id: mainPage
    anchors.fill: parent

    signal openCreateCard()

    Component.onCompleted: {
        console.log("MainPage загружена")
        userSession.loadCards()
        userSession.refreshBalance()
    }

    // Загрузка шрифта
    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    // Градиентный фон
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    // ============ Pull-to-Refresh индикатор ============
    Rectangle {
        id: refreshIndicator
        width: 50
        height: 50
        radius: 25
        color: "#27D6C5"
        anchors.horizontalCenter: parent.horizontalCenter
    
        y: Math.max(-70, Math.min(50, -contentFlickable.contentY - 20))
    
        opacity: contentFlickable.contentY < -20 ? Math.min(1.0, Math.abs(contentFlickable.contentY) / 80) : 0
        visible: opacity > 0
        z: 10

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        // Иконка обновления (статичная)
        Image {
            id: refreshIcon
            anchors.centerIn: parent
            width: 28
            height: 28
            source: "assets/update.svg"
            sourceSize: Qt.size(28, 28)
            smooth: true
            visible: !userSession.isRefreshing
        
            // Эффект поворота при протягивании
            rotation: contentFlickable.contentY < -20 ? Math.abs(contentFlickable.contentY) * 2 : 0
        
            Behavior on rotation {
                NumberAnimation { duration: 100 }
            }
        }
    
        // Индикатор загрузки (вращающаяся иконка)
        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: "assets/update.svg"
            sourceSize: Qt.size(28, 28)
            smooth: true
            visible: userSession.isRefreshing
        
            RotationAnimation on rotation {
                running: userSession.isRefreshing
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }

        // Текст подсказки
        Text {
            anchors.top: parent.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: contentFlickable.contentY < -80 ? "Отпустите..." : "Потяните вниз"
            font.pixelSize: 12
            color: "#27D6C5"
            opacity: parent.opacity
        }
    }
    // ===================================================

    Flickable {
        id: contentFlickable
        anchors.fill: parent
        contentHeight: contentColumn.height + 40
        clip: true
    
        boundsBehavior: Flickable.DragAndOvershootBounds
    
        // Обработка pull-to-refresh
        property real pullThreshold: -80
        property bool canRefresh: false
    
        onContentYChanged: {
            if (contentY < pullThreshold && !userSession.isRefreshing && atYBeginning) {
                canRefresh = true
            } else if (contentY >= pullThreshold) {
                canRefresh = false
            }
        }

        onDraggingChanged: {
            console.log("dragging:", dragging, "canRefresh:", canRefresh, "contentY:", contentY)
        
            if (!dragging && canRefresh && contentY < pullThreshold) {
                console.log("🔄 Запуск обновления!")
                triggerRefresh()
            }
        }
    
        function triggerRefresh() {
            console.log("=== triggerRefresh() вызван ===")
        
            if (typeof userSession.refreshAll === "function") {
                userSession.refreshAll()
                console.log("✓ userSession.refreshAll() вызван")
            } else {
                console.log("✗ ОШИБКА: userSession.refreshAll не существует!")
                console.log("Вызываем запасные методы...")
                userSession.loadCards()
                userSession.refreshBalance()
            }
        
            canRefresh = false
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: 24
            anchors.horizontalCenter: parent.horizontalCenter

            // Отступ сверху
            Item { width: 1; height: 20 }

            // Шапка с приветствием
            Row {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Column {
                    width: parent.width - 60
                    spacing: 4

                    Text {
                        text: "Добро пожаловать,"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                    }

                    Text {
                        text: userSession.shortName  // "Кондрашов Д."
                        font.pixelSize: 20
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#F7F7FB"
                    }
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: "#27D6C5"

                    Text {
                        anchors.centerIn: parent
                        text: userSession.lastName.charAt(0).toUpperCase()
                        font.pixelSize: 18
                        font.bold: true
                        color: "#050B1A"
                    }
                }
            }

            // Карта баланса
            Rectangle {
                width: parent.width - 32
                height: 180
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 20
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#1E40AF" }
                    GradientStop { position: 1.0; color: "#3B82F6" }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 12

                    Row {
                        width: parent.width
                        
                        Column {
                            width: parent.width - 40
                            spacing: 8

                            Text {
                                text: "Общий баланс"
                                font.pixelSize: 14
                                color: "#DBEAFE"
                                opacity: 0.8
                            }

                            Text {
                                text: userSession.totalBalance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                font.pixelSize: 32
                                font.bold: true
                                font.family: manropeFont.name
                                color: "#FFFFFF"
                            }
                        }

                        Text {
                            text: "💰"
                            font.pixelSize: 32
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item { width: 1; height: 1 }

                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            spacing: 4

                            Text {
                                text: "Доход"
                                font.pixelSize: 11
                                color: "#DBEAFE"
                                opacity: 0.7
                            }

                            Text {
                                text: "+0 ₽"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#10B981"
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 30
                            color: "#DBEAFE"
                            opacity: 0.3
                        }

                        Column {
                            spacing: 4

                            Text {
                                text: "Расход"
                                font.pixelSize: 11
                                color: "#DBEAFE"
                                opacity: 0.7
                            }

                            Text {
                                text: "-0 ₽"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#EF4444"
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                // Заголовок секции
                Row {
                    width: parent.width
                    
                    Text {
                        text: "Мои карты"
                        font.pixelSize: 18
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#F7F7FB"
                    }
                }

                // Если карт нет - показываем только кнопку
                Column {
                    width: parent.width
                    spacing: 16
                    visible: !userSession.hasCards  // Карт нет

                    Rectangle {
                        width: parent.width
                        height: 140
                        radius: 16
                        color: "#1F2937"
                        border.color: "#374151"
                        border.width: 2

                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            Text {
                                text: "📇"
                                font.pixelSize: 48
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

                    // Кнопка выпуска карты
                    Rectangle {
                        width: parent.width
                        height: 54
                        radius: 16
                        color: "#27D6C5"

                        Text {
                            anchors.centerIn: parent
                            text: "Выпустить карту"
                            font.pixelSize: 16
                            font.bold: true
                            font.family: manropeFont.name
                            color: "#050B1A"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                openCreateCard()
                            }
                        }
                    }
                }

                // Если карты есть - показываем список
                Column {
                    width: parent.width
                    spacing: 12
                    visible: userSession.hasCards  // Карты есть!

                    Repeater {
                        model: userSession.cards

                        Rectangle {
                            width: parent.width
                            height: 115  // ← ИЗМЕНЕНО: уменьшено до 110
                            radius: 16
        
                            gradient: Gradient {
                                GradientStop { 
                                    position: 0.0
                                    color: modelData.card_brand === "visa" ? "#1E3A8A" : 
                                           modelData.card_brand === "mastercard" ? "#7C3AED" : "#059669"
                                }
                                GradientStop { 
                                    position: 1.0
                                    color: modelData.card_brand === "visa" ? "#3B82F6" : 
                                           modelData.card_brand === "mastercard" ? "#A78BFA" : "#10B981"
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                // ============ ИЗМЕНЕНО: Строка 1 - Тип карты + Логотип справа ============
                                Row {
                                    width: parent.width
                                    spacing: 0

                                    // Тип карты + Платёжная система (слева)
                                    Text {
                                        text: (modelData.card_type === "credit" ? "Кредитная" : "Дебетовая")
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#FFFFFF"
                                        opacity: 0.9
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // ============ ИЗМЕНЕНО: Пустое пространство ============
                                    Item { 
                                        width: parent.width - parent.children[0].width - logoImage.width
                                        height: 1
                                    }
                                    // =======================================================

                                    // ============ ИЗМЕНЕНО: С импортом QtQuick.Shapes ============
                                    Image {
                                        id: logoImage
                                        width: 50
                                        height: 30
                                        source: modelData.card_brand === "visa" ? "assets/visa.svg" :
                                                modelData.card_brand === "mastercard" ? "assets/mastercard.svg" :
                                                "assets/mir.svg"
                                        sourceSize: Qt.size(50, 30)  // ← ИЗМЕНЕНО: формат Qt.size()
                                        fillMode: Image.PreserveAspectFit
                                        anchors.verticalCenter: parent.verticalCenter
                                        smooth: true
                                        asynchronous: true  // ← ДОБАВЛЕНО: асинхронная загрузка
                                    }
                                    // ==============================================================
                                }
                                // =========================================================================

                                // ============ ИЗМЕНЕНО: Строка 2 - Номер и Expired date ============
                                Row {
                                    width: parent.width
                                    spacing: 0

                                    // Маскированный номер (слева)
                                    Text {
                                        text: "•••• " + modelData.card_number.slice(-4)
                                        font.pixelSize: 20
                                        font.family: "Courier"
                                        font.bold: true
                                        color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Пустое пространство
                                    Item { 
                                        width: parent.width - parent.children[0].width - expiryText.width
                                        height: 1
                                    }

                                    // Expired date (справа)
                                    Text {
                                        id: expiryText
                                        text: modelData.expiry_date  // "12/30"
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                        opacity: 0.8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                // ===================================================================

                                // ============ ИЗМЕНЕНО: Строка 3 - Только баланс без подписи ============
                                Text {
                                    text: (modelData.balance !== undefined ? 
                                           modelData.balance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) : 
                                           "0.00") + " ₽"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#FFFFFF"
                                }
                                // =========================================================================
                            }
                        }
                    }


                    // Кнопка выпуска ещё одной карты
                    Rectangle {
                        width: parent.width
                        height: 54
                        radius: 16
                        color: "transparent"
                        border.color: "#27D6C5"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "+ Выпустить ещё карту"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: manropeFont.name
                            color: "#27D6C5"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                openCreateCard()
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Text {
                    text: "Быстрые действия"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: manropeFont.name
                    color: "#F7F7FB"
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 100
                        radius: 16
                        color: "#1F2937"

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "💸"
                                font.pixelSize: 32
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
                            onClicked: console.log("Перевод")
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 100
                        radius: 16
                        color: "#1F2937"

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "📱"
                                font.pixelSize: 32
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
                            onClicked: console.log("Пополнение")
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 100
                        radius: 16
                        color: "#1F2937"

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "📊"
                                font.pixelSize: 32
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
                            onClicked: console.log("История операций")
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 100
                        radius: 16
                        color: "#1F2937"

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "⚙️"
                                font.pixelSize: 32
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
                            onClicked: console.log("Настройки")
                        }
                    }
                }
            }

            // Отступ снизу
            Item { width: 1; height: 20 }
        }
    }
}