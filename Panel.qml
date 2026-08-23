import QtQuick
import QtQuick.Controls
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
  property string gpuMode: ""
  property string runtime: ""
  property string keyboard: ""
  property string auraMode: "static"
  property string selectedAuraColor: "ff2244"
  property string slashMode: "Bounce"
  property string slashBrightness: "255"
  property string slashEnabled: "unknown"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string helperPath: configHome + "/omarchy/plugins/ayumad.g14-controls/g14ctl"
  property string message: ""
  property string errorMessage: ""

  readonly property var auraColors: [
    { value: "ff2244", label: "Red" },
    { value: "ff9900", label: "Amber" },
    { value: "ffee33", label: "Yellow" },
    { value: "33dd66", label: "Green" },
    { value: "22ccff", label: "Cyan" },
    { value: "2299ff", label: "Blue" },
    { value: "aa66ff", label: "Purple" },
    { value: "ffffff", label: "White" }
  ]
  readonly property var auraModes: [
    { value: "static", label: "Static" },
    { value: "breathe", label: "Breathe" },
    { value: "rainbow-cycle", label: "Rainbow cycle" },
    { value: "rainbow-wave", label: "Rainbow wave" },
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

  function applyAuraColor(raw) {
    var color = normalizedColor(raw)
    if (!color) {
      root.errorMessage = "Use six hex digits, for example ff2244"
      return
    }
    root.selectedAuraColor = color
    auraHexField.text = "#" + color
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
      root.gpuMode = value.gpu_mode || ""
      root.runtime = value.nvidia_runtime || ""
      root.keyboard = value.keyboard_brightness || ""
      root.auraMode = value.aura_mode || root.auraMode
      var firmwareColor = root.normalizedColor(value.aura_color)
      if (firmwareColor) {
        root.selectedAuraColor = firmwareColor
        auraHexField.text = "#" + firmwareColor
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
      blocked: auraModeDropdown.popupOpen || auraColorDropdown.popupOpen
        || slashModeDropdown.popupOpen || slashBrightnessDropdown.popupOpen
        || auraHexField.activeFocus
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
            implicitHeight: heroLabels.implicitHeight

            Text {
              id: heroIcon
              text: "󰣇"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
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
                color: Qt.darker(root.contentForeground, 1.35)
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

            InfoPair { label: "NVIDIA"; value: root.runtime || "—" }
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
                  active: modelData !== "Adaptive" && root.profile === modelData
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
              text: "KEYBOARD AURA"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                id: auraModeDropdown
                width: (parent.width - parent.spacing) / 2
                label: "EFFECT"
                value: root.auraMode
                options: root.auraModes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applyAuraMode(value)
              }

              Dropdown {
                id: auraColorDropdown
                width: (parent.width - parent.spacing) / 2
                label: "COLOR"
                value: root.selectedAuraColor
                options: root.auraColors
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applyAuraColor(value)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: auraHexField
                width: parent.width - applyColorButton.width - parent.spacing
                text: "#" + root.selectedAuraColor
                placeholderText: "#RRGGBB"
                foreground: root.contentForeground
                onAccepted: root.applyAuraColor(text)
              }

              Button {
                id: applyColorButton
                width: Style.space(82)
                text: "SET"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                onClicked: root.applyAuraColor(auraHexField.text)
              }
            }

            Button {
              width: parent.width
              text: "NEXT EFFECT"
              fontSize: Style.font.caption
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              onClicked: root.runAction(["aura-next"])
            }
          }

          PanelSeparator { foreground: root.contentForeground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SLASH LIGHTBAR"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                id: slashModeDropdown
                width: (parent.width - parent.spacing) * 0.62
                label: "MODE"
                value: root.slashMode
                options: root.slashModes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applySlashMode(value)
              }

              Dropdown {
                id: slashBrightnessDropdown
                width: (parent.width - parent.spacing) * 0.38
                label: "BRIGHTNESS"
                value: root.slashBrightness
                options: root.slashBrightnessLevels
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: root.applySlashBrightness(value)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "SLASH ON"
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
                text: "SLASH OFF"
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

          PanelSeparator { foreground: root.contentForeground }

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

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: parent.width
              text: "REFRESH"
              fontSize: Style.font.bodySmall
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              onClicked: root.refresh()
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
