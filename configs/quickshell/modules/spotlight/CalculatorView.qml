import QtQuick
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

// Inline calculator for Spotlight.
// Evaluates math expressions as you type and shows the result.
// Press Enter to copy the result to the clipboard.
SpotlightProvider {
    id: calc
    implicitWidth: parent ? parent.width : 420
    implicitHeight: calcContent.implicitHeight

    // ── Provider identity ──
    providerKey: "calculator"
    providerLabel: "Calculator"
    providerIcon: "󰃬"
    hasSearch: true
    hasGrid: false
    preferredWidth: 420
    preferredMaxHeight: 360

    // ── State ──
    property string expression: ""
    property string result: ""
    property bool hasResult: result !== ""
    property var history: []       // recent calculations
    property int selectedIndex: 0  // selection in history list

    // ── Provider interface ──
    function activate() {
        expression = "";
        result = "";
        selectedIndex = 0;
    }
    function deactivate() {}

    function handleSearchText(text) {
        expression = text;
        evaluate(text);
    }

    function moveUp() {
        if (selectedIndex > 0) selectedIndex--;
    }
    function moveDown() {
        if (selectedIndex < history.length) selectedIndex++;
    }

    function accept() {
        if (hasResult) {
            // Copy result to clipboard
            copyProc.command = ["wl-copy", result];
            copyProc.running = true;

            // Add to history
            var h = history.slice();
            h.unshift({ expr: expression, res: result });
            if (h.length > 20) h = h.slice(0, 20);
            history = h;
            selectedIndex = 0;
        }
    }

    // ── Math evaluation ──
    // Sanitize to only allow safe math characters, then evaluate.
    function evaluate(text) {
        if (!text || text.trim() === "") {
            result = "";
            resultCount = 0;
            return;
        }

        // Normalize common symbols
        var expr = text
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\^/g, "**")
            .replace(/π/g, "Math.PI")
            .replace(/\be\b/g, "Math.E")
            .replace(/sqrt\(/g, "Math.sqrt(")
            .replace(/sin\(/g, "Math.sin(")
            .replace(/cos\(/g, "Math.cos(")
            .replace(/tan\(/g, "Math.tan(")
            .replace(/log\(/g, "Math.log10(")
            .replace(/ln\(/g, "Math.log(")
            .replace(/abs\(/g, "Math.abs(")
            .replace(/ceil\(/g, "Math.ceil(")
            .replace(/floor\(/g, "Math.floor(")
            .replace(/round\(/g, "Math.round(")
            .replace(/pow\(/g, "Math.pow(")
            .replace(/%/g, "/100");

        // Only allow safe characters: digits, operators, parens, dots, spaces, Math.*
        var safe = expr.replace(/Math\.\w+/g, "");
        if (/[^0-9+\-*/().,%\s]/.test(safe)) {
            result = "";
            resultCount = 0;
            return;
        }

        try {
            var val = Function('"use strict"; return (' + expr + ')')();
            if (typeof val === "number" && isFinite(val)) {
                // Format: avoid floating point noise
                if (Number.isInteger(val)) {
                    result = val.toLocaleString();
                } else {
                    // Round to 10 decimal places to avoid float noise
                    result = parseFloat(val.toPrecision(12)).toString();
                }
                resultCount = 1;
            } else {
                result = "";
                resultCount = 0;
            }
        } catch (e) {
            result = "";
            resultCount = 0;
        }
    }

    Process {
        id: copyProc
        command: ["wl-copy", ""]
    }

    // ── Visual ──
    Column {
        id: calcContent
        width: parent.width
        spacing: 0

        // ── Result display ──
        Item {
            width: parent.width
            height: calc.hasResult ? resultCol.height + 32 : emptyHeight
            visible: true

            property int emptyHeight: 120

            Column {
                id: resultCol
                anchors { left: parent.left; right: parent.right; margins: Root.Theme.spacingL; verticalCenter: parent.verticalCenter }
                spacing: Root.Theme.spacingS
                visible: calc.hasResult

                Text {
                    width: parent.width
                    text: calc.expression
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "= " + calc.result
                    color: Root.Theme.accentPrimary
                    font { family: Root.Theme.fontDisplay; pixelSize: Root.Theme.fontSize5XL; bold: true; features: ({ "tnum": 1 }) }
                    elide: Text.ElideRight
                }

                Text {
                    text: "↵ Enter to copy"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                    opacity: 0.6
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: Root.Theme.spacingS
                visible: !calc.hasResult && calc.expression === ""

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰃬"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.scaled(32) }
                    opacity: 0.4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Type a math expression"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                    opacity: 0.5
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Supports: + - * / ^ sqrt() sin() cos() π"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                    opacity: 0.3
                }
            }

            // Invalid expression hint
            Text {
                anchors.centerIn: parent
                visible: !calc.hasResult && calc.expression !== ""
                text: "..."
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize2XL }
                opacity: 0.4
            }
        }

        // ── History ──
        Rectangle {
            width: parent.width
            height: 1
            color: Root.Theme.textDimmed
            opacity: 0.15
            visible: calc.history.length > 0
        }

        Column {
            width: parent.width
            visible: calc.history.length > 0

            Item {
                width: parent.width; height: 28
                Text {
                    anchors { left: parent.left; leftMargin: Root.Theme.spacingL; verticalCenter: parent.verticalCenter }
                    text: "HISTORY"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS; bold: true; letterSpacing: Root.Theme.trackingCaps }
                    opacity: 0.5
                }
            }

            Repeater {
                model: calc.history
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 420
                    height: 36
                    color: index === calc.selectedIndex - 1
                        ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.08)
                        : histMouse.containsMouse
                            ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.04)
                            : "transparent"

                    Row {
                        anchors { left: parent.left; leftMargin: Root.Theme.spacingL; verticalCenter: parent.verticalCenter }
                        spacing: Root.Theme.spacingS

                        Text {
                            text: modelData.expr
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "="
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                            opacity: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.res
                            color: Root.Theme.accentPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: histMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            copyProc.command = ["wl-copy", modelData.res];
                            copyProc.running = true;
                        }
                    }
                }
            }
        }

        // Bottom padding
        Item { width: 1; height: 8 }
    }
}
