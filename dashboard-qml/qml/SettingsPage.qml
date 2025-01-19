pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

import io.github.wivrn.wivrn

Kirigami.ScrollablePage {
    id: settings
    title: i18n("Settings")

    flickable.interactive: false

    Settings {
        id: config
    }

    ColumnLayout {
        id: column
        anchors.fill: parent

        Kirigami.FormLayout {
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Foveation")
            }

            Controls.Label {
                Layout.maximumWidth: 35 * Kirigami.Units.gridUnit
                text: i18n("A stronger foveation makes the image sharper in the center than in the periphery and makes the decoding faster. This is better for fast paced games.\n\nA weaker foveation gives a uniform sharpness in the whole image.\n\nThe recommended values are between 20% and 50% for headsets without eye tracking and between 50% and 70% for headsets with eye tracking.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                Controls.RadioButton {
                    id: auto_foveation
                    checked: true
                    text: i18n("Automatic")
                }
                Controls.RadioButton {
                    id: manual_foveation
                    text: i18n("Manual")
                }
            }

            GridLayout {
                enabled: manual_foveation.checked
                columns: 4

                Controls.Slider {
                    id: scale_slider
                    Layout.columnSpan: 3
                    implicitWidth: 20 * Kirigami.Units.gridUnit
                    from: 0
                    to: 80
                    stepSize: 1
                }

                Controls.Label {
                    text: i18n("%1 %", scale_slider.value)
                }

                Controls.Label {
                    text: i18n("Weaker")
                }
                Item {
                    // spacer item
                    Layout.fillWidth: true
                }
                Controls.Label {
                    text: i18n("Stronger")
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Bitrate")
            }

            Controls.SpinBox {
                id: bitrate
                from: 1
                to: 200

                textFromValue: (value, locale) => i18n("%1 Mbit/s", value)
                valueFromText: (text, locale) => Number.fromLocaleString(locale, text.replace("Mbit/s", ""))
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Encoder configuration")
            }

            Controls.RadioButton {
                id: auto_encoders
                checked: true
                text: i18n("Automatic")
            }
            Controls.RadioButton {
                id: manual_encoders
                text: i18n("Manual")
            }

            Controls.Label {
                visible: manual_encoders.checked
                text: i18n("To add a new encoder, split an existing encoder by clicking near an edge.\nDrag an edge to resize or remove encoders.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RectanglePartitionner {
                id: partitionner
                Kirigami.FormData.label: i18n("Layout")
                implicitWidth: 600
                implicitHeight: 300
                visible: manual_encoders.checked
                settings: config
                onCodecChanged: {
                    for (var i = 0; i < codec_combo.model.length; i++) {
                        if (codec_combo.model[i].name == codec)
                            codec_combo.currentIndex = i;
                    }
                }
                onEncoderChanged: {
                    for (var i = 0; i < encoder_combo.model.length; i++) {
                        if (encoder_combo.model[i].name == encoder)
                            encoder_combo.currentIndex = i;
                    }
                }
            }

            Controls.ComboBox {
                id: encoder_combo
                Kirigami.FormData.label: i18n("Encoder")
                visible: manual_encoders.checked
                model: [
                    { name: "auto",   label: i18n("Auto"),   codecs: "auto"},
                    { name: "nvenc",  label: i18n("nvenc"),  codecs: "auto,h264,h265"},
                    { name: "vaapi",  label: i18n("vaapi"),  codecs: "auto,h264,h265,av1"},
                    { name: "x264",   label: i18n("x264"),   codecs: "h264"},
                    { name: "vulkan", label: i18n("Vulkan"), codecs: "h264"}
                ]
                enabled: partitionner.selected
                textRole: "label"
                onCurrentIndexChanged: {
                    partitionner.encoder = encoder_combo.model[currentIndex].name;

                    // Check if the currently selected codec is supported by the new encoder
                    var supported_codecs = model[currentIndex].codecs.split(",");
                    var current_codec = codec_combo.model[codec_combo.currentIndex].name;

                    if (!supported_codecs.includes(current_codec)) {
                        for(var i = 0; i < codec_combo.model.length; i++) {
                            if (supported_codecs.includes(codec_combo.model[i].name)) {
                                codec_combo.currentIndex = i;
                                break;
                            }
                        }
                    }
                }
            }

            Controls.ComboBox {
                id: codec_combo
                Kirigami.FormData.label: i18n("Codec")
                visible: manual_encoders.checked
                model: [
                    { name: "auto", label: i18n("Auto")},
                    { name: "h264", label: i18n("H264")},
                    { name: "h265", label: i18n("H265")},
                    { name: "av1",  label: i18n("AV1")}
                ]
                enabled: partitionner.selected
                textRole: "label"
                onCurrentIndexChanged: partitionner.codec = model[currentIndex].name

                delegate: Controls.ItemDelegate {
                    required property int index
                    required property string label
                    required property string name

                    width: codec_combo.width
                    text: i18n(label)
                    font.weight: codec_combo.currentIndex === index ? Font.DemiBold : Font.Normal
                    highlighted: ListView.isCurrentItem
                    enabled: encoder_combo.model[encoder_combo.currentIndex].codecs.split(",").includes(name)
                }
            }
        }

        Item {
            // spacer item
            Layout.fillHeight: true
        }
    }

    footer: Controls.DialogButtonBox {
        standardButtons: Controls.DialogButtonBox.Ok | Controls.DialogButtonBox.Cancel | Controls.DialogButtonBox.Reset

        onAccepted: {
            settings.save();
            config.save(WivrnServer);

            applicationWindow().pageStack.pop();
        }
        onReset: {
            config.restore_defaults();
            settings.load();
        }
        onRejected: applicationWindow().pageStack.pop()
    }

    Component.onCompleted: {
        config.load(WivrnServer);
        settings.load();
    }

    function save() {
        config.bitrate = bitrate.value * 1000000;
        config.scale = manual_foveation.checked ? 1 - scale_slider.value / 100.0 : -1;
        config.manualEncoders = manual_encoders.checked;
    }

    function load() {
        bitrate.value = config.bitrate / 1000000;

        if (config.scale > 0) {
            scale_slider.value = Math.round(100 - config.scale * 100);
            manual_foveation.checked = true;
        } else {
            auto_foveation.checked = true;
        }

        if (config.manualEncoders) {
            manual_encoders.checked = true;
        } else {
            auto_encoders.checked = true;
        }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: applicationWindow().pageStack.pop()
    }
}
