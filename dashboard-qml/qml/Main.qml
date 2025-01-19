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
                        text: i18n("Restart now")
                        onTriggered: {
                            WivrnServer.restart_server();
                            restart_capsysnice.visible = false;
                        }
                    }
                ]
            }

            GridLayout {
                columns: 2

                // columnSpacing: Kirigami.Units.largeSpacing
                // rowSpacing: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Item {}
                Item { Layout.fillWidth: true }

                Image {
                    source: Qt.resolvedUrl("wivrn.svg")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Controls.Switch {
                        text: i18n("Running")
                        id: switch_running

                        checked: true
                        onCheckedChanged: {
                            if (checked && !root.server_started)
                                WivrnServer.start_server()
                            else if (!checked && root.server_started)
                                WivrnServer.stop_server()
                        }
                    }

                    Controls.Switch {
                        text: i18n("Pairing")
                        id: switch_pairing
                        onCheckedChanged: {
                            if (checked && !WivrnServer.pairingEnabled)
                                WivrnServer.enable_pairing()
                            else if (!checked && WivrnServer.pairingEnabled)
                                WivrnServer.disable_pairing()
                        }
                        enabled: root.server_started
                    }

                    Controls.Label {
                        text: WivrnServer.pairingEnabled ? i18n("PIN: %1", WivrnServer.pin) : ""
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                }

                Kirigami.Separator {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                }

                Kirigami.Heading {
                    level: 1
                    text: i18n("Application")
                    // Layout.alignment: Qt.AlignTop
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
                            text: i18n("Browse")
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
                            Controls.ToolTip.text: "toto"
                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.delay: 1000
                        }

                        Controls.Button {
                            text: i18n("Copy")
                            icon.name: "edit-copy-symbolic"
                            onClicked: {
                                WivrnServer.copy_steam_command()
                                showPassiveNotification(i18n("Copied Steam launch command"), 2000)
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
            Kirigami.Action {
                text: i18n("Headsets")
                icon.name: "item-symbolic"
                onTriggered: root.pageStack.push(Qt.resolvedUrl("HeadsetsPage.qml"))

                enabled: root.server_started && root.pageStack.depth == 1
            },
            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "settings-configure-symbolic"
                onTriggered: root.pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                enabled: root.server_started && root.pageStack.depth == 1
            }
        ]
    }

    function save() {
        var new_application;

        if (apps.get(app_combobox.currentIndex).is_custom)
            new_application = app_text.text;
        else
            new_application = apps.get(app_combobox.currentIndex).command;

        config.load(WivrnServer);
        if (config.application != new_application)
        {
            config.application = new_application;
            config.save(WivrnServer);
        }
    }
}
