import QtQuick 2.15
import PushClone 1.0
import "../components" as Components

// ═══════════════════════════════════════════════════════════
// SESSION VIEW - Main view with 8×4 clips grid
// ═══════════════════════════════════════════════════════════
// Layout:
// - Track headers (names + colors)
// - 8×4 ClipPads grid
// - Scene buttons (right side)
// ═══════════════════════════════════════════════════════════

Rectangle {
    id: root

    color: PushCloneTheme.background

    // ═══════════════════════════════════════════════════════
    // TEST DATA (Later will come from UART backend)
    // ═══════════════════════════════════════════════════════
    property var trackNames: ["Drums", "Bass", "Lead", "Pad", "FX", "Vocal", "Keys", "Synth"]
    property var trackColors: [
        PushCloneTheme.clipColors[0],   // Red
        PushCloneTheme.clipColors[1],   // Orange
        PushCloneTheme.clipColors[2],   // Yellow
        PushCloneTheme.clipColors[4],   // Green
        PushCloneTheme.clipColors[8],   // Blue
        PushCloneTheme.clipColors[9],   // Purple
        PushCloneTheme.clipColors[10],  // Magenta
        PushCloneTheme.clipColors[6],   // Cyan
        PushCloneTheme.clipColors[12]   // Gray (Master)
    ]

    // Clips grid (8 tracks × 4 scenes = 32 clips)
    // Estado: 0=empty, 1=playing, 2=queued, 3=recording, 4=stopped
    property var clipStates: [
        // Track 0 (Drums)
        [1, 4, 0, 4],
        // Track 1 (Bass)
        [4, 1, 0, 4],
        // Track 2 (Lead)
        [4, 0, 4, 0],
        // Track 3 (Pad)
        [4, 4, 0, 4],
        // Track 4 (FX)
        [0, 4, 4, 0],
        // Track 5 (Vocal)
        [4, 0, 4, 4],
        // Track 6 (Keys)
        [0, 4, 0, 4],
        // Track 7 (Synth)
        [4, 0, 4, 0]
    ]

    property var clipNames: [
        ["Kick Loop", "Kick Alt", "", "Break"],
        ["Bass 1", "Bass 2", "", "Bass Fill"],
        ["Lead A", "", "Lead B", ""],
        ["Pad Ambient", "Pad Dark", "", "Pad Bright"],
        ["", "Reverb", "Delay", ""],
        ["Verse 1", "", "Chorus", "Bridge"],
        ["", "Piano", "", "Organ"],
        ["Synth 1", "", "Synth 2", ""]
    ]

    // ═══════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ═══════════════════════════════════════════════════════
    Column {
        anchors.fill: parent
        spacing: PushCloneTheme.spacing

        // ═══════════════════════════════════════════════════
        // TRACK HEADERS
        // ═══════════════════════════════════════════════════
        Row {
            width: parent.width
            height: 40
            spacing: PushCloneTheme.spacingSmall

            // First 8 tracks (regular width - with clips)
            Repeater {
                model: 8

                Rectangle {
                    // Calculate width to match clip grid (8 tracks)
                    width: (parent.width - 60 - PushCloneTheme.spacing - (PushCloneTheme.spacingSmall * 8)) / 8
                    height: parent.height
                    color: PushCloneTheme.surface
                    border.color: root.trackColors[index]
                    border.width: 2
                    radius: PushCloneTheme.radius

                    // Track color indicator
                    Rectangle {
                        width: parent.width
                        height: 4
                        anchors.top: parent.top
                        color: root.trackColors[index]
                        radius: PushCloneTheme.radius
                    }

                    Text {
                        text: root.trackNames[index]
                        anchors.centerIn: parent
                        color: PushCloneTheme.text
                        font.pixelSize: PushCloneTheme.fontSizeSmall
                        font.family: PushCloneTheme.fontFamily
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    // Touch to select track
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("Track selected:", index, root.trackNames[index])
                            // TODO: Send CMD_TRACK_SELECT
                        }
                    }
                }
            }

            // Master track (same width as scene buttons)
            Rectangle {
                width: 60
                height: parent.height
                color: PushCloneTheme.surface
                border.color: root.trackColors[8]
                border.width: 2
                radius: PushCloneTheme.radius

                // Track color indicator
                Rectangle {
                    width: parent.width
                    height: 4
                    anchors.top: parent.top
                    color: root.trackColors[8]
                    radius: PushCloneTheme.radius
                }

                Text {
                    text: "Master"
                    anchors.centerIn: parent
                    color: PushCloneTheme.text
                    font.pixelSize: PushCloneTheme.fontSizeSmall
                    font.family: PushCloneTheme.fontFamily
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Touch to select track
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Track selected: Master")
                        // TODO: Send CMD_TRACK_SELECT
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════
        // GRID 8×4 + SCENE BUTTONS
        // ═══════════════════════════════════════════════════
        Row {
            width: parent.width
            height: parent.height - 40 - PushCloneTheme.spacing
            spacing: PushCloneTheme.spacing

            // CLIP GRID (8 columns × 4 rows - 8 complete tracks)
            Grid {
                id: clipGrid
                width: parent.width - 60 - PushCloneTheme.spacing
                height: parent.height

                columns: 8
                rows: 4
                columnSpacing: PushCloneTheme.spacingSmall
                rowSpacing: PushCloneTheme.spacingSmall

                // Calculate each pad size
                property real padWidth: (width - (columnSpacing * (columns - 1))) / columns
                property real padHeight: (height - (rowSpacing * (rows - 1))) / rows

                // 32 ClipPads (8×4)
                Repeater {
                    model: 32
                    delegate: Components.ClipPad {
                        property int trackIdx: index % 8
                        property int sceneIdx: Math.floor(index / 8)

                        width: clipGrid.padWidth
                        height: clipGrid.padHeight

                        trackIndex: trackIdx
                        sceneIndex: sceneIdx
                        clipName: root.clipNames[trackIdx][sceneIdx]
                        clipState: root.clipStates[trackIdx][sceneIdx]
                        clipColor: root.trackColors[trackIdx]

                        onClipTriggered: {
                            console.log("Clip triggered: Track", trackIdx, "Scene", sceneIdx)
                            // TODO: Send CMD_CLIP_TRIGGER via UART
                        }

                        onClipLongPressed: {
                            console.log("Clip long pressed: Track", trackIdx, "Scene", sceneIdx)
                            // TODO: Show context menu (delete, duplicate, rename)
                        }
                    }
                }
            }

            // SCENE BUTTONS (lateral derecho)
            Column {
                width: 60
                height: parent.height
                spacing: PushCloneTheme.spacingSmall

                Repeater {
                    model: 4

                    Rectangle {
                        width: parent.width
                        height: (parent.height - (PushCloneTheme.spacingSmall * 3)) / 4
                        color: PushCloneTheme.surface
                        border.color: PushCloneTheme.borderBright
                        border.width: 1
                        radius: PushCloneTheme.radius

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "▶"
                                color: PushCloneTheme.primary
                                font.pixelSize: PushCloneTheme.fontSizeLarge
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "Scene\n" + (index + 1)
                                color: PushCloneTheme.textDim
                                font.pixelSize: PushCloneTheme.fontSizeSmall
                                font.family: PushCloneTheme.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("Scene fired:", index + 1)
                                // TODO: Enviar CMD_SCENE_FIRE
                            }
                        }

                        // Press feedback
                        scale: sceneMouseArea.pressed ? 0.95 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: PushCloneTheme.animationFast
                                easing.type: Easing.OutQuad
                            }
                        }

                        MouseArea {
                            id: sceneMouseArea
                            anchors.fill: parent
                            onClicked: {
                                console.log("Scene fired:", index + 1)
                                // TODO: Enviar CMD_SCENE_FIRE
                            }
                        }
                    }
                }
            }
        }
    }
}
