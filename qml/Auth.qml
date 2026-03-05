import QtQuick
import QtQuick.Controls

Item {
    id: authPage
    //anchors.fill: parent

    // Сигналы
    signal loginSuccess()
    signal switchToRegister()

    property string errorMessage: ""
    property bool showError: false
    property string cleanPhone: ""

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
            Item { width: 1; height: 60 }

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

            // Отступ
            Item { width: 1; height: 40 }

            Rectangle {
                width: parent.width - 32
                height: showError ? 60 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 12
                color: "#7F1D1D"
                border.color: "#DC2626"
                border.width: 1
                visible: showError
                opacity: showError ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
                
                Behavior on height {
                    NumberAnimation { duration: 200 }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24
                        source: "assets/warning.svg"
                        sourceSize: Qt.size(24, 24)
                    }

                    Column {
                        width: parent.width - 80
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "Ошибка входа"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FEE2E2"
                        }

                        Text {
                            text: errorMessage
                            font.pixelSize: 12
                            color: "#FECACA"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            source: "assets/cross.svg"
                            sourceSize: Qt.size(20, 20)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                showError = false
                                errorMessage = ""
                            }
                        }
                    }
                }
            }

            // Отступ после ошибки
            Item { width: 1; height: showError ? 16 : 0 }

            // Форма входа
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                // Поле телефона
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
                    
                                maximumLength: 15  // "(933) 221-19-01" = 15 символов

                                onTextChanged: {
                                    // Сбрасываем ошибку
                                    if (showError) {
                                        showError = false
                                        errorMessage = ""
                                    }
                        
                                    // Извлекаем только цифры из введённого текста
                                    var digits = text.replace(/\D/g, '')
                        
                                    // Ограничиваем до 10 цифр
                                    if (digits.length > 10) {
                                        digits = digits.substring(0, 10)
                                    }
                        
                                    // Сохраняем "чистый" номер
                                    cleanPhone = digits
                        
                                    // Форматируем номер
                                    var formatted = formatPhone(digits)
                        
                                    // Обновляем текст только если он изменился (избегаем зацикливания)
                                    if (text !== formatted) {
                                        var curPos = cursorPosition
                                        text = formatted
                            
                                        // Восстанавливаем позицию курсора в конец
                                        cursorPosition = formatted.length
                                    }
                                }
                    
                                function formatPhone(digits) {
                                    if (digits.length === 0) return ""
                        
                                    var formatted = ""
                        
                                    // (xxx)
                                    if (digits.length <= 3) {
                                        formatted = "(" + digits
                                    }
                                    // (xxx) xxx
                                    else if (digits.length <= 6) {
                                        formatted = "(" + digits.substring(0, 3) + ") " + digits.substring(3)
                                    }
                                    // (xxx) xxx-xx
                                    else if (digits.length <= 8) {
                                        formatted = "(" + digits.substring(0, 3) + ") " + 
                                                   digits.substring(3, 6) + "-" + 
                                                   digits.substring(6)
                                    }
                                    // (xxx) xxx-xx-xx
                                    else {
                                        formatted = "(" + digits.substring(0, 3) + ") " + 
                                                   digits.substring(3, 6) + "-" + 
                                                   digits.substring(6, 8) + "-" + 
                                                   digits.substring(8, 10)
                                    }
                        
                                    return formatted
                                }

                                Text {
                                    text: "(900) 123-45-67"
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

                                onTextChanged: {
                                    if (showError) {
                                        showError = false
                                        errorMessage = ""
                                    }
                                }

                                Text {
                                    text: "Введите пароль"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !passwordInput.text && !passwordInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 8
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.centerIn: parent
                                    width: 24; height: 24
                                    source: passwordInput.showPassword
                                            ? "assets/eye.svg"
                                            : "assets/eye-slash.svg"
                                    sourceSize: Qt.size(24, 24)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: passwordInput.showPassword = !passwordInput.showPassword
                                }
                            }
                        }
                    }
                }

                // Забыли пароль
                Text {
                    text: "Забыли пароль?"
                    font.pixelSize: 13
                    color: "#27D6C5"
                    anchors.right: parent.right

                    MouseArea {
                        anchors.fill: parent
                        onClicked: console.log("Password Recovery")
                    }
                }

                // Отступ
                Item { width: 1; height: 8 }

                // Кнопка входа
                Rectangle {
                    id: loginButton
                    width: parent.width
                    height: 54
                    radius: 16

                    property bool isFormValid: cleanPhone.length === 10 && passwordInput.text.length >= 8
                    property bool isLoading: false
                    
                    color: isFormValid && !isLoading ? "#27D6C5" : "#1F2937"

                    Row {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: loginButton.isLoading

                        Repeater {
                            model: 3
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "#050B1A"
                                
                                SequentialAnimation on opacity {
                                    running: loginButton.isLoading
                                    loops: Animation.Infinite
                                    NumberAnimation { 
                                        from: 0.3
                                        to: 1.0
                                        duration: 500 
                                        easing.type: Easing.InOutQuad
                                    }
                                    NumberAnimation { 
                                        from: 1.0
                                        to: 0.3
                                        duration: 500 
                                        easing.type: Easing.InOutQuad
                                    }
                                    PauseAnimation { duration: index * 150 }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: loginButton.isLoading ? "" : "Войти"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: loginButton.isFormValid && !loginButton.isLoading ? "#050B1A" : "#6B7280"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: loginButton.isFormValid && !loginButton.isLoading
                        onClicked: {
                            console.log("Попытка входа...")
            
                            loginButton.isLoading = true
            
                            var phone = cleanPhone  // Используем "чистый" номер без форматирования
                            if (!phone.startsWith("+7")) {
                                phone = "+7" + phone
                            }
            
                            // Вызываем метод авторизации
                            authController.loginUser(phone, passwordInput.text)
                        }
                    }
                }

                // Разделитель
                Row {
                    width: parent.width - 32 
                    spacing: 12  
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: (parent.width - orText.implicitWidth - parent.spacing * 2) / 2 
                        height: 1
                        color: "#1F2937"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: orText 
                        text: "или"
                        font.pixelSize: 13
                        color: "#6B7280"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: (parent.width - orText.implicitWidth - parent.spacing * 2) / 2  // ← ИЗМЕНЕНО: точный расчёт
                        height: 1
                        color: "#1F2937"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Кнопка регистрации
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: "transparent"
                    border.color: "#27D6C5"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "Создать аккаунт"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#27D6C5"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: authPage.switchToRegister()
                    }
                }
            }

            // Отступ снизу
            Item { width: 1; height: 40 }
        }
    }

    Connections {
        target: authController
        
        function onLoginSuccess() {
            console.log("Login is successful!")
            loginButton.isLoading = false
            showError = false
            errorMessage = ""
            
            // Очищаем поля
            phoneInput.text = ""
            passwordInput.text = ""
            
            // Отправляем сигнал успешной авторизации
            authPage.loginSuccess()
        }
        
        function onLoginFailed(error) {
            console.log("Login error:", error)
            loginButton.isLoading = false
            
            // Показываем сообщение об ошибке
            errorMessage = error
            showError = true
            
            // Автоматически скрываем через 5 секунд
            errorTimer.restart()
        }
    }
    
    Timer {
        id: errorTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            showError = false
            errorMessage = ""
        }
    }
}
