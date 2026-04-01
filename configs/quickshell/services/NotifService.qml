import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property bool dnd: false
    property int unreadCount: 0
    property int timeout: 5000
    property int maxVisible: 5

    property var popupStacks: ListModel {}
    property var popupItems: []

    property var stacks: ListModel {}
    property var items: []
    property int counter: 0
    property var expanded: ({})

    // ── Image copy queue ──
    property var imgCopyQueue: []
    property bool imgCopyBusy: false

    function safeStr(val) {
        if (val === null || val === undefined) return "";
        return "" + val;
    }

    function resolveImg(p) {
        if (!p || p === "") return "";
        if (p.indexOf("://") !== -1) return p;
        if (p.charAt(0) === "/") return "file://" + p;
        return Quickshell.iconPath(p, true);
    }

    function queueImageCopy(srcPath, nId) {
        if (!srcPath || srcPath === "" || srcPath.charAt(0) !== "/") return;
        var ext = ".png";
        var dotIdx = srcPath.lastIndexOf(".");
        if (dotIdx !== -1) ext = srcPath.substring(dotIdx);
        var destPath = "/tmp/qs-notif-" + nId + ext;
        imgCopyQueue.push({ src: srcPath, dest: destPath, nId: nId });
        processImgCopyQueue();
    }

    function processImgCopyQueue() {
        if (imgCopyBusy || imgCopyQueue.length === 0) return;
        imgCopyBusy = true;
        var item = imgCopyQueue.shift();
        imgCopyProc.targetNId = item.nId;
        imgCopyProc.destPath = item.dest;
        imgCopyProc.command = ["cp", "-f", item.src, item.dest];
        imgCopyProc.running = true;
    }

    Process {
        id: imgCopyProc
        property int targetNId: -1
        property string destPath: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && imgCopyProc.destPath !== "") {
                root.updateNotifImage(imgCopyProc.targetNId, "file://" + imgCopyProc.destPath);
            }
            root.imgCopyBusy = false;
            root.processImgCopyQueue();
        }
    }

    function updateNotifImage(nId, newPath) {
        for (var i = 0; i < root.items.length; i++) {
            if (root.items[i].nId === nId) {
                root.items[i].imagePath = newPath;
                break;
            }
        }
        rebuildStacks();
        rebuildPopupStacks();
    }

    // ── Shared entry creation (deduplicates handleNotification + syncTracked) ──
    function createEntry(appName, summary, body, img, appIcon) {
        root.counter = root.counter + 1;

        var displayImg = resolveImg(img);
        if (displayImg === "" && appIcon !== "") displayImg = resolveImg(appIcon);

        var rawImgPath = img;
        if (rawImgPath === "" && appIcon !== "" && appIcon.charAt(0) === "/") rawImgPath = appIcon;
        if (rawImgPath !== "" && rawImgPath.charAt(0) === "/") {
            queueImageCopy(rawImgPath, root.counter);
        }

        var ts = new Date();
        var h = ts.getHours();
        var mn = ts.getMinutes();

        return {
            nId: root.counter,
            appName: appName,
            summary: summary,
            body: body,
            imagePath: displayImg,
            timestamp: h + ":" + (mn < 10 ? "0" : "") + mn
        };
    }

    function addEntryAndPopup(entry, dur) {
        var arr = root.items.slice();
        arr.unshift(entry);
        root.items = arr;
        root.rebuildStacks();
        root.unreadCount = root.unreadCount + 1;

        if (dur > 0) {
            var newExpiry = Date.now() + dur;
            var pArr = root.popupItems.slice();
            for (var pi = 0; pi < pArr.length; pi++) {
                if (pArr[pi].appName === entry.appName) pArr[pi].expiry = newExpiry;
            }
            pArr.unshift({
                appName: entry.appName,
                summary: entry.summary,
                body: entry.body,
                imagePath: entry.imagePath,
                expiry: newExpiry
            });
            root.popupItems = pArr;
            root.rebuildPopupStacks();
        }
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
        var appIcon = "";
        try { appIcon = safeStr(n.appIcon); } catch(e) {}

        var urg = n.urgency;
        var dur = root.timeout;
        if (urg === NotificationUrgency.Critical) dur = dur * 3;

        var entry = createEntry(appName, summary, body, img, appIcon);
        var popupDur = (!root.dnd || urg === NotificationUrgency.Critical) ? dur : 0;
        addEntryAndPopup(entry, popupDur);
    }

    // ── Watch tracked notifications for property changes ──
    Connections {
        target: server
        function onTrackedNotificationsChanged() { root.syncTracked(); }
    }

    Timer {
        interval: 2000; repeat: true; running: true
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

                var key = appName + "|" + summary;
                var prevKey = root.lastSeen[appName];
                if (prevKey !== key && prevKey !== undefined) {
                    var entry = createEntry(appName, summary, body, img, appIcon);
                    addEntryAndPopup(entry, root.timeout);
                }
                root.lastSeen[appName] = key;
            }
        } catch(e) {
            console.log("syncTracked error: " + e);
        }
    }

    // ── Popup stacking ──
    function rebuildPopupStacks() {
        var now = Date.now();
        var alive = root.popupItems.filter(function(x) { return x.expiry > now; });
        if (alive.length !== root.popupItems.length) root.popupItems = alive;

        var grouped = groupByApp(alive);

        // Mark stacks for apps no longer present as dismissing
        for (var r = popupStacks.count - 1; r >= 0; r--) {
            var entry = popupStacks.get(r);
            if (!grouped.groups[entry.appName] && !entry.dismissing) {
                popupStacks.setProperty(r, "dismissing", true);
            }
        }

        var shown = 0;
        for (var j = 0; j < grouped.order.length; j++) {
            if (shown >= root.maxVisible) break;
            var gKey = grouped.order[j];
            var list = grouped.groups[gKey];
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
                    "appName": gKey, "summary": list[0].summary,
                    "body": list[0].body, "imagePath": list[0].imagePath,
                    "count": list.length, "dismissing": false
                });
            }
            shown = shown + 1;
        }
    }

    function removePopupApp(appName) {
        for (var i = popupStacks.count - 1; i >= 0; i--) {
            if (popupStacks.get(i).appName === appName) { popupStacks.remove(i); break; }
        }
    }

    function dismissPopupApp(appName) {
        root.popupItems = root.popupItems.filter(function(x) { return x.appName !== appName; });
        for (var i = popupStacks.count - 1; i >= 0; i--) {
            if (popupStacks.get(i).appName === appName) { popupStacks.setProperty(i, "dismissing", true); break; }
        }
    }

    Timer {
        id: popupTick
        interval: 1000; repeat: true
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
        var ls = root.lastSeen;
        delete ls[appName];
        root.lastSeen = ls;
        try {
            var tracked = server.trackedNotifications;
            if (tracked) {
                var vals = tracked.values;
                if (vals) {
                    for (var i = 0; i < vals.length; i++) {
                        if (vals[i] && safeStr(vals[i].appName) === appName) vals[i].tracked = false;
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

    // ── Shared grouping helper (deduplicates rebuildStacks + rebuildPopupStacks) ──
    function groupByApp(itemsList) {
        var groups = {};
        var order = [];
        for (var i = 0; i < itemsList.length; i++) {
            var n = itemsList[i];
            var key = n.appName || "Unknown";
            if (!groups[key]) { groups[key] = []; order.push(key); }
            groups[key].push(n);
        }
        return { groups: groups, order: order };
    }

    function rebuildStacks() {
        stacks.clear();
        var grouped = groupByApp(root.items);

        for (var j = 0; j < grouped.order.length; j++) {
            var gKey = grouped.order[j];
            var list = grouped.groups[gKey];
            var isExp = root.expanded[gKey] || false;

            stacks.append({
                isHeader: true, appName: gKey, count: list.length,
                summary: list[0].summary, body: list[0].body,
                imagePath: list[0].imagePath, nId: list[0].nId,
                timestamp: list[0].timestamp, expanded: isExp
            });

            if (isExp) {
                for (var k = 1; k < list.length; k++) {
                    stacks.append({
                        isHeader: false, appName: gKey, count: 0,
                        summary: list[k].summary, body: list[k].body,
                        imagePath: list[k].imagePath, nId: list[k].nId,
                        timestamp: list[k].timestamp, expanded: false
                    });
                }
            }
        }
    }
}
