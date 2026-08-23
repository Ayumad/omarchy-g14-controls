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
  property string view: "all"
  property string profile: ""
  property bool adaptive: false
  property string gpuMode: ""
  property string runtime: ""
  property string dgpuName: ""
  property string keyboard: ""
  property string auraMode: "static"
  property string selectedAuraColor: "ff2244"
  property real selectedHue: 0.0
  property bool auraLocked: false
  property string slashMode: "Bounce"
  property string slashBrightness: "255"
  property string slashEnabled: "unknown"
  readonly property string rogLogoSource: "file:///usr/share/icons/hicolor/512x512/apps/rog-control-center.png"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string helperPath: configHome + "/omarchy/plugins/ayumad.g14-controls/g14ctl"
  property string message: ""
  property string errorMessage: ""
  property bool advancedOpen: false
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var profileChoices: ["Quiet", "Balanced", "Performance", "Adaptive"]
  readonly property var keyboardLevels: ["off", "low", "med", "high"]
  readonly property var gpuChoices: ["integrated", "hybrid", "ultimate"]

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

  function adaptiveLevel() {
    switch (root.profile) {
      case "Quiet": return 1
      case "Performance": return 3
      default: return 2
    }
  }

  function profileOptionGlyph(profileName) {
    return profileName === "Adaptive" ? "↻" : {
      "Quiet": "󰌪",
      "Balanced": "󰊚",
      "Performance": "󰓅"
    }[profileName] || "󰂄"
  }

  function profileOptionTooltip(profileName) {
    return profileName === "Adaptive"
      ? "Adaptive · now " + (root.profile || "Balanced") + " · AC Balanced / battery Quiet"
      : profileName
  }

  function applySlashMode(mode) {
    root.slashMode = String(mode)
    root.runAction(["slash-mode", root.slashMode])
  }

  function applySlashBrightness(value) {
    root.slashBrightness = String(value)
    root.runAction(["slash-brightness", root.slashBrightness])
  }

  function cursorCount() {
    if (root.view === "profile") return root.profileChoices.length
    if (root.view === "graphics") return root.gpuChoices.length
    return root.advancedOpen ? 21 : 10
  }

  function activeProfileIndex() {
    if (root.adaptive) return root.profileChoices.indexOf("Adaptive")
    var profileIndex = root.profileChoices.indexOf(root.profile)
    return profileIndex >= 0 ? profileIndex : 0
  }

  function initialCursorIndex() {
    if (root.view === "graphics") {
      var gpuIndex = root.gpuChoices.indexOf(root.gpuMode)
      return gpuIndex >= 0 ? gpuIndex : 0
    }
    return root.activeProfileIndex()
  }

  function resetCursor() {
    root.cursorActive = false
    root.cursorIndex = root.initialCursorIndex()
    Qt.callLater(root.ensureCursorVisible)
  }

  function clampCursor() {
    root.cursorIndex = Math.max(0, Math.min(root.cursorIndex, root.cursorCount() - 1))
  }

  function adjustHue(direction) {
    root.selectedHue = Math.max(0, Math.min(1, root.selectedHue + direction * 0.025))
  }

  function moveCursor(dx, dy) {
    root.cursorActive = true
    if (root.view === "all" && root.cursorIndex === 8 && dx !== 0) {
      root.adjustHue(dx)
      return
    }
    var delta = dx !== 0 ? dx : dy
    if (delta === 0) return
    root.cursorIndex = Math.max(0, Math.min(root.cursorCount() - 1, root.cursorIndex + delta))
    Qt.callLater(root.ensureCursorVisible)
  }

  function activateCursor() {
    root.cursorActive = true
    if (root.view === "profile") {
      root.runAction(["profile", root.profileChoices[root.cursorIndex].toLowerCase()])
      return
    }
    if (root.view === "graphics") {
      root.runAction(["graphics", root.gpuChoices[root.cursorIndex]])
      return
    }

    if (root.cursorIndex < 4) {
      root.runAction(["profile", root.profileChoices[root.cursorIndex].toLowerCase()])
    } else if (root.cursorIndex < 8) {
      root.runAction(["keyboard", root.keyboardLevels[root.cursorIndex - 4]])
    } else if (root.cursorIndex === 8) {
      root.applyAuraColor(root.hueToColor(root.selectedHue))
    } else if (root.cursorIndex === 9) {
      root.advancedOpen = !root.advancedOpen
    } else if (root.cursorIndex === 10) {
      auraModeDropdown.open()
    } else if (root.cursorIndex === 11) {
      slashModeDropdown.open()
    } else if (root.cursorIndex === 12) {
      slashBrightnessDropdown.open()
    } else if (root.cursorIndex === 13) {
      root.runAction(["slash", "on"])
    } else if (root.cursorIndex === 14) {
      root.runAction(["slash", "off"])
    } else if (root.cursorIndex === 15) {
      root.runAction(["aura-lock", root.auraLocked ? "off" : "on"])
    } else if (root.cursorIndex === 16) {
      root.launchHotkeyCapture()
    } else if (root.cursorIndex === 17) {
      root.launchHotkeySetup()
    } else {
      root.runAction(["graphics", root.gpuChoices[root.cursorIndex - 18]])
    }
  }

  function cursorItem() {
    if (root.view === "profile") return profileButtons.itemAt(root.cursorIndex)
    if (root.view === "graphics") return gpuButtons.itemAt(root.cursorIndex)
    if (root.cursorIndex < 4) return profileButtons.itemAt(root.cursorIndex)
    if (root.cursorIndex < 8) return keyboardButtons.itemAt(root.cursorIndex - 4)
    if (root.cursorIndex === 8) return hueSlider
    if (root.cursorIndex === 9) return advancedButton
    if (root.cursorIndex === 10) return auraModeDropdown
    if (root.cursorIndex === 11) return slashModeDropdown
    if (root.cursorIndex === 12) return slashBrightnessDropdown
    if (root.cursorIndex === 13) return slashOnButton
    if (root.cursorIndex === 14) return slashOffButton
    if (root.cursorIndex === 15) return colorLockButton
    if (root.cursorIndex === 16) return captureHotkeysButton
    if (root.cursorIndex === 17) return setupHotkeysButton
    return gpuButtons.itemAt(root.cursorIndex - 18)
  }

  function launchHotkeyCapture() {
    if (hotkeyProc.running) return
    root.message = "Key capture opened in a terminal"
    root.errorMessage = ""
    hotkeyProc.command = ["omarchy", "launch", "terminal", root.helperPath, "hotkeys", "capture"]
    hotkeyProc.running = true
  }

  function launchHotkeySetup() {
    if (hotkeyProc.running) return
    root.message = "Hotkey setup opened in a terminal"
    root.errorMessage = ""
    hotkeyProc.command = ["omarchy", "launch", "terminal", root.helperPath, "hotkeys", "setup"]
    hotkeyProc.running = true
  }

  function ensureCursorVisible() {
    var target = root.cursorItem()
    var flickable = scrollArea ? scrollArea.contentItem : null
    if (!target || !flickable || !("contentY" in flickable)) return
    var position = target.mapToItem(panelColumn, 0, 0)
    var top = position.y
    var bottom = top + target.height
    var visibleTop = flickable.contentY
    var visibleBottom = visibleTop + scrollArea.height
    if (top < visibleTop) flickable.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > visibleBottom) flickable.contentY = Math.max(0, bottom - scrollArea.height + Style.space(8))
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
      root.auraLocked = value.aura_locked === true
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
    resetCursor()
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

  onViewChanged: root.resetCursor()
  onAdvancedOpenChanged: {
    root.clampCursor()
    Qt.callLater(root.ensureCursorVisible)
  }
  onCursorIndexChanged: Qt.callLater(root.ensureCursorVisible)

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

  Process {
    id: hotkeyProc
    stderr: StdioCollector {
      id: hotkeyStderr
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0)
        root.errorMessage = String(hotkeyStderr.text || "Could not open hotkey setup").trim()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.view === "all" ? Style.space(460) : Style.space(330))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: auraModeDropdown.popupOpen
        || slashModeDropdown.popupOpen || slashBrightnessDropdown.popupOpen
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
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
            visible: root.view === "all"
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
            visible: root.view === "all" || root.view === "profile"
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

              readonly property int columns: 4

              Repeater {
                id: profileButtons
                model: root.profileChoices

                Button {
                  required property string modelData
                  width: (profileFlow.width - profileFlow.spacing * (profileFlow.columns - 1)) / profileFlow.columns
                  text: root.view === "profile" ? "" : modelData
                  iconText: root.view === "profile" ? root.profileOptionGlyph(modelData) : ""
                  fontSize: Style.font.bodySmall
                  iconSize: Style.font.icon
                  tooltipText: root.view === "profile" ? root.profileOptionTooltip(modelData) : ""
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  horizontalPadding: Style.spacing.controlPaddingX
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
                  active: modelData === "Adaptive" ? root.adaptive : !root.adaptive && root.profile === modelData
                  hasCursor: root.cursorActive && root.cursorIndex === root.profileChoices.indexOf(modelData)
                  onClicked: root.runAction(["profile", modelData.toLowerCase()])

                  // Adaptive is a policy rather than another native ASUS
                  // profile. Its own automatic icon gets one, two, or three
                  // compact level marks for Quiet, Balanced, or Performance.
                  Row {
                    visible: root.view === "profile" && modelData === "Adaptive"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(4)
                    spacing: Style.space(1)

                    Repeater {
                      model: root.adaptiveLevel()

                      Rectangle {
                        width: Style.space(3)
                        height: Style.space(2)
                        radius: height / 2
                        color: root.contentForeground
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator {
            visible: root.view === "all"
            foreground: root.contentForeground
          }

          Column {
            visible: root.view === "all"
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
                id: keyboardButtons
                model: root.keyboardLevels

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
                  hasCursor: root.cursorActive && root.view === "all"
                    && root.cursorIndex === root.keyboardLevels.indexOf(modelData) + 4
                  onClicked: root.runAction(["keyboard", modelData])
                }
              }
            }
          }

          PanelSeparator {
            visible: root.view === "all"
            foreground: root.contentForeground
          }

          Column {
            visible: root.view === "all"
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
                  border.width: root.cursorActive && root.view === "all" && root.cursorIndex === 8
                    ? Style.normalBorderWidth : 0
                  border.color: root.contentForeground
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
            id: advancedButton
            visible: root.view === "all"
            width: parent.width
            text: root.advancedOpen ? "HIDE ADVANCED CONTROLS" : "SHOW ADVANCED CONTROLS"
            fontSize: Style.font.caption
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            active: root.advancedOpen
            hasCursor: root.cursorActive && root.cursorIndex === 9
            onClicked: root.advancedOpen = !root.advancedOpen
          }

          Column {
            id: advancedControls
            visible: root.view === "all" && root.advancedOpen
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
                hasCursor: root.cursorActive && root.cursorIndex === 10
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
                hasCursor: root.cursorActive && root.cursorIndex === 11
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
                hasCursor: root.cursorActive && root.cursorIndex === 12
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
                    id: slashOnButton
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
                    hasCursor: root.cursorActive && root.cursorIndex === 13
                    onClicked: root.runAction(["slash", "on"])
                  }

                  Button {
                    id: slashOffButton
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
                    hasCursor: root.cursorActive && root.cursorIndex === 14
                    onClicked: root.runAction(["slash", "off"])
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Button {
                id: colorLockButton
                text: root.auraLocked ? "COLOR LOCKED" : "LOCK COLOR"
                tooltipText: root.auraLocked
                  ? "Keyboard color lock is on — click to turn it off"
                  : "Keep the current keyboard lighting across theme changes"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(5)
                bordered: true
                active: root.auraLocked
                hasCursor: root.cursorActive && root.cursorIndex === 15
                onClicked: root.runAction(["aura-lock", root.auraLocked ? "off" : "on"])
              }

              Button {
                id: captureHotkeysButton
                text: "CAPTURE KEYS"
                tooltipText: "Open wev to identify your physical G14 key symbols"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(5)
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === 16
                onClicked: root.launchHotkeyCapture()
              }

              Button {
                id: setupHotkeysButton
                text: "SET UP HOTKEYS"
                tooltipText: "Guided, opt-in G14 hotkey setup with a backup and confirmation"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(5)
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === 17
                onClicked: root.launchHotkeySetup()
              }
            }

          }

          Column {
            visible: root.view === "graphics" || (root.view === "all" && root.advancedOpen)
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator {
              visible: root.view === "graphics"
              foreground: root.contentForeground
            }

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
                id: gpuButtons
                model: root.gpuChoices

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
                  hasCursor: root.cursorActive && (root.view === "graphics"
                    ? root.cursorIndex === root.gpuChoices.indexOf(modelData)
                    : root.cursorIndex === root.gpuChoices.indexOf(modelData) + 18)
                  onClicked: root.runAction(["graphics", modelData])
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
