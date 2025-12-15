import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: createCardPage
    anchors.fill: parent
    
    signal backToMain()              // Возврат на главную
    signal cardCreatedSuccess()      // Карта успешно создана
    
    // Свойства для хранения выбранных данных
    property string selectedCardType: ""
    property string selectedCardBrand: ""
    property int currentStep: 1
    property var createdCardData: ({})
    
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
            
            Row {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                
                // Кнопка "Назад" (только на шаге 1)
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: "#1F2937"
                    visible: currentStep === 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: 24
                        color: "#F7F7FB"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: backToMain()
                    }
                }
                
                Column {
                    width: parent.width - (currentStep === 1 ? 60 : 0)
                    spacing: 4
                    
                    Text {
                        text: "Выпуск карты"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                    }
                    
                    Text {
                        text: currentStep === 1 ? "Выбор типа карты" :
                              currentStep === 2 ? "Платёжная система" :
                              currentStep === 3 ? "Подтверждение" :
                              "Карта создана!"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: manropeFont.name
                        color: "#F7F7FB"
                    }
                }
            }
            
            // ШАГ 1: Выбор типа карты
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: currentStep === 1
                
                Text {
                    width: parent.width
                    text: "Выберите тип карты, которую хотите открыть"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                }
                
                // Дебетовая карта
                Rectangle {
                    width: parent.width
                    height: 140
                    radius: 16
                    color: selectedCardType === "debit" ? "#1E40AF" : "#1F2937"
                    border.color: selectedCardType === "debit" ? "#3B82F6" : "#374151"
                    border.width: 2
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        
                        Text {
                            text: "💳"
                            font.pixelSize: 48
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: "Дебетовая карта"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#F7F7FB"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: "Плата за обслуживание: 99 ₽"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: selectedCardType = "debit"
                    }
                }
                
                // Кредитная карта
                Rectangle {
                    width: parent.width
                    height: 140
                    radius: 16
                    color: selectedCardType === "credit" ? "#7C3AED" : "#1F2937"
                    border.color: selectedCardType === "credit" ? "#A78BFA" : "#374151"
                    border.width: 2
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        
                        Text {
                            text: "💎"
                            font.pixelSize: 48
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: "Кредитная карта"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#F7F7FB"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: "Начальный кредитный лимит: 20 000 ₽"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: selectedCardType = "credit"
                    }
                }
                
                // Кнопка "Далее"
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: selectedCardType !== "" ? "#27D6C5" : "#374151"
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Далее"
                        font.pixelSize: 16
                        font.bold: true
                        color: selectedCardType !== "" ? "#050B1A" : "#6B7280"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        enabled: selectedCardType !== ""
                        onClicked: currentStep = 2
                    }
                }
            }
            
            // ШАГ 2: Выбор платёжной системы
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12 // Чуть плотнее, чтобы все влезало
                visible: currentStep === 2

                Text {
                    width: parent.width
                    text: "Выберите платёжную систему"
                    font.pixelSize: 14
                    color: "#9CA3AF" // gray-400
                    bottomPadding: 4
                }

                // Repeater генерирует карточки по модели данных
                Repeater {
                    model: [
                        {
                            brand: "visa",
                            title: "Visa",
                            desc: "Принимается по всему миру",
                            image: "assets/visa.png",
                            color: "#3B82F6" // Blue-500
                        },
                        {
                            brand: "mastercard",
                            title: "Mastercard",
                            desc: "Надёжность и безопасность",
                            image: "assets/mastercard.png",
                            color: "#EF4444" // Red-500
                        },
                        {
                            brand: "mir",
                            title: "МИР",
                            desc: "Российская платёжная система",
                            image: "assets/mir.png",
                            color: "#10B981" // Emerald-500
                        }
                    ]

                    delegate: Rectangle {
                        id: cardItem
                        width: parent.width
                        height: 88
                        radius: 16
            
                        property bool isSelected: selectedCardBrand === modelData.brand
                        property bool isPressed: ma.pressed
                        property color accentColor: modelData.color

                        color: "#1F2937"
                        border.width: isSelected ? 2 : 1
                        border.color: isSelected ? accentColor : "#374151"
            
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Эффект нажатия
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: accentColor
                            opacity: isPressed ? 0.15 : 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        // --- ИЗМЕНЕНИЯ ЗДЕСЬ ---
            
                        // Левая акцентная полоска
                        Rectangle {
                            width: 4
                            height: 32
                            radius: 2
                            color: accentColor
                            visible: isSelected
                
                            // Ставим полоску чуть левее, чтобы был баланс
                            anchors.left: parent.left
                            anchors.leftMargin: 12 
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Контент карточки
                        Item {
                            anchors.fill: parent
                            // Увеличили отступ слева с 16 до 26.
                            // Теперь между полоской (x=16) и контентом (x=26) есть gap 10px.
                            anchors.leftMargin: 26 
                            anchors.rightMargin: 16

                            // 1. Подложка под логотип
                            Rectangle {
                                id: logoPlate
                                width: 64; height: 44
                                radius: 12
                                color: "#111827"
                                border.color: "#374151"
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left

                                Image {
                                    anchors.centerIn: parent
                                    width: 48; height: 32
                                    source: modelData.image
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    smooth: true
                                }
                            }

                            // 2. Тексты
                            Column {
                                anchors.left: logoPlate.right
                                anchors.leftMargin: 16
                                anchors.right: checkIndicator.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#F3F4F6"
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.desc
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                    elide: Text.ElideRight
                                }
                            }

                            // 3. Круглый индикатор
                            Rectangle {
                                id: checkIndicator
                                width: 20; height: 20
                                radius: 10
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                    
                                color: isSelected ? accentColor : "transparent"
                                border.width: isSelected ? 0 : 2
                                border.color: isSelected ? accentColor : "#4B5563"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 12
                                    color: "white"
                                    visible: isSelected
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            onClicked: selectedCardBrand = modelData.brand
                        }
                    }
                }

                // Разделитель (spacer)
                Item { width: 1; height: 8 }

                // Кнопки навигации
                Row {
                    width: parent.width
                    spacing: 12

                    // Кнопка Назад
                    Rectangle {
                        id: backBtn
                        width: (parent.width - 12) / 2
                        height: 54
                        radius: 16
                        color: maBack.pressed ? "#4B5563" : "#374151" // gray-600 : gray-700
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Назад"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#F3F4F6"
                        }

                        MouseArea {
                            id: maBack
                            anchors.fill: parent
                            onClicked: currentStep = 1
                        }
                    }

                    // Кнопка Далее
                    Rectangle {
                        id: nextBtn
                        width: (parent.width - 12) / 2
                        height: 54
                        radius: 16
                        // Основной цвет кнопки (Teal или серый)
                        color: selectedCardBrand !== "" 
                               ? (maNext.pressed ? "#14B8A6" : "#2DD4BF") // Нажатие : Обычный (Teal-400)
                               : "#1F2937" // Неактивный

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Далее"
                            font.pixelSize: 16
                            font.bold: true
                            color: selectedCardBrand !== "" ? "#0F172A" : "#6B7280"
                        }

                        MouseArea {
                            id: maNext
                            anchors.fill: parent
                            enabled: selectedCardBrand !== ""
                            onClicked: currentStep = 3
                        }
                    }
                }
            }


            // ШАГ 3: Подтверждение
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: currentStep === 3
                
                Text {
                    width: parent.width
                    text: "Подтвердите создание карты"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                }
                
                // Preview карты
                Rectangle {
                    width: parent.width
                    height: 200
                    radius: 20
                    
                    gradient: Gradient {
                        GradientStop { 
                            position: 0.0
                            color: selectedCardBrand === "visa" ? "#1E3A8A" : 
                                   selectedCardBrand === "mastercard" ? "#7C3AED" : "#059669"
                        }
                        GradientStop { 
                            position: 1.0
                            color: selectedCardBrand === "visa" ? "#3B82F6" : 
                                   selectedCardBrand === "mastercard" ? "#A78BFA" : "#10B981"
                        }
                    }
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12
                        
                        Text {
                            text: selectedCardBrand.toUpperCase()
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FFFFFF"
                            opacity: 0.8
                        }
                        
                        Item { width: 1; height: 40 }
                        
                        Text {
                            text: "•••• •••• •••• ••••"
                            font.pixelSize: 20
                            font.family: "Courier"
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        
                        Row {
                            width: parent.width
                            spacing: 8
                            
                            Text {
                                text: userSession.shortName.toUpperCase()
                                font.pixelSize: 12
                                color: "#FFFFFF"
                                opacity: 0.8
                            }
                            
                            Item { 
                                width: parent.width - parent.children[0].width - parent.children[2].width - 16
                                height: 1 
                            }
                            
                            Text {
                                text: {
                                    var futureDate = new Date();
                                    futureDate.setFullYear(futureDate.getFullYear() + 5);
                                    return Qt.formatDate(futureDate, "MM/yy");
                                }
                                font.pixelSize: 12
                                color: "#FFFFFF"
                                opacity: 0.8
                            }
                        }
                    }
                }
                
                // Информация
                Column {
                    width: parent.width
                    spacing: 12
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "Тип карты:"
                            font.pixelSize: 14
                            color: "#9CA3AF"
                        }
                        
                        Item { 
                            width: parent.width - parent.children[0].width - parent.children[2].width - 16
                            height: 1 
                        }
                        
                        Text {
                            text: selectedCardType === "debit" ? "Дебетовая" : "Кредитная"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                        }
                    }
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "Платёжная система:"
                            font.pixelSize: 14
                            color: "#9CA3AF"
                        }
                        
                        Item { 
                            width: parent.width - parent.children[0].width - parent.children[2].width - 16
                            height: 1 
                        }
                        
                        Text {
                            text: selectedCardBrand === "visa" ? "Visa" :
                                  selectedCardBrand === "mastercard" ? "MasterCard" : "МИР"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                        }
                    }
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "Срок действия:"
                            font.pixelSize: 14
                            color: "#9CA3AF"
                        }
                        
                        Item { 
                            width: parent.width - parent.children[0].width - parent.children[2].width - 16
                            height: 1 
                        }
                        
                        Text {
                            text: "5 лет"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#F7F7FB"
                        }
                    }
                }
                
                // Кнопки
                Row {
                    width: parent.width
                    spacing: 12
                    
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 54
                        radius: 16
                        color: "#374151"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Назад"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#F7F7FB"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: currentStep = 2
                        }
                    }
                    
                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 54
                        radius: 16
                        color: "#27D6C5"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Создать"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#050B1A"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                cardController.createCard(selectedCardType, selectedCardBrand)
                            }
                        }
                    }
                }
            }
            
            // ШАГ 4: Карта создана
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: currentStep === 4
                
                Text {
                    width: parent.width
                    text: "🎉 Поздравляем! Ваша карта успешно создана"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#10B981"
                    wrapMode: Text.WordWrap
                }
                
                // Данные карты
                Column {
                    width: parent.width
                    spacing: 12
                    
                    // Номер карты
                    Rectangle {
                        width: parent.width
                        height: 70
                        radius: 12
                        color: "#1F2937"
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            
                            Text {
                                text: "Номер карты"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                            }
                            
                            Row {
                                width: parent.width
                                spacing: 8
                                
                                Text {
                                    text: createdCardData.cardNumber || "****"
                                    font.pixelSize: 16
                                    font.family: "Courier"
                                    font.bold: true
                                    color: "#F7F7FB"
                                }
                                
                                Item { 
                                    width: parent.width - parent.children[0].width - parent.children[2].width - 16
                                    height: 1 
                                }
                                
                                Text {
                                    text: "📋"
                                    font.pixelSize: 18
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: console.log("Скопировать номер:", createdCardData.cardNumber)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Держатель
                    Rectangle {
                        width: parent.width
                        height: 70
                        radius: 12
                        color: "#1F2937"
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            
                            Text {
                                text: "Держатель карты"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                            }
                            
                            Text {
                                text: createdCardData.cardHolder || ""
                                font.pixelSize: 16
                                font.bold: true
                                color: "#F7F7FB"
                            }
                        }
                    }
                    
                    // Срок действия и CVC
                    Row {
                        width: parent.width
                        spacing: 12
                        
                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 70
                            radius: 12
                            color: "#1F2937"
                            
                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
                                
                                Text {
                                    text: "Срок действия"
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                }
                                
                                Text {
                                    text: createdCardData.expiryDate || ""
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#F7F7FB"
                                }
                            }
                        }
                        
                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 70
                            radius: 12
                            color: "#1F2937"
                            
                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
                                
                                Text {
                                    text: "CVC-код"
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                }
                                
                                Row {
                                    spacing: 8
                                    
                                    Text {
                                        text: createdCardData.cvc || "***"
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.family: "Courier"
                                        color: "#F7F7FB"
                                    }
                                    
                                    Text {
                                        text: "📋"
                                        font.pixelSize: 16
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: console.log("Скопировать CVC:", createdCardData.cvc)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // PIN-код
                    Rectangle {
                        width: parent.width
                        height: 80
                        radius: 12
                        color: "#7C3AED"
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            
                            Text {
                                text: "PIN-код (сохраните в безопасном месте!)"
                                font.pixelSize: 12
                                color: "#E9D5FF"
                                font.bold: true
                            }
                            
                            Row {
                                spacing: 12
                                
                                Text {
                                    text: createdCardData.pin || "****"
                                    font.pixelSize: 24
                                    font.bold: true
                                    font.family: "Courier"
                                    color: "#FFFFFF"
                                }
                                
                                Text {
                                    text: "📋"
                                    font.pixelSize: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: console.log("Скопировать PIN:", createdCardData.pin)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Предупреждение
                Rectangle {
                    width: parent.width
                    height: 90
                    radius: 12
                    color: "#7F1D1D"
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        
                        Text {
                            text: "⚠️"
                            font.pixelSize: 32
                            anchors.top: parent.top
                        }
                        
                        Text {
                            width: parent.width - 50
                            text: "Никому не сообщайте PIN-код и CVC! Запишите их в надёжном месте. После возврата на главную вы не сможете снова посмотреть PIN-код."
                            font.pixelSize: 12
                            color: "#FCA5A5"
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                
                // Кнопка "Готово"
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 16
                    color: "#27D6C5"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Вернуться на главную"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#050B1A"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // ============ ИЗМЕНЕНО: Возврат через сигнал ============
                            cardCreatedSuccess()
                            // Сброс состояния
                            currentStep = 1
                            selectedCardType = ""
                            selectedCardBrand = ""
                            createdCardData = {}
                            // =======================================================
                        }
                    }
                }
            }
            
            // Отступ снизу
            Item { width: 1; height: 20 }
        }
    }
    
    // Обработчики сигналов
    Connections {
        target: cardController
        
        function onCardCreated(cardData) {
            console.log("✓ Карта создана:", JSON.stringify(cardData))
            createdCardData = cardData
            currentStep = 4
        }
        
        function onCardCreationFailed(error) {
            console.error("✗ Ошибка создания карты:", error)
        }
        
        function onCreationProgress(message) {
            console.log("⏳", message)
        }
    }
}
