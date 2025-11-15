import QtQuick 2.15
import QtQuick.Window 2.15
import PushClone 1.0

// ═══════════════════════════════════════════════════════════
// MAIN WINDOW - PushClone Application
// ═══════════════════════════════════════════════════════════

Window {
    id: mainWindow
    width: 800
    height: 480
    visible: true
    visibility: Window.FullScreen  // Pantalla completa
    title: qsTr("PushClone")
    color: PushCloneTheme.background

    // ═══════════════════════════════════════════════════════
    // APPLICATION STATE
    // ═══════════════════════════════════════════════════════
    property bool showSplash: true
    property int currentView: 0  // 0=Session, 1=Mix, 2=Device, 3=Browse, 4=Note

    // ═══════════════════════════════════════════════════════
    // SPLASH SCREEN (inicial)
    // ═══════════════════════════════════════════════════════
    Loader {
        id: splashLoader
        anchors.fill: parent
        source: "SplashScreen.qml"
        visible: showSplash

        onLoaded: {
            if (item && item.finished) {
                item.finished.connect(function() {
                    console.log("✓ Splash completado, cargando app principal...")
                    splashFadeOut.start()
                })
            }
        }
    }

    // Splash fade out animation
    SequentialAnimation {
        id: splashFadeOut

        NumberAnimation {
            target: splashLoader
            property: "opacity"
            to: 0
            duration: 300
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: {
                showSplash = false
                mainContainer.opacity = 0
                mainContainer.visible = true
                mainFadeIn.start()
            }
        }
    }

    // Main app fade in animation
    NumberAnimation {
        id: mainFadeIn
        target: mainContainer
        property: "opacity"
        to: 1
        duration: 300
        easing.type: Easing.InOutQuad
    }

    // ═══════════════════════════════════════════════════════
    // MAIN CONTAINER (after splash)
    // ═══════════════════════════════════════════════════════
    Item {
        id: mainContainer
        anchors.fill: parent
        visible: false

        Column {
            anchors.fill: parent
            spacing: 0

            // NAVIGATION BAR (tabs)
            Loader {
                id: navBarLoader
                width: parent.width
                height: item ? item.height : 0
                source: "components/NavigationBar.qml"

                onLoaded: {
                    item.currentView = Qt.binding(function() { return mainWindow.currentView })
                    item.viewChanged.connect(function(viewIndex) {
                        console.log("Cambiando a vista:", viewIndex)
                        mainWindow.currentView = viewIndex
                        viewLoader.loadView(viewIndex)
                    })
                }
            }

            // CONTENT AREA (vistas)
            Item {
                width: parent.width
                height: parent.height - navBarLoader.height - transportBarLoader.height

                Loader {
                    id: viewLoader
                    anchors.fill: parent

                    // Load initial view (SessionView)
                    Component.onCompleted: {
                        loadView(0)
                    }

                    function loadView(viewIndex) {
                        switch(viewIndex) {
                            case 0:
                                source = "views/SessionView.qml"
                                break
                            case 1:
                                source = "views/MixView.qml"
                                break
                            case 2:
                                sourceComponent = placeholderView
                                placeholderText = "DEVICE VIEW\n(Coming soon)"
                                break
                            case 3:
                                sourceComponent = placeholderView
                                placeholderText = "BROWSE VIEW\n(Coming soon)"
                                break
                            case 4:
                                sourceComponent = placeholderView
                                placeholderText = "NOTE/SEQUENCER VIEW\n(Coming soon)"
                                break
                            default:
                                sourceComponent = placeholderView
                                placeholderText = "UNKNOWN VIEW"
                        }
                    }

                    property string placeholderText: ""

                    // Placeholder for unimplemented views
                    Component {
                        id: placeholderView

                        Rectangle {
                            color: PushCloneTheme.background

                            Text {
                                anchors.centerIn: parent
                                text: viewLoader.placeholderText
                                color: PushCloneTheme.textDim
                                font.pixelSize: PushCloneTheme.fontSizeXLarge
                                font.family: PushCloneTheme.fontFamily
                                horizontalAlignment: Text.AlignHCenter

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 1000 }
                                    NumberAnimation { to: 1.0; duration: 1000 }
                                }
                            }
                        }
                    }
                }
            }

            // TRANSPORT BAR (footer)
            Loader {
                id: transportBarLoader
                width: parent.width
                height: item ? item.height : 0
                source: "components/TransportBar.qml"

                onLoaded: {
                    // Set test data
                    item.tempo = 120.0
                    item.songPosition = "1.1.1"
                    item.selectedClip = "Drums - Kick Loop"

                    // Connect signals
                    item.playPressed.connect(function() {
                        console.log("Transport: Play pressed")
                        // TODO: Send CMD_TRANSPORT_PLAY via UART
                    })

                    item.stopPressed.connect(function() {
                        console.log("Transport: Stop pressed")
                        // TODO: Send CMD_TRANSPORT_PLAY (stop) via UART
                    })

                    item.recordPressed.connect(function() {
                        console.log("Transport: Record pressed")
                        // TODO: Send CMD_TRANSPORT_RECORD via UART
                    })
                }
            }
        }
    }
}
