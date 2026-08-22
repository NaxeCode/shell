pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.misc
import qs.utils

Singleton {
    id: root

    property list<var> ddcMonitors: []
    property bool ddcDetectionComplete
    property bool brightnessStateLoaded
    property var brightnessState: ({})
    readonly property var ddcMonitorMap: {
        const map = {};
        for (const m of ddcMonitors)
            map[m.connector] = m;
        return map;
    }
    readonly property list<Monitor> monitors: variants.instances // qmllint disable incompatible-type
    property bool appleDisplayPresent: false

    function getMonitorForScreen(screen: ShellScreen): var {
        if (!screen)
            return null;
        return monitors.find(m => m.modelData && m.modelData === screen) ?? null; // qmllint disable missing-property
    }

    function getMonitor(query: string): var {
        if (query === "active") {
            return monitors.find(m => m.modelData && Hypr.monitorFor(m.modelData)?.focused); // qmllint disable missing-property
        }

        if (query.startsWith("model:")) {
            const model = query.slice(6);
            return monitors.find(m => m.modelData && m.modelData.model === model); // qmllint disable missing-property
        }

        if (query.startsWith("serial:")) {
            const serial = query.slice(7);
            return monitors.find(m => m.modelData && (m.modelData.serialNumber === serial || m.ddcInfo?.serial === serial)); // qmllint disable missing-property
        }

        if (query.startsWith("id:")) {
            const id = parseInt(query.slice(3), 10);
            return monitors.find(m => m.modelData && Hypr.monitorFor(m.modelData)?.id === id); // qmllint disable missing-property
        }

        return monitors.find(m => m.modelData && m.modelData.name === query); // qmllint disable missing-property
    }

    function parseDdcMonitors(output: string): list<var> {
        const parsed = [];
        for (const block of output.trim().split(/\n\s*\n/)) {
            const bus = block.match(/I2C bus:\s*\/dev\/i2c-([0-9]+)/);
            const connector = block.match(/DRM connector:\s+(?:card\d+-)?(\S+)/);
            const identity = block.match(/Monitor:\s*([^:\n]+):([^:\n]+):([^\n]+)/);
            if (bus && connector)
                parsed.push({
                    busNum: bus[1],
                    connector: connector[1],
                    model: identity ? identity[2].trim() : "",
                    serial: identity ? identity[3].trim() : ""
                });
        }
        return parsed;
    }

    function restoreMonitors(): void {
        if (!ddcDetectionComplete || !brightnessStateLoaded)
            return;
        for (const monitor of monitors)
            monitor.restoreBrightness();
    }

    function rememberBrightness(key: string, value: real): void {
        if (!key || !brightnessStateLoaded)
            return;

        const storedValue = Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
        if (brightnessState[key] === storedValue)
            return;

        const next = Object.assign({}, brightnessState);
        next[key] = storedValue;
        brightnessState = next;
        brightnessSaveTimer.restart();
    }

    function snapBrightness(value: real): real {
        const percent = value * 100;
        for (const snapPoint of [25, 50, 65, 80])
            if (Math.abs(percent - snapPoint) <= 2)
                return snapPoint / 100;
        return value;
    }

    function increaseBrightness(): void {
        const monitor = getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
    }

    function decreaseBrightness(): void {
        const monitor = getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
    }

    onMonitorsChanged: {
        ddcDetectionComplete = false;
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Variants {
        id: variants

        model: Quickshell.screens // Don't respect excluded screens cause ipc

        Monitor {}
    }

    Process {
        running: true
        command: ["sh", "-c", "asdbctl get"] // To avoid warnings if asdbctl is not installed
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
    }

    Process {
        id: ddcProc

        running: true
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ddcMonitors = root.parseDdcMonitors(text);
                root.ddcDetectionComplete = true;
                Qt.callLater(root.restoreMonitors);
            }
        }
    }

    FileView {
        id: brightnessStorage

        path: `${Paths.state}/brightness.json`
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.brightnessState = parsed && typeof parsed === "object" ? parsed : {};
            } catch (error) {
                console.warn("Failed to parse saved brightness state:", error);
                root.brightnessState = {};
            }
            root.brightnessStateLoaded = true;
            root.restoreMonitors();
        }
        onLoadFailed: error => {
            root.brightnessState = {};
            root.brightnessStateLoaded = true;
            if (error === FileViewError.FileNotFound)
                Qt.callLater(() => setText("{}"));
            root.restoreMonitors();
        }
    }

    Timer {
        id: brightnessSaveTimer

        interval: 250
        onTriggered: brightnessStorage.setText(JSON.stringify(root.brightnessState))
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "brightnessUp"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "brightnessDown"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }

    IpcHandler {
        function get(): real {
            return getFor("active");
        }

        // Allows searching by active/model/serial/id/name
        function getFor(query: string): real {
            return root.getMonitor(query)?.brightness ?? -1;
        }

        function set(value: string): string {
            return setFor("active", value);
        }

        // Handles brightness value like brightnessctl: 0.1, +0.1, 0.1-, 10%, +10%, 10%-
        function setFor(query: string, value: string): string {
            const monitor = root.getMonitor(query);
            if (!monitor)
                return "Invalid monitor: " + query;

            let targetBrightness;
            if (value.endsWith("%-")) {
                const percent = parseFloat(value.slice(0, -2));
                targetBrightness = monitor.brightness - (percent / 100);
            } else if (value.startsWith("+") && value.endsWith("%")) {
                const percent = parseFloat(value.slice(1, -1));
                targetBrightness = monitor.brightness + (percent / 100);
            } else if (value.endsWith("%")) {
                const percent = parseFloat(value.slice(0, -1));
                targetBrightness = percent / 100;
            } else if (value.startsWith("+")) {
                const increment = parseFloat(value.slice(1));
                targetBrightness = monitor.brightness + increment;
            } else if (value.endsWith("-")) {
                const decrement = parseFloat(value.slice(0, -1));
                targetBrightness = monitor.brightness - decrement;
            } else if (value.includes("%") || value.includes("-") || value.includes("+")) {
                return `Invalid brightness format: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;
            } else {
                targetBrightness = parseFloat(value);
            }

            if (isNaN(targetBrightness))
                return `Failed to parse value: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;

            monitor.setBrightness(targetBrightness);

            return `Set monitor ${monitor.modelData.name} brightness to ${+monitor.brightness.toFixed(2)}`;
        }

        target: "brightness"
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property var ddcInfo: modelData ? (root.ddcMonitorMap[modelData.name] ?? null) : null
        readonly property bool isDdc: ddcInfo !== null
        readonly property string busNum: ddcInfo?.busNum ?? ""
        readonly property bool isAppleDisplay: !!modelData && root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        readonly property string stateKey: !modelData ? "" : (ddcInfo?.serial ? `serial:${ddcInfo.serial}` : (modelData.serialNumber ? `serial:${modelData.serialNumber}` : `connector:${modelData.name}`))
        readonly property string legacyStateKey: !modelData ? "" : `connector:${modelData.name}`
        property int maxBrightness: 100
        property real brightness
        property real queuedBrightness: NaN
        property int ddcRetryCount

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (monitor.isAppleDisplay) {
                        const value = parseInt(text.trim(), 10);
                        if (!isNaN(value))
                            monitor.brightness = Math.max(0, Math.min(1, value / 101));
                        return;
                    }

                    const match = text.trim().match(/^VCP\s+\S+\s+\S+\s+([0-9]+)\s+([0-9]+)/);
                    if (!match)
                        return;

                    const current = parseInt(match[1], 10);
                    const maximum = parseInt(match[2], 10);
                    if (maximum <= 0)
                        return;

                    monitor.maxBrightness = maximum;
                    monitor.brightness = Math.max(0, Math.min(1, current / maximum));
                }
            }
        }

        readonly property Process setProc: Process {
            onExited: code => { // qmllint disable signal-handler-parameters
                if (code !== 0 && monitor.ddcRetryCount < 1) {
                    monitor.ddcRetryCount++;
                    monitor.retryTimer.restart();
                    return;
                }

                if (code !== 0) {
                    console.warn(`Failed to set brightness on ${monitor.stateKey} after retry`);
                    monitor.initBrightness();
                }

                monitor.ddcRetryCount = 0;
                monitor.timer.restart();
            }
        }

        readonly property Timer retryTimer: Timer {
            interval: 250
            onTriggered: monitor.setProc.running = true
        }

        readonly property Timer timer: Timer {
            interval: 500
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    const value = monitor.queuedBrightness;
                    monitor.queuedBrightness = NaN;
                    monitor.applyBrightness(value, true, false);
                }
            }
        }

        function setBrightness(value: real): void {
            applyBrightness(root.snapBrightness(value), true, false);
        }

        function applyBrightness(value: real, persist: bool, force: bool): void {
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            const effectiveBrightness = isNaN(queuedBrightness) ? brightness : queuedBrightness;

            if (persist)
                root.rememberBrightness(stateKey, value);

            if (!force && Math.round(effectiveBrightness * 100) === rounded)
                return;

            if (isDdc && (timer.running || setProc.running || retryTimer.running)) {
                queuedBrightness = value;
                return;
            }

            queuedBrightness = NaN;
            brightness = value;

            if (isAppleDisplay)
                Quickshell.execDetached(["asdbctl", "set", rounded]);
            else if (isDdc) {
                setProc.command = ["ddcutil", "--verify", "-b", busNum, "setvcp", "10", `${Math.round(value * maxBrightness)}`];
                setProc.running = true;
            } else
                Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);
        }

        function restoreBrightness(): void {
            if (!modelData || !root.ddcDetectionComplete || !root.brightnessStateLoaded)
                return;

            let saved = root.brightnessState[stateKey];
            if (!(typeof saved === "number" && isFinite(saved)) && stateKey !== legacyStateKey) {
                saved = root.brightnessState[legacyStateKey];
                if (typeof saved === "number" && isFinite(saved)) {
                    const next = Object.assign({}, root.brightnessState);
                    delete next[legacyStateKey];
                    next[stateKey] = saved;
                    root.brightnessState = next;
                    brightnessSaveTimer.restart();
                }
            }

            if (typeof saved === "number" && isFinite(saved))
                applyBrightness(saved, false, true);
            else
                initBrightness();
        }

        function initBrightness(): void {
            if (!modelData)
                return;

            if (isAppleDisplay)
                initProc.command = ["asdbctl", "get"];
            else if (isDdc)
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            else
                initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];

            initProc.running = true;
        }

        onBusNumChanged: restoreBrightness()
        Component.onCompleted: restoreBrightness()
    }
}
