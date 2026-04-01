import QtQuick
import Quickshell.Io
import ".." as Root
import "../components" as Components

// Background stock ticker widget showing configurable symbols with price and change
Components.WidgetFrame {
    id: root
    widgetName: "stock"

    property var symbols: ["SPY", "QQQ", "AAPL"]
    property int fontSize: 14
    property int refreshInterval: 300000

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
            root.stockData = root.stockData.slice();
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
            onRead: data => { fetchProc.buffer += data; }
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
                            symbol: sym, price: price.toFixed(2),
                            change: change.toFixed(2), changePercent: pct.toFixed(2)
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

    Timer { id: startTimer; interval: 3000; running: true; onTriggered: root.startFetch() }
    Timer { id: pollTimer; interval: root.refreshInterval; onTriggered: root.startFetch() }

    Column {
        spacing: 6

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

        Repeater {
            model: root.stockData.length > 0 ? root.stockData.length : root.symbols.length
            Row {
                spacing: 10
                property var item: root.stockData.length > index ? root.stockData[index] : null
                property bool isUp: item ? parseFloat(item.change) >= 0 : true
                property color changeColor: item ? (parseFloat(item.change) > 0 ? Root.Theme.accentSuccess : (parseFloat(item.change) < 0 ? Root.Theme.accentDanger : Root.Theme.widgetTextDimmed)) : Root.Theme.widgetTextDimmed

                Text {
                    width: 40
                    text: item ? item.symbol : root.symbols[index]
                    color: Root.Theme.widgetText
                    font { family: Root.Theme.fontMono; pixelSize: root.fontSize; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: 65
                    text: item ? item.price : "--"
                    color: Root.Theme.widgetText
                    horizontalAlignment: Text.AlignRight
                    font { family: Root.Theme.fontMono; pixelSize: root.fontSize }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: item ? (isUp ? Root.Theme.iconStockUp : Root.Theme.iconStockDown) : ""
                    color: changeColor
                    font { family: Root.Theme.fontIcons; pixelSize: root.fontSize * 0.9 }
                    anchors.verticalCenter: parent.verticalCenter
                }
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
