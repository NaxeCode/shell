import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "../../services/PowerTelemetry.js" as Telemetry

Item {
    id: root

    readonly property var cpu: SysControl.cpu
    property bool details: false
    readonly property var gpu: SysControl.gpu
    readonly property var room: SysControl.room
    readonly property var roomAge: Telemetry.age(room?.ts, SysControl.now)
    readonly property bool roomStale: !!room && (room.stale === true || roomAge === null || roomAge > 300)

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: profiles.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium

            ColumnLayout {
                id: profiles

                anchors.left: parent.left
                anchors.margins: Tokens.padding.medium
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        font: Tokens.font.body.medium
                        text: qsTr("Power mode")
                    }
                    StyledText {
                        color: SysControl.profileMatches === true ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        text: SysControl.busy ? qsTr("Applying…") : !SysControl.ready ? "—" : SysControl.profileMatches === true ? qsTr("Settings verified") : qsTr("Check settings")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: [
                            {
                                id: "cool",
                                icon: "ac_unit",
                                label: "Cool"
                            },
                            {
                                id: "normal",
                                icon: "balance",
                                label: "Normal"
                            },
                            {
                                id: "gaming",
                                icon: "sports_esports",
                                label: "Gaming"
                            }
                        ]

                        delegate: IconTextButton {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            checked: SysControl.profileSaved === modelData.id
                            disabled: SysControl.busy || (checked && SysControl.profileMatches === true)
                            // The selected mode remains visibly selected, not greyed out.
                            disabledColour: checked ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer
                            disabledOnColour: checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            icon: modelData.icon
                            text: modelData.label
                            type: checked ? IconTextButton.Filled : IconTextButton.Tonal

                            onClicked: SysControl.setProfile(modelData.id)
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    color: SysControl.actionError || SysControl.profileMatches === false ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    text: SysControl.actionError || (SysControl.profileMatches === false ? qsTr("Some settings differ from %1. Select the mode again to reapply it.").arg(Telemetry.profileLabel(SysControl.profileSaved)) : qsTr("Cool keeps heat down. Normal balances speed. Gaming allows more power."))
                    wrapMode: Text.WordWrap
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: Tokens.spacing.small
            columns: root.width >= 520 ? 2 : 1
            rowSpacing: Tokens.spacing.small

            SystemMetricCard {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                caution: root.roomStale
                icon: "thermostat"
                note: !root.room ? qsTr("Waiting for the Govee sensor") : root.roomStale ? qsTr("Old reading · sensor needs attention") : qsTr("Govee · calibrated temperature")
                rows: [
                    {
                        label: "Humidity",
                        value: Telemetry.reading(root.room?.humidity, "%", 1)
                    },
                    {
                        label: "Updated",
                        value: Telemetry.ageLabel(root.roomAge)
                    }
                ]
                title: qsTr("Room")
                value: Telemetry.reading(root.room?.temp_f, "°F", 1)
            }
            SystemMetricCard {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "air"
                note: qsTr("Estimated tower only · monitors excluded.")
                rows: [
                    {
                        label: "Estimated draw",
                        value: Telemetry.range(SysControl.heat.tower_estimate_w, "W")
                    },
                    {
                        label: "CPU + GPU sensors",
                        value: Telemetry.reading(SysControl.heat.component_w, " W", 1)
                    }
                ]
                title: qsTr("Tower heat · estimate")
                unit: "BTU/h"
                value: Telemetry.range(SysControl.heat.tower_estimate_btu_h)
            }
            SystemMetricCard {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "memory"
                note: ""
                rows: [
                    {
                        label: "Load / temperature",
                        value: Telemetry.reading(root.cpu.usage_pct, "%", 1) + " · " + Telemetry.reading(root.cpu.temp_c, "°C", 1)
                    },
                    {
                        label: "Clock / ceiling",
                        value: Telemetry.reading(Telemetry.finite(root.cpu.freq_avg_mhz) ? root.cpu.freq_avg_mhz / 1000 : null, "", 2) + " / " + Telemetry.reading(Telemetry.finite(root.cpu.freq_max_mhz) ? root.cpu.freq_max_mhz / 1000 : null, " GHz", 1)
                    },
                    {
                        label: "Boost",
                        value: ({
                                on: "On",
                                off: "Off",
                                mixed: "Mixed",
                                unavailable: "—"
                            })[root.cpu.boost_state] ?? "—"
                    }
                ]
                title: qsTr("CPU")
                unit: "W · package"
                value: Telemetry.reading(root.cpu.pkg_w, "", 1)
            }
            SystemMetricCard {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "videogame_asset"
                note: ""
                rows: [
                    {
                        label: "Load / temperature",
                        value: Telemetry.reading(root.gpu.usage_pct, "%") + " · " + Telemetry.reading(root.gpu.temp_c, "°C")
                    },
                    {
                        label: "Power ceiling",
                        value: Telemetry.reading(root.gpu.power_cap_w, " W")
                    },
                    {
                        label: "Fan",
                        value: Telemetry.reading(root.gpu.fan_rpm, " RPM")
                    }
                ]
                title: qsTr("GPU")
                unit: "W · " + (root.gpu.power_label ?? "sensor")
                value: Telemetry.reading(root.gpu.power_w, "", 1)
            }
        }
        StyledText {
            Layout.fillWidth: true
            color: Colours.palette.m3error
            text: SysControl.warnings.join(" · ")
            visible: text !== ""
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true

            IconTextButton {
                icon: root.details ? "expand_less" : "expand_more"
                text: root.details ? qsTr("Fewer details") : qsTr("More readings")
                type: IconTextButton.Tonal

                onClicked: root.details = !root.details
            }
            Item {
                Layout.fillWidth: true
            }
            IconTextButton {
                icon: "terminal"
                text: qsTr("Terminal view")
                type: IconTextButton.Text

                onClicked: Quickshell.execDetached(["ghostty", "-e", "pp-status"])
            }
        }
        StyledRect {
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: detailsColumn.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            visible: root.details

            ColumnLayout {
                id: detailsColumn

                anchors.left: parent.left
                anchors.margins: Tokens.padding.medium
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Tokens.spacing.small

                StyledText {
                    font: Tokens.font.body.medium
                    text: qsTr("More readings")
                }
                Repeater {
                    model: [
                        {
                            label: "CPU policy",
                            value: (root.cpu.governor ?? "—") + " · " + (root.cpu.epp ?? "—")
                        },
                        {
                            label: "CPU threads online",
                            value: Telemetry.reading(root.cpu.threads_online) + " / " + Telemetry.reading(root.cpu.threads_present)
                        },
                        {
                            label: "CPU ceilings across cores",
                            value: Telemetry.reading(root.cpu.freq_min_cap_mhz, " MHz") + " – " + Telemetry.reading(root.cpu.freq_max_mhz, " MHz")
                        },
                        {
                            label: "GPU core / memory clock",
                            value: Telemetry.reading(root.gpu.core_clock?.current, " MHz") + " / " + Telemetry.reading(root.gpu.memory_clock?.current, " MHz")
                        },
                        {
                            label: "GPU hotspot / memory",
                            value: Telemetry.reading(root.gpu.junction_c, "°C") + " / " + Telemetry.reading(root.gpu.memory_c, "°C")
                        },
                        {
                            label: "GPU power policy",
                            value: (root.gpu.mode ?? "—") + " · " + (root.gpu.dpm ?? "—")
                        },
                        {
                            label: "GPU voltage offset",
                            value: Telemetry.reading(root.gpu.v_offset_mv, " mV")
                        },
                        {
                            label: "Room sensor battery",
                            value: Telemetry.reading(root.room?.battery, "%")
                        },
                        {
                            label: "Room raw / offset",
                            value: Telemetry.reading(root.room?.temp_raw_f, "°F", 2) + " / " + Telemetry.reading(root.room?.offset_f, "°F", 2)
                        }
                    ].concat(SysControl.fans.map(fan => ({
                                label: fan.name,
                                value: Telemetry.reading(fan.rpm, " RPM") + " · " + Telemetry.reading(fan.duty_pct, "% duty", 1)
                            })))

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            color: Colours.palette.m3onSurfaceVariant
                            text: modelData.label
                            wrapMode: Text.WordWrap
                        }
                        StyledText {
                            Layout.maximumWidth: detailsColumn.width * 0.58
                            horizontalAlignment: Text.AlignRight
                            text: modelData.value
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    color: Colours.palette.m3onSurfaceVariant
                    text: qsTr("Heat model assumes 35–70 W for other components and 85–92% power-supply efficiency. It excludes monitors and cannot predict how quickly the room warms.")
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    Layout.fillWidth: true
                    color: Colours.palette.m3error
                    text: SysControl.profileIssues.join("\n")
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
