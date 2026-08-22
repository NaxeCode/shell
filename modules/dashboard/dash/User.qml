pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property FileDialog facePicker
    property bool hasFace
    property color pfpFallbackColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
    required property ScreenState screenState

    anchors.fill: parent
    anchors.margins: Tokens.padding.large

    Behavior on pfpFallbackColour {
        CAnim {
        }
    }

    FileView {
        path: `${Paths.home}/.face`
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoadFailed: root.hasFace = false
        onLoaded: root.hasFace = true
    }

    Item {
        id: pfpContainer

        anchors.bottom: parent.bottom
        anchors.left: logoShape.right
        anchors.leftMargin: -(Tokens.padding.largeIncreased + Tokens.padding.extraLarge) / 2
        anchors.top: parent.top
        implicitWidth: height

        MaterialShape {
            id: shape

            anchors.centerIn: parent
            color: Qt.alpha(root.pfpFallbackColour, 1)
            implicitSize: parent.height
            layer.enabled: true
            opacity: root.pfpFallbackColour.a
            shape: MaterialShape.Pill

            MouseArea {
                id: mouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                containmentMask: QtObject {
                    function contains(pt: point): bool {
                        return shape.contains(pt) && !logoShape.contains(mouse.mapToItem(logoShape, pt)) && !uptimeShape.contains(mouse.mapToItem(uptimeShape, pt));
                    }
                }

                onClicked: {
                    root.screenState.dashboard = false;
                    root.facePicker.open();
                }
            }
        }

        Item {
            anchors.fill: parent
            layer.enabled: true

            layer.effect: Mask {
                maskSource: shape
            }

            Loader {
                active: !faceLoader.item || faceLoader.item.status !== Image.Ready
                anchors.centerIn: parent
                asynchronous: true

                sourceComponent: MaterialIcon {
                    color: Colours.palette.m3onSurfaceVariant
                    fill: 1
                    fontStyle: Tokens.font.icon.extraLarge
                    grade: -2 // Ugh material symbols are such a pain with fill
                    text: "person_add"
                }
            }

            Loader {
                id: faceLoader

                active: root.hasFace
                anchors.fill: parent
                asynchronous: true

                sourceComponent: CachingImage {
                    path: `${Paths.home}/.face`
                }
            }

            StyledRect {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3scrim, faceLoader.item?.status === Image.Ready ? 0.4 : 0)
                layer.enabled: opacity < 1
                opacity: mouse.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MaterialShape {
                    anchors.centerIn: parent
                    color: Colours.palette.m3primary
                    implicitSize: parent.height * 0.7
                    scale: mouse.pressed ? 0.9 : mouse.containsMouse ? 1 : 0.7
                    shape: MaterialShape.Diamond

                    Behavior on color {
                        CAnim {
                        }
                    }
                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        color: Colours.palette.m3onPrimary
                        fontStyle: Tokens.font.icon.large
                        text: "person_edit"
                    }
                }
            }
        }
    }

    MaterialShape {
        id: logoShape

        color: Colours.palette.m3primaryContainer
        implicitSize: Tokens.sizes.dashboard.logoSize + Tokens.padding.small * 2
        shape: MaterialShape.Gem
        x: Tokens.padding.extraSmall

        Behavior on color {
            CAnim {
            }
        }

        Loader {
            anchors.centerIn: parent
            sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : osLogo
        }
    }

    Component {
        id: osLogo

        ColouredIcon {
            id: icon

            colour: Colours.palette.m3onPrimaryContainer
            implicitSize: Tokens.sizes.dashboard.logoSize
            source: SysInfo.osLogo
        }
    }

    Component {
        id: caelestiaLogo

        Logo {
            bottomColour: Colours.palette.m3onPrimaryContainer
            implicitHeight: Tokens.sizes.dashboard.logoSize
            implicitWidth: Tokens.sizes.dashboard.logoSize
            topColour: Colours.palette.m3primary
        }
    }

    MaterialShape {
        id: uptimeShape

        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Tokens.padding.small // Clamshell is taller than what it is visually
        anchors.left: pfpContainer.right
        anchors.leftMargin: -Tokens.padding.extraLargeIncreased
        color: Colours.palette.m3tertiaryContainer
        implicitSize: Tokens.sizes.dashboard.uptimeSize + Tokens.padding.small * 2
        shape: MaterialShape.ClamShell

        Behavior on color {
            CAnim {
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            color: Colours.palette.m3onTertiaryContainer
            fontStyle: Tokens.font.icon.medium
            text: "clock_arrow_up"
        }
    }

    StyledText {
        anchors.left: uptimeShape.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.verticalCenter: uptimeShape.verticalCenter
        anchors.verticalCenterOffset: Math.round(fontInfo.pointSize * 0.1)
        elide: Text.ElideRight
        text: "up " + SysInfo.uptime.split(",").slice(0, 2).join(",") // Max 2 components
        width: Tokens.sizes.dashboard.userWidth - x - Tokens.padding.extraLarge
    }

    StyledRect {
        id: bubble1

        anchors.left: pfpContainer.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.top: bubble2.bottom
        anchors.topMargin: -Tokens.spacing.extraSmall
        color: Colours.palette.m3secondaryContainer
        implicitHeight: 10
        implicitWidth: 10
        radius: Tokens.rounding.full
    }

    StyledRect {
        id: bubble2

        anchors.left: bubble1.right
        anchors.leftMargin: Tokens.spacing.extraSmall
        anchors.verticalCenter: wmContainer.bottom
        color: Colours.palette.m3secondaryContainer
        implicitHeight: 15
        implicitWidth: 15
        radius: Tokens.rounding.full
    }

    StyledRect {
        id: wmContainer

        anchors.left: bubble2.left
        anchors.leftMargin: -Tokens.padding.medium
        color: Colours.palette.m3secondaryContainer
        implicitHeight: wmLabel.implicitHeight + Tokens.padding.small * 2
        implicitWidth: wmLabel.implicitWidth + Tokens.padding.medium * 2
        radius: Tokens.rounding.largeIncreased
        y: Tokens.padding.extraSmall

        Row {
            id: wmLabel

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                id: wmIcon

                anchors.verticalCenter: parent.verticalCenter
                color: Colours.palette.m3onSecondaryContainer
                fontStyle: wmText.font
                text: "select_window"
            }

            StyledText {
                id: wmText

                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Math.round(fontInfo.pointSize * 0.1)
                color: Colours.palette.m3onSecondaryContainer
                elide: Text.ElideRight
                font: Tokens.font.body.builders.small.vaxis("slnt", -4).build()
                text: SysInfo.wm + "..."
                width: Math.min(implicitWidth, Tokens.sizes.dashboard.userWidth - wmContainer.x - Tokens.padding.medium * 2 - wmIcon.implicitWidth - wmLabel.spacing - Tokens.padding.extraLarge)
            }
        }
    }
}
