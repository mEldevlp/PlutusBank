pragma Singleton
import QtQuick

QtObject {
    // Фоны
    readonly property color background:       "#1a1a2e"
    readonly property color backgroundDark:   "#0A1229"
    readonly property color backgroundDeep:   "#050B1A"
    readonly property color surface:          "#0F172A"

    // Карточки / панели
    readonly property color card:             "#1F2937"
    readonly property color cardLight:        "#374151"
    readonly property color cardDark:         "#374151"
    readonly property color cardBorder:       "#4B5563"

    // Акцент
    readonly property color accent:           "#20a9bc"
    readonly property color accentLight:      "#2DD4BF"
    readonly property color accentDark:       "#14B8A6"

    // Текст
    readonly property color textPrimary:      "#FFFFFF"
    readonly property color textSecondary:    "#ccd2db"
    readonly property color textMuted:        "#6B7280"
    readonly property color textSubtle:       "#E5E7EB"

    // Семантика
    readonly property color success:          "#10B981"
    readonly property color successDark:      "#059669"
    readonly property color error:            "#EF4444"
    readonly property color errorDark:        "#DC2626"
    readonly property color errorBg:          "#7F1D1D"
    readonly property color errorLight:       "#FCA5A5"
    readonly property color warning:          "#F59E0B"
    readonly property color info:             "#3B82F6"
    readonly property color infoLight:        "#60A5FA"

    // Оверлеи
    readonly property color overlay:          "#80000000"
    readonly property color overlayDark:      "#CC000000"

    // Прочие
    readonly property color purple:           "#7C3AED"
    readonly property color purpleLight:      "#A78BFA"
    readonly property color blueDark:         "#1E3A8A"
    readonly property color tealDark:         "#042F2E"
    readonly property color neutral:          "#111827"
    readonly property color neutralLight:     "#F3F4F6"
    readonly property color neutralBg:        "#F7F7FB"
    readonly property color border:           "#D1D5DB"
    readonly property color green:            "#0e8b3e"
    readonly property color red:              "#b21f1f"
    readonly property color redLight:         "#e52a2a"

    // Градиенты
    // Градиент для обычных блоков (баланс, быстрые действия и тд)
    readonly property color grBlockPosStart:       "#99374151"
    readonly property color grBlockPosEnd:         "#99111827"
    readonly property color grBlockAltPosEnd:      "#9927303f"
    readonly property color grBlockAltDefPosEnd:   "#27303f"
    readonly property color grBlockDefPosStart:    "#374151"
    readonly property color grBlockDefPosEnd:      "#111827"

    /*
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
    }
    */

    // Visa
    readonly property color grVisaPosStart:     "#111827"
    readonly property color grVisaPosEnd:       "#1E3A8A" 

    // mastercard
    readonly property color grMSPosStart:       "#2E1065"
    readonly property color grMSPosEnd:         "#5B21B6" 

    // mir
    readonly property color grMirPosStart:      "#064E3B"
    readonly property color grMirPosEnd:        "#059669" 

}