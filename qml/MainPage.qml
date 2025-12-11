import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Effects

ApplicationWindow {
    visible: true
    width: 400
    height: 800
    title: "PlutusBank"
    
    // Загрузка шрифта Manrope
    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    // Основной фон экрана
    color: "#070D1F"   // Background Main

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }  // Чуть светлее сверху
            GradientStop { position: 1.0; color: "#000000" }  // Почти черный снизу
        }

        // Контейнер для прокручиваемого контента
        Flickable {
            id: contentFlickable
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: navigationBar.top
            anchors.margins: 16
            anchors.bottomMargin: 8
            
            contentHeight: contentColumn.height
            clip: true

            Column {
                id: contentColumn
                width: parent.width
                spacing: 16

                // Шапка с логотипом и именем пользователя + общий баланс
                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 16
                    color: "#050B1A"          // Primary Navy

                    // Левая часть: логотип + имя
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        // Логотип с рамкой
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: "assets/logo.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "PLUTUS"
                                font.pixelSize: 16
                                font.bold: true
                                font.family: manropeFont.name
                                font.letterSpacing: 2.5           // Разрядка текста
                                color: "#F7F7FB"                  // Brand Text Light
                            }

                            Text {
                                text: "username"
                                font.pixelSize: 13
                                color: "#9CA3AF"      // Secondary Text
                            }
                        }
                    }

                    // Правая часть: общий баланс
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Общий баланс"
                            font.pixelSize: 11
                            color: "#9CA3AF"          // Secondary Text
                            horizontalAlignment: Text.AlignRight
                            anchors.right: parent.right
                        }

                        Text {
                            text: "50 000.00 ₽"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F4C045"          // Gold Core
                            horizontalAlignment: Text.AlignRight
                            anchors.right: parent.right
                        }
                    }
                }

                // Карточка с балансом / тратами
                Rectangle {
                    width: parent.width
                    height: 110
                    radius: 18
                    color: "#0F172A"              // Card Background
                    border.color: "#1F2937"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Text {
                            text: "Все операции"
                            font.pixelSize: 14
                            color: "#E5E7EB"        // Primary Text
                        }

                        Text {
                            text: "Траты в этом месяце"
                            font.pixelSize: 12
                            color: "#9CA3AF"        // Secondary Text
                        }

                        Text {
                            text: "0.00 ₽"
                            font.pixelSize: 24
                            font.bold: true
                            color: "#F4C045"        // Gold Core
                        }
                    }
                }

                // Карта кредитной карты
                Rectangle {
                    width: parent.width
                    height: 140
                    radius: 20
                    
                    // Градиент премиальной карты
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#050B1A" }  // Primary Navy
                        GradientStop { position: 0.4; color: "#7C4DFF" }  // Accent Purple
                        GradientStop { position: 1.0; color: "#27D6C5" }  // Accent Teal
                    }
                    border.color: "#111827"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "Кредитная карта"
                                font.pixelSize: 14
                                color: "#F7F7FB"
                            }

                            Rectangle {
                                radius: 8
                                color: "#F4C045"
                                height: 18
                                width: 58

                                Text {
                                    anchors.centerIn: parent
                                    text: "PRO"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#050B1A"
                                }
                            }
                        }

                        Text {
                            text: "6 500.00 ₽"
                            font.pixelSize: 22
                            font.bold: true
                            color: "#F7F7FB"
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "•••• 0798"
                                font.pixelSize: 14
                                color: "#E5E7EB"
                            }

                            Item { width: 1; height: 1 }

                            Text {
                                text: "Кредитная"
                                font.pixelSize: 13
                                color: "#E5E7EB"
                            }
                        }
                    }
                }

                // Кнопка CTA "Выпустить карту"
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 16
                    color: "#27D6C5"              // Accent Teal

                    Text {
                        anchors.centerIn: parent
                        text: "Выпустить карту"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#050B1A"          // Primary Navy
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: console.log("Выпустить карту")
                    }
                }
            }
        }

        // Нижняя навигация - ВСЕГДА ВНИЗУ
        Rectangle {
            id: navigationBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            height: 70
            radius: 18
            color: "#050B1A"              // Primary Navy
            border.color: "#111827"
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Repeater {
                    model: [
                        { label: "Главная", active: false },
                        { label: "Банк",    active: true  },
                        { label: "Крипто",  active: false },
                        { label: "Ещё",     active: false }
                    ]

                    Rectangle {
                        width: (parent.width - 8) / 4
                        height: parent.height - 8
                        radius: 12
                        color: modelData.active ? "#0F172A" : "transparent"

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.label
                                font.pixelSize: 13
                                color: modelData.active ? "#F7F7FB" : "#9CA3AF"
                            }

                            Rectangle {
                                width: 32
                                height: 3
                                radius: 2
                                color: modelData.active ? "#F4C045" : "transparent"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: console.log(modelData.label + " clicked")
                        }
                    }
                }
            }
        }
    }
}
