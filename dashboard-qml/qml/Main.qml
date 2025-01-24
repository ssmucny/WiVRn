import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

import io.github.wivrn.wivrn

Kirigami.ApplicationWindow {
    id: root
    title: i18n("WiVRn dashboard")

    Settings {
        id: config
    }

    Apps {
        id: apps
    }

    Dialogs.FileDialog {
        id: app_browse
        onAccepted: {
            app_text.text = new URL(selectedFile).pathname;
            root.save();
        }
    }

    width: 800
    height: 600

    property bool server_started: WivrnServer.serverStatus == WivrnServer.Started
    property bool json_loaded: false
    property bool prev_headset_connected: false
    property int connected_headset_count: 0
    property string connected_headset_serial: ""

    Connections {
        target: WivrnServer
        function onCapSysNiceChanged(value) {
            if (WivrnServer.serverStatus != WivrnServer.Stopped)
                restart_capsysnice.visible = true;
        }

        function onJsonConfigurationChanged(value) {
            if (root.json_loaded || !root.server_started || WivrnServer.jsonConfiguration == "")
                return;

            config.load(WivrnServer);

            var found = false;
            var custom_idx = -1;
            for (var i = 0; i < apps.count; i++) {
                var app = apps.get(i);
                if (app.is_custom)
                    custom_idx = i;
                else if (app.command == config.application) {
                    app_combobox.currentIndex = i;
                    found = true;
                    break;
                }
            }

            if (!found) {
                app_text.text = config.application;
                app_combobox.currentIndex = custom_idx;
            }

            root.json_loaded = true;
        }

        function onServerStatusChanged(value) {
            var started = value == WivrnServer.Started;

            if (switch_running.checked != started)
                switch_running.checked = started;
        }

        function onPairingEnabledChanged(value) {
            if (switch_pairing.checked != WivrnServer.pairingEnabled)
                switch_pairing.checked = WivrnServer.pairingEnabled;
        }

        // function onHeadsetConnectedChanged(value) {
        //     if (value != root.prev_headset_connected) {
        //         root.prev_headset_connected = value;
        //
        //         if (value && root.pageStack.depth == 1)
        //             root.pageStack.push(Qt.resolvedUrl("HeadsetStatsPage.qml"));
        //     }
        // }
    }

    Connections {
        target: Adb

        function onRowsInserted() {
            root.connected_devices_changed();
        }

        function onRowsRemoved() {
            root.connected_devices_changed();
        }

        function onDataChanged() {
            root.connected_devices_changed();
        }
    }

    Component.onCompleted: {
        if (WivrnServer.serverStatus == WivrnServer.Stopped)
            WivrnServer.start_server();
    }

    // pageStack.defaultColumnWidth: 40 * Kirigami.Units.gridUnit
    pageStack.globalToolBar.showNavigationButtons: 0
    pageStack.defaultColumnWidth: width // Force non-wide mode

    pageStack.initialPage: Kirigami.ScrollablePage {

        ColumnLayout {
            anchors.fill: parent
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                text: i18n("The server does not have CAP_SYS_NICE capabilities.")
                // type: Kirigami.MessageType.Warning
                type: Kirigami.MessageType.Information
                showCloseButton: true
                visible: !WivrnServer.capSysNice
                actions: [
                    Kirigami.Action {
                        text: i18n("Fix it")
                        onTriggered: WivrnServer.grant_cap_sys_nice()
                    }
                ]
            }

            Kirigami.InlineMessage {
                id: restart_capsysnice
                Layout.fillWidth: true
                text: i18n("The CAP_SYS_NICE capability will be used when the server is restarted.")
                type: Kirigami.MessageType.Information
                showCloseButton: true
                visible: false
                actions: [
                    Kirigami.Action {
                        text: i18nc("restart the server", "Restart now")
                        onTriggered: {
                            WivrnServer.restart_server();
                            restart_capsysnice.visible = false;
                        }
                    }
                ]
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                text: i18n("ADB is not installed.")
                type: Kirigami.MessageType.Information
                showCloseButton: true
                visible: !Adb.adbInstalled
            }

            GridLayout {
                columns: 2

                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Item {}
                Item {
                    Layout.fillWidth: true
                }

                Image {
                    source: Qt.resolvedUrl("wivrn.svg")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Controls.Switch {
                        id: switch_running
                        text: i18nc("whether the server is running, displayed in front of a checkbox", "Running")

                        checked: true
                        onCheckedChanged: {
                            if (checked && !root.server_started)
                                WivrnServer.start_server();
                            else if (!checked && root.server_started)
                                WivrnServer.stop_server();
                        }
                    }

                    Controls.Switch {
                        id: switch_pairing
                        text: i18nc("whether pairing is enabled, displayed in front of a checkbox", "Pairing")
                        onCheckedChanged: {
                            if (checked && !WivrnServer.pairingEnabled)
                                WivrnServer.enable_pairing();
                            else if (!checked && WivrnServer.pairingEnabled)
                                WivrnServer.disable_pairing();
                        }
                        enabled: root.server_started
                    }

                    Controls.Label {
                        text: WivrnServer.pairingEnabled ? i18n("PIN: %1", WivrnServer.pin) : ""
                        wrapMode: Text.WordWrap
                        // font.pixelSize: 20
                        Layout.fillWidth: true
                    }

                    Controls.Button {
                        text: i18n("Connect by USB")
                        onClicked: root.connect_usb()
                        enabled: root.server_started && Adb.adbInstalled && !WivrnServer.headsetConnected && root.connected_headset_count > 0
                    }
                }

                Kirigami.Separator {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                }

                Kirigami.Heading {
                    level: 1
                    text: i18nc("automatically started application", "Application")
                }

                ColumnLayout {
                    RowLayout {
                        Layout.fillWidth: true
                        Controls.ComboBox {
                            id: app_combobox
                            Layout.columnSpan: 2
                            textRole: "name"
                            model: apps
                            enabled: root.server_started
                            onActivated: root.save()
                        }
                        Controls.TextField {
                            id: app_text
                            placeholderText: app_combobox.currentText
                            visible: !!app_combobox.model.get(app_combobox.currentIndex)?.is_custom && root.server_started
                            Layout.fillWidth: true
                            onTextEdited: root.save()
                        }
                        Controls.Button {
                            text: i18nc("browse a file to choose the application to start", "Browse")
                            visible: app_text.visible
                            onClicked: app_browse.open()
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    visible: root.server_started
                }

                Kirigami.Heading {
                    level: 1
                    text: i18n("Steam stuff")
                    visible: root.server_started
                    // Layout.alignment: Qt.AlignTop
                }
                ColumnLayout {
                    Controls.Label {
                        text: i18n("For Steam games, use the following command:")
                        visible: root.server_started
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        visible: root.server_started
                        Controls.TextField {
                            text: WivrnServer.steamCommand
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            readOnly: true
                            // cursorVisible: true
                            Controls.ToolTip.text: i18n("Paste this in the Steam launch options for the app you want to start")
                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.delay: 1000
                        }

                        Controls.Button {
                            text: i18nc("copy text to the clipboard", "Copy")
                            icon.name: "edit-copy-symbolic"
                            onClicked: {
                                WivrnServer.copy_steam_command();
                                showPassiveNotification(i18n("Copied Steam launch command"), 2000);
                            }
                        }
                    }
                }

                Item {
                    // spacer item
                    Layout.fillHeight: true
                }
            }
        }

        actions: [
            // Kirigami.Action {
            //     text: i18n("Install the app")
            //     // icon.name: "item-symbolic"
            //     onTriggered: root.pageStack.push(Qt.resolvedUrl("ApkInstallPage.qml"))
            //     visible: root.pageStack.depth == 1
            //     enabled: root.server_started && Adb.adbInstalled
            // },
            // Kirigami.Action {
            //     text: i18n("Statistics")
            //     icon.name: "office-chart-line-symbolic"
            //     onTriggered: root.pageStack.push(Qt.resolvedUrl("HeadsetStatsPage.qml"))
            //     visible: root.pageStack.depth == 1
            //     enabled: root.server_started && Adb.adbInstalled && WivrnServer.headsetConnected
            // },
            Kirigami.Action {
                text: i18n("Disconnect")
                icon.name: "network-disconnect-symbolic"
                onTriggered: WivrnServer.disconnect_headset()
                visible: root.pageStack.depth == 1
                enabled: root.server_started && WivrnServer.headsetConnected
            },
            Kirigami.Action {
                text: i18n("Headsets")
                icon.name: "item-symbolic"
                onTriggered: root.pageStack.push(Qt.resolvedUrl("HeadsetsPage.qml"))
                visible: root.pageStack.depth == 1
                enabled: root.server_started
            },
            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "settings-configure-symbolic"
                onTriggered: root.pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                visible: root.pageStack.depth == 1
                enabled: root.server_started
            }//,
            // Kirigami.Action {
            //     text: i18n("Troubleshoot")
            //     icon.name: "help-contents-symbolic"
            //     onTriggered: root.pageStack.push(Qt.resolvedUrl("TroubleshootPage.qml"))
            //     enabled: root.server_started && root.pageStack.depth == 1
            // }


        ]
    }

    Component {
        id: usb_device_component
        Kirigami.Action {
            property string serial
            property string label

            // icon.name: "media-playback-start"
            text: label
            onTriggered: Adb.startUsbConnection(serial, WivrnServer.pin)
        }
    }

    Kirigami.MenuDialog {
        id: select_usb_device

        title: i18n("Select your headset")
        showCloseButton: true

        actions: []
    }

    function save() {
        var new_application;

        if (apps.get(app_combobox.currentIndex).is_custom)
            new_application = app_text.text;
        else
            new_application = apps.get(app_combobox.currentIndex).command;

        config.load(WivrnServer);
        if (config.application != new_application) {
            config.application = new_application;
            config.save(WivrnServer);
        }
    }

    function connect_usb() {
        if (root.connected_headset_count == 1) {
            Adb.startUsbConnection(root.connected_headset_serial, WivrnServer.pin);
        } else {
            select_usb_device.open();
        }
    }

    function connected_devices_changed() {
        var n = Adb.rowCount();
        var nb_found = 0;

        select_usb_device.actions.length = 0;

        for (var i = 0; i < n; i++) {
            var serial = Adb.data(Adb.index(i, 0), 257);
            var isWivrnInstalled = Adb.data(Adb.index(i, 0), 258);
            var manufacturer = Adb.data(Adb.index(i, 0), 259);
            var model = Adb.data(Adb.index(i, 0), 260);

            if (isWivrnInstalled) {
                nb_found++;
                root.connected_headset_serial = serial;

                select_usb_device.actions.push(usb_device_component.createObject(select_usb_device, {
                    "label": manufacturer + " " + model,
                    "serial": serial
                }));
            }
        }

        root.connected_headset_count = nb_found;
        if (nb_found != 1)
            root.connected_headset_serial = "";
    }
}
