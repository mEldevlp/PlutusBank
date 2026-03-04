import QtQuick
import QtQuick.Controls

Item {
    id: registerPage
    //anchors.fill: parent

    // Сигналы
    signal registerSuccess()
    signal backToLogin()

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
            Item { width: 1; height: 40 }

            // Кнопка назад
            Row {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 40
                    height: 40
                    radius: 10
                    color: "#0F172A"

                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(24, 24)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: registerPage.backToLogin()
                    }
                }

                Text {
                    text: "Назад"
                    font.pixelSize: 16
                    color: "#E5E7EB"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Отступ
            Item { width: 1; height: 30 }

            // Заголовок
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    text: "Регистрация"
                    font.pixelSize: 28
                    font.bold: true
                    font.family: manropeFont.name
                    font.letterSpacing: 2
                    color: "#F7F7FB"
                }

                Text {
                    text: "Заполните все данные для создания аккаунта"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                }
            }

            // Отступ
            Item { width: 1; height: 24 }

            // Форма регистрации
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                // БЛОК ФИО
                Text {
                    text: "Личные данные"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#27D6C5"
                }

                // Фамилия
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Фамилия"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: lastNameInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        TextInput {
                            id: lastNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            font.pixelSize: 16
                            color: "#E5E7EB"
                            verticalAlignment: Text.AlignVCenter

                            Text {
                                text: "Иванов"
                                font.pixelSize: 16
                                color: "#4B5563"
                                visible: !lastNameInput.text && !lastNameInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Имя
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Имя"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: firstNameInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        TextInput {
                            id: firstNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            font.pixelSize: 16
                            color: "#E5E7EB"
                            verticalAlignment: Text.AlignVCenter

                            Text {
                                text: "Иван"
                                font.pixelSize: 16
                                color: "#4B5563"
                                visible: !firstNameInput.text && !firstNameInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Отчество (необязательное)
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        spacing: 8
                        Text {
                            text: "Отчество"
                            font.pixelSize: 13
                            color: "#E5E7EB"
                            font.family: manropeFont.name
                        }
                        Text {
                            text: "(необязательно)"
                            font.pixelSize: 11
                            color: "#6B7280"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: middleNameInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        TextInput {
                            id: middleNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            font.pixelSize: 16
                            color: "#E5E7EB"
                            verticalAlignment: Text.AlignVCenter

                            Text {
                                text: "Иванович"
                                font.pixelSize: 16
                                color: "#4B5563"
                                visible: !middleNameInput.text && !middleNameInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Дата рождения
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Дата рождения"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: birthDateInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        TextInput {
                            id: birthDateInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            font.pixelSize: 16
                            color: "#E5E7EB"
                            verticalAlignment: Text.AlignVCenter
                            inputMask: "99.99.9999"
                            inputMethodHints: Qt.ImhDate

                            Text {
                                text: "ДД.ММ.ГГГГ"
                                font.pixelSize: 16
                                color: "#4B5563"
                                visible: !birthDateInput.text && !birthDateInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Text {
                        text: "Некорректная дата"
                        font.pixelSize: 11
                        color: "#EF4444"
                        visible: birthDateInput.text.length === 10 && !isValidDate(birthDateInput.text)

                        function isValidDate(dateStr) {
                            var parts = dateStr.split('.');
                            if (parts.length !== 3) return false;
                            
                            var day = parseInt(parts[0]);
                            var month = parseInt(parts[1]);
                            var year = parseInt(parts[2]);
                            
                            if (year < 1900 || year > 2010) return false;
                            if (month < 1 || month > 12) return false;
                            if (day < 1 || day > 31) return false;
                            
                            return true;
                        }
                    }
                }

                // Отступ между секциями
                Item { width: 1; height: 8 }

                // БЛОК ПАСПОРТ 
                Text {
                    text: "Паспортные данные"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#27D6C5"
                }

                Row {
                    width: parent.width
                    spacing: 12

                    // Серия паспорта
                    Column {
                        width: (parent.width - 12) / 2
                        spacing: 8

                        Text {
                            text: "Серия"
                            font.pixelSize: 13
                            color: "#E5E7EB"
                            font.family: manropeFont.name
                        }

                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: 12
                            color: "#0F172A"
                            border.color: passportSeriesInput.activeFocus ? "#27D6C5" : "#1F2937"
                            border.width: 2

                            TextInput {
                                id: passportSeriesInput
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhDigitsOnly
                                maximumLength: 4

                                Text {
                                    text: "0000"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !passportSeriesInput.text && !passportSeriesInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Номер паспорта
                    Column {
                        width: (parent.width - 12) / 2
                        spacing: 8

                        Text {
                            text: "Номер"
                            font.pixelSize: 13
                            color: "#E5E7EB"
                            font.family: manropeFont.name
                        }

                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: 12
                            color: "#0F172A"
                            border.color: passportNumberInput.activeFocus ? "#27D6C5" : "#1F2937"
                            border.width: 2

                            TextInput {
                                id: passportNumberInput
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                                inputMethodHints: Qt.ImhDigitsOnly
                                maximumLength: 6

                                Text {
                                    text: "000000"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !passportNumberInput.text && !passportNumberInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Отступ между секциями
                Item { width: 1; height: 8 }

                // БЛОК КОНТАКТЫ 
                Text {
                    text: "Контактные данные"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#27D6C5"
                }

                // Поле Email
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Email"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: emailInput.activeFocus ? "#27D6C5" : "#1F2937"
                        border.width: 2

                        TextInput {
                            id: emailInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            font.pixelSize: 16
                            color: "#E5E7EB"
                            verticalAlignment: Text.AlignVCenter
                            inputMethodHints: Qt.ImhEmailCharactersOnly

                            Text {
                                text: "example@mail.com"
                                font.pixelSize: 16
                                color: "#4B5563"
                                visible: !emailInput.text && !emailInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Text {
                        text: "Некорректный email"
                        font.pixelSize: 11
                        color: "#EF4444"
                        visible: emailInput.text.length > 0 && !isValidEmail(emailInput.text)

                        function isValidEmail(email) {
                            var re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                            return re.test(email);
                        }
                    }
                }

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
                                maximumLength: 10

                                Text {
                                    text: "900 123-45-67"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !phoneInput.text && !phoneInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Отступ между секциями
                Item { width: 1; height: 8 }

                // БЛОК БЕЗОПАСНОСТЬ 
                Text {
                    text: "Безопасность"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#27D6C5"
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
                                    text: "Минимум 8 символов"
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

                    // Индикатор силы пароля
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 4
                            radius: 2
                            color: passwordInput.text.length >= 8 ? "#10B981" : "#1F2937"
                        }
                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 4
                            radius: 2
                            color: passwordInput.text.length >= 10 ? "#10B981" : "#1F2937"
                        }
                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 4
                            radius: 2
                            color: passwordInput.text.length >= 12 ? "#10B981" : "#1F2937"
                        }
                    }
                }

                // Поле подтверждения пароля
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Подтвердите пароль"
                        font.pixelSize: 13
                        color: "#E5E7EB"
                        font.family: manropeFont.name
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 12
                        color: "#0F172A"
                        border.color: confirmPasswordInput.activeFocus ? "#27D6C5" : 
                                     (confirmPasswordInput.text.length > 0 && confirmPasswordInput.text !== passwordInput.text) ? "#EF4444" : "#1F2937"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            TextInput {
                                id: confirmPasswordInput
                                width: parent.width - 50
                                height: parent.height
                                font.pixelSize: 16
                                color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                                echoMode: showConfirmPassword ? TextInput.Normal : TextInput.Password

                                property bool showConfirmPassword: false

                                Text {
                                    text: "Повторите пароль"
                                    font.pixelSize: 16
                                    color: "#4B5563"
                                    visible: !confirmPasswordInput.text && !confirmPasswordInput.activeFocus
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
                                    onClicked: confirmPasswordInput.showConfirmPassword = !confirmPasswordInput.showConfirmPassword
                                }
                            }
                        }
                    }

                    Text {
                        text: "Пароли не совпадают"
                        font.pixelSize: 11
                        color: "#EF4444"
                        visible: confirmPasswordInput.text.length > 0 && confirmPasswordInput.text !== passwordInput.text
                    }
                }

                // Отступ
                Item { width: 1; height: 8 }

                // Чекбокс согласия
                Row {
                    id: termsRow
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        id: termsCheckbox
                        width: 24
                        height: 24
                        radius: 6
                        color: termsCheckbox.checked ? "#27D6C5" : "#0F172A"
                        border.color: "#1F2937"
                        border.width: 2

                        property bool checked: false

                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: "assets/check-mark.svg"
                            sourceSize: Qt.size(16, 16)
                            visible: termsCheckbox.checked
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: termsCheckbox.checked = !termsCheckbox.checked
                        }
                    }

                    Column {
                        width: parent.width - 36
                        spacing: 4

                        Text {
                            text: "Я согласен с условиями"
                            font.pixelSize: 13
                            color: "#E5E7EB"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Row {
                            spacing: 4

                            Text {
                                text: "Политики конфиденциальности"
                                font.pixelSize: 12
                                color: "#27D6C5"
                                font.underline: true

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: console.log("Open a policy")
                                }
                            }

                            Text {
                                text: "и"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                            }

                            Text {
                                text: "Пользовательского соглашения"
                                font.pixelSize: 12
                                color: "#27D6C5"
                                font.underline: true

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: console.log("Open an agreement")
                                }
                            }
                        }
                    }
                }

                // Отступ
                Item { width: 1; height: 8 }

                // Кнопка регистрации
                Rectangle {
                    id: registerButton
                    width: parent.width
                    height: 54
                    radius: 16

                    property bool isFormValid: {
                        var firstNameValid = firstNameInput.text.length >= 2;
                        var lastNameValid = lastNameInput.text.length >= 2;
                        var birthDateValid = birthDateInput.text.length === 10;
                        var passportSeriesValid = passportSeriesInput.text.length === 4;
                        var passportNumberValid = passportNumberInput.text.length === 6;
                        var emailValid = emailInput.text.length > 0 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailInput.text);
                        var phoneValid = phoneInput.text.length >= 10;
                        var passwordValid = passwordInput.text.length >= 8;
                        var passwordMatch = confirmPasswordInput.text === passwordInput.text && confirmPasswordInput.text.length > 0;
                        var termsAccepted = termsCheckbox.checked;

                        return firstNameValid && lastNameValid && birthDateValid && 
                               passportSeriesValid && passportNumberValid &&
                               emailValid && phoneValid && passwordValid && passwordMatch && termsAccepted;
                    }

                    color: isFormValid ? "#27D6C5" : "#1F2937"

                    Text {
                        anchors.centerIn: parent
                        text: "Зарегистрироваться"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: manropeFont.name
                        color: registerButton.isFormValid ? "#050B1A" : "#6B7280"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: registerButton.isFormValid
                        onClicked: {
                            console.log("User registration...")
                            
                            // Преобразуем дату в формат YYYY-MM-DD
                            var dateParts = birthDateInput.text.split('.');
                            var birthDate = dateParts[2] + '-' + dateParts[1] + '-' + dateParts[0];
                            
                            // Вызываем C++ метод с новыми параметрами
                            var success = authController.registerUser(
                                firstNameInput.text,
                                lastNameInput.text,
                                middleNameInput.text,
                                birthDate,
                                passportSeriesInput.text,
                                passportNumberInput.text,
                                emailInput.text,
                                phoneInput.text,
                                passwordInput.text
                            )
                            
                            if (success) {
                                // Очищаем поля
                                firstNameInput.text = ""
                                lastNameInput.text = ""
                                middleNameInput.text = ""
                                birthDateInput.text = ""
                                passportSeriesInput.text = ""
                                passportNumberInput.text = ""
                                emailInput.text = ""
                                phoneInput.text = ""
                                passwordInput.text = ""
                                confirmPasswordInput.text = ""
                                termsCheckbox.checked = false
                                
                                // Переходим на главную
                                registerPage.registerSuccess()
                            }
                        }
                    }
                }

                // Уже есть аккаунт
                Row {
                    width: parent.width
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Уже есть аккаунт?"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }

                    Text {
                        text: "Войти"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#27D6C5"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: registerPage.backToLogin()
                        }
                    }
                }
            }

            // Отступ снизу
            Item { width: 1; height: 40 }
        }
    }

    // Обработчики сигналов от C++
    Connections {
        target: authController
        
        function onRegistrationSuccess() {
            console.log("✓ Registration is successful!")
        }
        
        function onRegistrationFailed(error) {
            console.log("✗ Registration error:", error)
            // TODO: Показать всплывающее уведомление с ошибкой
        }
    }
}