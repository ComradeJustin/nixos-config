import QtQuick
import Quickshell.Io
import ".." as Root

// Background stock ticker widget showing configurable symbols with price and change
Item {
    id: root

    // Config properties
    property var symbols: ["SPY", "QQQ", "AAPL"]
    property int fontSize: 14
    property int refreshInterval: 300000  // 5 minutes

    implicitWidth: content.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // Stock data: array of { symbol, price, change, changePercent }
    property var stockData: []
    property bool fetching: false
    property int currentFetchIndex: -1

    function startFetch() {
        if (root.fetching || root.symbols.length === 0) return;
        root.fetching = true;
        root.stockData = [];
        root.currentFetchIndex = 0;
        fetchNext();
    }

    function fetchNext() {
        if (root.currentFetchIndex >= root.symbols.length) {
            root.fetching = false;
            root.stockData = root.stockData.slice();  // trigger reactivity
            pollTimer.start();
            return;
        }
        let sym = root.symbols[root.currentFetchIndex];
        fetchProc.command = ["curl", "-s", "--max-time", "8",
            "-H", "User-Agent: Mozilla/5.0",
            "https://query1.finance.yahoo.com/v8/finance/chart/" + sym + "?interval=1d&range=1d"];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                fetchProc.buffer += data;
            }
        }
        onExited: (code) => {
            let sym = root.symbols[root.currentFetchIndex];
            if (code === 0 && fetchProc.buffer.length > 0) {
                try {
                    let priceMatch = fetchProc.buffer.match(/"regularMarketPrice":\s*([\d.]+)/);
                    let prevMatch = fetchProc.buffer.match(/"chartPreviousClose":\s*([\d.]+)/);
                    if (priceMatch && prevMatch) {
                        let price = parseFloat(priceMatch[1]);
                        let prev = parseFloat(prevMatch[1]);
                        let change = price - prev;
                        let pct = prev > 0 ? (change / prev) * 100 : 0;
                        root.stockData.push({
                            symbol: sym,
                            price: price.toFixed(2),
                            change: change.toFixed(2),
                            changePercent: pct.toFixed(2)
                        });
                    } else {
                        root.stockData.push({ symbol: sym, price: "--", change: "0", changePercent: "0" });
                    }
                } catch(e) {
                    root.stockData.push({ symbol: sym, price: "--", change: "0", changePercent: "0" });
                }
            } else {
                root.stockData.push({ symbol: sym, price: "--", change: "0", changePercent: "0" });
            }
            fetchProc.buffer = "";
            root.currentFetchIndex++;
            fetchNext();
        }
    }

    Timer {
        id: startTimer
        interval: 3000
        running: true
        onTriggered: root.startFetch()
    }

    Timer {
        id: pollTimer
        interval: root.refreshInterval
        onTriggered: root.startFetch()
    }

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // Header
        Row {
            spacing: 6
            Text {
                text: Root.Theme.iconStock
                color: Root.Theme.widgetStockAccent
                font { family: Root.Theme.fontIcons; pixelSize: root.fontSize }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Stocks"
                color: Root.Theme.widgetTextDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Math.round(root.fontSize * 0.85); bold: true }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Stock rows
        Repeater {
            model: root.stockData.length > 0 ? root.stockData.length : root.symbols.length

            Row {
                spacing: 10
                property var item: root.stockData.length > index ? root.stockData[index] : null
                property bool isUp: item ? parseFloat(item.change) >= 0 : true
                property color changeColor: item ? (parseFloat(item.change) > 0 ? Root.Theme.accentSuccess : (parseFloat(item.change) < 0 ? Root.Theme.accentDanger : Root.Theme.widgetTextDimmed)) : Root.Theme.widgetTextDimmed

                // Symbol
                Text {
                    width: 40
                    text: item ? item.symbol : root.symbols[index]
                    color: Root.Theme.widgetText
                    font { family: Root.Theme.fontMono; pixelSize: root.fontSize; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Price
                Text {
                    width: 65
                    text: item ? item.price : "--"
                    color: Root.Theme.widgetText
                    horizontalAlignment: Text.AlignRight
                    font { family: Root.Theme.fontMono; pixelSize: root.fontSize }
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Change indicator
                Text {
                    text: item ? (isUp ? Root.Theme.iconStockUp : Root.Theme.iconStockDown) : ""
                    color: changeColor
                    font { family: Root.Theme.fontIcons; pixelSize: root.fontSize * 0.9 }
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Percent change
                Text {
                    text: item ? ((parseFloat(item.changePercent) >= 0 ? "+" : "") + item.changePercent + "%") : ""
                    color: changeColor
                    font { family: Root.Theme.fontMono; pixelSize: Math.round(root.fontSize * 0.85) }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
