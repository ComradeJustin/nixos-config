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

    // Quickshell-assigned notification id (from the D-Bus `id` field on the
    // Notification object) → our internal `nId`. Used to honor the freedesktop
    // `replaces_id` mechanism: when a sender calls `notify-send -r <id>`, the
    // resulting Notification arrives with the same `.id` and we update the
    // existing entry in-place instead of appending a new one.
    property var qsIdToEntryId: ({})

    // ── Image copy queue ──
    property var imgCopyQueue: []
    property bool imgCopyBusy: false

    function toggleDnd() { dnd = !dnd; }

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

    // ── Synchronous-hint helpers ──
    // Mako/dunst convention: notifications carrying
    // `x-canonical-private-synchronous: <tag>` replace any prior notification
    // with the same tag rather than stacking. We implement it here because
    // we're acting as our own NotificationServer and inherit nothing from
    // the standard daemons.
    function getSyncTag(n) {
        try {
            var h = n.hints;
            if (!h) return "";
            var v = h["x-canonical-private-synchronous"];
            if (v !== undefined && v !== null && ("" + v).length > 0) return "" + v;
            v = h["synchronous"];
            if (v !== undefined && v !== null && ("" + v).length > 0) return "" + v;
        } catch(e) {}
        return "";
    }

    function removeBySyncTag(tag) {
        if (!tag) return;
        root.items = root.items.filter(function(x) { return x.syncTag !== tag; });
        root.popupItems = root.popupItems.filter(function(x) { return x.syncTag !== tag; });
    }

    // ── Content-hash dedup (fallback for senders that don't use replaces_id) ──
    // If an identical (appName, summary, body) triple already exists in the
    // visible items, treat the new arrival as a replacement: evict the old
    // one before inserting. Cheap JS string comparison is sufficient — the
    // full SHA-256 hash that Noctalia uses is overkill for a local dedup
    // across at most ~100 items.
    function _contentKey(appName, summary, body) {
        return (appName || "") + "\u0001" + (summary || "") + "\u0001" + (body || "");
    }

    function findDuplicateEntryId(appName, summary, body) {
        var key = _contentKey(appName, summary, body);
        for (var i = 0; i < root.items.length; i++) {
            var it = root.items[i];
            if (_contentKey(it.appName, it.summary, it.body) === key) return it.nId;
        }
        return -1;
    }

    function removeByEntryId(nId) {
        if (nId < 0) return;
        root.items = root.items.filter(function(x) { return x.nId !== nId; });
        root.popupItems = root.popupItems.filter(function(x) { return x.nId !== nId; });
    }

    // ── In-place update for replaces_id / content dedup / live mutations ──
    // Rather than evict + append (which resets position and resets timer),
    // mutate the existing entry. This matches Noctalia's `updatePopup` and
    // keeps the popup stable in the user's view while its content updates.
    //
    // `dur` semantics:
    //   dur > 0  → update content AND extend expiry (normal replacement path).
    //              If the popup had already expired, re-add a fresh one.
    //   dur == 0 → update content only, preserve existing expiry, do not
    //              re-add an expired popup. Used by live-mutation watchers
    //              (e.g. Spotify track changes) where we want the popup
    //              to reflect the new title but not reset its timer or
    //              come back from the dead.
    function updateEntryInPlace(nId, appName, summary, body, img, appIcon, syncTag, dur) {
        var displayImg = resolveImg(img);
        if (displayImg === "" && appIcon !== "") displayImg = resolveImg(appIcon);

        var updated = false;
        // Update history items
        var arr = root.items.slice();
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].nId === nId) {
                arr[i] = Object.assign({}, arr[i], {
                    appName: appName,
                    summary: summary,
                    body: body,
                    imagePath: displayImg !== "" ? displayImg : arr[i].imagePath,
                    syncTag: syncTag || arr[i].syncTag || ""
                });
                updated = true;
                break;
            }
        }
        if (updated) {
            root.items = arr;
            root.rebuildStacks();
        }

        // Update popup items content (always, regardless of dur). Track
        // whether we found a live popup entry so we can decide whether to
        // re-add an expired one below.
        var pArr = root.popupItems.slice();
        var popupUpdated = false;
        for (var j = 0; j < pArr.length; j++) {
            if (pArr[j].nId === nId) {
                var newExpiry = (dur > 0) ? (Date.now() + dur) : pArr[j].expiry;
                pArr[j] = Object.assign({}, pArr[j], {
                    appName: appName,
                    summary: summary,
                    body: body,
                    imagePath: displayImg !== "" ? displayImg : pArr[j].imagePath,
                    expiry: newExpiry,
                    syncTag: syncTag || pArr[j].syncTag || ""
                });
                popupUpdated = true;
                break;
            }
        }

        // If the popup had already expired but history still has the entry,
        // re-add a fresh popup so the user sees the update. Only on dur > 0.
        // For live-mutation updates (dur == 0) we deliberately skip this —
        // a Spotify track change shouldn't resurrect a timed-out popup.
        if (!popupUpdated && updated && dur > 0) {
            var found = null;
            for (var k = 0; k < root.items.length; k++) {
                if (root.items[k].nId === nId) { found = root.items[k]; break; }
            }
            if (found) {
                pArr.unshift({
                    nId: nId,
                    appName: found.appName,
                    summary: found.summary,
                    body: found.body,
                    imagePath: found.imagePath,
                    expiry: Date.now() + dur,
                    syncTag: found.syncTag || ""
                });
                popupUpdated = true;
            }
        }

        if (popupUpdated) {
            root.popupItems = pArr;
            root.rebuildPopupStacks();
        }
        return updated;
    }

    // ── Shared entry creation ──
    function createEntry(appName, summary, body, img, appIcon, syncTag, qsId) {
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

        // Register qsId → nId mapping so future arrivals with the same
        // D-Bus `replaces_id` can find this entry.
        if (qsId !== undefined && qsId !== null && qsId > 0) {
            var map = root.qsIdToEntryId;
            map[qsId] = root.counter;
            root.qsIdToEntryId = map;
        }

        return {
            nId: root.counter,
            qsId: (qsId !== undefined && qsId !== null) ? qsId : -1,
            appName: appName,
            summary: summary,
            body: body,
            imagePath: displayImg,
            timestamp: h + ":" + (mn < 10 ? "0" : "") + mn,
            syncTag: syncTag || ""
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
                nId: entry.nId,
                appName: entry.appName,
                summary: entry.summary,
                body: entry.body,
                imagePath: entry.imagePath,
                expiry: newExpiry,
                syncTag: entry.syncTag || ""
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

    // ── Per-notification watcher (Noctalia pattern) ──
    // Some senders (notably Spotify and other MPRIS players) mutate the
    // tracked Notification object's `summary` / `body` in place instead of
    // issuing a fresh `Notify()` call with `replaces_id`. `onNotification`
    // never fires for those silent updates, so we'd miss every track
    // change. The fix is reactive, not polling: attach a Connections object
    // to each live Notification we care about and sync on property changes.
    //
    // This replaces the old `syncTracked` polling loop, which had an
    // infinite-stacking bug when two notifications from the same app had
    // different summaries (lastSeen oscillation).
    property Component _watcherComponent: Component {
        Connections {
            property int entryId: -1
            property var notifObj: null
            target: notifObj
            ignoreUnknownSignals: true

            function onSummaryChanged() { root._notifChanged(entryId); }
            function onBodyChanged() { root._notifChanged(entryId); }
            function onAppNameChanged() { root._notifChanged(entryId); }
            function onImageChanged() { root._notifChanged(entryId); }
            function onAppIconChanged() { root._notifChanged(entryId); }
            function onClosed() { root._notifClosed(entryId); }
        }
    }

    // nId → Connections instance. One watcher per live entry.
    property var _watchers: ({})

    function _attachWatcher(nId, n) {
        if (!n || nId < 0) return;
        // Replace any existing watcher for this nId first — the caller may
        // be updating an entry with a fresh Notification object.
        _detachWatcher(nId);
        var w = _watcherComponent.createObject(root, {
            "entryId": nId,
            "notifObj": n
        });
        if (w) {
            var map = root._watchers;
            map[nId] = w;
            root._watchers = map;
        }
    }

    function _detachWatcher(nId) {
        var w = root._watchers[nId];
        if (w) {
            try { w.destroy(); } catch(e) {}
            var map = root._watchers;
            delete map[nId];
            root._watchers = map;
        }
    }

    // Called when a watched Notification mutates one of its content props.
    // We pull the fresh values from the Notification object directly and
    // call updateEntryInPlace with dur=0 so the popup content refreshes
    // without resetting the expiry timer — for a Spotify track change,
    // you want the title to update but the toast to still time out on
    // its original schedule, not linger forever.
    function _notifChanged(nId) {
        var w = root._watchers[nId];
        if (!w || !w.notifObj) return;
        var n = w.notifObj;
        var appName = safeStr(n.appName);
        var summary = safeStr(n.summary);
        var body = safeStr(n.body);
        var img = safeStr(n.image);
        var appIcon = "";
        try { appIcon = safeStr(n.appIcon); } catch(e) {}

        // Locate the entry and short-circuit if nothing actually changed.
        // Property-change signals can fire during our own updateEntryInPlace
        // mutations (via QML binding propagation), so without this guard
        // we'd recurse forever.
        var found = null;
        for (var i = 0; i < root.items.length; i++) {
            if (root.items[i].nId === nId) { found = root.items[i]; break; }
        }
        if (!found) {
            _detachWatcher(nId);
            return;
        }
        if (found.appName === appName
            && found.summary === summary
            && found.body === body) return;

        // Refresh the popup content in place. Pass dur=0 so expiry is
        // preserved — Spotify track updates shouldn't reset the 5s timer.
        updateEntryInPlace(nId, appName, summary, body, img, appIcon, found.syncTag || "", 0);
    }

    // Sender called Notification.dismiss() or the D-Bus CloseNotification
    // method. Clean up the watcher and remove the entry from history.
    function _notifClosed(nId) {
        _detachWatcher(nId);
        removeOne(nId);
    }

    function handleNotification(n) {
        var appName = safeStr(n.appName);
        var summary = safeStr(n.summary);
        var body = safeStr(n.body);
        var img = safeStr(n.image);
        var appIcon = "";
        try { appIcon = safeStr(n.appIcon); } catch(e) {}

        // Quickshell's Notification exposes the freedesktop-assigned id.
        // When `notify-send -r <id>` is used, this arrives as the previous
        // notification's id rather than a fresh one.
        var qsId = -1;
        try { qsId = n.id || -1; } catch(e) {}

        var urg = n.urgency;
        var dur = root.timeout;
        if (urg === NotificationUrgency.Critical) dur = dur * 3;
        var popupDur = (!root.dnd || urg === NotificationUrgency.Critical) ? dur : 0;

        var syncTag = getSyncTag(n);

        // ── Layered replacement check ──
        // Tier 1: D-Bus replaces_id (the freedesktop-standard mechanism).
        //   If the Quickshell id maps to an existing entry, update in place.
        // Tier 2: Synchronous hint (mako/dunst convention, our own senders).
        //   Evict all entries carrying the same tag, then insert fresh.
        // Tier 3: Content-hash dedup fallback.
        //   If (appName, summary, body) matches an existing visible item,
        //   update it in place. Catches apps that repeat themselves without
        //   bothering to use replaces_id.
        //
        // The order matters: replaces_id is authoritative intent from the
        // sender, so it wins. Sync-tag is intent from our own code. Content
        // hash is a heuristic safety net.

        // ── Tier 1: replaces_id in-place update ──
        if (qsId > 0 && root.qsIdToEntryId[qsId] !== undefined) {
            var existingNId = root.qsIdToEntryId[qsId];
            if (updateEntryInPlace(existingNId, appName, summary, body, img, appIcon, syncTag, popupDur)) {
                // Rebind watcher: the incoming `n` may be a fresh Notification
                // object even though the D-Bus id matches. Without this the
                // next silent mutation on the new object wouldn't fire any
                // signal we're listening to.
                if (syncTag === "") _attachWatcher(existingNId, n);
                return;
            }
            // Entry disappeared (user cleared it) — fall through to fresh insert
            var mapCleanup = root.qsIdToEntryId;
            delete mapCleanup[qsId];
            root.qsIdToEntryId = mapCleanup;
        }

        // ── Tier 2: synchronous hint eviction ──
        if (syncTag !== "") {
            // Also detach any watchers for entries we're about to evict.
            for (var wi = 0; wi < root.items.length; wi++) {
                if (root.items[wi].syncTag === syncTag) _detachWatcher(root.items[wi].nId);
            }
            removeBySyncTag(syncTag);
        }

        // ── Tier 3: content-hash dedup in-place update ──
        // Skip when syncTag already handled the eviction — a same-tag
        // replacement is a different intent than "same content repeated".
        if (syncTag === "") {
            var dupId = findDuplicateEntryId(appName, summary, body);
            if (dupId >= 0) {
                if (updateEntryInPlace(dupId, appName, summary, body, img, appIcon, syncTag, popupDur)) {
                    // Register qsId against the existing entry so future
                    // replaces_id calls find it too.
                    if (qsId > 0) {
                        var map = root.qsIdToEntryId;
                        map[qsId] = dupId;
                        root.qsIdToEntryId = map;
                    }
                    // Rebind watcher to the fresh Notification object.
                    _attachWatcher(dupId, n);
                    return;
                }
            }
        }

        // ── Fresh insert ──
        var entry = createEntry(appName, summary, body, img, appIcon, syncTag, qsId);
        addEntryAndPopup(entry, popupDur);

        // Attach a watcher for live-mutation tracking (Spotify-style).
        // Synchronous-hint notifications are about to be untracked on the
        // D-Bus side, so skip watching them — their Notification object
        // will emit `closed` immediately and we'd lose the entry.
        if (syncTag === "") _attachWatcher(entry.nId, n);

        // Synchronous-hint notifications are self-replacing, so release
        // them from D-Bus tracking immediately — they should not linger
        // in `server.trackedNotifications`. Non-synchronous notifications
        // stay tracked so `replaces_id` updates can find them later.
        if (syncTag !== "") {
            try { n.tracked = false; } catch(e) {}
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

    // Prune qsIdToEntryId of any mappings whose internal entries no longer
    // exist. Called after any bulk removal so the map doesn't grow unbounded
    // when users clear notifications.
    function _pruneQsIdMap() {
        var alive = {};
        for (var i = 0; i < root.items.length; i++) {
            var e = root.items[i];
            if (e.qsId !== undefined && e.qsId > 0) alive[e.qsId] = e.nId;
        }
        root.qsIdToEntryId = alive;
    }

    function removeOne(nId) {
        _detachWatcher(nId);
        root.items = root.items.filter(function(x) { return x.nId !== nId; });
        _pruneQsIdMap();
        rebuildStacks();
    }

    function removeApp(appName) {
        // Detach watchers for every entry we're about to remove before
        // mutating root.items, so the detach lookup can still see them.
        for (var wi = 0; wi < root.items.length; wi++) {
            if (root.items[wi].appName === appName) _detachWatcher(root.items[wi].nId);
        }
        root.items = root.items.filter(function(x) { return x.appName !== appName; });
        _pruneQsIdMap();
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
        // Detach every watcher. Iterate the map's own keys so we don't
        // depend on root.items still being populated.
        for (var wid in root._watchers) {
            var w = root._watchers[wid];
            if (w) try { w.destroy(); } catch(e) {}
        }
        root._watchers = {};

        root.items = [];
        root.unreadCount = 0;
        root.qsIdToEntryId = {};
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
