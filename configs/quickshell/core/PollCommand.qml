import Quickshell.Io
import QtQuick

// Reusable poll-execute-wait-repeat cycle for services.
// Wraps the common pattern: run command → parse stdout → wait → repeat.
//
// Usage:
//   PollCommand {
//       command: ["bash", "-c", "cat /proc/stat | head -1"]
//       interval: 3000
//       onLineRead: data => { /* parse data */ }
//   }
//
// Features:
//   - Automatic poll loop (command → wait → command → ...)
//   - Suppress window: call suppressBriefly() after manual changes to skip poll results
//   - Adaptive polling: set activeInterval for faster polling after markActive()
//   - Manual trigger: call run() to start immediately outside the poll cycle
//   - Buffer mode: set buffered=true to accumulate all output, emitted via bufferReady()
Item {
    id: pc
    visible: false

    property var command: []
    property int interval: 3000
    property bool active: true
    property bool autoStart: true

    // Adaptive polling: faster interval after markActive(), reverts after cooldown
    property int activeInterval: -1  // -1 = use interval always
    property int _activeCooldown: 2000
    property bool _recentlyActive: false

    // Suppress poll results briefly (avoids jitter after manual set)
    property bool suppressPoll: false
    property int suppressDuration: 300

    // Buffer mode: accumulate all stdout lines, emit as single string on exit
    property bool buffered: false
    property string _buffer: ""

    signal lineRead(string data)
    signal bufferReady(string data)
    signal exited(int code)

    function run() { _proc.running = true; }

    function suppressBriefly() {
        suppressPoll = true;
        _suppressTimer.restart();
    }

    function markActive() {
        _recentlyActive = true;
        _cooldownTimer.restart();
    }

    Timer {
        id: _suppressTimer
        interval: pc.suppressDuration
        onTriggered: pc.suppressPoll = false
    }

    Timer {
        id: _cooldownTimer
        interval: pc._activeCooldown
        onTriggered: pc._recentlyActive = false
    }

    Process {
        id: _proc
        command: pc.command

        stdout: SplitParser {
            onRead: data => {
                if (pc.suppressPoll) return;
                if (pc.buffered) {
                    pc._buffer += data + "\n";
                } else {
                    pc.lineRead(data);
                }
            }
        }

        onExited: (code) => {
            if (pc.buffered && pc._buffer !== "") {
                pc.bufferReady(pc._buffer);
                pc._buffer = "";
            }
            pc.exited(code);
            if (pc.active) _pollTimer.start();
        }
    }

    Timer {
        id: _pollTimer
        interval: (pc.activeInterval > 0 && pc._recentlyActive) ? pc.activeInterval : pc.interval
        onTriggered: _proc.running = true
    }

    Component.onCompleted: {
        if (autoStart && active && command.length > 0)
            _proc.running = true;
    }
}
