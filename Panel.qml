import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ayumad.g14-controls"
  ipcTarget: "ayumad.g14-controls"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string profile: ""
  property bool adaptive: false
  property string gpuMode: ""
  property string runtime: ""
  property string dgpuName: ""
  property string keyboard: ""
  property string auraMode: "static"
  property string selectedAuraColor: "ff2244"
  property real selectedHue: 0.0
  property string slashMode: "Bounce"
  property string slashBrightness: "255"
  property string slashEnabled: "unknown"
  readonly property string rogLogoSource: "file:///usr/share/icons/hicolor/512x512/apps/rog-control-center.png"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string helperPath: configHome + "/omarchy/plugins/ayumad.g14-controls/g14ctl"
  property string message: ""
  property string errorMessage: ""
  property bool advancedOpen: false

  readonly property var auraModes: [
    { value: "static", label: "Static" },
    { value: "breathe", label: "Breathing" },
    { value: "rainbow-cycle", label: "Color Cycle" },
    { value: "rainbow-wave", label: "Rainbow" },
    { value: "pulse", label: "Pulse" }
  ]
  readonly property var slashModes: [
    "Static", "Bounce", "Slash", "Loading", "BitStream", "Transmission",
    "Flow", "Flux", "Phantom", "Spectrum", "Hazard", "Interfacing",
    "Ramp", "GameOver", "Start", "Buzzer"
  ]
  readonly property var slashBrightnessLevels: [
    { value: "0", label: "Off" },
    { value: "64", label: "25%" },
    { value: "128", label: "50%" },
    { value: "192", label: "75%" },
    { value: "255", label: "100%" }
  ]

  readonly property color contentForeground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string contentFontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runAction(args) {
    if (actionProc.running) return
    root.message = "Applying…"
    root.errorMessage = ""
    actionProc.command = [root.helperPath].concat(args)
    actionProc.running = true
  }

  function normalizedColor(raw) {
    var value = String(raw || "").trim().replace(/^#/, "")
    return /^[0-9a-fA-F]{6}$/.test(value) ? value.toLowerCase() : ""
  }

  function colorToHue(raw) {
    var color = normalizedColor(raw)
    if (!color) return 0.0
    var red = parseInt(color.slice(0, 2), 16) / 255
    var green = parseInt(color.slice(2, 4), 16) / 255
    var blue = parseInt(color.slice(4, 6), 16) / 255
    var maximum = Math.max(red, green, blue)
    var minimum = Math.min(red, green, blue)
    var delta = maximum - minimum
    if (delta === 0) return 0.0
    var hue
    if (maximum === red) hue = ((green - blue) / delta + (green < blue ? 6 : 0)) / 6
    else if (maximum === green) hue = ((blue - red) / delta + 2) / 6
    else hue = ((red - green) / delta + 4) / 6
    return hue
  }

  function colorComponentHex(component) {
    var hex = Math.round(Math.max(0, Math.min(1, component)) * 255).toString(16)
    return hex.length === 1 ? "0" + hex : hex
  }

  function hueToColor(hue) {
    var color = Qt.hsla(Math.max(0, Math.min(1, hue)), 1, 0.5, 1)
    return colorComponentHex(color.r) + colorComponentHex(color.g) + colorComponentHex(color.b)
  }

  function applyAuraColor(raw) {
    var color = normalizedColor(raw)
    if (!color) {
      root.errorMessage = "Use six hex digits, for example ff2244"
      return
    }
    root.selectedAuraColor = color
    root.selectedHue = root.colorToHue(color)
    root.runAction(["aura-static", color])
  }

  function applyAuraMode(mode) {
    root.auraMode = String(mode)
    root.runAction(["aura-mode", root.auraMode, root.selectedAuraColor])
  }

  function applySlashMode(mode) {
    root.slashMode = String(mode)
    root.runAction(["slash-mode", root.slashMode])
  }

  function applySlashBrightness(value) {
    root.slashBrightness = String(value)
    root.runAction(["slash-brightness", root.slashBrightness])
  }

  function updateStatus(raw) {
    try {
      var value = JSON.parse(raw)
      root.profile = value.profile || ""
      root.adaptive = value.adaptive === true
      root.gpuMode = value.gpu_mode || ""
      root.runtime = value.dgpu_runtime || value.nvidia_runtime || ""
      root.dgpuName = value.dgpu_name || ""
      root.keyboard = value.keyboard_brightness || ""
      root.auraMode = value.aura_mode || root.auraMode
      var firmwareColor = root.normalizedColor(value.aura_color)
      if (firmwareColor) {
        root.selectedAuraColor = firmwareColor
        root.selectedHue = root.colorToHue(firmwareColor)
      }
      root.slashMode = value.slash_mode || root.slashMode
      root.slashBrightness = value.slash_brightness || root.slashBrightness
      root.slashEnabled = value.slash_enabled || root.slashEnabled
    } catch (error) {
      // Keep the last good state while a command is settling.
    }
  }

  function open() {
    refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    root.opened ? root.close() : root.open()
  }

  function switchPanel(direction) {
    if (root.hostWidget && root.hostWidget.bar && typeof root.hostWidget.bar.switchPanelFrom === "function")
      return root.hostWidget.bar.switchPanelFrom(root.hostWidget, direction)
    return false
  }

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      onStreamFinished: root.updateStatus(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: actionStderr
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        root.message = "Applied"
        root.errorMessage = ""
      } else {
        root.message = ""
        root.errorMessage = String(actionStderr.text || "Action failed").trim()
      }
      root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: auraModeDropdown.popupOpen
        || slashModeDropdown.popupOpen || slashBrightnessDropdown.popupOpen
      onMoveRequested: function(dx, dy) {}
      onActivateRequested: function() {}
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.height, heroLabels.implicitHeight)

            Image {
              id: heroIcon
              width: Style.space(34)
              height: width
              source: root.rogLogoSource
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              visible: false
              layer.enabled: true
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            MultiEffect {
              anchors.fill: heroIcon
              source: heroIcon
              autoPaddingEnabled: false
              colorization: 1.0
              colorizationColor: root.contentForeground
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "G14 CONTROL"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: (root.profile || "Unknown") + " · " + (root.gpuMode || "Unknown")
                color: root.contentForeground
                opacity: 0.65
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(18)

            InfoPair {
              label: "dGPU" + (root.runtime ? " · " + root.runtime : "")
              value: root.dgpuName || "—"
            }
            InfoPair { label: "Keyboard"; value: root.keyboard || "—" }
          }

          Text {
            width: parent.width
            visible: root.message !== "" || root.errorMessage !== ""
            text: root.errorMessage || root.message
            color: root.errorMessage !== "" ? Color.urgent : root.contentForeground
            opacity: root.errorMessage !== "" ? 1.0 : 0.7
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.contentForeground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "POWER PROFILE"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Flow {
              id: profileFlow
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: ["Quiet", "Balanced", "Performance", "Adaptive"]

                Button {
                  required property string modelData
                  width: (profileFlow.width - profileFlow.spacing * 3) / 4
                  text: modelData
                  fontSize: Style.font.bodySmall
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  horizontalPadding: Style.spacing.controlPaddingX
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
                  active: modelData === "Adaptive" ? root.adaptive : !root.adaptive && root.profile === modelData
                  onClicked: root.runAction(["profile", modelData.toLowerCase()])
                }
              }
            }
          }

          PanelSeparator { foreground: root.contentForeground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "KEYBOARD BACKLIGHT"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Flow {
              id: keyboardFlow
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: ["off", "low", "med", "high"]

                Button {
                  required property string modelData
                  width: (keyboardFlow.width - keyboardFlow.spacing * 3) / 4
                  text: modelData.toUpperCase()
                  fontSize: Style.font.caption
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  horizontalPadding: Style.spacing.controlPaddingX
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
                  active: root.keyboard.toLowerCase() === modelData
                  onClicked: root.runAction(["keyboard", modelData])
                }
              }
            }
          }

          PanelSeparator { foreground: root.contentForeground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "KEYBOARD COLOR"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(28)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: "#" + root.hueToColor(root.selectedHue)
                border.width: Style.normalBorderWidth
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.55)
              }

              Slider {
                id: hueSlider
                width: parent.width - Style.space(28) - parent.spacing
                height: Style.space(28)
                from: 0.0
                to: 1.0
                value: root.selectedHue
                onMoved: root.selectedHue = value
                onPressedChanged: {
                  if (!pressed) root.applyAuraColor(root.hueToColor(value))
                }

                background: Rectangle {
                  x: hueSlider.leftPadding
                  y: hueSlider.topPadding + hueSlider.availableHeight / 2 - Style.space(5)
                  width: hueSlider.availableWidth
                  height: Style.space(10)
                  radius: height / 2
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "#ff2244" }
                    GradientStop { position: 0.16; color: "#ffee33" }
                    GradientStop { position: 0.33; color: "#33dd66" }
                    GradientStop { position: 0.50; color: "#22ccff" }
                    GradientStop { position: 0.67; color: "#2299ff" }
                    GradientStop { position: 0.83; color: "#aa66ff" }
                    GradientStop { position: 1.00; color: "#ff2244" }
                  }
                }

                handle: Rectangle {
                  x: hueSlider.leftPadding + hueSlider.visualPosition * (hueSlider.availableWidth - width)
                  y: hueSlider.topPadding + hueSlider.availableHeight / 2 - height / 2
                  width: Style.space(18)
                  height: width
                  radius: width / 2
                  color: "#" + root.hueToColor(hueSlider.value)
                  border.width: Style.normalBorderWidth
                  border.color: root.contentForeground
                }
              }
            }
          }

          Button {
            width: parent.width
            text: root.advancedOpen ? "HIDE ADVANCED CONTROLS" : "SHOW ADVANCED CONTROLS"
            fontSize: Style.font.caption
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            active: root.advancedOpen
            onClicked: root.advancedOpen = !root.advancedOpen
          }

          Column {
            id: advancedControls
            visible: root.advancedOpen
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.contentForeground }

            PanelSectionHeader {
              text: "ADVANCED"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                id: auraModeDropdown
                width: (parent.width - parent.spacing) / 2
                label: "KEYBOARD MODE"
                value: root.auraMode
                options: root.auraModes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applyAuraMode(value)
              }

              Dropdown {
                id: slashModeDropdown
                width: (parent.width - parent.spacing) / 2
                label: "SLASH"
                value: root.slashMode
                options: root.slashModes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applySlashMode(value)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                id: slashBrightnessDropdown
                width: (parent.width - parent.spacing * 2) / 3
                label: "BRIGHT"
                value: root.slashBrightness
                options: root.slashBrightnessLevels
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applySlashBrightness(value)
              }

              Column {
                width: parent.width - slashBrightnessDropdown.width - parent.spacing
                spacing: Style.spacing.labelGap

                Text {
                  text: "POWER"
                  color: root.contentForeground
                  opacity: 0.65
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  width: parent.width
                  height: Style.spacing.controlHeight
                  spacing: Style.space(8)

                  Button {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    text: "ON"
                    fontSize: Style.font.caption
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: root.slashEnabled === "true"
                    onClicked: root.runAction(["slash", "on"])
                  }

                  Button {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    text: "OFF"
                    fontSize: Style.font.caption
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: root.slashEnabled === "false"
                    onClicked: root.runAction(["slash", "off"])
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "GRAPHICS MODE · REBOOT REQUIRED"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              Flow {
                id: gpuFlow
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: ["integrated", "hybrid", "ultimate"]

                  Button {
                    required property string modelData
                    width: (gpuFlow.width - gpuFlow.spacing * 2) / 3
                    text: modelData.toUpperCase()
                    fontSize: Style.font.bodySmall
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: root.gpuMode === modelData
                    onClicked: root.runAction(["graphics", modelData])
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  component InfoPair: Column {
    width: (parent.width - parent.spacing) / 2
    spacing: Style.spacing.labelGap

    property string label: ""
    property string value: ""

    Text {
      text: parent.label
      color: root.contentForeground
      opacity: 0.6
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      text: parent.value
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
