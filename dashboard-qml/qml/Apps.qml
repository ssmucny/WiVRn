import QtQuick
import io.github.wivrn.wivrn

ListModel {
    id: model

    Component.onCompleted: {
            model.append({
                "name": i18nc("don't start an application automatically", "None"),
                "image_path": "",
                "command": "",
                "is_custom": false
            });

            model.append({
                "name": i18nc("choose a custom application to start", "Custom"),
                "image_path": "",
                "command": "",
                "is_custom": true
            });

        var apps = SteamApps.apps;
        for (var i = 0; i < apps.length; i++) {
            model.append({
                "name": apps[i].name,
                "image_path": apps[i].imagePath,
                "command": apps[i].command,
                "is_custom": false
            });
        }
    }
}
