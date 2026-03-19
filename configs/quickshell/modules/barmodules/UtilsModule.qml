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

    Row {
        id: row
        spacing: Root.Theme.barSpacing
        anchors.verticalCenter: parent.verticalCenter

        ResourceModule {}
        AudioModule { audioService: root.audioService }
        NetworkModule { wifiService: root.wifiService }
        BluetoothModule { bluetoothService: root.bluetoothService }
        BatteryModule {}
    }
}
