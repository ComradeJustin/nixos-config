import Quickshell
import Quickshell.Io
import QtQuick
import ".." as Root

// Monitors fcitx5 input method state via fcitx5-remote.
// Provides toggle/activate/deactivate for switching between
// English (direct input) and Japanese (mozc).
//
// Also manages mozc's behavioural settings (live conversion + kanji
// suggestion) by rewriting ~/.config/mozc/config1.db via the helper
// script at scripts/mozc-set-config.py. Mozc has no CLI config, so we
// edit the protobuf wire format directly and bounce mozc_server.
Scope {
    id: root

    // fcitx5-remote state: 0=not running, 1=inactive (EN), 2=active (JP)
    property int state: 0
    property string method: ""
    property bool available: state > 0
    property bool active: state === 2
    property string label: {
        if (!available) return "EN";
        if (active && method.indexOf("mozc") >= 0) return "\u3042";  // あ
        return "EN";
    }

    signal methodSwitched(string oldMethod, string newMethod)

    function toggle() { toggleProc.running = true; }
    function activate() { activateMozcProc.running = true; }
    function deactivate() { deactivateProc.running = true; }

    // Mozc config knobs. liveConversion = on means mozc offers kanji
    // candidates as you type; off means hiragana-only until you press space.
    // prediction = on means suggestion candidates appear from dictionary +
    // history; off means no auto-correct-style suggestions.
    function setLiveConversion(on) {
        mozcConfigProc.command = ["python3", root._scriptPath,
            "use_realtime_conversion=" + (on ? "true" : "false")];
        mozcConfigProc.running = true;
    }

    function setPrediction(on) {
        mozcConfigProc.command = ["python3", root._scriptPath,
            "use_dictionary_suggest=" + (on ? "true" : "false"),
            "use_history_suggest=" + (on ? "true" : "false"),
            "history_learning_level=" + (on ? "0" : "2")];
        mozcConfigProc.running = true;
    }

    // Push all current Config values into mozc at once. Used on startup so
    // mozc's state always reflects the QuickShell config, even if the user
    // edited config.json by hand or this is the first boot.
    function applyAll() {
        var cfg = Root.Config.inputMethod;
        if (!cfg) return;
        mozcConfigProc.command = ["python3", root._scriptPath,
            "use_realtime_conversion=" + (cfg.liveConversion ? "true" : "false"),
            "use_dictionary_suggest=" + (cfg.prediction ? "true" : "false"),
            "use_history_suggest=" + (cfg.prediction ? "true" : "false"),
            "history_learning_level=" + (cfg.prediction ? "0" : "2")];
        mozcConfigProc.running = true;
    }

    readonly property string _scriptPath: Qt.resolvedUrl("../scripts/mozc-set-config.py")
        .toString().replace(/^file:\/\//, "")

    // Combined poll: state + method name in one shot
    Process {
        id: pollProc
        command: ["bash", "-c", "s=$(fcitx5-remote 2>/dev/null || echo 0); n=$(fcitx5-remote -n 2>/dev/null || echo ''); printf '%s:%s' \"$s\" \"$n\""]
        stdout: SplitParser {
            onRead: data => {
                let sep = data.indexOf(":");
                if (sep < 0) return;
                let s = parseInt(data.substring(0, sep));
                if (!isNaN(s)) root.state = s;
                let name = data.substring(sep + 1).trim();
                if (name !== "" && name !== root.method) {
                    let old = root.method;
                    root.method = name;
                    if (old !== "") root.methodSwitched(old, name);
                }
            }
        }
        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 1000
        onTriggered: pollProc.running = true
    }

    // Apply current Config to mozc shortly after startup. Delayed so
    // Root.Config singleton has had time to load from disk.
    Timer {
        id: initApplyTimer
        interval: 500
        running: true
        repeat: false
        onTriggered: root.applyAll()
    }

    Component.onCompleted: pollProc.running = true

    // Action processes
    Process { id: toggleProc; command: ["fcitx5-remote", "-t"] }
    Process { id: deactivateProc; command: ["fcitx5-remote", "-c"] }
    Process { id: activateMozcProc; command: ["fcitx5-remote", "-s", "mozc"] }
    Process { id: mozcConfigProc }
}
