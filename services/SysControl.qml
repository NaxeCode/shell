pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// SysControl — exposes pp-data JSON + lets the dashboard fire pp-* / mon-*
// scripts. NaxeCode fork. Polls every 2s; pp-data takes ~150ms (RAPL needs
// 100ms), so the loop is mostly idle.
Singleton {
    id: root

    // Profile
    readonly property string profileActive: state.profileActive
    readonly property string profileSaved: state.profileSaved

    // Monitor layout (last `mon-*` button — not real-time hyprctl state)
    readonly property string monitorMode: state.monitorMode
    readonly property int awHz: state.awHz

    // CPU
    readonly property int cpuPkgW: state.cpuPkgW
    readonly property int cpuFreqAvgMhz: state.cpuFreqAvgMhz
    readonly property int cpuFreqMaxMhz: state.cpuFreqMaxMhz
    readonly property string cpuEpp: state.cpuEpp
    readonly property bool cpuBoost: state.cpuBoost

    // GPU
    readonly property int gpuPowerW: state.gpuPowerW
    readonly property int gpuPowerCapW: state.gpuPowerCapW
    readonly property int gpuUsagePct: state.gpuUsagePct
    readonly property int gpuVOffsetMv: state.gpuVOffsetMv

    // Govee room sensor; null if listener hasn't broadcast yet
    readonly property var room: state.room

    // Per-monitor conf state parsed from ~/.config/hypr/hyprland.conf.
    // Keyed by output name. Each value: { vrr, cm, mode, bitdepth, ... }.
    // Hyprctl's `lastIpcObject.vrr` only reports VRR ENGAGEMENT (bool), so
    // for `vrr=2` (fullscreen-only) it shows false at idle even though VRR
    // is configured on. Conf values are the truth for "is VRR enabled?".
    readonly property var monitorConf: state.monitorConf

    readonly property bool ready: state.ready

    function setProfile(name: string): void {
        if (!["cool", "normal", "gaming"].includes(name))
            return;
        Quickshell.execDetached(["sh", "-c", `~/.local/bin/pp-${name}`]);
    }

    function setMonitorMode(mode: string): void {
        const map = { desk: "mon-desk", cintiq: "mon-cin", gaming: "mon-gam", "cool-s": "mon-cool-s" };
        const cmd = map[mode];
        if (!cmd)
            return;
        Quickshell.execDetached(["sh", "-c", `~/.local/bin/${cmd}`]);
    }

    QtObject {
        id: state

        property string profileActive: "?"
        property string profileSaved: "?"
        property string monitorMode: "?"
        property int awHz: 0
        property int cpuPkgW: 0
        property int cpuFreqAvgMhz: 0
        property int cpuFreqMaxMhz: 0
        property string cpuEpp: "?"
        property bool cpuBoost: false
        property int gpuPowerW: 0
        property int gpuPowerCapW: 0
        property int gpuUsagePct: 0
        property int gpuVOffsetMv: 0
        property var room: null
        property bool ready: false
        property var monitorConf: ({})
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

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: state.monitorConf = root._parseHyprConf(text())
    }

    Process {
        id: dataProc

        command: ["pp-data"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (!raw)
                    return;
                let data;
                try {
                    data = JSON.parse(raw);
                } catch (e) {
                    console.warn("SysControl: pp-data JSON parse failed:", e);
                    return;
                }
                state.profileActive = data.profile?.active ?? "?";
                state.profileSaved = data.profile?.saved ?? "?";
                state.monitorMode = data.monitor_mode ?? "?";
                state.awHz = data.aw_hz ?? 0;
                state.cpuPkgW = data.cpu?.pkg_w ?? 0;
                state.cpuFreqAvgMhz = data.cpu?.freq_avg_mhz ?? 0;
                state.cpuFreqMaxMhz = data.cpu?.freq_max_mhz ?? 0;
                state.cpuEpp = data.cpu?.epp ?? "?";
                state.cpuBoost = data.cpu?.boost ?? false;
                state.gpuPowerW = data.gpu?.power_w ?? 0;
                state.gpuPowerCapW = data.gpu?.power_cap_w ?? 0;
                state.gpuUsagePct = data.gpu?.usage_pct ?? 0;
                state.gpuVOffsetMv = data.gpu?.v_offset_mv ?? 0;
                state.room = data.room ?? null;
                state.ready = true;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!dataProc.running)
                dataProc.running = true;
        }
    }
}
