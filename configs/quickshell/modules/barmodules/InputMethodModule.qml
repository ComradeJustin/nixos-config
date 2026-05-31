import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.inputMethod
    property bool isJapanese: svc ? (svc.active && svc.method.indexOf("mozc") >= 0) : false

    custom: true
    accent: isJapanese ? Root.Theme.accentSecondary : Root.Theme.textDimmed
    tooltipText: isJapanese ? "Japanese (Mozc)" : "English"
    popupContent: imePopup

    Text {
        text: root.svc ? root.svc.label : "EN"
        color: root.isJapanese ? Root.Theme.accentSecondary : Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    // ── Popup content (hosted in shared BarPopup window) ──
    property Components.HoverPopup imePopup: Components.HoverPopup {
        visible: false
        popupWidth: 200

        Text {
            text: "Input Method"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
            width: parent ? parent.width : 0
        }

        // Language selector row
        Row {
            spacing: 6
            width: parent ? parent.width : 0

            Rectangle {
                width: (parent.width - 6) / 2
                height: 28
                radius: Root.Theme.radiusSmall
                color: !root.isJapanese
                    ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.2)
                    : Root.Theme.layer2

                Text {
                    anchors.centerIn: parent
                    text: "EN"
                    color: !root.isJapanese ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: !root.isJapanese }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.svc) root.svc.deactivate(); }
                }
            }

            Rectangle {
                width: (parent.width - 6) / 2
                height: 28
                radius: Root.Theme.radiusSmall
                color: root.isJapanese
                    ? Qt.rgba(Root.Theme.accentSecondary.r, Root.Theme.accentSecondary.g, Root.Theme.accentSecondary.b, 0.2)
                    : Root.Theme.layer2

                Text {
                    anchors.centerIn: parent
                    text: "\u3042"
                    color: root.isJapanese ? Root.Theme.accentSecondary : Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: root.isJapanese }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.svc) root.svc.activate(); }
                }
            }
        }

        Rectangle {
            width: parent ? parent.width : 0; height: 1
            color: Root.Theme.borderColor; opacity: 0.5
        }

        Components.SettingToggle {
            label: "Live Conversion"
            description: "Auto-convert hiragana to kanji as you type"
            isOn: Root.Config.inputMethod.liveConversion
            accent: Root.Theme.accentSecondary
            onToggled: {
                var next = !Root.Config.inputMethod.liveConversion;
                Root.Config.inputMethod.liveConversion = next;
                Root.Config.save();
                if (root.svc) root.svc.setLiveConversion(next);
            }
        }

        Components.SettingToggle {
            label: "Auto-Correct"
            description: "Predictive suggestions"
            isOn: Root.Config.inputMethod.prediction
            accent: Root.Theme.accentSecondary
            onToggled: {
                var next = !Root.Config.inputMethod.prediction;
                Root.Config.inputMethod.prediction = next;
                Root.Config.save();
                if (root.svc) root.svc.setPrediction(next);
            }
        }
    }
}
