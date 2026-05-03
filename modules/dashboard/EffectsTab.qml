pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    readonly property int minWidth: 500
    implicitWidth: Math.max(minWidth, flickable.contentItem.childrenRect.width + Tokens.padding.large * 2)
    implicitHeight: Math.min(flickable.contentHeight + Tokens.padding.large * 2, 900)

    // ── HyprGlass defaults (current hyprland.conf values) ──
    readonly property var hgDefaults: ({
        enabled: true,
        blur_strength: 6.0,
        blur_iterations: 3,
        refraction_strength: 0.9,
        chromatic_aberration: 0.7,
        fresnel_strength: 0.5,
        specular_strength: 0.5,
        edge_thickness: 0.08,
        lens_distortion: 0.6,
        vibrancy: 0.15,
        vibrancy_darkness: 0.0
    })

    readonly property var trDefaults: ({
        enabled: true,
        base: 0.85,
        layers: 0.4
    })

    readonly property var ghosttyDefaults: ({
        opacity: 0.85,
        blur: false
    })

    readonly property string ghosttyPath: `${Paths.home}/.config/ghostty/config`

    // ── HyprGlass mutable state ──
    property bool hgEnabled: hgDefaults.enabled
    property real hgBlurStrength: hgDefaults.blur_strength
    property int hgBlurIterations: hgDefaults.blur_iterations
    property real hgRefractionStrength: hgDefaults.refraction_strength
    property real hgChromaticAberration: hgDefaults.chromatic_aberration
    property real hgFresnelStrength: hgDefaults.fresnel_strength
    property real hgSpecularStrength: hgDefaults.specular_strength
    property real hgEdgeThickness: hgDefaults.edge_thickness
    property real hgLensDistortion: hgDefaults.lens_distortion
    property real hgVibrancy: hgDefaults.vibrancy
    property real hgVibrancyDarkness: hgDefaults.vibrancy_darkness

    property real ghosttyOpacity: ghosttyDefaults.opacity
    property bool ghosttyBlur: ghosttyDefaults.blur

    property bool _loaded: false

    function applyHg(key: string, value): void {
        Hypr.extras.batchMessage([`keyword plugin:hyprglass:${key} ${value}`]);
    }

    function applyAllHg(): void {
        Hypr.extras.batchMessage([
            `keyword plugin:hyprglass:enabled ${hgEnabled ? 1 : 0}`,
            `keyword plugin:hyprglass:blur_strength ${hgBlurStrength}`,
            `keyword plugin:hyprglass:blur_iterations ${hgBlurIterations}`,
            `keyword plugin:hyprglass:refraction_strength ${hgRefractionStrength}`,
            `keyword plugin:hyprglass:chromatic_aberration ${hgChromaticAberration}`,
            `keyword plugin:hyprglass:fresnel_strength ${hgFresnelStrength}`,
            `keyword plugin:hyprglass:specular_strength ${hgSpecularStrength}`,
            `keyword plugin:hyprglass:edge_thickness ${hgEdgeThickness}`,
            `keyword plugin:hyprglass:lens_distortion ${hgLensDistortion}`,
            `keyword plugin:hyprglass:vibrancy ${hgVibrancy}`,
            `keyword plugin:hyprglass:vibrancy_darkness ${hgVibrancyDarkness}`,
        ]);
    }

    function save(): void {
        if (!_loaded) return;
        const data = {
            enabled: hgEnabled,
            blur_strength: hgBlurStrength,
            blur_iterations: hgBlurIterations,
            refraction_strength: hgRefractionStrength,
            chromatic_aberration: hgChromaticAberration,
            fresnel_strength: hgFresnelStrength,
            specular_strength: hgSpecularStrength,
            edge_thickness: hgEdgeThickness,
            lens_distortion: hgLensDistortion,
            vibrancy: hgVibrancy,
            vibrancy_darkness: hgVibrancyDarkness,
        };
        jsonFile.setText(JSON.stringify(data, null, 2) + "\n");

        const conf = [
            "plugin {",
            "    hyprglass {",
            `        enabled = ${hgEnabled ? 1 : 0}`,
            `        blur_strength = ${hgBlurStrength}`,
            `        blur_iterations = ${hgBlurIterations}`,
            `        refraction_strength = ${hgRefractionStrength}`,
            `        chromatic_aberration = ${hgChromaticAberration}`,
            `        fresnel_strength = ${hgFresnelStrength}`,
            `        specular_strength = ${hgSpecularStrength}`,
            `        edge_thickness = ${hgEdgeThickness}`,
            `        lens_distortion = ${hgLensDistortion}`,
            `        vibrancy = ${hgVibrancy}`,
            `        vibrancy_darkness = ${hgVibrancyDarkness}`,
            "    }",
            "}",
        ].join("\n") + "\n";
        confFile.setText(conf);
    }

    function hgChange(key: string, value): void {
        applyHg(key, value);
        saveDebounce.restart();
    }

    function loadGhosttyConfig(text: string): void {
        const opMatch = text.match(/^background-opacity\s*=\s*([\d.]+)/m);
        if (opMatch) ghosttyOpacity = parseFloat(opMatch[1]);
        const blurMatch = text.match(/^background-blur\s*=\s*(\w+)/m);
        if (blurMatch) ghosttyBlur = blurMatch[1] === "true";
    }

    function saveGhostty(): void {
        Quickshell.execDetached(["sh", "-c",
            `sed -i -e 's/^background-opacity = .*/background-opacity = ${ghosttyOpacity}/' ` +
            `-e 's/^background-blur = .*/background-blur = ${ghosttyBlur}/' ` +
            `'${ghosttyPath}' && ` +
            `gdbus call --session --dest com.mitchellh.ghostty ` +
            `--object-path /com/mitchellh/ghostty ` +
            `--method org.gtk.Actions.Activate reload-config '[]' '{}'`]);
    }

    function loadFromJson(text: string): void {
        try {
            const data = JSON.parse(text);
            hgEnabled = data.enabled ?? hgDefaults.enabled;
            hgBlurStrength = data.blur_strength ?? hgDefaults.blur_strength;
            hgBlurIterations = data.blur_iterations ?? hgDefaults.blur_iterations;
            hgRefractionStrength = data.refraction_strength ?? hgDefaults.refraction_strength;
            hgChromaticAberration = data.chromatic_aberration ?? hgDefaults.chromatic_aberration;
            hgFresnelStrength = data.fresnel_strength ?? hgDefaults.fresnel_strength;
            hgSpecularStrength = data.specular_strength ?? hgDefaults.specular_strength;
            hgEdgeThickness = data.edge_thickness ?? hgDefaults.edge_thickness;
            hgLensDistortion = data.lens_distortion ?? hgDefaults.lens_distortion;
            hgVibrancy = data.vibrancy ?? hgDefaults.vibrancy;
            hgVibrancyDarkness = data.vibrancy_darkness ?? hgDefaults.vibrancy_darkness;
        } catch (e) {
            console.warn("EffectsTab: JSON parse failed, using defaults");
        }
        _loaded = true;
        applyAllHg();
    }

    function resetToDefaults(): void {
        hgEnabled = hgDefaults.enabled;
        hgBlurStrength = hgDefaults.blur_strength;
        hgBlurIterations = hgDefaults.blur_iterations;
        hgRefractionStrength = hgDefaults.refraction_strength;
        hgChromaticAberration = hgDefaults.chromatic_aberration;
        hgFresnelStrength = hgDefaults.fresnel_strength;
        hgSpecularStrength = hgDefaults.specular_strength;
        hgEdgeThickness = hgDefaults.edge_thickness;
        hgLensDistortion = hgDefaults.lens_distortion;
        hgVibrancy = hgDefaults.vibrancy;
        hgVibrancyDarkness = hgDefaults.vibrancy_darkness;

        GlobalConfig.appearance.transparency.enabled = trDefaults.enabled;
        GlobalConfig.appearance.transparency.base = trDefaults.base;
        GlobalConfig.appearance.transparency.layers = trDefaults.layers;

        ghosttyOpacity = ghosttyDefaults.opacity;
        ghosttyBlur = ghosttyDefaults.blur;

        save();
        applyAllHg();
        saveGhostty();
    }

    FileView {
        id: jsonFile

        path: `${Paths.config}/effects.json`
        printErrors: false
        onLoaded: root.loadFromJson(text())
        onLoadFailed: {
            root._loaded = true;
            root.save();
            root.applyAllHg();
        }
    }

    FileView {
        id: confFile

        path: `${Paths.config}/hyprglass-effects.conf`
        printErrors: false
    }

    FileView {
        id: ghosttyFile

        path: root.ghosttyPath
        printErrors: false
        onLoaded: root.loadGhosttyConfig(text())
    }

    Timer {
        id: saveDebounce

        interval: 200
        onTriggered: root.save()
    }

    Timer {
        id: ghosttyDebounce

        interval: 200
        onTriggered: root.saveGhostty()
    }

    StyledFlickable {
        id: flickable

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        flickableDirection: Flickable.VerticalFlick
        contentHeight: layout.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flickable
        }

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.spacing.larger

            // ── Header ────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.normal

                RowLayout {
                    spacing: Tokens.spacing.small

                    IconTextButton {
                        icon: "auto_awesome"
                        text: (Colours.transparency.enabled && root.hgEnabled)
                            ? qsTr("All effects on")
                            : qsTr("All effects off")
                        checked: Colours.transparency.enabled && root.hgEnabled
                        type: IconTextButton.Filled
                        onClicked: {
                            const enable = !(Colours.transparency.enabled && root.hgEnabled);
                            GlobalConfig.appearance.transparency.enabled = enable;
                            root.hgEnabled = enable;
                            root.applyHg("enabled", enable ? 1 : 0);
                            root.saveDebounce.restart();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                IconTextButton {
                    icon: "restart_alt"
                    text: qsTr("Default")
                    type: IconTextButton.Tonal
                    onClicked: root.resetToDefaults()
                }
            }

            // ── Transparency ──────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Transparency")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                SwitchRow {
                    label: qsTr("Enabled")
                    checked: Colours.transparency.enabled
                    onToggled: checked => {
                        GlobalConfig.appearance.transparency.enabled = checked;
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: trSliders.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer
                    opacity: Colours.transparency.enabled ? 1.0 : 0.5

                    ColumnLayout {
                        id: trSliders

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        EffectSlider {
                            label: qsTr("Base opacity")
                            value: (GlobalConfig.appearance.transparency.base ?? 0.85) * 100
                            from: 0; to: 100; stepSize: 1; decimals: 0
                            suffix: "%"
                            enabled: Colours.transparency.enabled
                            onValueModified: v => {
                                GlobalConfig.appearance.transparency.base = v / 100;
                            }
                        }

                        EffectSlider {
                            label: qsTr("Layer opacity")
                            value: (GlobalConfig.appearance.transparency.layers ?? 0.4) * 100
                            from: 0; to: 100; stepSize: 1; decimals: 0
                            suffix: "%"
                            enabled: Colours.transparency.enabled
                            onValueModified: v => {
                                GlobalConfig.appearance.transparency.layers = v / 100;
                            }
                        }
                    }
                }
            }

            // ── HyprGlass ────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("HyprGlass")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                SwitchRow {
                    label: qsTr("Enabled")
                    checked: root.hgEnabled
                    onToggled: checked => {
                        root.hgEnabled = checked;
                        root.applyHg("enabled", checked ? 1 : 0);
                        root.saveDebounce.restart();
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: hgSliders.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer
                    opacity: root.hgEnabled ? 1.0 : 0.5

                    ColumnLayout {
                        id: hgSliders

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal
                        enabled: root.hgEnabled

                        EffectSlider {
                            label: qsTr("Blur strength")
                            value: root.hgBlurStrength
                            from: 0; to: 20; stepSize: 0.5; decimals: 1
                            onValueModified: v => {
                                root.hgBlurStrength = v;
                                root.hgChange("blur_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Blur iterations")
                            value: root.hgBlurIterations
                            from: 1; to: 10; stepSize: 1; decimals: 0
                            onValueModified: v => {
                                root.hgBlurIterations = Math.round(v);
                                root.hgChange("blur_iterations", Math.round(v));
                            }
                        }

                        EffectSlider {
                            label: qsTr("Refraction")
                            value: root.hgRefractionStrength
                            from: 0; to: 2; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgRefractionStrength = v;
                                root.hgChange("refraction_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Chromatic aberration")
                            value: root.hgChromaticAberration
                            from: 0; to: 2; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgChromaticAberration = v;
                                root.hgChange("chromatic_aberration", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Fresnel")
                            value: root.hgFresnelStrength
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgFresnelStrength = v;
                                root.hgChange("fresnel_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Specular")
                            value: root.hgSpecularStrength
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgSpecularStrength = v;
                                root.hgChange("specular_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Edge thickness")
                            value: root.hgEdgeThickness
                            from: 0; to: 0.5; stepSize: 0.01; decimals: 2
                            onValueModified: v => {
                                root.hgEdgeThickness = v;
                                root.hgChange("edge_thickness", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Lens distortion")
                            value: root.hgLensDistortion
                            from: 0; to: 2; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgLensDistortion = v;
                                root.hgChange("lens_distortion", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Vibrancy")
                            value: root.hgVibrancy
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgVibrancy = v;
                                root.hgChange("vibrancy", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Vibrancy darkness")
                            value: root.hgVibrancyDarkness
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgVibrancyDarkness = v;
                                root.hgChange("vibrancy_darkness", v);
                            }
                        }
                    }
                }
            }

            // ── Ghostty ──────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Ghostty")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: ghosttyCol.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer

                    ColumnLayout {
                        id: ghosttyCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        EffectSlider {
                            label: qsTr("Background opacity")
                            value: root.ghosttyOpacity * 100
                            from: 0; to: 100; stepSize: 1; decimals: 0
                            suffix: "%"
                            onValueModified: v => {
                                root.ghosttyOpacity = v / 100;
                                ghosttyDebounce.restart();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Background blur")
                            checked: root.ghosttyBlur
                            onToggled: checked => {
                                root.ghosttyBlur = checked;
                                root.saveGhostty();
                            }
                        }
                    }
                }
            }
        }
    }

    component EffectSlider: ColumnLayout {
        id: slider

        property string label
        property real value
        property real from: 0
        property real to: 1
        property real stepSize: 0.01
        property int decimals: 2
        property string suffix: ""

        signal valueModified(real newValue)

        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: slider.label
                font.pointSize: Tokens.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: slider.value.toFixed(slider.decimals) + slider.suffix
                font.pointSize: Tokens.font.size.smaller
                color: Colours.palette.m3onSurface
                font.family: Tokens.font.family.mono
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.normal * 3
            from: slider.from
            to: slider.to
            stepSize: slider.stepSize
            value: slider.value
            onMoved: slider.valueModified(value)
        }
    }
}
