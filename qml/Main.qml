import QtQuick
import QtQuick.Controls
import "."

ApplicationWindow {
    visible: true
    width: 400
    height: 800
    title: "PlutusBank"

    color: "#070D1F"

    // Стек страниц
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: authComponent
    }

    // Компонент авторизации
    Component {
        id: authComponent
        
        Auth {
            onLoginSuccess: {
                stackView.push(mainPageComponent)
            }
        }
    }

    // Компонент главной страницы
    Component {
        id: mainPageComponent
        MainPage {}
    }
}
