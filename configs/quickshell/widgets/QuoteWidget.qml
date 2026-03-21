import QtQuick
import Quickshell.Io
import ".." as Root

// Background quote widget with inspirational quotes
Item {
    id: root

    // Config properties
    property int maxWidth: 400
    property int fontSize: 16
    property int refreshInterval: 3600000  // 1 hour

    implicitWidth: Math.min(content.implicitWidth, maxWidth) + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // Quote state
    property string quoteText: ""
    property string quoteAuthor: ""
    property bool fetching: false

    // Fallback quotes (used when API unavailable)
    readonly property var fallbackQuotes: [
        { text: "The only way to do great work is to love what you do.", author: "Steve Jobs" },
        { text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci" },
        { text: "First, solve the problem. Then, write the code.", author: "John Johnson" },
        { text: "Code is like humor. When you have to explain it, it's bad.", author: "Cory House" },
        { text: "Make it work, make it right, make it fast.", author: "Kent Beck" },
        { text: "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.", author: "Martin Fowler" },
        { text: "The best error message is the one that never shows up.", author: "Thomas Fuchs" },
        { text: "Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away.", author: "Antoine de Saint-Exupery" },
        { text: "Talk is cheap. Show me the code.", author: "Linus Torvalds" },
        { text: "Programs must be written for people to read, and only incidentally for machines to execute.", author: "Harold Abelson" }
    ]

    property int fallbackIndex: Math.floor(Math.random() * fallbackQuotes.length)

    function useFallback() {
        let quote = fallbackQuotes[fallbackIndex];
        root.quoteText = quote.text;
        root.quoteAuthor = quote.author;
        fallbackIndex = (fallbackIndex + 1) % fallbackQuotes.length;
    }

    // Try quotable.io API
    Process {
        id: quoteProc
        command: ["curl", "-s", "--max-time", "5", "https://api.quotable.io/random?maxLength=150"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let contentMatch = data.match(/"content":\s*"([^"]+)"/);
                    let authorMatch = data.match(/"author":\s*"([^"]+)"/);
                    if (contentMatch && authorMatch) {
                        root.quoteText = contentMatch[1];
                        root.quoteAuthor = authorMatch[1];
                    } else {
                        root.useFallback();
                    }
                } catch(e) {
                    root.useFallback();
                }
            }
        }
        onExited: (code) => {
            root.fetching = false;
            if (code !== 0 || root.quoteText === "") {
                root.useFallback();
            }
            pollTimer.start();
        }
    }

    function fetchQuote() {
        if (root.fetching) return;
        root.fetching = true;
        quoteProc.running = true;
    }

    Component.onCompleted: {
        // Start with fallback immediately, then fetch
        useFallback();
        startTimer.start();
    }

    Timer {
        id: startTimer
        interval: 3000
        onTriggered: root.fetchQuote()
    }

    Timer {
        id: pollTimer
        interval: root.refreshInterval
        onTriggered: root.fetchQuote()
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
        spacing: 8
        width: Math.min(quoteTextItem.implicitWidth, root.maxWidth)

        Text {
            id: quoteTextItem
            width: root.maxWidth
            text: "\"" + root.quoteText + "\""
            color: Root.Theme.widgetText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font {
                family: Root.Theme.fontFamily
                pixelSize: root.fontSize
                italic: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "— " + root.quoteAuthor
            color: Root.Theme.widgetTextDimmed
            font {
                family: Root.Theme.fontFamily
                pixelSize: Math.round(root.fontSize * 0.8)
            }
        }
    }
}
