import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property var audioService: null

    Row {
        id: row
        spacing: theme.barSpacing
        anchors.verticalCenter: parent.verticalCenter

        ResourceModule {}
        AudioModule { audioService: root.audioService }
        NetworkModule {}
        BatteryModule {}
    }
}
