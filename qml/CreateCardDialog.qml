import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root

    // ── Сигналы ──
    signal backToMain()
    signal cardCreatedSuccess()

    // ── Состояние мастера ──
    property int    step: 1            // 1‑4
    property string cardType: ""       // "debit" | "credit"
    property string paySystem: ""      // "visa" | "mastercard" | "mir"
    property var    cardResult: ({})    // данные созданной карты

    // ── Вычисляемые вспомогательные свойства ──
    readonly property string cardTypeLabel:
        cardType === "debit" ? "Дебетовая" : "Кредитная"

    readonly property string paySystemLabel:
        paySystem === "visa"       ? "Visa" :
        paySystem === "mastercard" ? "Mastercard" : "МИР"

    readonly property string expiryPreview: {
        var d = new Date();
        d.setFullYear(d.getFullYear() + 5);
        var mm = ("0" + (d.getMonth() + 1)).slice(-2);
        var yy = String(d.getFullYear()).slice(-2);
        return mm + "/" + yy;
    }

    readonly property string stepTitle:
        step === 1 ? "Выберите тип карты" :
        step === 2 ? "Платёжная система" :
        step === 3 ? "Подтверждение"      :
                     "Карта создана!"

    // ── Цвета платёжных систем ──
    function brandAccent(brand) {
        if (brand === "visa")       return "#3B82F6";
        if (brand === "mastercard") return "#EF4444";
        if (brand === "mir")        return "#10B981";
        return "#6B7280";
    }

    function brandGradientStart(brand) {
        if (brand === "visa")       return "#1E3A8A";
        if (brand === "mastercard") return "#991B1B";
        if (brand === "mir")        return "#065F46";
        return "#1F2937";
    }

    function brandGradientEnd(brand) {
        if (brand === "visa")       return "#60A5FA";
        if (brand === "mastercard") return "#F87171";
        if (brand === "mir")        return "#34D399";
        return "#374151";
    }

    // ── Фон ──
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0B1120" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    // ══════════════════════════════════════════
    //  Прокручиваемая область
    // ══════════════════════════════════════════
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: mainLayout.height + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainLayout
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Item { Layout.preferredHeight: 16 }  // верхний отступ

            // ── Заголовок + кнопка назад ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Круглая кнопка «←» — только на 1‑м шаге
                Rectangle {
                    width: 42; height: 42; radius: 21
                    color: backBtnArea.pressed ? "#374151" : "#1F2937"
                    visible: step === 1

                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(22, 22)
                    }

                    MouseArea {
                        id: backBtnArea
                        anchors.fill: parent
                        onClicked: root.backToMain()
                    }
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "Новая карта"
                        font.pixelSize: 13
                        color: "#6B7280"
                    }

                    Text {
                        text: root.stepTitle
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: "#F9FAFB"
                    }
                }
            }

            // ── Индикатор шагов ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: 4
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 2
                        color: (index + 1) <= root.step ? "#2DD4BF" : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }

            // ══════════════════════════════════════
            //  ШАГ 1 — Тип карты
            // ══════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: step === 1

                Text {
                    Layout.fillWidth: true
                    text: "Выберите тип карты, которую хотите открыть"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                }

                // — Дебетовая —
                Rectangle {
                    id: debitCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: 18

                    property bool hovered: debitHover.hovered
                    property bool selected: root.cardType === "debit"

                    color: selected ? "#172554"
                         : hovered  ? "#1E293B"
                                    : "#111827"
                    border.width: selected ? 2 : 1
                    border.color: selected ? "#3B82F6"
                               : hovered  ? "#2563EB"
                                          : "#1F2937"

                    Behavior on color        { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    // Свечение при hover
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: "#3B82F6"
                        opacity: debitCard.hovered && !debitCard.selected ? 0.06 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "💳"
                            font.pixelSize: 40
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Дебетовая карта"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: "#F3F4F6"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Обслуживание 99 ₽ / мес."
                            font.pixelSize: 12
                            color: debitCard.selected ? "#93C5FD" : "#6B7280"
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    HoverHandler { id: debitHover }
                    TapHandler   { onTapped: root.cardType = "debit" }
                }

                // — Кредитная —
                Rectangle {
                    id: creditCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: 18

                    property bool hovered: creditHover.hovered
                    property bool selected: root.cardType === "credit"

                    color: selected ? "#3B0764"
                         : hovered  ? "#1E1B2E"
                                    : "#111827"
                    border.width: selected ? 2 : 1
                    border.color: selected ? "#A78BFA"
                               : hovered  ? "#7C3AED"
                                          : "#1F2937"

                    Behavior on color        { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    // Свечение при hover
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: "#A78BFA"
                        opacity: creditCard.hovered && !creditCard.selected ? 0.06 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "💎"
                            font.pixelSize: 40
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Кредитная карта"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: "#F3F4F6"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Лимит 20 000 ₽"
                            font.pixelSize: 12
                            color: creditCard.selected ? "#C4B5FD" : "#6B7280"
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    HoverHandler { id: creditHover }
                    TapHandler   { onTapped: root.cardType = "credit" }
                }

                // Кнопка «Далее»
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 14
                    color: root.cardType !== ""
                           ? (step1NextArea.pressed ? "#14B8A6" : "#2DD4BF")
                           : "#1F2937"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Далее"
                        font.pixelSize: 15; font.weight: Font.Bold
                        color: root.cardType !== "" ? "#042F2E" : "#4B5563"
                    }

                    MouseArea {
                        id: step1NextArea
                        anchors.fill: parent
                        enabled: root.cardType !== ""
                        onClicked: root.step = 2
                    }
                }
            }

            // ══════════════════════════════════════
            //  ШАГ 2 — Платёжная система
            // ══════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: step === 2

                Text {
                    Layout.fillWidth: true
                    text: "Выберите платёжную систему для карты"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                    Layout.bottomMargin: 4
                }

                // Модель данных
                ListModel {
                    id: brandsModel
                    ListElement { key: "visa";       label: "Visa";       desc: "Принимается по всему миру";       accent: "#3B82F6"; icon: "assets/visa.png" }
                    ListElement { key: "mastercard"; label: "Mastercard"; desc: "Надёжность и безопасность";        accent: "#EF4444"; icon: "assets/mastercard.png" }
                    ListElement { key: "mir";        label: "МИР";       desc: "Российская платёжная система";     accent: "#10B981"; icon: "assets/mir.png" }
                }

                Repeater {
                    model: brandsModel

                    delegate: Rectangle {
                        id: brandDelegate
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        radius: 16

                        required property int    index
                        required property string key
                        required property string label
                        required property string desc
                        required property string accent
                        required property string icon

                        property bool isCurrent: root.paySystem === key
                        property bool isHovered: brandHover.hovered

                        color: "#111827"
                        border.width: isCurrent ? 2 : 1
                        border.color: isCurrent ? accent
                                    : isHovered ? Qt.darker(accent, 1.4)
                                                : "#1F2937"

                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        // Подсвечивающий оверлей
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: brandDelegate.accent
                            opacity: brandDelegate.isCurrent ? 0.08
                                   : brandDelegate.isHovered ? 0.04 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16; anchors.rightMargin: 16
                            spacing: 14

                            // Логотип
                            Rectangle {
                                width: 56; height: 40; radius: 10
                                color: "#0B1120"
                                border.color: "#1F2937"; border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: 42; height: 28
                                    source: brandDelegate.icon
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true; smooth: true
                                }
                            }

                            // Тексты
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: brandDelegate.label
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: "#E5E7EB"
                                }
                                Text {
                                    text: brandDelegate.desc
                                    font.pixelSize: 11
                                    color: "#6B7280"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Радио-кнопка
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.width: 2
                                border.color: brandDelegate.isCurrent ? brandDelegate.accent : "#374151"

                                Behavior on border.color { ColorAnimation { duration: 160 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: brandDelegate.accent
                                    scale: brandDelegate.isCurrent ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        HoverHandler { id: brandHover }
                        TapHandler   { onTapped: root.paySystem = brandDelegate.key }
                    }
                }

                Item { Layout.preferredHeight: 6 }

                // Навигация
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: step2BackArea.pressed ? "#374151" : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { anchors.centerIn: parent; text: "Назад"; font.pixelSize: 15; font.weight: Font.Bold; color: "#D1D5DB" }
                        MouseArea { id: step2BackArea; anchors.fill: parent; onClicked: root.step = 1 }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: root.paySystem !== ""
                               ? (step2NextArea.pressed ? "#14B8A6" : "#2DD4BF")
                               : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent; text: "Далее"
                            font.pixelSize: 15; font.weight: Font.Bold
                            color: root.paySystem !== "" ? "#042F2E" : "#4B5563"
                        }
                        MouseArea { id: step2NextArea; anchors.fill: parent; enabled: root.paySystem !== ""; onClicked: root.step = 3 }
                    }
                }
            }

            // ══════════════════════════════════════
            //  ШАГ 3 — Подтверждение
            // ══════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: step === 3

                Text {
                    text: "Проверьте данные и подтвердите выпуск"
                    font.pixelSize: 14; color: "#9CA3AF"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }

                // ── Превью банковской карты ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    radius: 20
                    clip: true

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: brandGradientStart(root.paySystem) }
                        GradientStop { position: 1.0; color: brandGradientEnd(root.paySystem) }
                    }

                    // Декоративные круги
                    Rectangle {
                        x: parent.width - 80; y: -30
                        width: 160; height: 160; radius: 80
                        color: "#FFFFFF"; opacity: 0.04
                    }
                    Rectangle {
                        x: parent.width - 130; y: 80
                        width: 120; height: 120; radius: 60
                        color: "#FFFFFF"; opacity: 0.03
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 0

                        // Платёжная система — верхний левый угол
                        Text {
                            text: root.paySystemLabel
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            opacity: 0.85
                        }

                        Item { Layout.fillHeight: true }

                        // Номер карты (скрытый)
                        Text {
                            text: "••••    ••••    ••••    ••••"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            font.letterSpacing: 2
                            color: "#FFFFFF"
                        }

                        Item { Layout.preferredHeight: 14 }

                        // Нижняя строка: имя + срок
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2
                                Text { text: "ДЕРЖАТЕЛЬ"; font.pixelSize: 9; color: "#FFFFFF"; opacity: 0.5 }
                                Text {
                                    text: typeof userSession !== "undefined"
                                          ? userSession.shortName.toUpperCase()
                                          : "IVANOV A."
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"; opacity: 0.9
                                }
                            }

                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignRight
                                Text { text: "VALID THRU"; font.pixelSize: 9; color: "#FFFFFF"; opacity: 0.5; Layout.alignment: Qt.AlignRight }
                                Text {
                                    text: root.expiryPreview
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"; opacity: 0.9
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }

                // ── Сводка (текстом) ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: infoCol.height + 28
                    radius: 14; color: "#111827"
                    border.color: "#1F2937"; border.width: 1

                    ColumnLayout {
                        id: infoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                        spacing: 12

                        // Строка‑разделитель: повторяемый компонент
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Тип карты";        font.pixelSize: 13; color: "#6B7280" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.cardTypeLabel;  font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#1F2937" }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Платёжная система"; font.pixelSize: 13; color: "#6B7280" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.paySystemLabel; font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#1F2937" }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Срок действия";     font.pixelSize: 13; color: "#6B7280" }
                            Item { Layout.fillWidth: true }
                            Text { text: "5 лет (" + root.expiryPreview + ")"; font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#1F2937" }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Обслуживание";      font.pixelSize: 13; color: "#6B7280" }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.cardType === "debit" ? "99 ₽ / мес." : "0 ₽"
                                font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB"
                            }
                        }
                    }
                }

                // ── Навигация ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: step3BackArea.pressed ? "#374151" : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { anchors.centerIn: parent; text: "Назад"; font.pixelSize: 15; font.weight: Font.Bold; color: "#D1D5DB" }
                        MouseArea { id: step3BackArea; anchors.fill: parent; onClicked: root.step = 2 }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: step3CreateArea.pressed ? "#14B8A6" : "#2DD4BF"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { anchors.centerIn: parent; text: "Создать карту"; font.pixelSize: 15; font.weight: Font.Bold; color: "#042F2E" }
                        MouseArea {
                            id: step3CreateArea
                            anchors.fill: parent
                            onClicked: {
                                cardController.createCard(root.cardType, root.paySystem)
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════
            //  ШАГ 4 — Успешное создание
            // ══════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: step === 4

                // Заголовок
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52; radius: 14
                    color: "#052E16"
                    border.color: "#166534"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "🎉  Карта успешно выпущена!"
                        font.pixelSize: 15; font.weight: Font.Bold
                        color: "#4ADE80"
                    }
                }

                // ── Блок данных ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Номер карты
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68; radius: 12; color: "#111827"
                        border.color: "#1F2937"; border.width: 1

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "Номер карты"; font.pixelSize: 11; color: "#6B7280" }
                            RowLayout {
                                Text {
                                    text: root.cardResult.cardNumber || "•••• •••• •••• ••••"
                                    font.pixelSize: 17; font.weight: Font.Bold
                                    color: "#F3F4F6"
                                }
                                Item { Layout.fillWidth: true }
                                Image {
                                    width: 18; height: 18
                                    source: "assets/copy.svg"
                                    sourceSize: Qt.size(18, 18)
                                    TapHandler { onTapped: console.log("Copy number:", root.cardResult.cardNumber) }
                                }
                            }
                        }
                    }

                    // Держатель
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68; radius: 12; color: "#111827"
                        border.color: "#1F2937"; border.width: 1

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "Держатель карты"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: root.cardResult.cardHolder || ""
                                font.pixelSize: 15; font.weight: Font.Bold; color: "#F3F4F6"
                            }
                        }
                    }

                    // Срок действия + CVC
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 68; radius: 12; color: "#111827"
                            border.color: "#1F2937"; border.width: 1

                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 4
                                Text { text: "Срок действия"; font.pixelSize: 11; color: "#6B7280" }
                                Text {
                                    text: root.cardResult.expiryDate || ""
                                    font.pixelSize: 15; font.weight: Font.Bold; color: "#F3F4F6"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 68; radius: 12; color: "#111827"
                            border.color: "#1F2937"; border.width: 1

                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 4
                                Text { text: "CVC-код"; font.pixelSize: 11; color: "#6B7280" }
                                RowLayout {
                                    Text {
                                        text: root.cardResult.cvc || "***"
                                        font.pixelSize: 17; font.weight: Font.Bold; color: "#F3F4F6"
                                    }
                                    
                                    Image {
                                        width: 18; height: 18
                                        source: "assets/copy.svg"
                                        sourceSize: Qt.size(18, 18)
                                        TapHandler { onTapped: console.log("Copy CVC:", root.cardResult.cvc) }
                                    }
                                }
                            }
                        }
                    }

                    // PIN-код (акцентный блок)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76; radius: 12
                        color: "#4C1D95"
                        border.color: "#7C3AED"; border.width: 1

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "PIN-код  (запишите в надёжном месте!)"; font.pixelSize: 11; font.weight: Font.Bold; color: "#DDD6FE" }
                            RowLayout {
                                Text {
                                    text: root.cardResult.pin || "****"
                                    font.pixelSize: 22; font.weight: Font.Bold; color: "#FFFFFF"
                                }
                               
                                Image {
                                    width: 18; height: 18
                                    source: "assets/copy.svg"
                                    sourceSize: Qt.size(18, 18)
                                    TapHandler { onTapped: console.log("Copy number:", root.cardResult.pin) }
                                }
                            }
                        }
                    }
                }

                // Предупреждение
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: warningRow.height + 24
                    radius: 12; color: "#450A0A"
                    border.color: "#7F1D1D"; border.width: 1

                    RowLayout {
                        id: warningRow
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 10

                        //Text { text: "⚠️"; font.pixelSize: 28 }

                        Image {
                            width: 28; height: 28
                            source: "assets/warning.svg"
                            sourceSize: Qt.size(28, 28)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Никому не сообщайте PIN-код и CVC-код карты. После закрытия этого экрана PIN-код будет недоступен."
                            font.pixelSize: 12; color: "#FCA5A5"
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Кнопка «Готово»
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52; radius: 14
                    color: doneArea.pressed ? "#14B8A6" : "#2DD4BF"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text { anchors.centerIn: parent; text: "На главную"; font.pixelSize: 15; font.weight: Font.Bold; color: "#042F2E" }

                    MouseArea {
                        id: doneArea
                        anchors.fill: parent
                        onClicked: {
                            root.cardCreatedSuccess()
                            // Сброс
                            root.step       = 1
                            root.cardType   = ""
                            root.paySystem  = ""
                            root.cardResult = {}
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }  // нижний отступ
        }
    }

    // ══════════════════════════════════════════
    //  Связь с контроллером
    // ══════════════════════════════════════════
    Connections {
        target: cardController

        function onCardCreated(cardData) {
            console.log("✓ Карта создана:", JSON.stringify(cardData))
            root.cardResult = cardData
            root.step = 4
        }

        function onCardCreationFailed(error) {
            console.error("✗ Ошибка:", error)
        }

        function onCreationProgress(message) {
            console.log("⏳", message)
        }
    }
}
