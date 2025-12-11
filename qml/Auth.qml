import QtQuick
import QtQuick.Controls

Item {
    id: authPage
    anchors.fill: parent

    // Сигнал для успешной авторизации
    signal loginSuccess()
	signal openRegister()  // Добавь этот сигнал
	
    // Загрузка шрифта Manrope
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
        contentHeight: contentColumn.height + 100
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter

            // Отступ сверху
            Item { width: 1; height: 80 }

            // Логотип в центре
            Item {
                width: parent.width
                height: 160

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    // Логотип
                    Image {
                        width: 126
                        height: 126
                        source: "assets/logo.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Название
                    Text {
                        text: "PLUTUS"
                        font.pixelSize: 34
                        font.bold: true
                        font.family: manropeFont.name
                        font.letterSpacing: 5
                        color: "#F7F7FB"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Вход в систему"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Отступ перед формой
            Item { width: 1; height: 40 }

            // Форма авторизации
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                // Поле номера телефона
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Номер телефона"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: phoneInput.activeFocus ? "#27D6C5" : "#1F2937"
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
                                id: phoneInput
                                width: parent.width - 40
                                height: parent.height
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhDialableCharactersOnly
                                maximumLength: 10
                                
                                Text {
                                    text: "000 000-00-00"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !phoneInput.text && !phoneInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Поле пароля
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Пароль"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: passwordInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            TextInput {
                                id: passwordInput
                                width: parent.width - 50
                                height: parent.height
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                                echoMode: showPassword ? TextInput.Normal : TextInput.Password
                                
                                property bool showPassword: false

                                Text {
                                    text: "Введите пароль"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !passwordInput.text && !passwordInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Кнопка показать/скрыть пароль
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 8
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: passwordInput.showPassword ? "👁️" : "👁️‍🗨️"
                                    font.pixelSize: 20
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: passwordInput.showPassword = !passwordInput.showPassword
                                }
                            }
                        }
                    }
                }

                // Кнопка "Забыли пароль?"
                Text {
                    text: "Забыли пароль?"
                    font.pixelSize: 13
                    color: "#27D6C5"
                    anchors.right: parent.right

                    MouseArea {
                        anchors.fill: parent
                        onClicked: console.log("Восстановление пароля")
                    }
                }

                // Кнопка входа
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: phoneInput.text.length >= 10 && passwordInput.text.length >= 6 
                           ? "#27D6C5" : "#1F2937"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Войти"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: phoneInput.text.length >= 10 && passwordInput.text.length >= 6
                               ? "#050B1A" : "#6B7280"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: phoneInput.text.length >= 10 && passwordInput.text.length >= 6
                        onClicked: {
                            console.log("Вход:", phoneInput.text, passwordInput.text)
                            authPage.loginSuccess()
                        }
                    }
                }

                // Отступ перед разделителем
                Item { width: 1; height: 24 }

                // Разделитель
                Row {
                    width: parent.width
                    spacing: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: (parent.width - 60) / 2
                        height: 1
                        color: "#1F2937"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "или"
                        font.pixelSize: 13
                        color: "#6B7280"
                    }

                    Rectangle {
                        width: (parent.width - 60) / 2
                        height: 1
                        color: "#1F2937"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Отступ перед кнопкой регистрации
                Item { width: 1; height: 12 }

                // Кнопка регистрации
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: "transparent"
                    border.color: "#7C4DFF"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "Создать аккаунт"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#7C4DFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: authPage.openRegister()
                    }
                }
            }

            // Отступ перед копирайтом
            Item { width: 1; height: 40 }

            // Нижний текст
            Text {
                text: "Plutus Crypto Bank © 2026"
                font.pixelSize: 12
                color: "#4B5563"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Отступ снизу
            Item { width: 1; height: 40 }
        }
    }
}
