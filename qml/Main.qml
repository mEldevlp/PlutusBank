import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 400
    height: 800
    title: "PlutusBank - Hello World"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#4158D0" }
            GradientStop { position: 0.5; color: "#C850C0" }
            GradientStop { position: 1.0; color: "#FFCC70" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "🏦 PlutusBank"
                font.pixelSize: 48
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Hello World!"
                font.pixelSize: 32
                font.bold: true
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Mobile Banking App"
                font.pixelSize: 16
                color: "white"
                opacity: 0.8
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: 200
                height: 50
                color: "white"
                radius: 25
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "Get Started"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#4158D0"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Button clicked!")
                    }
                }
            }
        }
    }
}
