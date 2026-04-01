pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function resolveIcon(path) {
        if (!path || path === "") return "";
        if (path.indexOf("/") !== -1) return "file://" + path;
        return Quickshell.iconPath(path, true);
    }

    function hoverColor(base, opacity) {
        return Qt.rgba(base.r, base.g, base.b, opacity || 0.06);
    }

    function activeColor(base, opacity) {
        return Qt.rgba(base.r, base.g, base.b, opacity || 0.15);
    }
}
