import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// SystemTab — NaxeCode fork dashboard tab. Surfaces pp-data telemetry and
// fires pp-* / mon-* scripts via the SysControl service. Tab is registered
// in modules/dashboard/Content.qml.
Item {
    id: root

    readonly property int minWidth: 600
    implicitWidth: Math.max(minWidth, layout.implicitWidth + Tokens.padding.large * 2)
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    // Helpers — derive everything from lastIpcObject so cable swaps don't break.
    function monAvailableRates(monitor): var {
        const obj = monitor?.lastIpcObject;
        if (!obj) return [];
        const prefix = `${obj.width}x${obj.height}@`;
        const modes = obj.availableModes ?? [];
        const rates = new Set();
        for (const m of modes) {
            if (!m.startsWith(prefix)) continue;
            const match = m.match(/@([\d.]+)Hz/);
            if (!match) continue;
            const r = Math.round(parseFloat(match[1]));
            // Drop cinematic / film fallback rates (24/25/30/50). Anything <60 is
            // never what the user means by "switch refresh rate" on a desktop.
            if (r >= 60) rates.add(r);
        }
        return [...rates].sort((a, b) => a - b);
    }

    // Heuristic: a monitor that exposes any >60Hz mode at its current
    // resolution is treated as VRR-capable. Hyprland doesn't surface AdaptiveSync
    // capability directly, so this is a proxy that catches modern gaming/HDR
    // displays and excludes plain 60Hz LCDs.
    function monSupportsVrr(monitor): bool {
        const rates = monAvailableRates(monitor);
        return rates.some(r => r > 60);
    }

    // Heuristic: panel currently running 10-bit (XRGB2101010) is HDR-capable.
    // 8-bit panels can't drive HDR meaningfully. Caveat: a 10-bit panel that
    // hasn't been forced into 10-bit mode in the user's conf will look like
    // an 8-bit panel here — set bitdepth=10 in monitorv2 to expose the toggle.
    function monSupportsHdr(monitor): bool {
        const fmt = monitor?.lastIpcObject?.currentFormat ?? "";
        return fmt.includes("2101010");
    }

    // Apply runtime monitor changes via the mon-set helper, which edits the
    // matching monitorv2 block in hyprland.conf and reloads. Why not raw
    // `hyprctl keyword monitor`: Hyprland 0.54.3 silently ignores runtime
    // monitor/monitorv2 keyword overrides for monitors configured via
    // monitorv2 blocks (returns "ok" but the rate/vrr/cm don't change).
    // mon-set edits the conf and `hyprctl reload`s — both effective AND
    // persistent. Only the changed key(s) get sent; unrelated fields stay.
    function monApply(monitor, opts): void {
        const obj = monitor?.lastIpcObject;
        if (!obj) return;
        const args = ["mon-set", monitor.name];
        if (opts?.rate !== undefined) {
            args.push(`mode=${obj.width}x${obj.height}@${opts.rate}`);
            // Sync monitor-restore state file so the rate survives reboot.
            // monitor-restore reads ~/.local/state/monitor-aw-hz at boot and
            // overrides the monitorv2 block via hyprctl keyword monitor.
            if (monitor.name === "DP-2")
                Quickshell.execDetached(["sh", "-c", `printf '%s\\n' '${opts.rate}' > ~/.local/state/monitor-aw-hz`]);
        }
        if (opts?.vrr !== undefined)
            args.push(`vrr=${opts.vrr ? 1 : 0}`);
        if (opts?.cm !== undefined)
            args.push(`cm=${opts.cm}`);
        if (args.length > 2)
            Quickshell.execDetached(args);
    }

    function resetToDefaults(): void {
        SysControl.setProfile("normal");
        SysControl.setMonitorMode("desk");
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.larger

        // ── Header ─────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            IconTextButton {
                icon: "restart_alt"
                text: qsTr("Default")
                type: IconTextButton.Tonal
                onClicked: root.resetToDefaults()
            }
        }

        // ── Power profile ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Power profile")
                font.pointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        { id: "cool",   icon: "ac_unit",  label: qsTr("Cool")   },
                        { id: "normal", icon: "balance",  label: qsTr("Normal") },
                        { id: "gaming", icon: "rocket_launch", label: qsTr("Gaming") },
                    ]

                    delegate: IconTextButton {
                        required property var modelData
                        Layout.fillWidth: true
                        icon: modelData.icon
                        text: modelData.label
                        checked: SysControl.profileActive === modelData.id
                        type: IconTextButton.Filled
                        onClicked: SysControl.setProfile(modelData.id)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: SysControl.profileActive !== SysControl.profileSaved
                text: qsTr("Active = %1, saved = %2 — run power-profile %2 to sync")
                    .arg(SysControl.profileActive)
                    .arg(SysControl.profileSaved)
                font.pointSize: Tokens.font.size.smaller
                color: Colours.palette.m3error
                wrapMode: Text.WordWrap
            }
        }

        // ── Monitor layout ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Monitor layout")
                font.pointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        { id: "desk",   icon: "desktop_windows",   label: qsTr("Desk")    },
                        { id: "cintiq", icon: "draw",              label: qsTr("Cintiq")  },
                        { id: "gaming", icon: "stadia_controller", label: qsTr("Gaming")  },
                        { id: "cool-s", icon: "monitor",           label: qsTr("Cool-S")  },
                    ]

                    delegate: IconTextButton {
                        required property var modelData
                        Layout.fillWidth: true
                        icon: modelData.icon
                        text: modelData.label
                        checked: SysControl.monitorMode === modelData.id
                        type: IconTextButton.Filled
                        onClicked: SysControl.setMonitorMode(modelData.id)
                    }
                }
            }
        }

        // ── Connected monitors ────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Connected monitors")
                font.pointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: Hypr.monitors

                    delegate: StyledRect {
                        id: tile
                        required property var modelData
                        readonly property real hz: modelData?.lastIpcObject?.refreshRate ?? 0
                        readonly property var rates: root.monAvailableRates(modelData)
                        readonly property bool vrrCapable: root.monSupportsVrr(modelData)
                        // VRR state from conf, NOT from lastIpcObject.vrr.
                        // lastIpcObject.vrr reports engagement (bool); for
                        // vrr=2 (fullscreen-only) it stays false at idle.
                        readonly property bool vrrOn: {
                            const v = SysControl.monitorConf[modelData?.name]?.vrr;
                            return v !== undefined && v !== "0";
                        }
                        readonly property bool hdrCapable: root.monSupportsHdr(modelData)
                        readonly property bool hdrOn: (modelData?.lastIpcObject?.colorManagementPreset ?? "srgb") !== "srgb"

                        Layout.fillWidth: true
                        Layout.preferredHeight: monCol.implicitHeight + Tokens.padding.normal * 2
                        radius: Tokens.rounding.normal
                        color: Colours.tPalette.m3surfaceContainer

                        ColumnLayout {
                            id: monCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.rightMargin: Tokens.padding.normal
                            anchors.topMargin: Tokens.padding.normal
                            spacing: Tokens.spacing.small

                            // ── Header: icon + name + current Hz ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: "monitor"
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Tokens.font.size.normal
                                }
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: tile.modelData?.name ?? "?"
                                        font.pointSize: Tokens.font.size.smaller
                                        color: Colours.palette.m3onSurface
                                    }
                                    StyledText {
                                        text: `${Math.round(tile.hz)} Hz`
                                        font.pointSize: Tokens.font.size.normal
                                        color: Colours.palette.m3primary
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }

                            // ── Refresh rate buttons (only if multiple rates) ──
                            RowLayout {
                                Layout.fillWidth: true
                                visible: tile.rates.length > 1
                                spacing: Tokens.spacing.smaller

                                Repeater {
                                    model: tile.rates

                                    delegate: IconTextButton {
                                        required property int modelData
                                        Layout.fillWidth: true
                                        text: `${modelData}`
                                        checked: Math.round(tile.hz) === modelData
                                        type: IconTextButton.Tonal
                                        font.pointSize: Tokens.font.size.smaller
                                        verticalPadding: Tokens.padding.small
                                        onClicked: root.monApply(tile.modelData, { rate: modelData })
                                    }
                                }
                            }

                            // ── VRR + HDR toggles (only if heuristic detects support) ──
                            RowLayout {
                                Layout.fillWidth: true
                                visible: tile.vrrCapable || tile.hdrCapable
                                spacing: Tokens.spacing.smaller

                                IconTextButton {
                                    Layout.fillWidth: true
                                    visible: tile.vrrCapable
                                    icon: "tv_gen"
                                    text: tile.vrrOn ? qsTr("VRR on") : qsTr("VRR off")
                                    checked: tile.vrrOn
                                    type: IconTextButton.Tonal
                                    font.pointSize: Tokens.font.size.smaller
                                    verticalPadding: Tokens.padding.small
                                    onClicked: root.monApply(tile.modelData, { vrr: !tile.vrrOn })
                                }

                                IconTextButton {
                                    Layout.fillWidth: true
                                    visible: tile.hdrCapable
                                    icon: "hdr_on"
                                    text: tile.hdrOn ? qsTr("HDR on") : qsTr("HDR off")
                                    checked: tile.hdrOn
                                    type: IconTextButton.Tonal
                                    font.pointSize: Tokens.font.size.smaller
                                    verticalPadding: Tokens.padding.small
                                    onClicked: root.monApply(tile.modelData, { cm: tile.hdrOn ? "srgb" : "hdredid" })
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Telemetry tile ────────────────────────────────────────────────────
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: telemetry.implicitHeight + Tokens.padding.normal * 2
            radius: Tokens.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: telemetry

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.normal
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.larger

                    StatTile {
                        Layout.fillWidth: true
                        icon: "memory"
                        label: qsTr("CPU")
                        value: SysControl.ready ? `${SysControl.cpuPkgW} W` : "—"
                        sub: SysControl.ready
                            ? `${SysControl.cpuFreqAvgMhz} MHz · ${SysControl.cpuBoost ? "boost" : "no boost"}`
                            : ""
                    }

                    StatTile {
                        Layout.fillWidth: true
                        icon: "videogame_asset"
                        label: qsTr("GPU")
                        value: SysControl.ready ? `${SysControl.gpuPowerW} / ${SysControl.gpuPowerCapW} W` : "—"
                        sub: SysControl.ready
                            ? `${SysControl.gpuUsagePct}% · ${SysControl.gpuVOffsetMv} mV offset`
                            : ""
                    }

                    StatTile {
                        Layout.fillWidth: true
                        visible: SysControl.room !== null
                        icon: "thermostat"
                        label: qsTr("Room")
                        value: SysControl.room
                            ? `${SysControl.room.temp_f.toFixed(1)}°F`
                            : "—"
                        sub: SysControl.room
                            ? `${SysControl.room.humidity}% RH · ${SysControl.room.stale_s}s ago`
                            : ""
                    }
                }
            }
        }

        // ── Open pp-status ────────────────────────────────────────────────────
        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "terminal"
            text: qsTr("Open pp-status")
            type: IconTextButton.Tonal
            onClicked: Quickshell.execDetached(["ghostty", "-e", "pp-status"])
        }

        Item { Layout.fillHeight: true }
    }

    component StatTile: ColumnLayout {
        property string icon
        property string label
        property string value
        property string sub

        spacing: 2

        RowLayout {
            spacing: Tokens.spacing.small
            MaterialIcon {
                text: icon
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.normal
            }
            StyledText {
                text: label
                font.pointSize: Tokens.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }
        }
        StyledText {
            text: value
            font.pointSize: Tokens.font.size.large
            color: Colours.palette.m3onSurface
        }
        StyledText {
            text: sub
            font.pointSize: Tokens.font.size.smaller
            color: Colours.palette.m3onSurfaceVariant
            visible: text.length > 0
        }
    }
}
