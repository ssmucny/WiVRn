pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

import io.github.wivrn.wivrn

Kirigami.ScrollablePage {
    id: headsets
    title: i18n("USB connection")

    flickable.interactive: false

    Component {
        id: device_delegate
        Kirigami.Card {
            id: device_card
            required property string serial
            // required property string state
            // required property string product
            required property string model
            required property string manufacturer
            // required property string device
            required property bool isWivrnInstalled
            implicitHeight: 80

            contentItem: GridLayout {
                id: delegate_layout
                rowSpacing: Kirigami.Units.largeSpacing
                columnSpacing: Kirigami.Units.largeSpacing
                columns: 2

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.column: 0
                    Layout.row: 0
                    wrapMode: Text.WordWrap
                    font.pixelSize: 20
                    text: device_card.manufacturer + " " + device_card.model
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.column: 0
                    Layout.row: 1
                    wrapMode: Text.WordWrap
                    text: i18nc("device list", "WiVRn is not installed on this device")
                    visible: !device_card.isWivrnInstalled
                }

                Controls.Button {
                    Layout.column: 1
                    Layout.row: 0
                    Layout.rowSpan: 2
                    text: i18nc("device list", "Install WiVRn")
                    icon.name: "install-symbolic"
                    visible: !device_card.isWivrnInstalled
                    onClicked: {}
                }

                Controls.Button {
                    Layout.column: 1
                    Layout.row: 0
                    Layout.rowSpan: 2
                    text: i18nc("device list", "Connect")
                    icon.name: "network-connect-symbolic"
                    visible: device_card.isWivrnInstalled
                    onClicked: Adb.startUsbConnection(device_card.serial)
                }
            }
        }
    }

    Kirigami.CardsListView {
        model: Adb
        delegate: device_delegate

        Kirigami.PlaceholderMessage {
            id: placeholder_message
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)

            visible: parent.count == 0

            text: Adb.adbInstalled ? i18n("Connect a headset and make sure developper mode is enabled") : i18n("ADB is not installed")
        }
    }

    footer: Controls.DialogButtonBox {
        standardButtons: Controls.DialogButtonBox.NoButton
        onAccepted: applicationWindow().pageStack.pop()

        Controls.Button {
            text: i18nc("go back to the home page", "Back")
            icon.name: "go-previous"
            Controls.DialogButtonBox.buttonRole: Controls.DialogButtonBox.AcceptRole
        }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: applicationWindow().pageStack.pop()
    }
}
