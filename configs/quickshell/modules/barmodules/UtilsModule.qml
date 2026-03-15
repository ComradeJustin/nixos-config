import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    signal wifiClicked()

    Row {
        id: row
        spacing: theme.barSpacing
        anchors.verticalCenter: parent.verticalCenter

        ResourceModule {}
        AudioModule {}
        NetworkModule { onClicked: root.wifiClicked() }
        BatteryModule {}
    }
}
