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
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string helperPath: configHome + "/omarchy/plugins/ayumad.g14-controls/g14ctl"
  property string message: ""
  property string errorMessage: ""

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

  function updateStatus(raw) {
    try {
      var value = JSON.parse(raw)
      root.profile = value.profile || ""
      root.gpuMode = value.gpu_mode || ""
      root.runtime = value.nvidia_runtime || ""
      root.keyboard = value.keyboard_brightness || ""
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
    onExited: {
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
                model: ["Quiet", "Balanced", "Performance"]

                Button {
                  required property string modelData
                  width: (profileFlow.width - profileFlow.spacing * 2) / 3
                  text: modelData
                  fontSize: Style.font.bodySmall
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  horizontalPadding: Style.spacing.controlPaddingX
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
                  active: root.profile === modelData
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
                model: ["off", "low", "med", "high", "down", "up"]

                Button {
                  required property string modelData
                  width: (keyboardFlow.width - keyboardFlow.spacing * 5) / 6
                  text: modelData.toUpperCase()
                  fontSize: Style.font.caption
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  horizontalPadding: Style.spacing.controlPaddingX
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
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
              text: "AURA / SLASH"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Flow {
              id: auraFlow
              width: parent.width
              spacing: Style.space(6)

              Button {
                width: (auraFlow.width - auraFlow.spacing * 3) / 4
                text: "NEXT"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                onClicked: root.runAction(["aura-next"])
              }
              Button {
                width: (auraFlow.width - auraFlow.spacing * 3) / 4
                text: "RED"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                onClicked: root.runAction(["aura-static", "ff2244"])
              }
              Button {
                width: (auraFlow.width - auraFlow.spacing * 3) / 4
                text: "BLUE"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                onClicked: root.runAction(["aura-static", "2299ff"])
              }
              Button {
                width: (auraFlow.width - auraFlow.spacing * 3) / 4
                text: "SLASH"
                fontSize: Style.font.caption
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                onClicked: root.runAction(["slash", "on"])
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
              width: (parent.width - parent.spacing) / 2
              text: "SLASH OFF"
              fontSize: Style.font.bodySmall
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              onClicked: root.runAction(["slash", "off"])
            }
            Button {
              width: (parent.width - parent.spacing) / 2
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
