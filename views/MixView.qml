import QtQuick 2.15
import QtQuick.Layouts 1.15
import PushClone 1.0

// ═══════════════════════════════════════════════════════════
// MIX VIEW - Matrix layout with parameter column on right
// ═══════════════════════════════════════════════════════════

Rectangle {
    id: root
    anchors.fill: parent
    clip: true
    color: PushCloneTheme.background

    // ═══════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════
    property bool showMasterReturns: false
    property int trackBank: 0
    property int returnBank: 0
    property int activeParameterRow: 0  // 0=PAN, 1=SEND A, etc.
    property int selectedTrackIndex: 0

    readonly property int tracksPerBank: 4
    readonly property int returnsPerBank: 3

    // Parameter banks (navegación vertical por bancos)
    property int parameterBank: 0

    property var parameterBanks: [
        // Bank 0: Pan + Sends A/B + FX
        [
            { key: "pan",    label: "PAN",    valueKey: "panLabel",    ratioKey: "panRatio" },
            { key: "sendA",  label: "SEND A", valueKey: "sendAText",   ratioKey: "sendA" },
            { key: "sendB",  label: "SEND B", valueKey: "sendBText",   ratioKey: "sendB" },
            { key: "fx",     label: "FX",     valueKey: "fxText",      ratioKey: "fxValue" }
        ]
        // Aquí se pueden agregar más bancos: Bank 1 (SEND C/D/E/F), etc.
    ]

    property var parameterRows: parameterBanks[parameterBank]

    // ═══════════════════════════════════════════════════════
    // DATA (mock data)
    // ═══════════════════════════════════════════════════════
    ListModel {
        id: trackModel
        ListElement { name: "Drums"; tag: "DRM"; color: "#ff4c4c";
            meterL: 0.82; meterR: 0.78; volume: 0.85; volumeLabel: "-2.5 dB";
            panLabel: "C"; panRatio: 0.5; sendA: 0.32; sendAText: "32%";
            sendB: 0.1; sendBText: "10%"; fxValue: 0.55; fxText: "HPF 120Hz";
            muted: false; solo: false; armed: false }
        ListElement { name: "Bass"; tag: "BASS"; color: "#4cff4c";
            meterL: 0.6; meterR: 0.52; volume: 0.6; volumeLabel: "-6.0 dB";
            panLabel: "L12"; panRatio: 0.35; sendA: 0.4; sendAText: "40%";
            sendB: 0.12; sendBText: "12%"; fxValue: 0.2; fxText: "Chorus";
            muted: false; solo: false; armed: false }
        ListElement { name: "Lead"; tag: "LEAD"; color: "#4cffff";
            meterL: 0.5; meterR: 0.45; volume: 0.7; volumeLabel: "-3.5 dB";
            panLabel: "R8"; panRatio: 0.65; sendA: 0.18; sendAText: "18%";
            sendB: 0.35; sendBText: "35%"; fxValue: 0.74; fxText: "LPF 2.3k";
            muted: false; solo: false; armed: true }
        ListElement { name: "Pad"; tag: "PAD"; color: "#ffa54c";
            meterL: 0.35; meterR: 0.3; volume: 0.25; volumeLabel: "-∞";
            panLabel: "C"; panRatio: 0.5; sendA: 0.6; sendAText: "60%";
            sendB: 0.22; sendBText: "22%"; fxValue: 0.4; fxText: "Delay";
            muted: true; solo: false; armed: false }
        ListElement { name: "FX"; tag: "FX"; color: "#ff4ca5";
            meterL: 0.75; meterR: 0.73; volume: 0.76; volumeLabel: "-3.0 dB";
            panLabel: "L6"; panRatio: 0.45; sendA: 0.58; sendAText: "58%";
            sendB: 0.44; sendBText: "44%"; fxValue: 0.66; fxText: "Comp";
            muted: false; solo: true; armed: false }
        ListElement { name: "Vocal"; tag: "VOX"; color: "#a54cff";
            meterL: 0.22; meterR: 0.2; volume: 0.3; volumeLabel: "-18 dB";
            panLabel: "R20"; panRatio: 0.75; sendA: 0.12; sendAText: "12%";
            sendB: 0.7; sendBText: "70%"; fxValue: 0.28; fxText: "Gate";
            muted: false; solo: false; armed: false }
    }

    // Master data (always fixed)
    property var masterData: {
        "name": "Master", "tag": "MST", "color": "#ffffff",
        "meterL": 0.78, "meterR": 0.78, "volume": 0.9, "volumeLabel": "0.0 dB",
        "panLabel": "C", "panRatio": 0.5, "sendA": 0.0, "sendAText": "-",
        "sendB": 0.0, "sendBText": "-", "fxValue": 0.0, "fxText": "-",
        "muted": false, "solo": false, "armed": false
    }

    // Returns data (navegable)
    ListModel {
        id: returnModel
        ListElement { name: "Return A"; tag: "RTA"; color: "#00ff88";
            meterL: 0.45; meterR: 0.45; volume: 0.65; volumeLabel: "-5.0 dB";
            panLabel: "C"; panRatio: 0.5; sendA: 0.0; sendAText: "-";
            sendB: 0.0; sendBText: "-"; fxValue: 0.8; fxText: "Reverb";
            muted: false; solo: false; armed: false }
        ListElement { name: "Return B"; tag: "RTB"; color: "#ff8800";
            meterL: 0.35; meterR: 0.35; volume: 0.55; volumeLabel: "-7.0 dB";
            panLabel: "C"; panRatio: 0.5; sendA: 0.0; sendAText: "-";
            sendB: 0.0; sendBText: "-"; fxValue: 0.6; fxText: "Delay";
            muted: false; solo: false; armed: false }
        ListElement { name: "Return C"; tag: "RTC"; color: "#ff00ff";
            meterL: 0.25; meterR: 0.25; volume: 0.45; volumeLabel: "-10.0 dB";
            panLabel: "L10"; panRatio: 0.4; sendA: 0.0; sendAText: "-";
            sendB: 0.0; sendBText: "-"; fxValue: 0.5; fxText: "Chorus";
            muted: false; solo: false; armed: false }
        ListElement { name: "Return D"; tag: "RTD"; color: "#00ffff";
            meterL: 0.3; meterR: 0.3; volume: 0.5; volumeLabel: "-8.0 dB";
            panLabel: "R10"; panRatio: 0.6; sendA: 0.0; sendAText: "-";
            sendB: 0.0; sendBText: "-"; fxValue: 0.7; fxText: "Flanger";
            muted: false; solo: false; armed: false }
    }

    // ═══════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════
    function nextTrackBank() {
        if (showMasterReturns) {
            var maxBanks = Math.ceil(returnModel.count / 3)
            returnBank = (returnBank + 1) % Math.max(1, maxBanks)
        } else {
            var maxBanks = Math.ceil(trackModel.count / tracksPerBank)
            trackBank = (trackBank + 1) % Math.max(1, maxBanks)
        }
    }

    function prevTrackBank() {
        if (showMasterReturns) {
            var maxBanks = Math.ceil(returnModel.count / 3)
            returnBank = (returnBank - 1 + Math.max(1, maxBanks)) % Math.max(1, maxBanks)
        } else {
            var maxBanks = Math.ceil(trackModel.count / tracksPerBank)
            trackBank = (trackBank - 1 + Math.max(1, maxBanks)) % Math.max(1, maxBanks)
        }
    }

    function nextParameterBank() {
        parameterBank = Math.min(parameterBanks.length - 1, parameterBank + 1)
    }

    function prevParameterBank() {
        parameterBank = Math.max(0, parameterBank - 1)
    }

    function displayedTrackIndex(localIndex) {
        return trackBank * tracksPerBank + localIndex
    }

    property real masterVolume: 0.78

    // ═══════════════════════════════════════════════════════
    // LAYOUT
    // ═══════════════════════════════════════════════════════
    Column {
        anchors.fill: parent
        anchors.leftMargin: PushCloneTheme.spacing
        anchors.rightMargin: PushCloneTheme.spacing
        anchors.topMargin: PushCloneTheme.spacing
        anchors.bottomMargin: 2
        spacing: 2

        // MATRIX (Tracks + Parameter Column) - No header
        Row {
            width: parent.width
            height: parent.height - footer.height - 2
            spacing: 0

            // TRACK COLUMNS (left side)
            Row {
                id: tracksArea
                width: parent.width - parameterColumn.width
                height: parent.height
                spacing: 0

                Repeater {
                    model: showMasterReturns ? 4 : tracksPerBank
                    delegate: Item {
                        id: trackDelegate
                        property int localIndex: index
                        property int globalIndex: showMasterReturns ? localIndex : root.displayedTrackIndex(localIndex)

                        // Compute track data based on mode
                        property string trackName: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return "Master"
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).name
                                return "---"
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).name
                                return "---"
                            }
                        }

                        property string trackTag: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return "MST"
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).tag
                                return "---"
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).tag
                                return "---"
                            }
                        }

                        property color trackColor: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return "#ffffff"
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).color
                                return PushCloneTheme.border
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).color
                                return PushCloneTheme.border
                            }
                        }

                        property real trackVolume: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return root.masterData.volume
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).volume
                                return 0
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).volume
                                return 0
                            }
                        }

                        property string volumeLabel: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return root.masterData.volumeLabel
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).volumeLabel
                                return "--"
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).volumeLabel
                                return "--"
                            }
                        }

                        property bool isMuted: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return root.masterData.muted
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).muted
                                return false
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).muted
                                return false
                            }
                        }

                        property bool isSolo: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return root.masterData.solo
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).solo
                                return false
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).solo
                                return false
                            }
                        }

                        property bool isArmed: {
                            if (showMasterReturns) {
                                if (localIndex === 3) return root.masterData.armed
                                var retIdx = (root.returnBank * 3) + localIndex
                                if (retIdx < returnModel.count) return returnModel.get(retIdx).armed
                                return false
                            } else {
                                if (globalIndex < trackModel.count) return trackModel.get(globalIndex).armed
                                return false
                            }
                        }

                        width: tracksArea.width / (showMasterReturns ? 4 : root.tracksPerBank)
                        height: parent.height

                        TrackColumn {
                            anchors.fill: parent
                            trackName: trackDelegate.trackName
                            trackTag: trackDelegate.trackTag
                            trackColor: trackDelegate.trackColor
                            trackVolume: trackDelegate.trackVolume
                            volumeLabel: trackDelegate.volumeLabel
                            isMuted: trackDelegate.isMuted
                            isSolo: trackDelegate.isSolo
                            isArmed: trackDelegate.isArmed

                            isSelected: trackDelegate.globalIndex === root.selectedTrackIndex
                            activeParameterRow: root.activeParameterRow
                            parameterRows: root.parameterRows

                            // Pass model data for parameter gauges
                            property var modelData: {
                                if (showMasterReturns) {
                                    if (trackDelegate.localIndex === 3) return root.masterData
                                    var retIdx = (root.returnBank * 3) + trackDelegate.localIndex
                                    if (retIdx < returnModel.count) return returnModel.get(retIdx)
                                    return null
                                } else {
                                    if (trackDelegate.globalIndex < trackModel.count) return trackModel.get(trackDelegate.globalIndex)
                                    return null
                                }
                            }

                            onTrackClicked: {
                                root.selectedTrackIndex = trackDelegate.globalIndex
                            }

                            onMuteToggled: {
                                console.log("Mute toggled for track", trackDelegate.globalIndex)
                                if (!showMasterReturns && trackDelegate.globalIndex < trackModel.count) {
                                    var item = trackModel.get(trackDelegate.globalIndex)
                                    item.muted = !item.muted
                                }
                            }

                            onSoloToggled: {
                                console.log("Solo toggled for track", trackDelegate.globalIndex)
                                if (!showMasterReturns && trackDelegate.globalIndex < trackModel.count) {
                                    var item = trackModel.get(trackDelegate.globalIndex)
                                    item.solo = !item.solo
                                }
                            }

                            onArmToggled: {
                                console.log("Arm toggled for track", trackDelegate.globalIndex)
                                if (!showMasterReturns && trackDelegate.globalIndex < trackModel.count) {
                                    var item = trackModel.get(trackDelegate.globalIndex)
                                    item.armed = !item.armed
                                }
                            }
                        }
                    }
                }
            }

            // PARAMETER COLUMN (right side - near encoders)
            Column {
                id: parameterColumn
                width: 120
                height: parent.height
                spacing: 0

                // Header - Up navigation
                Rectangle {
                    width: parent.width
                    height: 40
                    color: PushCloneTheme.surface
                    border.width: 1
                    border.color: PushCloneTheme.border

                    Rectangle {
                        width: 32
                        height: 18
                        radius: 3
                        color: PushCloneTheme.background
                        border.color: PushCloneTheme.border
                        anchors.centerIn: parent

                        Text {
                            anchors.centerIn: parent
                            text: "▲"
                            color: PushCloneTheme.text
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.prevParameterBank()
                        }
                    }
                }

                // Parameter rows (no click, only visual)
                Repeater {
                    model: parameterRows

                    Rectangle {
                        width: parent.width
                        height: 55
                        color: index === activeParameterRow ?
                               PushCloneTheme.surfaceActive :
                               PushCloneTheme.surface
                        border.width: 1
                        border.color: index === activeParameterRow ?
                                     PushCloneTheme.primary :
                                     PushCloneTheme.border

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            // Value of selected track
                            Text {
                                text: {
                                    if (showMasterReturns) {
                                        if (selectedTrackIndex === 3) {
                                            return root.masterData[modelData.valueKey] || "--"
                                        } else {
                                            var returnIndex = (root.returnBank * 3) + selectedTrackIndex
                                            if (returnIndex >= returnModel.count) return "--"
                                            var ret = returnModel.get(returnIndex)
                                            return ret[modelData.valueKey] || "--"
                                        }
                                    } else {
                                        if (selectedTrackIndex >= trackModel.count) return "--"
                                        var track = trackModel.get(selectedTrackIndex)
                                        return track[modelData.valueKey] || "--"
                                    }
                                }
                                font.pixelSize: 13
                                font.bold: true
                                color: index === activeParameterRow ?
                                       PushCloneTheme.primary :
                                       PushCloneTheme.text
                                font.family: PushCloneTheme.fontFamilyMono
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Parameter name
                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "►"
                                    font.pixelSize: 9
                                    color: PushCloneTheme.primary
                                    visible: index === activeParameterRow
                                }

                                Text {
                                    text: modelData.label
                                    font.pixelSize: 10
                                    color: index === activeParameterRow ?
                                           PushCloneTheme.primary :
                                           PushCloneTheme.textDim
                                    font.bold: index === activeParameterRow
                                }
                            }
                        }
                    }
                }

                // Footer - Down navigation
                Rectangle {
                    width: parent.width
                    height: 60
                    color: PushCloneTheme.surface
                    border.width: 1
                    border.color: PushCloneTheme.border

                    Rectangle {
                        width: 32
                        height: 18
                        radius: 3
                        color: PushCloneTheme.background
                        border.color: PushCloneTheme.border
                        anchors.centerIn: parent

                        Text {
                            anchors.centerIn: parent
                            text: "▼"
                            color: PushCloneTheme.text
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.nextParameterBank()
                        }
                    }
                }
            }
        }

        // FOOTER (Navigation + Master Volume)
        Rectangle {
            id: footer
            height: 40
            width: parent.width
            radius: PushCloneTheme.radius
            color: PushCloneTheme.surface
            border.color: PushCloneTheme.border

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                // Track/Return bank navigation (left arrow)
                Rectangle {
                    width: 28
                    height: 28
                    radius: PushCloneTheme.radius
                    border.color: PushCloneTheme.border
                    color: PushCloneTheme.background

                    Text {
                        anchors.centerIn: parent
                        text: "◀"
                        color: PushCloneTheme.text
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (showMasterReturns) {
                                root.returnBank = Math.max(0, root.returnBank - 1)
                            } else {
                                prevTrackBank()
                            }
                        }
                    }
                }

                Text {
                    text: {
                        if (showMasterReturns) {
                            var start = returnBank * 3 + 1
                            var end = Math.min((returnBank + 1) * 3, returnModel.count)
                            return "Returns " + start + "-" + end + " + Master"
                        } else {
                            return "Tracks " + (trackBank * tracksPerBank + 1) + "-" +
                                  Math.min((trackBank + 1) * tracksPerBank, trackModel.count)
                        }
                    }
                    color: PushCloneTheme.text
                    font.pixelSize: 11
                    font.family: PushCloneTheme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Track/Return bank navigation (right arrow)
                Rectangle {
                    width: 28
                    height: 28
                    radius: PushCloneTheme.radius
                    border.color: PushCloneTheme.border
                    color: PushCloneTheme.background

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: PushCloneTheme.text
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (showMasterReturns) {
                                var maxReturnBank = Math.ceil(returnModel.count / 3) - 1
                                root.returnBank = Math.min(maxReturnBank, root.returnBank + 1)
                            } else {
                                nextTrackBank()
                            }
                        }
                    }
                }

                // Track/Master toggle
                Rectangle {
                    width: 70
                    height: 28
                    radius: PushCloneTheme.radius
                    border.color: PushCloneTheme.border
                    color: showMasterReturns ? PushCloneTheme.surfaceActive : PushCloneTheme.background
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: showMasterReturns ? "Tracks" : "M·Ret"
                        color: showMasterReturns ? PushCloneTheme.primary : PushCloneTheme.text
                        font.pixelSize: 9
                        font.family: PushCloneTheme.fontFamily
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            showMasterReturns = !showMasterReturns
                            selectedTrackIndex = 0
                        }
                    }
                }

                Item { width: 1; height: 1 }  // Spacer

                // Master Volume (horizontal bar)
                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Master"
                        color: PushCloneTheme.textDim
                        font.pixelSize: 8
                        font.family: PushCloneTheme.fontFamily
                    }

                    Rectangle {
                        width: 160
                        height: 10
                        radius: 5
                        color: PushCloneTheme.background

                        Rectangle {
                            width: parent.width * root.masterVolume
                            height: parent.height
                            radius: 5
                            color: PushCloneTheme.primary
                        }
                    }
                }

                Text {
                    text: "-3.0 dB"
                    color: PushCloneTheme.text
                    font.pixelSize: 10
                    font.family: PushCloneTheme.fontFamilyMono
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // TRACK COLUMN COMPONENT (inline)
    // ═══════════════════════════════════════════════════════
    component TrackColumn: Rectangle {
        id: trackCol

        // Input properties
        property string trackName: "---"
        property string trackTag: "---"
        property color trackColor: PushCloneTheme.border
        property real trackVolume: 0
        property string volumeLabel: "--"
        property bool isMuted: false
        property bool isSolo: false
        property bool isArmed: false

        property bool isSelected: false
        property int activeParameterRow: 0
        property var parameterRows: []
        property var modelData: null

        // Signals
        signal trackClicked()
        signal muteToggled()
        signal soloToggled()
        signal armToggled()

        color: isSelected ? PushCloneTheme.surfaceActive : PushCloneTheme.background
        border.width: 1
        border.color: isSelected ? PushCloneTheme.primary : PushCloneTheme.border

        Column {
            anchors.fill: parent
            spacing: 0

            // Track header
            Rectangle {
                width: parent.width
                height: 40
                color: trackCol.trackColor
                border.width: isSelected ? 2 : 0
                border.color: PushCloneTheme.primary

                Text {
                    anchors.centerIn: parent
                    text: trackCol.trackName
                    font.pixelSize: 12
                    color: "#000000"
                    font.bold: true
                    font.family: PushCloneTheme.fontFamily
                    elide: Text.ElideRight
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: trackCol.trackClicked()
                }
            }

            // Parameter rows with arc gauges
            Repeater {
                model: parameterRows

                Rectangle {
                    width: parent.width
                    height: 55
                    color: "transparent"
                    border.width: 1
                    border.color: PushCloneTheme.border

                    Canvas {
                        id: gauge
                        anchors.centerIn: parent
                        width: 46
                        height: 28

                        property real value: {
                            if (!trackCol.modelData) return 0
                            return trackCol.modelData[modelData.ratioKey] || 0
                        }

                        onValueChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var centerX = width / 2
                            var centerY = height - 2
                            var radius = 20

                            // Background arc
                            ctx.strokeStyle = index === activeParameterRow ?
                                            PushCloneTheme.surfaceHover :
                                            PushCloneTheme.border
                            ctx.lineWidth = 3.5
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius, Math.PI, 2 * Math.PI)
                            ctx.stroke()

                            // Value arc
                            var angle = Math.PI + (value * Math.PI)
                            ctx.strokeStyle = index === activeParameterRow ?
                                            PushCloneTheme.primary :
                                            PushCloneTheme.textDim
                            ctx.lineWidth = 3.5
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius, Math.PI, angle)
                            ctx.stroke()
                        }
                    }

                    // Highlight active row
                    Rectangle {
                        anchors.fill: parent
                        color: PushCloneTheme.colorWithAlpha(PushCloneTheme.primary, 0.1)
                        visible: index === activeParameterRow
                        z: -1
                    }
                }
            }

            // Volume + M/S/A combined section
            Rectangle {
                width: parent.width
                height: 60
                color: "transparent"
                border.width: 1
                border.color: PushCloneTheme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    // Volume section
                    Column {
                        width: parent.width
                        spacing: 3

                        Text {
                            text: trackCol.volumeLabel
                            font.pixelSize: 10
                            font.family: PushCloneTheme.fontFamilyMono
                            font.bold: true
                            color: PushCloneTheme.text
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 5
                            color: PushCloneTheme.surfaceHover
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                width: parent.width * trackCol.trackVolume
                                height: parent.height
                                radius: 5
                                color: PushCloneTheme.primary
                            }
                        }
                    }

                    // M/S/A buttons
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        // Mute button
                        Rectangle {
                            width: 26
                            height: 20
                            radius: 3
                            border.width: 1
                            border.color: trackCol.isMuted ? PushCloneTheme.warning : PushCloneTheme.border
                            color: trackCol.isMuted ? PushCloneTheme.colorWithAlpha(PushCloneTheme.warning, 0.3) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "M"
                                color: trackCol.isMuted ? PushCloneTheme.warning : PushCloneTheme.textDim
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("M button clicked!")
                                    trackCol.muteToggled()
                                }
                            }
                        }

                        // Solo button
                        Rectangle {
                            width: 26
                            height: 20
                            radius: 3
                            border.width: 1
                            border.color: trackCol.isSolo ? PushCloneTheme.primary : PushCloneTheme.border
                            color: trackCol.isSolo ? PushCloneTheme.colorWithAlpha(PushCloneTheme.primary, 0.3) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "S"
                                color: trackCol.isSolo ? PushCloneTheme.primary : PushCloneTheme.textDim
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("S button clicked!")
                                    trackCol.soloToggled()
                                }
                            }
                        }

                        // Arm button
                        Rectangle {
                            width: 26
                            height: 20
                            radius: 3
                            border.width: 1
                            border.color: trackCol.isArmed ? PushCloneTheme.error : PushCloneTheme.border
                            color: trackCol.isArmed ? PushCloneTheme.colorWithAlpha(PushCloneTheme.error, 0.3) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "A"
                                color: trackCol.isArmed ? PushCloneTheme.error : PushCloneTheme.textDim
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("A button clicked!")
                                    trackCol.armToggled()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
