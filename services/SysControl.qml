pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "PowerTelemetry.js" as Telemetry
import "DisplayScale.js" as DisplayScale

Singleton {
    id: root

    readonly property string actionError: state.actionError
    readonly property bool autoHdr: state.autoHdr
    readonly property bool busy: actionProc.running
    property var consumers: []
    readonly property var cpu: snapshot?.cpu ?? ({})
    readonly property string error: state.error
    readonly property var fans: snapshot?.fans ?? []
    readonly property var gpu: snapshot?.gpu ?? ({})
    readonly property var heat: snapshot?.heat ?? ({})
    readonly property var monitorConf: state.monitorConf
    readonly property string monitorMode: snapshot?.monitor_mode ?? "unknown"
    readonly property double now: state.now
    readonly property bool polling: consumers.some(consumer => consumer.polling)
    readonly property string profileActive: snapshot?.profile?.active ?? "unknown"
    readonly property var profileIssues: snapshot?.profile?.issues ?? []
    readonly property var profileMatches: snapshot?.profile?.matches ?? null
    readonly property string profileSaved: snapshot?.profile?.saved ?? "unknown"
    readonly property bool ready: snapshot !== null
    readonly property var room: snapshot?.room ?? null
    readonly property bool scaleBusy: scaleProc.running
    readonly property string scaleError: state.scaleError

    // Keep the shared pp-status schema intact, including null (unavailable).
    readonly property var snapshot: state.snapshot
    readonly property bool stale: ready && (state.error !== "" || state.now - Date.parse(snapshot.sampled_at) > 10000)
    readonly property var warnings: snapshot?.warnings ?? []

    function _parseAutoHdr(text: string): bool {
        const match = text.match(/^\s*cm_auto_hdr\s*=\s*(\d+)/m);
        return match ? Number(match[1]) !== 0 : false;
    }
    function _parseHyprConf(text: string): var {
        const result = {};
        const lines = text.split("\n");
        let inBlock = false;
        let block = {};
        for (const line of lines) {
            const stripped = line.trim();
            if (stripped.startsWith("monitorv2") && stripped.includes("{")) {
                inBlock = true;
                block = {};
                continue;
            }
            if (!inBlock)
                continue;
            if (stripped === "}") {
                if (block.output)
                    result[block.output] = block;
                inBlock = false;
                continue;
            }
            const content = stripped.split("#")[0].trim();
            if (!content || !content.includes("="))
                continue;
            const eq = content.indexOf("=");
            const k = content.slice(0, eq).trim();
            const v = content.slice(eq + 1).trim();
            block[k] = v;
        }
        return result;
    }
    function refresh(): void {
        if (!dataProc.running)
            dataProc.running = true;
    }
    function setAutoHdr(enabled: bool): void {
        state.autoHdr = enabled;
        const cmd = `${Quickshell.env("HOME")}/.local/bin/hypr-auto-hdr ${enabled ? "on" : "off"} >> ${Quickshell.env("HOME")}/.local/state/hypr-auto-hdr.log 2>&1`;
        console.warn("SysControl auto HDR:", cmd);
        Quickshell.execDetached(["sh", "-lc", cmd]);
    }
    function setMonitorMode(mode: string): void {
        const map = {
            desk: "mon-desk",
            gaming: "mon-gam"
        };
        const cmd = map[mode];
        if (!cmd)
            return;
        Quickshell.execDetached(["sh", "-c", `flock -n "$XDG_RUNTIME_DIR/caelestia-monitor-mode.lock" ~/.local/bin/${cmd}`]);
    }
    function setProfile(name: string): void {
        if (!["cool", "normal", "gaming"].includes(name) || actionProc.running)
            return;
        state.actionError = "";
        actionProc.command = [Quickshell.env("HOME") + "/.local/bin/pp-" + name];
        actionProc.running = true;
    }
    function setScale(scale: string): void {
        if (scaleProc.running || !DisplayScale.steps.some(step => step.argument === scale))
            return;
        state.scaleError = "";
        scaleProc.command = [Quickshell.env("HOME") + "/.local/bin/hypr-scale-toggle", scale];
        scaleProc.running = true;
    }
    function subscribe(consumer): void {
        if (!consumers.includes(consumer))
            consumers = consumers.concat([consumer]);
    }
    function unsubscribe(consumer): void {
        consumers = consumers.filter(item => item !== consumer);
    }

    onPollingChanged: {
        state.now = Date.now();
        if (polling)
            refresh();
    }

    QtObject {
        id: state

        property string actionError: ""
        property bool autoHdr: false
        property string error: ""
        property var monitorConf: ({})
        property double now: Date.now()
        property string scaleError: ""
        property var snapshot: null
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/monitor-layout.conf"
        watchChanges: true

        onFileChanged: reload()
        onLoaded: state.monitorConf = root._parseHyprConf(text())
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.conf"
        watchChanges: true

        onFileChanged: reload()
        onLoaded: state.autoHdr = root._parseAutoHdr(text())
    }
    Process {
        id: dataProc

        // Same reader and contract as the terminal; never parse terminal styling.
        command: [Quickshell.env("HOME") + "/.local/bin/pp-status", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!Telemetry.validSnapshot(data))
                        throw new Error("Invalid telemetry");
                    state.snapshot = data;
                    state.now = Date.now();
                    state.error = "";
                } catch (_) {
                    state.error = "Readings are temporarily unavailable";
                }
            }
        }

        onExited: (code, status) => {
            readTimeout.stop();
            if (code !== 0)
                state.error = "Readings are temporarily unavailable";
        }
        onRunningChanged: {
            if (running)
                readTimeout.restart();
        }
    }
    Timer {
        id: readTimeout

        interval: 5000

        onTriggered: {
            state.error = "Readings timed out";
            dataProc.running = false;
        }
    }
    Process {
        id: actionProc

        onExited: (code, status) => {
            state.actionError = code === 0 ? "" : "Could not apply the profile. Try again.";
            root.refresh();
        }
    }
    Process {
        id: scaleProc

        onExited: (code, status) => {
            scaleTimeout.stop();
            state.scaleError = code === 0 ? "" : "Could not change scale. Try again.";
            Hypr.refreshMonitors();
        }
        onRunningChanged: {
            if (running)
                scaleTimeout.restart();
        }
    }
    Timer {
        id: scaleTimeout

        interval: 10000

        onTriggered: {
            state.scaleError = "Scale change timed out. Check the current display size.";
            scaleProc.running = false;
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.polling

        onTriggered: root.refresh()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.polling

        onTriggered: state.now = Date.now()
    }
}
