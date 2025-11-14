import QtQuick 2.15
import PushClone 1.0

// ═══════════════════════════════════════════════════════════
// TRANSPORT BAR - Footer con controles de transporte
// ═══════════════════════════════════════════════════════════
// Siempre visible en todas las vistas
// Play/Stop/Record, Tempo, Time position
// ═══════════════════════════════════════════════════════════

Rectangle {
    id: root

    height: PushCloneTheme.footerHeight
    color: PushCloneTheme.surface

    // ═══════════════════════════════════════════════════════
    // PROPERTIES
    // ═══════════════════════════════════════════════════════
    property bool isPlaying: false
    property bool isRecording: false
    property real tempo: 120.0
    property string songPosition: "1.1.1"
    property string selectedClip: ""

    // ═══════════════════════════════════════════════════════
    // SIGNALS
    // ═══════════════════════════════════════════════════════
    signal playPressed()
    signal stopPressed()
    signal recordPressed()

    // ═══════════════════════════════════════════════════════
    // TOP BORDER
    // ═══════════════════════════════════════════════════════
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 1
        color: PushCloneTheme.border
    }

    // ═══════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ═══════════════════════════════════════════════════════
    Row {
        anchors {
            fill: parent
            margins: PushCloneTheme.spacing
        }
        spacing: PushCloneTheme.spacing

        // ═══════════════════════════════════════════════════
        // LEFT SECTION: Info
        // ═══════════════════════════════════════════════════
        Column {
            width: 200
            height: parent.height
            spacing: 2

            Text {
                text: selectedClip !== "" ? "Clip: " + selectedClip : "No selection"
                color: PushCloneTheme.text
                font.pixelSize: PushCloneTheme.fontSizeSmall
                font.family: PushCloneTheme.fontFamily
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: "Position: " + songPosition
                color: PushCloneTheme.textDim
                font.pixelSize: PushCloneTheme.fontSizeSmall
                font.family: PushCloneTheme.fontFamilyMono
            }
        }

        // Spacer
        Item {
            width: parent.width - 200 - 280 - (parent.spacing * 2)
            height: 1
        }

        // ═══════════════════════════════════════════════════
        // CENTER SECTION: Tempo
        // ═══════════════════════════════════════════════════
        Rectangle {
            width: 80
            height: parent.height
            color: PushCloneTheme.background
            radius: PushCloneTheme.radius
            border.color: PushCloneTheme.border
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: "♩ TEMPO"
                    color: PushCloneTheme.textDim
                    font.pixelSize: PushCloneTheme.fontSizeSmall
                    font.family: PushCloneTheme.fontFamily
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: tempo.toFixed(1)
                    color: PushCloneTheme.primary
                    font.pixelSize: PushCloneTheme.fontSizeLarge
                    font.family: PushCloneTheme.fontFamilyMono
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ═══════════════════════════════════════════════════
        // RIGHT SECTION: Transport Controls
        // ═══════════════════════════════════════════════════
        Row {
            width: 200
            height: parent.height
            spacing: PushCloneTheme.spacing

            // Component: Transport Button
            component TransportButton: Rectangle {
                property string label: ""
                property string icon: ""
                property bool isActive: false
                property color activeColor: PushCloneTheme.primary

                signal pressed()

                width: 60
                height: parent.height
                radius: PushCloneTheme.radius
                color: isActive ? activeColor : PushCloneTheme.background
                border.color: isActive ? activeColor : PushCloneTheme.borderBright
                border.width: 1

                // Hover/Press feedback
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: PushCloneTheme.surfaceHover
                    opacity: touchArea.pressed ? 0.5 : (touchArea.containsMouse ? 0.3 : 0)

                    Behavior on opacity {
                        NumberAnimation { duration: PushCloneTheme.animationFast }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: icon
                        color: isActive ? "#ffffff" : PushCloneTheme.text
                        font.pixelSize: PushCloneTheme.fontSizeLarge
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: label
                        color: isActive ? "#ffffff" : PushCloneTheme.textDim
                        font.pixelSize: PushCloneTheme.fontSizeSmall
                        font.family: PushCloneTheme.fontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: touchArea
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        parent.pressed()
                    }
                }

                scale: touchArea.pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: PushCloneTheme.animationFast
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: PushCloneTheme.animationFast }
                }
            }

            // STOP Button
            TransportButton {
                label: "STOP"
                icon: "■"
                onPressed: {
                    console.log("Stop pressed")
                    root.isPlaying = false
                    root.stopPressed()
                }
            }

            // PLAY Button
            TransportButton {
                label: "PLAY"
                icon: "▶"
                isActive: root.isPlaying
                activeColor: PushCloneTheme.success
                onPressed: {
                    console.log("Play pressed")
                    root.isPlaying = !root.isPlaying
                    root.playPressed()
                }
            }

            // RECORD Button
            TransportButton {
                label: "REC"
                icon: "●"
                isActive: root.isRecording
                activeColor: PushCloneTheme.error
                onPressed: {
                    console.log("Record pressed")
                    root.isRecording = !root.isRecording
                    root.recordPressed()
                }
            }
        }
    }
}
