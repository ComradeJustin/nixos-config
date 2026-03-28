import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property var audioService: null
    property var wifiService: null
    property var bluetoothService: null

    component UtilSep : Rectangle {
        width: 1; height: 14
        color: Root.Theme.textDimmed; opacity: 0.15
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        id: row
        spacing: Root.Theme.barSpacing
        anchors.verticalCenter: parent.verticalCenter

        ResourceModule {}
        UtilSep {}
        AudioModule { audioService: root.audioService }
        UtilSep {}
        NetworkModule { wifiService: root.wifiService }
        UtilSep { visible: btModule.visible }
        BluetoothModule { id: btModule; bluetoothService: root.bluetoothService }
        UtilSep { visible: batModule.visible }
        BatteryModule { id: batModule }
    }
}
