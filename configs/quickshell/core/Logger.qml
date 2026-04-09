pragma Singleton
import QtQuick

// Tag-based logger with level gating.
//
// Usage:
//   import "../core" as Core
//   Core.Logger.i("WifiService", "scan started")
//   Core.Logger.d("NotifService", "entry", id, "updated")
//   Core.Logger.w("HooksService", "missing script", path)
//   Core.Logger.e("PowerService", "failed to read capacity:", err)
//
// Output format: [HH:MM:SS]  tag  message
// The tag is padded/truncated to a fixed width so log lines align visually
// in the terminal, which makes it much easier to scan for a particular
// service when several are active.
//
// Debug logs are gated by `debugEnabled` (default off). Toggle via IPC or
// directly at runtime: Core.Logger.debugEnabled = true.
QtObject {
    id: root

    // Gate for d() calls. Flip true to see verbose traces.
    property bool debugEnabled: false

    // Width for the tag column. Matches Noctalia's convention (14).
    readonly property int _tagWidth: 14

    // ANSI color codes — QtCreator/journalctl render these; if output is
    // piped somewhere that can't, they're harmless escape sequences.
    readonly property string _cTime: "\x1b[36m"  // cyan
    readonly property string _cTag:  "\x1b[35m"  // magenta
    readonly property string _cWarn: "\x1b[33m"  // yellow
    readonly property string _cErr:  "\x1b[31m"  // red
    readonly property string _cRst:  "\x1b[0m"

    function _ts() {
        var d = new Date();
        function pad(n) { return n < 10 ? "0" + n : "" + n; }
        return pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
    }

    function _fmtTag(tag) {
        var t = (tag || "").substring(0, _tagWidth);
        while (t.length < _tagWidth) t = " " + t;
        return t;
    }

    // Join argv starting at `start` with spaces, stringifying non-strings.
    function _joinArgs(args, start) {
        var out = [];
        for (var i = start; i < args.length; i++) {
            var v = args[i];
            if (typeof v === "object") {
                try { out.push(JSON.stringify(v)); }
                catch (e) { out.push(String(v)); }
            } else {
                out.push(String(v));
            }
        }
        return out.join(" ");
    }

    function _format(tag, color, args) {
        return _cTime + "[" + _ts() + "]" + _cRst
             + " " + color + _fmtTag(tag) + _cRst
             + " " + _joinArgs(args, 1);
    }

    function d() {
        if (!debugEnabled) return;
        console.debug(_format(arguments[0], _cTag, arguments));
    }

    function i() {
        console.info(_format(arguments[0], _cTag, arguments));
    }

    function w() {
        console.warn(_format(arguments[0], _cWarn, arguments));
    }

    function e() {
        console.error(_format(arguments[0], _cErr, arguments));
    }
}
