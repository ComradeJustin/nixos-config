import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Io
Item {
    id: wifi
    property string output: isConnectedWifi()




        function isConnectedWifi()
        {
            if (Networking.devices.values[0].connected == true)
            {
                return ""
            }
            else {
                return "󰤮"
                //return String(Networking.devices.values[0].signalStrength)
            }

        }
        function isEther()
        {

            // Todo

        }




        Text {
            anchors.centerIn: parent
            color: '#ffffff'
            text: output
        }
    }