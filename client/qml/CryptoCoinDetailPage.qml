import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

/*
    CryptoCoinDetailPage — страница деталей одной монеты.

    Открывается из CryptoMainPage по тапу на карточку монеты.
    Принимает на входе свойство `currency` (минимально нужны id, symbol, name,
    icon_color, icon_letter, current_price). Все остальные данные тянет с
    сервера одним запросом cryptoController.startCoinDetail(id), который
    возвращает:
        - currency       (полная карточка из БД)
        - wallet         (баланс пользователя по этой монете + RUB-эквивалент)
        - stats24h       (цена сутки назад, абсолютная и процентная дельта)
        - portfolio      (вложено / получено / профит / 24ч-дельта по портфелю)
        - history        (последние ~50 операций по этой монете)
        - priceHistory   (~150 точек за последние 24 часа для графика)

    Пока страница открыта, autoRefresh контроллера тянет coinDetail каждые
    несколько секунд → цена и график оживают в реальном времени.
*/
Item {
    id: root

    // Входные данные (минимальная "обложка" монеты — чтобы шапка показывала
    // что-то осмысленное ещё до прихода полного ответа).
    property var currency: ({})

    signal backToMain()
    signal openBuy(var currency)
    signal openSell(var currency, real currentBalance)
    signal openTransfer(var currency, real currentBalance)
    signal openHistory(int currencyId)

    FontLoader { id: manropeFont; source: "assets/fonts/Manrope-Bold.ttf" }

    // --------------------------------------------------------------------
    // Lifecycle: подписываемся на детальный поток для нашей монеты,
    // отписываемся при закрытии страницы. Auto-refresh контроллера
    // в это время будет тянуть данные именно по этой монете.
    // --------------------------------------------------------------------
    Component.onCompleted: {
        if (currency && currency.id)
            cryptoController.startCoinDetail(currency.id)
    }

    Component.onDestruction: {
        cryptoController.stopCoinDetail()
    }

    // Удобные алиасы (обновляются вместе с coinDetail; безопасны при пустом ответе)
    readonly property var detail:    cryptoController.coinDetail
    readonly property var detailCur: detail && detail.currency  ? detail.currency  : currency
    readonly property var wallet:    detail && detail.wallet    ? detail.wallet    : ({})
    readonly property var stats24h:  detail && detail.stats24h  ? detail.stats24h  : ({})
    readonly property var portfolio: detail && detail.portfolio ? detail.portfolio : ({})
    readonly property var historyAll:detail && detail.history   ? detail.history   : []
    readonly property var pricePoints:(detail && detail.priceHistory) ? detail.priceHistory : []

    readonly property bool hasBalance: (wallet.balance !== undefined && Number(wallet.balance) > 0)
    readonly property bool isUp:       (stats24h.is_up === true) || (Number(stats24h.change_abs || 0) >= 0)
    readonly property color trendColor: isUp ? Theme.success : Theme.error

    // ---- Хелперы форматирования ----
    function fmtCoins(n) {
        if (typeof n !== "number") n = Number(n)
        if (!isFinite(n) || n === 0) return "0"
        var s = n.toFixed(8)
        return s.replace(/0+$/, "").replace(/\.$/, "")
    }
    function fmtRub(n) {
        return Number(n || 0).toLocaleString(Qt.locale("ru_RU"), 'f', 2)
    }
    function fmtPriceSmart(n) {
        var v = Number(n || 0)
        if (v >= 100) return v.toLocaleString(Qt.locale("ru_RU"), 'f', 2)
        if (v >= 10)  return v.toLocaleString(Qt.locale("ru_RU"), 'f', 3)
        if (v >= 1)   return v.toLocaleString(Qt.locale("ru_RU"), 'f', 4)
        return v.toLocaleString(Qt.locale("ru_RU"), 'f', 6)
    }
    function fmtTime(ts) {
        var d = new Date(Number(ts))
        var hh = String(d.getHours()).padStart(2, "0")
        var mm = String(d.getMinutes()).padStart(2, "0")
        return hh + ":" + mm
    }

    function opTitle(t) {
        switch (t) {
            case "buy":          return "Пополнение: Доход"
            case "sell":         return "Продажа: Доход"
            case "transfer_in":  return "Перевод: Получен"
            case "transfer_out": return "Перевод: Отправлен"
        }
        return t
    }
    function opColor(t) {
        switch (t) {
            case "buy":          return Theme.success
            case "sell":         return Theme.warning
            case "transfer_in":  return Theme.info
            case "transfer_out": return "#A78BFA"
        }
        return "#9CA3AF"
    }
    function opTintBg(t) {
        var c = opColor(t)
        return Qt.rgba(c.r, c.g, c.b, 0.18)
    }

    // --------------------------------------------------------------------
    //  Шапка
    // --------------------------------------------------------------------
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 60
        color: "transparent"

        Rectangle {
            width: 36; height: 36; radius: 18
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: backMouse.pressed ? "#374151" : "#1F2937"
            Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 18; font.bold: true; color: "#E5E7EB" }
            MouseArea { id: backMouse; anchors.fill: parent; onClicked: root.backToMain() }
        }

        Text {
            anchors.centerIn: parent
            text: detailCur.name || currency.name || "Монета"
            font { pixelSize: 17; bold: true; family: manropeFont.name }
            color: "#FFFFFF"
        }

        GuideButton {
            anchors.right: parent.right
            anchors.rightMargin: 38
            anchors.verticalCenter: parent.verticalCenter
            onClicked: guide.open()
        }

        // Индикатор live-обновления
        Rectangle {
            width: 8; height: 8; radius: 4
            anchors.right: parent.right; anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.success
            opacity: cryptoController.autoRefreshEnabled ? 1.0 : 0.25

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: cryptoController.autoRefreshEnabled
                NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
                NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
            }
        }
    }

    // --------------------------------------------------------------------
    //  Контент
    // --------------------------------------------------------------------
    Flickable {
        id: flick
        anchors {
            top: header.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        contentHeight: mainCol.height + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainCol
            width: parent.width
            spacing: 18
            topPadding: 8
            bottomPadding: 24

            // ============================================================
            //  Карточка с ценой и 24ч-дельтой
            // ============================================================
            Rectangle {
                id: priceCard
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card
                height: priceCol.height + 28

                Column {
                    id: priceCol
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18; rightMargin: 18
                    }
                    spacing: 6

                    // Иконка + название/тикер
                    Row {
                        spacing: 12

                        Rectangle {
                            width: 44; height: 44; radius: 22
                            color: detailCur.icon_color || currency.icon_color || Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: detailCur.icon_letter || currency.icon_letter || "?"
                                font { pixelSize: 20; bold: true; family: manropeFont.name }
                                color: "#FFFFFF"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: detailCur.name || currency.name || ""
                                font { pixelSize: 13; family: manropeFont.name }
                                color: "#9CA3AF"
                            }
                            Text {
                                text: detailCur.symbol || currency.symbol || ""
                                font { pixelSize: 14; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                            }
                        }
                    }

                    Item { width: 1; height: 6 }

                    // Большая цена
                    Text {
                        text: fmtPriceSmart(detailCur.current_price) + " ₽"
                        font { pixelSize: 32; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }

                    // 24ч-дельта (абсолютная и процентная) + плашка "Сегодня"
                    Row {
                        spacing: 10

                        Text {
                            text: (isUp ? "+" : "−")
                                  + fmtPriceSmart(Math.abs(Number(stats24h.change_abs || 0)))
                                  + " ₽"
                            font { pixelSize: 13; bold: true; family: manropeFont.name }
                            color: trendColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            radius: 10
                            height: 22
                            width: pctText.implicitWidth + 16
                            color: Qt.rgba(trendColor.r, trendColor.g, trendColor.b, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: pctText
                                anchors.centerIn: parent
                                text: (isUp ? "↑ " : "↓ ")
                                      + Number(Math.abs(Number(stats24h.change_pct || 0)))
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2)
                                      + "%"
                                font { pixelSize: 12; bold: true; family: manropeFont.name }
                                color: trendColor
                            }
                        }

                        Text {
                            text: "Сегодня"
                            font.pixelSize: 12
                            color: "#9CA3AF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ============================================================
            //  Мини-график за 1 день
            // ============================================================
            Rectangle {
                id: chartBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card
                height: 200

                Item {
                    id: chartHost
                    anchors.fill: parent
                    anchors.margins: 12

                    // Полоска справа под лейблы цены, снизу — под лейблы времени.
                    readonly property real labelsRight: 48
                    readonly property real labelsBottom: 22

                    // Холст с линией графика
                    Canvas {
                        id: chart
                        anchors {
                            left: parent.left; top: parent.top
                            right: parent.right; bottom: parent.bottom
                            rightMargin: chartHost.labelsRight
                            bottomMargin: chartHost.labelsBottom
                        }

                        property var pts: root.pricePoints
                        property real lo: 0
                        property real hi: 0
                        property color stroke: root.trendColor

                        onPtsChanged:    { recompute(); requestPaint() }
                        onStrokeChanged: requestPaint()
                        onWidthChanged:  requestPaint()
                        onHeightChanged: requestPaint()

                        function recompute() {
                            if (!pts || pts.length === 0) { lo = 0; hi = 0; return }
                            var l = Number(pts[0].price), h = l
                            for (var i = 1; i < pts.length; i++) {
                                var p = Number(pts[i].price)
                                if (p < l) l = p
                                if (p > h) h = p
                            }
                            // 10% паддинг сверху и снизу, чтобы линия не утыкалась в края
                            var pad = (h - l) * 0.10
                            if (pad <= 0) pad = (h > 0 ? h * 0.02 : 1)
                            lo = l - pad
                            hi = h + pad
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            if (!pts || pts.length < 2) return

                            var w = width, h = height
                            var t0 = Number(pts[0].ts)
                            var tN = Number(pts[pts.length - 1].ts)
                            var dt = (tN - t0) || 1
                            var dp = (hi - lo) || 1

                            // Координаты всех точек
                            var xs = [], ys = []
                            for (var i = 0; i < pts.length; i++) {
                                xs.push(((Number(pts[i].ts) - t0) / dt) * w)
                                ys.push(h - ((Number(pts[i].price) - lo) / dp) * (h - 4) - 2)
                            }

                            // 1) Заливка под графиком
                            var grad = ctx.createLinearGradient(0, 0, 0, h)
                            grad.addColorStop(0, Qt.rgba(stroke.r, stroke.g, stroke.b, 0.32))
                            grad.addColorStop(1, Qt.rgba(stroke.r, stroke.g, stroke.b, 0.0))
                            ctx.fillStyle = grad
                            ctx.beginPath()
                            ctx.moveTo(xs[0], h)
                            for (var j = 0; j < xs.length; j++) ctx.lineTo(xs[j], ys[j])
                            ctx.lineTo(xs[xs.length - 1], h)
                            ctx.closePath()
                            ctx.fill()

                            // 2) Сама линия
                            ctx.strokeStyle = stroke
                            ctx.lineWidth = 2
                            ctx.lineJoin = "round"
                            ctx.lineCap  = "round"
                            ctx.beginPath()
                            ctx.moveTo(xs[0], ys[0])
                            for (var k = 1; k < xs.length; k++) ctx.lineTo(xs[k], ys[k])
                            ctx.stroke()
                        }
                    }

                    // Лейблы цены справа: max … min (4 равномерных уровня)
                    Repeater {
                        model: 4
                        delegate: Text {
                            required property int index
                            readonly property real frac: index / 3.0
                            readonly property real val: chart.hi - frac * (chart.hi - chart.lo)
                            visible: chart.hi > chart.lo

                            anchors.right: chartHost.right
                            y: chart.y + frac * (chart.height - 12)
                            text: fmtPriceSmart(val)
                            font.pixelSize: 10
                            color: "#9CA3AF"
                        }
                    }

                    // Лейблы времени снизу: 4 равномерных метки
                    Repeater {
                        model: 4
                        delegate: Text {
                            required property int index
                            readonly property real frac: index / 3.0
                            visible: root.pricePoints.length >= 2

                            anchors.bottom: chartHost.bottom
                            x: frac * (chart.width - implicitWidth)
                            text: {
                                if (root.pricePoints.length < 2) return ""
                                var t0 = Number(root.pricePoints[0].ts)
                                var tN = Number(root.pricePoints[root.pricePoints.length - 1].ts)
                                return fmtTime(t0 + frac * (tN - t0))
                            }
                            font.pixelSize: 10
                            color: "#9CA3AF"
                        }
                    }

                    // Заглушка
                    Text {
                        anchors.centerIn: chart
                        visible: root.pricePoints.length < 2
                        text: cryptoController.isLoading ? "Загружаем график…"
                                                         : "Данных за сутки пока нет"
                        color: "#6B7280"
                        font.pixelSize: 12
                    }
                }
            }

            // ============================================================
            //  Блок "Ваш портфель" (только если у юзера есть монета)
            // ============================================================
            Rectangle {
                visible: hasBalance
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card
                height: portfolioCol.height + 28

                Column {
                    id: portfolioCol
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18; rightMargin: 18
                    }
                    spacing: 8

                    Text {
                        text: "Ваш портфель"
                        font { pixelSize: 13; bold: true; family: manropeFont.name }
                        color: Theme.accentLight
                    }

                    Text {
                        text: fmtRub(portfolio.current_value) + " ₽"
                        font { pixelSize: 24; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }

                    // 24ч-дельта по портфелю
                    Row {
                        spacing: 10
                        Text {
                            text: (Number(portfolio.change_24h_abs) >= 0 ? "+" : "−")
                                  + fmtRub(Math.abs(Number(portfolio.change_24h_abs || 0))) + " ₽"
                            font { pixelSize: 12; bold: true; family: manropeFont.name }
                            color: Number(portfolio.change_24h_abs) >= 0 ? Theme.success : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (Number(portfolio.change_24h_pct) >= 0 ? "↑ " : "↓ ")
                                  + Number(Math.abs(Number(portfolio.change_24h_pct || 0)))
                                        .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + "%"
                            font { pixelSize: 11; bold: true; family: manropeFont.name }
                            color: Number(portfolio.change_24h_pct) >= 0 ? Theme.success : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "24 ч"
                            font.pixelSize: 11
                            color: "#9CA3AF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Разделитель
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#1F2937"
                        opacity: 0.7
                    }

                    // Строка "Основной баланс"
                    Item {
                        width: parent.width
                        height: 50

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: detailCur.icon_color || currency.icon_color || Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: detailCur.icon_letter || currency.icon_letter || "?"
                                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: "Основной баланс"
                                    font { pixelSize: 13; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: fmtCoins(wallet.balance) + " " + (detailCur.symbol || currency.symbol || "")
                                    font.pixelSize: 11
                                    color: "#9CA3AF"
                                }
                            }
                        }

                        Column {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                anchors.right: parent.right
                                text: fmtRub(portfolio.current_value) + " ₽"
                                font { pixelSize: 14; bold: true; family: manropeFont.name }
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.right: parent.right
                                text: (Number(portfolio.change_24h_abs) >= 0 ? "+" : "−")
                                      + fmtRub(Math.abs(Number(portfolio.change_24h_abs || 0))) + " ₽"
                                font.pixelSize: 11
                                color: Number(portfolio.change_24h_abs) >= 0 ? Theme.success : Theme.error
                            }
                        }
                    }

                    // Разделитель перед себестоимостью
                    Rectangle {
                        visible: Number(portfolio.net_invested || 0) > 0
                        width: parent.width
                        height: 1
                        color: "#1F2937"
                        opacity: 0.7
                    }

                    // Себестоимость / профит — только если в принципе были покупки
                    Item {
                        visible: Number(portfolio.net_invested || 0) > 0
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Вложено"
                            font.pixelSize: 12
                            color: "#9CA3AF"
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: fmtRub(portfolio.net_invested) + " ₽"
                            font { pixelSize: 12; bold: true; family: manropeFont.name }
                            color: "#E5E7EB"
                        }
                    }

                    Item {
                        visible: Number(portfolio.net_invested || 0) > 0
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Прибыль / убыток"
                            font.pixelSize: 12
                            color: "#9CA3AF"
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var v = Number(portfolio.profit_abs || 0)
                                var sign = v >= 0 ? "+" : "−"
                                var pct  = Number(portfolio.profit_pct || 0)
                                return sign + fmtRub(Math.abs(v)) + " ₽  ("
                                     + (pct >= 0 ? "+" : "−")
                                     + Math.abs(pct).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + "%)"
                            }
                            font { pixelSize: 12; bold: true; family: manropeFont.name }
                            color: Number(portfolio.profit_abs) >= 0 ? Theme.success : Theme.error
                        }
                    }
                }
            }

            // ============================================================
            //  Кнопки действий: Купить / Продать / Перевести
            //  Стиль — как у быстрых действий на главной (MainPage):
            //  градиент Theme.grBlockPosStart→grBlockPosEnd, рамка Theme.card,
            //  светлый текст #E5E7EB.
            // ============================================================
            Row {
                id: actionsBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                // Купить
                Rectangle {
                    width: (parent.width - parent.spacing * 2) / 3
                    height: 44
                    radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                    }
                    border.color: Theme.card
                    opacity: buyMa.pressed ? 0.7 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: "Купить"
                        font { pixelSize: 13; bold: true; family: manropeFont.name }
                        color: "#E5E7EB"
                    }
                    MouseArea { id: buyMa; anchors.fill: parent; onClicked: root.openBuy(detailCur) }
                }

                // Продать
                Rectangle {
                    width: (parent.width - parent.spacing * 2) / 3
                    height: 44
                    radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                    }
                    border.color: Theme.card
                    opacity: (root.hasBalance ? 1.0 : 0.4) * (sellMa.pressed ? 0.7 : 1.0)

                    Text {
                        anchors.centerIn: parent
                        text: "Продать"
                        font { pixelSize: 13; bold: true; family: manropeFont.name }
                        color: "#E5E7EB"
                    }
                    MouseArea {
                        id: sellMa
                        anchors.fill: parent
                        enabled: root.hasBalance
                        onClicked: root.openSell(detailCur, Number(root.wallet.balance || 0))
                    }
                }

                // Перевести
                Rectangle {
                    width: (parent.width - parent.spacing * 2) / 3
                    height: 44
                    radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                    }
                    border.color: Theme.card
                    opacity: (root.hasBalance ? 1.0 : 0.4) * (trMa.pressed ? 0.7 : 1.0)

                    Text {
                        anchors.centerIn: parent
                        text: "Перевести"
                        font { pixelSize: 13; bold: true; family: manropeFont.name }
                        color: "#E5E7EB"
                    }
                    MouseArea {
                        id: trMa
                        anchors.fill: parent
                        enabled: root.hasBalance
                        onClicked: root.openTransfer(detailCur, Number(root.wallet.balance || 0))
                    }
                }
            }

            // ============================================================
            //  История транзакций по этой монете
            // ============================================================
            Column {
                id: coinHistoryBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "История транзакций"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Rectangle {
                    width: parent.width
                    radius: 18
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                    }
                    border.color: Theme.card
                    height: histInner.height + 16

                    Column {
                        id: histInner
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top; topMargin: 8
                            leftMargin: 8; rightMargin: 8
                        }
                        spacing: 0

                        // Пустое состояние
                        Item {
                            width: parent.width
                            height: 70
                            visible: root.historyAll.length === 0

                            Text {
                                anchors.centerIn: parent
                                text: cryptoController.isLoading ? "Загружаем…" : "По этой монете пока операций нет"
                                color: "#6B7280"
                                font.pixelSize: 12
                            }
                        }

                        // Показываем максимум 5 первых
                        Repeater {
                            id: histRep
                            model: root.historyAll.slice(0, 5)

                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: parent.width
                                height: 60

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 12

                                    // Иконка с цветом операции
                                    Item {
                                        width: 40; height: 40
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 20
                                            color: opTintBg(modelData.operation_type)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "%"  // знак "проценты"
                                                font { pixelSize: 16; bold: true; family: manropeFont.name }
                                                color: opColor(modelData.operation_type)
                                            }
                                        }
                                    }

                                    // Левая колонка: тип + дата
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        width: (parent.width - 40 - parent.spacing * 2) * 0.55

                                        Text {
                                            width: parent.width
                                            text: opTitle(modelData.operation_type)
                                            font { pixelSize: 13; bold: true; family: manropeFont.name }
                                            color: "#FFFFFF"
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: modelData.created_at
                                            font.pixelSize: 11
                                            color: "#9CA3AF"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Правая колонка: суммы
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        width: (parent.width - 40 - parent.spacing * 2) * 0.45

                                        Text {
                                            width: parent.width
                                            text: {
                                                var sign = (modelData.operation_type === "buy"
                                                            || modelData.operation_type === "transfer_in")
                                                           ? "+" : "−"
                                                return sign + fmtCoins(modelData.coin_amount) + " "
                                                     + (modelData.symbol || "")
                                            }
                                            font { pixelSize: 13; bold: true; family: manropeFont.name }
                                            color: (modelData.operation_type === "buy"
                                                    || modelData.operation_type === "transfer_in")
                                                   ? Theme.success : Theme.error
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            visible: modelData.operation_type === "transfer_in"
                                                     || modelData.operation_type === "transfer_out"
                                            text: modelData.operation_type === "transfer_in"
                                                  ? "Получено" : "Отправлено"
                                            font.pixelSize: 10
                                            color: "#9CA3AF"
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        Text {
                                            width: parent.width
                                            visible: Number(modelData.rub_amount) > 0
                                                     && modelData.operation_type !== "transfer_in"
                                                     && modelData.operation_type !== "transfer_out"
                                            text: fmtRub(modelData.rub_amount) + " ₽"
                                            font.pixelSize: 10
                                            color: "#9CA3AF"
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }

                                // Разделитель — кроме последней строки
                                Rectangle {
                                    visible: index < Math.min(5, root.historyAll.length) - 1
                                    anchors {
                                        left: parent.left; right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: 56; rightMargin: 8
                                    }
                                    height: 1
                                    color: "#1F2937"
                                    opacity: 0.6
                                }
                            }
                        }

                        // "Показать все" — открывает полную историю крипто-операций
                        Item {
                            visible: root.historyAll.length > 0
                            width: parent.width
                            height: 44

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Показать все"
                                font { pixelSize: 13; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                font.pixelSize: 18
                                color: "#9CA3AF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.openHistory(detailCur.id || 0)
                            }
                        }
                    }
                }
            }

            // ============================================================
            //  О криптовалюте
            // ============================================================
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "О криптовалюте"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Rectangle {
                    width: parent.width
                    radius: 18
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                    }
                    border.color: Theme.card
                    height: aboutCol.height + 28

                    Column {
                        id: aboutCol
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 18; rightMargin: 18
                        }
                        spacing: 12

                        Text {
                            width: parent.width
                            text: detailCur.description || "Описание появится после загрузки."
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                            color: "#E5E7EB"
                            lineHeight: 1.3
                        }

                        // Bullet-список фактов
                        Column {
                            width: parent.width
                            spacing: 6

                            Row {
                                spacing: 8
                                Text { text: "•"; color: Theme.accentLight; font.pixelSize: 14 }
                                Text {
                                    text: "Покупка и продажа за рубли с любой дебетовой карты PlutusBank."
                                    color: "#9CA3AF"
                                    font.pixelSize: 12
                                    width: aboutCol.width - 18
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Row {
                                spacing: 8
                                Text { text: "•"; color: Theme.accentLight; font.pixelSize: 14 }
                                Text {
                                    text: "Мгновенные переводы другим клиентам по адресу кошелька."
                                    color: "#9CA3AF"
                                    font.pixelSize: 12
                                    width: aboutCol.width - 18
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Row {
                                spacing: 8
                                Text { text: "•"; color: Theme.accentLight; font.pixelSize: 14 }
                                Text {
                                    text: "Котировки моделируются биржевым движком и обновляются каждые несколько секунд."
                                    color: "#9CA3AF"
                                    font.pixelSize: 12
                                    width: aboutCol.width - 18
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // Тех. факты: символ, базовая цена, адрес кошелька
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#1F2937"
                            opacity: 0.7
                        }

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Символ"; font.pixelSize: 12; color: "#9CA3AF"
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: detailCur.symbol || ""
                                font { pixelSize: 12; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                            }
                        }

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Базовая цена"; font.pixelSize: 12; color: "#9CA3AF"
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: fmtPriceSmart(detailCur.base_price) + " ₽"
                                font { pixelSize: 12; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                            }
                        }

                        Item {
                            visible: !!wallet.address
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Адрес кошелька"; font.pixelSize: 12; color: "#9CA3AF"
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: wallet.address
                                      ? (String(wallet.address).slice(0, 6) + "…" + String(wallet.address).slice(-4))
                                      : ""
                                font { pixelSize: 12; bold: true; family: manropeFont.name }
                                color: "#E5E7EB"
                            }
                        }
                    }
                }
            }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "cryptoCoin"
        steps: [
            { target: priceCard, flickable: flick, title: "Текущая цена",
              text: "Живая котировка монеты и её изменение за 24 часа — зелёным рост, красным падение." },
            { target: chartBlock, flickable: flick, title: "График за день",
              text: "Движение цены за последние сутки. График обновляется автоматически каждые несколько секунд." },
            { target: actionsBlock, flickable: flick, title: "Торговля",
              text: "«Купить» — за рубли с карты, «Продать» — с зачислением на карту, «Перевести» — отправить монеты на кошелёк другого пользователя." },
            { target: coinHistoryBlock, flickable: flick, title: "Операции по монете",
              text: "История ваших сделок именно с этой криптовалютой." }
        ]
    }
}
