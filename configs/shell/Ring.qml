import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, carrying the whole shell.
//
// Station names travel on a braille orbit around a large clock. h and l
// turn the ring, and the name on the right is the focused one, shown in
// reverse video. Enter opens it: the ring's names are wiped away and a
// page (Panel.qml) is wiped in where the focused name was. Rows of a page
// can open further pages; esc backs out one page at a time.
//
// There is one way for anything here to appear or disappear: a dithered
// front wipes across it from the left, and wipes back to take it away. The
// orbit is plotted clockwise from the right, and each name is wiped in as
// the plot reaches it, so the ring draws itself round in a sweep. The
// dimming behind it dithers in and out. The only movement is the ring
// turning, in whole jumps on the character grid; the name that takes focus
// flashes bright for a moment.
PanelWindow {
    id: ring

    // The shell root (shell.qml), which holds the state.
    required property var shell

    readonly property var stations: shell.stations
    readonly property int stationCount: stations.length
    readonly property real stepDegrees: 360 / stationCount
    // How many letters the longest station name has.
    readonly property int longestName: {
        let longest = 0;
        for (const station of stations)
            longest = Math.max(longest, station.name.length);
        return longest;
    }

    // --- The four animated values ---
    // Each runs at a steady rate with no easing. They are chained so that
    // things happen in order: opening a station wipes the names away and
    // then wipes the page in; going from one page to another wipes the
    // first away and then the second in; leaving wipes the page away and
    // then brings the names back; closing wipes away whatever is showing
    // and then shuts the ring.

    // How much of the ring is showing: 0 = closed, 1 = open. It stays open
    // until an open page has been wiped away.
    property real openness: shell.ringOpen || panelOpen ? 1 : 0
    // Rotation of the ring, in degrees. shell.turns counts presses and
    // never wraps, so the ring keeps turning the same way when it passes
    // the last station.
    property real angle: -stepDegrees * shell.turns
    // 0 = the names, orbit and hints are showing. 1 = they are wiped away,
    // to make room for a page or because the ring is closing.
    property real aside: !shell.ringOpen || shell.dived || panelOpen ? 1 : 0
    // How much of the page is showing. It starts only once the names have
    // been wiped away, and drops to nothing while a change of page waits.
    property real dive: shell.dived && !shell.stackPending && aside === 1 ? 1 : 0

    // --- What is drawn from them ---
    // One turn is drawn as a few equal jumps round the orbit.
    readonly property real angleJump: stepDegrees / Theme.turnSteps
    readonly property real drawnAngle: Math.round(angle / angleJump) * angleJump
    // How much of the ring's own names, orbit and hints is showing, from 0 to 1.
    readonly property real ringShown: Math.min(openness, 1 - aside)
    // The orbit is fully plotted when the ring is this far shown; the rest
    // of the time lets the last name finish wiping in.
    readonly property real sweepShare: 0.7
    // True from when a page starts to wipe in until it has been wiped away.
    readonly property bool panelOpen: dive > 0

    // The page on screen has gone: let the waiting change of page happen.
    onDiveChanged: {
        if (dive === 0 && shell.stackPending)
            shell.commitStack();
    }

    Connections {
        target: ring.shell

        // No page is on screen, so there is nothing to wipe away first.
        function onStackPendingChanged(): void {
            if (ring.shell.stackPending && ring.dive === 0)
                ring.shell.commitStack();
        }
    }

    Behavior on openness {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }
    Behavior on angle {
        NumberAnimation {
            duration: Theme.turnMs
        }
    }
    Behavior on aside {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }
    Behavior on dive {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // --- Geometry, all on the character grid ---
    // The orbit is forty cells across at most, and smaller when the screen
    // is not tall enough for that.
    readonly property real orbitRadius: Theme.snapY(Math.min(40 * Theme.cellWidth, height * 0.37))
    readonly property real centerX: Theme.snapX(width / 2)
    readonly property real centerY: Theme.snapY(height / 2)

    // The orbit is one block of braille text centred on the ring. Each
    // cell holds two columns of four dots, so a dot is half a cell wide and
    // a quarter of a cell tall, which is the same distance both ways.
    readonly property int orbitColumns: 2 * Math.ceil(orbitRadius / Theme.cellWidth) + 2
    readonly property int orbitRows: 2 * Math.ceil(orbitRadius / Theme.cellHeight) + 2
    readonly property real dotPitch: Theme.cellWidth / 2
    // How many points the circle is plotted with, and how many pixels
    // around each station's name are left clear of them.
    readonly property int orbitPoints: 250
    readonly property real orbitGap: 3 * Theme.dotSize
    // A braille character's code is 0x2800 plus one bit per raised dot.
    // These are the bits of a cell's left and right column, top dot first.
    readonly property var leftDots: [0x01, 0x02, 0x04, 0x40]
    readonly property var rightDots: [0x08, 0x10, 0x20, 0x80]

    function clamp01(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    // Whether a point of the orbit, given from the ring's centre, falls
    // behind a station's name or closer to it than the gap.
    function behindName(pointX: real, pointY: real, turnedDegrees: real): bool {
        for (let station = 0; station < ring.stationCount; station++) {
            const theta = (ring.stepDegrees * station + turnedDegrees) * Math.PI / 180;
            // A name is at double size, with two cells of margin each side.
            const halfWidth = (ring.stations[station].name.length + 2) * Theme.cellWidth + ring.orbitGap;
            const halfHeight = Theme.cellHeight + ring.orbitGap;
            const fromNameX = Math.abs(pointX - ring.orbitRadius * Math.cos(theta));
            const fromNameY = Math.abs(pointY - ring.orbitRadius * Math.sin(theta));
            if (fromNameX < halfWidth && fromNameY < halfHeight)
                return true;
        }
        return false;
    }

    // The orbit as text: the first `plottedPoints` points of the circle,
    // clockwise from the right, with the ring turned by `turnedDegrees`.
    function orbitText(plottedPoints: int, turnedDegrees: real): string {
        const cells = new Array(ring.orbitColumns * ring.orbitRows).fill(0);
        const middleX = ring.orbitColumns / 2 * Theme.cellWidth;
        const middleY = ring.orbitRows / 2 * Theme.cellHeight;
        for (let point = 0; point < plottedPoints; point++) {
            const theta = point * 2 * Math.PI / ring.orbitPoints;
            const pointX = ring.orbitRadius * Math.cos(theta);
            const pointY = ring.orbitRadius * Math.sin(theta);
            if (ring.behindName(pointX, pointY, turnedDegrees))
                continue;
            const dotColumn = Math.floor((middleX + pointX) / ring.dotPitch);
            const dotRow = Math.floor((middleY + pointY) / ring.dotPitch);
            const cell = Math.floor(dotRow / 4) * ring.orbitColumns + Math.floor(dotColumn / 2);
            const dots = dotColumn % 2 === 0 ? ring.leftDots : ring.rightDots;
            cells[cell] |= dots[dotRow % 4];
        }
        const lines = [];
        for (let row = 0; row < ring.orbitRows; row++) {
            let line = "";
            for (let column = 0; column < ring.orbitColumns; column++)
                line += String.fromCharCode(0x2800 + cells[row * ring.orbitColumns + column]);
            lines.push(line);
        }
        return lines.join("\n");
    }

    // Stay mapped until the ring has closed all the way.
    visible: shell.ringOpen || openness > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.ringOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            stage.forceActiveFocus();
    }

    // Dim everything behind the ring. It dithers in as the ring opens and
    // out as it closes.
    Dim {
        level: ring.openness
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const shell = ring.shell;
            const key = event.key;
            // Whether letters go into a text field: the page's own, or
            // the search field that "/" brings up on any other page.
            const hasField = shell.page !== null && (shell.page.field !== undefined || shell.searching);
            event.accepted = true;

            if (key === Qt.Key_Escape) {
                shell.back();
                return;
            }
            if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                shell.act();
                return;
            }

            // The ring's names are showing: turn it, or open the focused one.
            if (!shell.dived) {
                if (key === Qt.Key_L || key === Qt.Key_Right)
                    shell.rotate(1);
                else if (key === Qt.Key_H || key === Qt.Key_Left)
                    shell.rotate(-1);
                else if (key === Qt.Key_Space)
                    shell.act();
                return;
            }

            // A page is open. The arrows always move the selection.
            if (key === Qt.Key_Down) {
                shell.moveSelection(1);
                return;
            }
            if (key === Qt.Key_Up) {
                shell.moveSelection(-1);
                return;
            }

            // With a text field, the other keys edit its text.
            if (hasField) {
                const control = (event.modifiers & Qt.ControlModifier) !== 0;
                if (key === Qt.Key_Left)
                    shell.placeCursor(shell.cursor - 1);
                else if (key === Qt.Key_Right)
                    shell.placeCursor(shell.cursor + 1);
                else if (key === Qt.Key_Home || (control && key === Qt.Key_A))
                    shell.placeCursor(0);
                else if (key === Qt.Key_End || (control && key === Qt.Key_E))
                    shell.placeCursor(shell.query.length);
                else if (control && key === Qt.Key_U)
                    shell.clearText();
                else if (key === Qt.Key_Backspace)
                    shell.eraseText();
                else if (key === Qt.Key_Delete)
                    shell.deleteText();
                else if (event.text.length === 1 && event.text >= " ")
                    shell.typeText(event.text);
                return;
            }

            // Without one, "/" brings up a search field.
            if (key === Qt.Key_Slash) {
                shell.searching = true;
                return;
            }

            // And the letters move too. On a level, left and right move
            // the level; anywhere else they go back and act.
            const left = key === Qt.Key_H || key === Qt.Key_Left;
            const right = key === Qt.Key_L || key === Qt.Key_Right;
            const onLevel = shell.pageRows.length > 0 && shell.pageRows[shell.selectedIndex].kind === "level";
            if (key === Qt.Key_J)
                shell.moveSelection(1);
            else if (key === Qt.Key_K)
                shell.moveSelection(-1);
            else if (left && onLevel)
                shell.adjust(-1);
            else if (right && onLevel)
                shell.adjust(1);
            else if (left)
                shell.back();
            else if (right)
                shell.act();
        }

        // --- The mouse on the empty part of the ring ---
        // A click beside everything goes back one step, like esc. The
        // wheel turns the ring while its names are showing.
        MouseArea {
            anchors.fill: parent
            onClicked: ring.shell.back()
            onWheel: wheel => {
                if (!ring.shell.dived)
                    ring.shell.rotate(wheel.angleDelta.y > 0 ? -1 : 1);
            }
        }

        // --- The orbit ---
        // Plotted clockwise from the right, and un-plotted in reverse.
        Label {
            x: ring.centerX - ring.orbitColumns / 2 * Theme.cellWidth
            y: ring.centerY - ring.orbitRows / 2 * Theme.cellHeight
            visible: ring.ringShown > 0
            text: ring.orbitText(Math.round(ring.clamp01(ring.ringShown / ring.sweepShare) * ring.orbitPoints), ring.drawnAngle)
            color: Theme.inkDim
        }

        // --- The clock at the centre: the time at four times size, the date under it ---
        // Wiped in as the ring opens and away as it closes.
        Item {
            id: clock

            readonly property string timeText: Qt.formatDateTime(ring.shell.now, "hh:mm")
            readonly property string dateText: Qt.formatDateTime(ring.shell.now, "dddd d MMMM")
            // Steps back to the border colour while a page is open.
            readonly property bool steppedBack: ring.shell.dived || ring.panelOpen
            // As wide as the wider of its two lines, in cells.
            readonly property int columns: Math.max(timeText.length * 4, dateText.length)

            x: ring.centerX - Theme.snapX(width / 2)
            y: ring.centerY - 3 * Theme.cellHeight
            width: columns * Theme.cellWidth
            height: 5 * Theme.cellHeight
            visible: ring.openness > 0
            // Drawn through the dither only while it is changing.
            layer.enabled: ring.openness < 1
            layer.effect: DitherFade {
                amount: ring.openness
                spread: Theme.wipeFront
            }

            Label {
                x: Theme.snapX((clock.width - width) / 2)
                text: clock.timeText
                scaleFactor: 4
                color: clock.steppedBack ? Theme.line : Theme.ink
            }

            Label {
                x: Theme.snapX((clock.width - width) / 2)
                y: 4 * Theme.cellHeight
                text: clock.dateText
                color: clock.steppedBack ? Theme.line : Theme.inkDim
                smallCaps: true
            }
        }

        // --- Stations ---
        Repeater {
            model: ring.stations

            // Zero-sized, sitting on its point of the orbit, snapped to the
            // grid; the name is placed around that point.
            Item {
                id: station

                required property var modelData
                required property int index

                readonly property bool focused: index === ring.shell.focusedIndex
                readonly property string nameText: modelData.name
                readonly property real degrees: ring.stepDegrees * index + ring.drawnAngle
                readonly property real theta: degrees * Math.PI / 180
                // Where this station sits on the orbit, as a share of the way
                // round clockwise from the right: 0 on the right, 0.5 on the left.
                readonly property real orbitShare: ((degrees % 360) + 360) % 360 / 360
                // How much of the name is showing. It starts when the plotted
                // orbit reaches this station, so the names appear in a sweep.
                readonly property real shown: ring.clamp01((ring.ringShown - ring.sweepShare * orbitShare) / (1 - ring.sweepShare))
                readonly property int nameWidth: nameText.length * Theme.cellWidth * 2

                z: focused ? 1 : 0
                x: ring.centerX + Theme.snapX(ring.orbitRadius * Math.cos(theta))
                y: ring.centerY + Theme.snapY(ring.orbitRadius * Math.sin(theta))

                onFocusedChanged: {
                    if (focused)
                        focusFlash.restart();
                }

                Timer {
                    id: focusFlash

                    interval: Theme.flashMs
                }

                // The name at double size, with two cells of margin each
                // side. The focused one is in reverse video.
                Item {
                    x: -Theme.snapX(station.nameWidth / 2) - 2 * Theme.cellWidth
                    y: -Theme.cellHeight
                    width: station.nameWidth + 4 * Theme.cellWidth
                    height: 2 * Theme.cellHeight
                    visible: station.shown > 0
                    // Drawn through the dither only while it is changing.
                    layer.enabled: station.shown < 1
                    layer.effect: DitherFade {
                        amount: station.shown
                        spread: Theme.wipeFront
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: station.focused
                        color: focusFlash.running ? Theme.ink : Theme.accent
                    }

                    Label {
                        x: 2 * Theme.cellWidth
                        text: station.nameText
                        scaleFactor: 2
                        color: station.focused ? Theme.slab : Theme.inkSoft
                    }

                    // A click opens the focused name, and turns the ring
                    // to any other.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (station.focused)
                                ring.shell.act();
                            else
                                ring.shell.focusStation(station.index);
                        }
                    }
                }
            }
        }

        // A click on the page itself, outside its rows, does nothing: it
        // must not reach the empty part of the ring and go back.
        MouseArea {
            anchors.fill: page
            visible: page.visible
        }

        // --- The open page, wiped in where the focused name was ---
        Panel {
            id: page

            // Always in the same place whichever station is open: where
            // the block of the longest name starts, moved left as far as
            // it takes to stay on the screen.
            x: Math.min(ring.centerX + ring.orbitRadius - ring.longestName * Theme.cellWidth - 2 * Theme.cellWidth, Theme.snapX(parent.width - implicitWidth - Theme.cellWidth))
            y: ring.centerY - Theme.cellHeight
            visible: ring.panelOpen
            page: ring.shell.page
            entries: ring.shell.pageRows
            selectedIndex: ring.shell.selectedIndex
            query: ring.shell.query
            cursor: ring.shell.cursor
            searchable: true
            searching: ring.shell.searching
            // A page can ask for more room for its labels.
            valueColumn: ring.shell.page !== null && ring.shell.page.valueColumn !== undefined ? ring.shell.page.valueColumn : 18
            shown: ring.dive
            // The mouse selects the row it is over, a click acts on it,
            // and the wheel moves the selection.
            interactive: true
            onRowEntered: entryIndex => {
                if (!ring.shell.stackPending)
                    ring.shell.select(entryIndex);
            }
            onRowClicked: entryIndex => {
                if (ring.shell.stackPending)
                    return;
                ring.shell.select(entryIndex);
                ring.shell.act();
            }
            onWheelTurned: step => ring.shell.moveSelection(step)
        }

        // --- A picture of the selected row, when it has one ---
        // Shown above the page, for choosing a wallpaper. The picture is
        // drawn in two colours, like everything else.
        Box {
            id: preview

            // The selected row's picture, or "" when it has none.
            readonly property string image: {
                const rows = ring.shell.pageRows;
                const row = rows.length > 0 ? rows[ring.shell.selectedIndex] : undefined;
                return row && row.image ? row.image : "";
            }

            x: page.x
            y: page.y - implicitHeight
            visible: ring.panelOpen && image !== ""
            columns: page.columns
            rows: 13
            title: "preview"
            shown: ring.dive

            Image {
                anchors.fill: parent
                source: preview.image === "" ? "" : "file://" + preview.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // No larger than it is drawn.
                sourceSize.width: width
                layer.enabled: true
                layer.effect: DitherImage {}
            }
        }

        // --- Key hints for the ring view; an open page carries its own ---
        Row {
            x: Theme.snapX((parent.width - width) / 2)
            y: Theme.snapY(parent.height - 2 * Theme.cellHeight)
            visible: ring.ringShown > 0
            // Drawn through the dither only while it is changing.
            layer.enabled: ring.ringShown < 1
            layer.effect: DitherFade {
                amount: ring.ringShown
                spread: Theme.wipeFront
            }

            Repeater {
                model: [["←→ hl", " turn    "], ["↵", " open    "], ["esc", " close"]]

                Row {
                    required property var modelData

                    Label {
                        text: parent.modelData[0]
                        color: Theme.ink
                    }

                    Label {
                        text: parent.modelData[1]
                        color: Theme.inkDim
                    }
                }
            }
        }
    }
}
