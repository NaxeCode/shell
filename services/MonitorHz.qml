pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live scanout/VRR cadence sampled from DRM vblank counters via monitor-hz.
// This is GPU/kernel-side live Hz, not just the configured Hyprland mode.
Singleton {
    id: root

    readonly property var monitors: state.monitors
    readonly property bool ready: state.ready
    readonly property string error: state.error

    function fmtHz(hz): string {
        if (hz === null || hz === undefined || isNaN(hz))
            return "—";
        const rounded = Math.round(hz);
        if (Math.abs(hz - rounded) < 0.05)
            return `${rounded}`;
        return hz.toFixed(1);
    }

    QtObject {
        id: state
        property var monitors: []
        property bool ready: false
        property string error: ""
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/monitor-hz", "--json", "1.0"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                if (!raw)
                    return;
                try {
                    const parsed = JSON.parse(raw);
                    state.monitors = parsed;
                    state.ready = true;
                    state.error = "";
                } catch (e) {
                    state.error = `parse failed: ${e}: ${raw}`;
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                if (raw)
                    state.error = raw;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!proc.running)
                proc.running = true;
        }
    }
}
