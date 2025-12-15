import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: mainPage
    anchors.fill: parent

    // ============ ДОБАВЛЕНО: Сигнал для открытия создания карты ============
    signal openCreateCard()
    // =======================================================================

    // ============ ДОБАВЛЕНО: Автообновление данных при появлении страницы ============
    Component.onCompleted: {
        console.log("MainPage загружена")
        userSession.loadCards()
        userSession.refreshBalance()
    }
    // ==================================================================================

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

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + 40
        clip: true

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
                        // ============ ИЗМЕНЕНО: Используем реальное имя ============
                        text: userSession.shortName  // "Кондрашов Д."
                        // ===========================================================
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
                        // ============ ИЗМЕНЕНО: Первая буква фамилии ============
                        text: userSession.lastName.charAt(0).toUpperCase()
                        // =======================================================
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
                                // ============ ИЗМЕНЕНО: Используем реальный баланс ============
                                text: userSession.totalBalance.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                // ==============================================================
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

            // ============ ДОБАВЛЕНО: Условное отображение карт ============
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
                                // ============ ИЗМЕНЕНО ============
                                openCreateCard()
                                // ==================================
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
                            height: 90
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

                                Row {
                                    width: parent.width

                                    Text {
                                        text: modelData.card_brand.toUpperCase()
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#FFFFFF"
                                        opacity: 0.8
                                    }

                                    Item { width: 1; Layout.fillWidth: true }

                                    Rectangle {
                                        width: 50
                                        height: 20
                                        radius: 4
                                        color: modelData.is_active ? "#10B981" : "#EF4444"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.is_active ? "Активна" : "Заблок."
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.card_number
                                    font.pixelSize: 16
                                    font.family: "Courier"
                                    font.bold: true
                                    color: "#FFFFFF"
                                }

                                Row {
                                    width: parent.width

                                    Text {
                                        text: modelData.card_holder_name
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                        opacity: 0.8
                                    }

                                    Item { width: 1; Layout.fillWidth: true }

                                    Text {
                                        text: modelData.expiry_date
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                        opacity: 0.8
                                    }
                                }
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
            // ==============================================================

            // Быстрые действия (без изменений)
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