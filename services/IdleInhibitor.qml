pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property alias enabled: props.enabled
    property alias durationMinutes: props.durationMinutes
    readonly property alias enabledSince: props.enabledSince
    readonly property int remainingSeconds: props.enabled && props.expiresAt > 0
        ? Math.max(0, Math.ceil((props.expiresAt - Date.now()) / 1000))
        : 0
    readonly property string durationLabel: props.durationMinutes > 0
        ? qsTr("%1 min").arg(props.durationMinutes)
        : qsTr("Indefinite")

    function syncSystemInhibitor(): void {
        const seconds = props.enabled && props.durationMinutes > 0 ? props.durationMinutes * 60 : 0;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/keep-awake", props.enabled ? "on" : "off", `${seconds}`]);
    }

    function setDuration(minutes: int): void {
        props.durationMinutes = minutes;
        if (props.enabled) {
            props.enabledSince = new Date();
            props.expiresAt = minutes > 0 ? Date.now() + minutes * 60 * 1000 : 0;
            syncSystemInhibitor();
        }
    }

    onEnabledChanged: {
        if (enabled) {
            props.enabledSince = new Date();
            props.expiresAt = props.durationMinutes > 0 ? Date.now() + props.durationMinutes * 60 * 1000 : 0;
        } else {
            props.expiresAt = 0;
        }
        syncSystemInhibitor();
    }

    PersistentProperties {
        id: props

        property bool enabled
        property int durationMinutes: 0
        property double expiresAt: 0
        property date enabledSince

        reloadableId: "idleInhibitor"
        onLoaded: {
            if (enabled && expiresAt > 0 && Date.now() >= expiresAt)
                enabled = false;
            else
                root.syncSystemInhibitor();
        }
        onReloaded: {
            if (enabled && expiresAt > 0 && Date.now() >= expiresAt)
                enabled = false;
            else
                root.syncSystemInhibitor();
        }
    }

    Timer {
        interval: 1000
        running: props.enabled && props.expiresAt > 0
        repeat: true
        onTriggered: {
            if (Date.now() >= props.expiresAt)
                props.enabled = false;
        }
    }

    IdleInhibitor {
        enabled: props.enabled
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function setDuration(minutes: int): void {
            root.setDuration(minutes);
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "idleInhibitor"
    }
}
