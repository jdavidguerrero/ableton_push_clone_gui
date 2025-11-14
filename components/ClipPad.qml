import QtQuick 2.15
import PushClone 1.0

// ═══════════════════════════════════════════════════════════
// CLIP PAD - Individual component for session grid
// ═══════════════════════════════════════════════════════════
// Represents a clip in the SessionView (8×4 grid)
// States: 0=empty, 1=playing, 2=queued, 3=recording, 4=stopped
// ═══════════════════════════════════════════════════════════

Rectangle {
    id: root

    // ═══════════════════════════════════════════════════════
    // PUBLIC PROPERTIES
    // ═══════════════════════════════════════════════════════
    property string clipName: ""                    // Clip name
    property int clipState: 0                       // 0-4 (see above)
    property color clipColor: PushCloneTheme.clipColors[0]  // Base color
    property int trackIndex: 0                      // Track index (0-7)
    property int sceneIndex: 0                      // Scene index (0-3)
    property bool isSelected: false                 // Selected clip

    // ═══════════════════════════════════════════════════════
    // SIGNALS
    // ═══════════════════════════════════════════════════════
    signal clipTriggered()                          // Tap: trigger clip
    signal clipStopped()                            // Stop clip
    signal clipLongPressed()                        // Long press: context menu

    // ═══════════════════════════════════════════════════════
    // APPEARANCE
    // ═══════════════════════════════════════════════════════
    width: 80
    height: 60
    radius: PushCloneTheme.radius

    // Color based on state
    color: {
        if (clipState === 0) {
            // Empty: RGB(40, 40, 40) - base color from API
            return PushCloneTheme.clipEmpty
        } else if (clipState === 1) {
            // Playing: brighter
            return Qt.lighter(clipColor, 1.4)
        } else if (clipState === 2) {
            // Queued: pulsing yellow
            return PushCloneTheme.warning
        } else if (clipState === 3) {
            // Recording: pulsing red
            return PushCloneTheme.error
        } else {
            // Stopped: original color from Live
            return clipColor
        }
    }

    border.color: isSelected ? PushCloneTheme.primary : PushCloneTheme.border
    border.width: isSelected ? 2 : 1

    // ═══════════════════════════════════════════════════════
    // SMOOTH COLOR TRANSITIONS
    // ═══════════════════════════════════════════════════════
    Behavior on color {
        ColorAnimation {
            duration: PushCloneTheme.animationFast
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on border.color {
        ColorAnimation { duration: PushCloneTheme.animationFast }
    }

    // ═══════════════════════════════════════════════════════
    // CLIP NAME (if exists)
    // ═══════════════════════════════════════════════════════
    Text {
        id: nameText
        text: clipName
        visible: clipState !== 0  // Only show if not empty

        anchors {
            centerIn: parent
            margins: PushCloneTheme.spacingSmall
        }

        color: {
            // Contrast based on background brightness
            var luminance = (clipColor.r * 0.299 + clipColor.g * 0.587 + clipColor.b * 0.114)
            return luminance > 0.5 ? "#000000" : "#ffffff"
        }

        font.pixelSize: PushCloneTheme.fontSizeSmall
        font.family: PushCloneTheme.fontFamily
        font.bold: clipState === 1  // Bold when playing

        elide: Text.ElideRight
        width: parent.width - 8
        horizontalAlignment: Text.AlignHCenter
    }

    // ═══════════════════════════════════════════════════════
    // STATE INDICATOR (icon)
    // ═══════════════════════════════════════════════════════
    Text {
        id: stateIcon
        visible: clipState === 1 || clipState === 3

        anchors {
            right: parent.right
            top: parent.top
            margins: 4
        }

        text: clipState === 1 ? "▶" : "●"  // Playing: ▶, Recording: ●
        color: "#ffffff"
        font.pixelSize: 8
        font.bold: true
    }

    // ═══════════════════════════════════════════════════════
    // PULSING ANIMATION (queued and recording)
    // ═══════════════════════════════════════════════════════
    SequentialAnimation {
        running: clipState === 2 || clipState === 3
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0.6
            duration: 500
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1.0
            duration: 500
            easing.type: Easing.InOutQuad
        }
    }

    // ═══════════════════════════════════════════════════════
    // TOUCH INTERACTION
    // ═══════════════════════════════════════════════════════
    MouseArea {
        id: touchArea
        anchors.fill: parent

        // Enable long press detection
        pressAndHoldInterval: 600

        // Visual feedback on press
        onPressed: {
            root.scale = 0.95
        }

        onReleased: {
            root.scale = 1.0
        }

        onCanceled: {
            root.scale = 1.0
        }

        // Tap: Trigger or stop clip
        onClicked: {
            console.log("Clip triggered:", trackIndex, sceneIndex, clipName)
            root.clipTriggered()
        }

        // Long press: Context menu
        onPressAndHold: {
            console.log("Clip long pressed:", clipName)
            root.clipLongPressed()
        }
    }

    // Smooth scale animation
    Behavior on scale {
        NumberAnimation {
            duration: PushCloneTheme.animationFast
            easing.type: Easing.OutQuad
        }
    }

    // ═══════════════════════════════════════════════════════
    // DEFINED STATES (alternative to color: logic)
    // ═══════════════════════════════════════════════════════
    states: [
        State {
            name: "empty"
            when: clipState === 0
            PropertyChanges {
                target: root
                opacity: 0.3
            }
        },
        State {
            name: "playing"
            when: clipState === 1
            // Color already handled in binding
        },
        State {
            name: "queued"
            when: clipState === 2
        },
        State {
            name: "recording"
            when: clipState === 3
        },
        State {
            name: "stopped"
            when: clipState === 4
        }
    ]
}
