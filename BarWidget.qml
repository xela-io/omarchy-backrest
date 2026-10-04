import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "xela.backrest"
  ipcTarget: "xela.backrest"
  // Hourly plan: warn once the last good backup is older than this.
  readonly property int staleAfter: 3 * 3600
  readonly property string webUi: "http://127.0.0.1:9898"
  property var info: ({})
  property real now: Date.now() / 1000
  property var palette: ({})

  readonly property bool serviceUp: info.service === "active"
  readonly property bool running: info.running === "1"
  readonly property bool failed: info.last_status === "error" || info.error !== undefined
  readonly property bool stale: !info.last_ok || now - Number(info.last_ok) > staleAfter
  readonly property bool problem: !serviceUp || failed || stale
  readonly property string headline: {
    if (info.service === undefined) return "Status wird geladen …"
    if (!serviceUp) return "Backrest-Dienst läuft nicht"
    if (running) return "Backup läuft gerade …"
    if (failed) return "Letztes Backup fehlgeschlagen"
    if (stale) return "Kein aktuelles Backup"
    if (info.last_status === "warning") return "Backup mit Warnungen"
    return "Backups sind aktuell"
  }

  // Icon state: running spins, ok is green, warnings yellow, failures pulse red.
  readonly property string iconState: {
    if (info.service === undefined) return "loading"
    if (running) return "running"
    if (!serviceUp || failed) return "error"
    if (stale || info.last_status === "warning") return "warning"
    return "ok"
  }
  readonly property color iconColor: {
    var fg = bar ? bar.barForeground : Color.foreground
    if (iconState === "running") return Color.accent
    if (iconState === "ok") return themeColor("green", "#8fbf6a")
    if (iconState === "warning") return themeColor("yellow", "#e5c07b")
    if (iconState === "error") return themeColor("red", Color.urgent)
    return fg
  }
  function themeColor(name, fallback) { return palette[name] || fallback }
  // Pop the icon once when a running backup finishes cleanly.
  property string prevIconState: ""
  onIconStateChanged: {
    if (iconState === "ok" && prevIconState === "running") donePulse.restart()
    prevIconState = iconState
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { now = Date.now() / 1000; if (!probe.running) probe.running = true }
  function parseOutput(raw) {
    var next = {}
    var lines = String(raw || "").trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].indexOf("=")
      if (p > 0) next[lines[i].slice(0, p)] = lines[i].slice(p + 1)
    }
    info = next
  }
  function value(key, suffix) {
    var v = info[key]
    return v === undefined || v === "" ? "–" : String(v) + (suffix || "")
  }
  function ago(ts) {
    if (!ts) return "nie"
    var s = Math.max(0, now - Number(ts))
    if (s < 90) return "gerade eben"
    if (s < 5400) return "vor " + Math.round(s / 60) + " min"
    if (s < 172800) return "vor " + Math.round(s / 3600) + " h"
    return "vor " + Math.round(s / 86400) + " Tagen"
  }
  function until(ts) {
    if (!ts) return ""
    var s = Number(ts) - now
    if (s <= 60) return "gleich"
    if (s < 5400) return "in " + Math.round(s / 60) + " min"
    return "in " + Math.round(s / 3600) + " h"
  }
  function clock(ts) { return ts ? Qt.formatDateTime(new Date(Number(ts) * 1000), "ddd HH:mm") : "–" }
  function duration(sec) {
    if (sec === undefined) return "–"
    var s = Number(sec)
    return s < 60 ? s + " s" : Math.floor(s / 60) + " min " + (s % 60) + " s"
  }
  function statusLabel(v) {
    return ({ success: "erfolgreich", warning: "mit Warnungen", error: "fehlgeschlagen", cancelled: "abgebrochen" })[v] || "–"
  }
  function count(v) { return v === undefined ? "–" : Number(v).toLocaleString(Qt.locale("de_DE"), "f", 0) }
  function openWebUi() {
    if (bar) bar.run("xdg-open " + webUi)
    close()
  }
  onOpenedChanged: if (opened) refresh()

  Process {
    id: probe
    command: ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/xela.backrest/status.py"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: root.parseOutput(output.text)
  }
  FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var next = {}
      var re = /^\s*(\w+)\s*=\s*"(#[0-9a-fA-F]{6,8})"/gm, m
      var t = text()
      while ((m = re.exec(t)) !== null) next[m[1]] = m[2]
      root.palette = next
    }
  }
  // Poll faster while a backup runs so the spinner stops promptly.
  Timer { interval: root.running ? 5000 : 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰁯"
    labelVisible: false
    dimmed: root.iconState === "loading"
    horizontalMargin: 7.5
    tooltipText: root.headline + " · letztes " + root.ago(root.info.last_ok)
    onPressed: function(b) { if (b === Qt.RightButton) root.refresh(); else root.toggle() }

    Text {
      id: icon
      anchors.centerIn: parent
      text: "󰁯"
      textFormat: Text.PlainText
      color: root.iconColor
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
      Behavior on color { ColorAnimation { duration: 300 } }

      RotationAnimation on rotation {
        running: root.iconState === "running"
        loops: Animation.Infinite
        from: 360; to: 0
        duration: 1400
        onRunningChanged: if (!running) icon.rotation = 0
      }
      SequentialAnimation on opacity {
        running: root.iconState === "error"
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) icon.opacity = 1
      }
      SequentialAnimation {
        id: donePulse
        NumberAnimation { target: icon; property: "scale"; to: 1.4; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: icon; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack }
      }
    }
  }

  KeyboardPanel {
    id: details
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: details.fittedContentWidth(Style.space(380))
    contentHeight: details.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)
        bottomPadding: Style.space(8)

        Text { text: "Backup"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
        Text {
          width: parent.width; wrapMode: Text.WordWrap
          text: root.headline
          color: root.problem && !root.running ? Color.urgent : Color.popups.text
          font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
        }
        Text {
          visible: root.failed
          width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
          text: root.value("last_message") !== "–" ? root.value("last_message") : root.value("error")
          color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }

        PanelSeparator {}
        PanelSectionHeader { text: "ZEITPLAN" }
        Column {
          width: parent.width; spacing: Style.space(5)
          Text { text: "Letztes erfolgreiches  " + root.ago(root.info.last_ok) + (root.info.last_ok ? "  (" + root.clock(root.info.last_ok) + ")" : ""); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
          Text { visible: root.info.next !== undefined; text: "Nächstes  " + root.clock(root.info.next) + "  (" + root.until(root.info.next) + ")"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
          Text { text: "Snapshots im Repo  " + root.value("snapshots"); color: Qt.darker(Color.popups.text, 1.3); font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }

        PanelSectionHeader { text: "LETZTER LAUF"; visible: root.info.last_start !== undefined }
        Rectangle {
          visible: root.info.last_start !== undefined
          width: parent.width; implicitHeight: runCard.implicitHeight + Style.space(20)
          radius: Style.cornerRadius; color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.05)
          Column {
            id: runCard
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Style.space(10); spacing: Style.space(5)
            Text { text: root.clock(root.info.last_start) + "  ·  " + root.duration(root.info.duration) + "  ·  " + root.statusLabel(root.info.last_status); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Neu hochgeladen  " + root.value("data_added") + "  von  " + root.value("bytes_total"); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Dateien  " + root.count(root.info.files_total) + "  ·  neu " + root.count(root.info.files_new) + "  ·  geändert " + root.count(root.info.files_changed); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
        }

        PanelSeparator {}
        Row {
          spacing: Style.space(8)
          Button { text: "Backrest öffnen"; bordered: true; onClicked: root.openWebUi() }
          Button { text: "Aktualisieren"; bordered: true; onClicked: root.refresh() }
        }
      }
    }
  }
}
