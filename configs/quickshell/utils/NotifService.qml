import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property bool dnd: false
    property int unreadCount: 0
    property int timeout: 5000
    property int maxVisible: 5

    // Toast popup stacked model for display
    property var popupStacks: ListModel {}
    property var popupItems: []

    // CC stacked notification model
    property var stacks: ListModel {}
    property var items: []
    property int counter: 0
    property var expanded: ({})

    // Helper to safely read a string property
    function safeStr(val) {
        if (val === null || val === undefined) return "";
        return "" + val;
    }

    // Helper to resolve image path for display
    // Handles: URLs (file://, https://), absolute paths, icon names (firefox)
    function resolveImg(p) {
        if (!p || p === "") return "";
        if (p.indexOf("://") !== -1) return p;
        if (p.charAt(0) === "/") return "file://" + p;
        // Assume freedesktop icon name (e.g. "firefox", "spotify")
        return "image://icon/" + p;
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: notification => {
            try {
                notification.tracked = true;
                root.handleNotification(notification);
            } catch(e) {
                console.log("NotifService error: " + e);
            }
        }
    }

    function handleNotification(n) {
        var appName = safeStr(n.appName);
        var summary = safeStr(n.summary);
        var body = safeStr(n.body);
        var img = safeStr(n.image);

        // Try to get app icon (notify-send sends this as app_icon)
        var appIcon = "";
        try { appIcon = safeStr(n.appIcon); } catch(e) {}

        // Use image if available, otherwise app icon
        var displayImg = resolveImg(img);
        if (displayImg === "" && appIcon !== "") displayImg = resolveImg(appIcon);

        var urg = n.urgency;

        var dur = root.timeout;
        if (urg === NotificationUrgency.Critical) dur = dur * 3;

        root.counter = root.counter + 1;
        var ts = new Date();
        var h = ts.getHours();
        var mn = ts.getMinutes();
        var timeStr = h + ":" + (mn < 10 ? "0" : "") + mn;

        var entry = {
            nId: root.counter,
            appName: appName,
            summary: summary,
            body: body,
            imagePath: displayImg,
            timestamp: timeStr
        };

        var arr = root.items.slice();
        arr.unshift(entry);
        root.items = arr;
        root.rebuildStacks();
        root.unreadCount = root.unreadCount + 1;

        if (!root.dnd || urg === NotificationUrgency.Critical) {
            var newExpiry = Date.now() + dur;
            var pArr = root.popupItems.slice();
            // Reset expiry for all existing popups from same app
            for (var pi = 0; pi < pArr.length; pi++) {
                if (pArr[pi].appName === appName) {
                    pArr[pi].expiry = newExpiry;
                }
            }
            pArr.unshift({
                appName: appName,
                summary: summary,
                body: body,
                imagePath: displayImg,
                expiry: newExpiry
            });
            root.popupItems = pArr;
            root.rebuildPopupStacks();
        }
    }

    // ── Watch tracked notifications for property changes (Spotify replacements) ──
    // When Spotify changes tracks, it sends a replacement notification.
    // The NotificationServer may update the existing Notification object
    // instead of firing onNotification again.
    Connections {
        target: server
        function onTrackedNotificationsChanged() {
            root.syncTracked();
        }
    }

    Timer {
        // Poll tracked notifications for property changes
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.syncTracked()
    }

    property var lastSeen: ({})

    function syncTracked() {
        try {
            var tracked = server.trackedNotifications;
            if (!tracked) return;
            var vals = tracked.values;
            if (!vals) return;

            for (var i = 0; i < vals.length; i++) {
                var n = vals[i];
                if (!n) continue;
                var appName = safeStr(n.appName);
                var summary = safeStr(n.summary);
                var body = safeStr(n.body);
                var img = safeStr(n.image);
                var appIcon = "";
                try { appIcon = safeStr(n.appIcon); } catch(e) {}
                var displayImg = resolveImg(img);
                if (displayImg === "" && appIcon !== "") displayImg = resolveImg(appIcon);

                // Key only on appName + summary (not body which may change constantly)
                var key = appName + "|" + summary;

                var prevKey = root.lastSeen[appName];
                if (prevKey !== key && prevKey !== undefined) {
                    // Summary changed — this is a real replacement (e.g. new track)
                    // Add to history
                    root.counter = root.counter + 1;
                    var ts = new Date();
                    var h = ts.getHours();
                    var mn = ts.getMinutes();
                    var timeStr = h + ":" + (mn < 10 ? "0" : "") + mn;

                    var entry = {
                        nId: root.counter,
                        appName: appName,
                        summary: summary,
                        body: body,
                        imagePath: displayImg,
                        timestamp: timeStr
                    };

                    var arr = root.items.slice();
                    arr.unshift(entry);
                    root.items = arr;
                    root.rebuildStacks();
                    root.unreadCount = root.unreadCount + 1;

                    // Add popup
                    var dur = root.timeout;
                    var newExpiry = Date.now() + dur;
                    var pArr = root.popupItems.slice();
                    for (var pi = 0; pi < pArr.length; pi++) {
                        if (pArr[pi].appName === appName) pArr[pi].expiry = newExpiry;
                    }
                    pArr.unshift({
                        appName: appName,
                        summary: summary,
                        body: body,
                        imagePath: displayImg,
                        expiry: newExpiry
                    });
                    root.popupItems = pArr;
                    root.rebuildPopupStacks();
                }
                root.lastSeen[appName] = key;
            }
        } catch(e) {
            console.log("syncTracked error: " + e);
        }
    }

    // ── Popup stacking ──
    // Updates popupStacks in-place to avoid destroying QML delegates
    function rebuildPopupStacks() {
        var now = Date.now();
        // Purge expired items
        var alive = root.popupItems.filter(function(x) { return x.expiry > now; });
        if (alive.length !== root.popupItems.length) root.popupItems = alive;

        // Build grouped data
        var groups = {};
        var order = [];
        for (var i = 0; i < alive.length; i++) {
            var p = alive[i];
            var key = p.appName || "Unknown";
            if (!groups[key]) { groups[key] = []; order.push(key); }
            groups[key].push(p);
        }

        // Mark stacks for apps no longer present as dismissing (don't remove yet)
        for (var r = popupStacks.count - 1; r >= 0; r--) {
            var entry = popupStacks.get(r);
            if (!groups[entry.appName] && !entry.dismissing) {
                popupStacks.setProperty(r, "dismissing", true);
            }
        }

        // Update existing or insert new
        var shown = 0;
        for (var j = 0; j < order.length; j++) {
            if (shown >= root.maxVisible) break;
            var gKey = order[j];
            var list = groups[gKey];
            var found = false;

            for (var k = 0; k < popupStacks.count; k++) {
                if (popupStacks.get(k).appName === gKey) {
                    popupStacks.setProperty(k, "summary", list[0].summary);
                    popupStacks.setProperty(k, "body", list[0].body);
                    popupStacks.setProperty(k, "imagePath", list[0].imagePath);
                    popupStacks.setProperty(k, "count", list.length);
                    popupStacks.setProperty(k, "dismissing", false);
                    found = true;
                    break;
                }
            }

            if (!found) {
                popupStacks.append({
                    "appName": gKey,
                    "summary": list[0].summary,
                    "body": list[0].body,
                    "imagePath": list[0].imagePath,
                    "count": list.length,
                    "dismissing": false
                });
            }
            shown = shown + 1;
        }
    }

    // Called from QML after fade-out animation finishes
    function removePopupApp(appName) {
        for (var i = popupStacks.count - 1; i >= 0; i--) {
            if (popupStacks.get(i).appName === appName) {
                popupStacks.remove(i);
                break;
            }
        }
    }

    function dismissPopupApp(appName) {
        root.popupItems = root.popupItems.filter(function(x) { return x.appName !== appName; });
        // Mark as dismissing — delegate will animate out then call removePopupApp
        for (var i = popupStacks.count - 1; i >= 0; i--) {
            if (popupStacks.get(i).appName === appName) {
                popupStacks.setProperty(i, "dismissing", true);
                break;
            }
        }
    }

    // Tick timer - expires old popups
    Timer {
        id: popupTick
        interval: 1000
        repeat: true
        running: root.popupItems.length > 0
        onTriggered: root.rebuildPopupStacks()
    }

    function toggleExpand(appName) {
        var e = root.expanded;
        e[appName] = !e[appName];
        root.expanded = e;
        rebuildStacks();
    }

    function removeOne(nId) {
        root.items = root.items.filter(function(x) { return x.nId !== nId; });
        rebuildStacks();
    }

    function removeApp(appName) {
        root.items = root.items.filter(function(x) { return x.appName !== appName; });
        // Reset lastSeen for this app so syncTracked doesn't re-add
        var ls = root.lastSeen;
        delete ls[appName];
        root.lastSeen = ls;
        // Dismiss tracked notifications from this app
        try {
            var tracked = server.trackedNotifications;
            if (tracked) {
                var vals = tracked.values;
                if (vals) {
                    for (var i = 0; i < vals.length; i++) {
                        if (vals[i] && safeStr(vals[i].appName) === appName) {
                            vals[i].tracked = false;
                        }
                    }
                }
            }
        } catch(e) {}
        rebuildStacks();
    }

    function clearAll() {
        root.items = [];
        root.unreadCount = 0;
        root.lastSeen = {};
        // Dismiss all tracked notifications
        try {
            var tracked = server.trackedNotifications;
            if (tracked) {
                var vals = tracked.values;
                if (vals) {
                    for (var i = vals.length - 1; i >= 0; i--) {
                        if (vals[i]) vals[i].tracked = false;
                    }
                }
            }
        } catch(e) {}
        rebuildStacks();
    }

    function rebuildStacks() {
        stacks.clear();
        var groups = {};
        var order = [];

        for (var i = 0; i < root.items.length; i++) {
            var n = root.items[i];
            var key = n.appName || "Unknown";
            if (!groups[key]) {
                groups[key] = [];
                order.push(key);
            }
            groups[key].push(n);
        }

        for (var j = 0; j < order.length; j++) {
            var gKey = order[j];
            var list = groups[gKey];
            var isExp = root.expanded[gKey] || false;

            stacks.append({
                isHeader: true,
                appName: gKey,
                count: list.length,
                summary: list[0].summary,
                body: list[0].body,
                imagePath: list[0].imagePath,
                nId: list[0].nId,
                timestamp: list[0].timestamp,
                expanded: isExp
            });

            if (isExp) {
                for (var k = 1; k < list.length; k++) {
                    stacks.append({
                        isHeader: false,
                        appName: gKey,
                        count: 0,
                        summary: list[k].summary,
                        body: list[k].body,
                        imagePath: list[k].imagePath,
                        nId: list[k].nId,
                        timestamp: list[k].timestamp,
                        expanded: false
                    });
                }
            }
        }
    }
}
