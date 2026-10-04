import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xela.backrest"
  // Hourly plan: warn once the last good backup is older than this.
  readonly property int staleAfter: 3 * 3600
  property var info: ({})
  property real now: Date.now() / 1000

  readonly property bool serviceUp: info.service === "active"
  readonly property bool running: info.running === "1"
  readonly property bool failed: info.last_status === "error" || info.error !== undefined
  readonly property bool stale: !info.last_ok || now - Number(info.last_ok) > staleAfter
  readonly property bool problem: !serviceUp || failed || stale

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
  function ago(ts) {
    if (!ts) return "nie"
    var s = Math.max(0, now - Number(ts))
    if (s < 90) return "gerade eben"
    if (s < 5400) return "vor " + Math.round(s / 60) + " min"
    if (s < 172800) return "vor " + Math.round(s / 3600) + " h"
    return "vor " + Math.round(s / 86400) + " Tagen"
  }
  function clock(ts) { return ts ? Qt.formatDateTime(new Date(Number(ts) * 1000), "ddd HH:mm") : "–" }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: probe
    command: ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/xela.backrest/status.py"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: root.parseOutput(output.text)
  }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.running ? "󰁯 …" : (root.problem ? "󰁯 !" : "󰁯")
    active: root.problem && !root.running
    dimmed: root.info.service === undefined
    horizontalMargin: 7.5
    tooltipText: {
      var lines = []
      if (!root.serviceUp) lines.push("Backrest-Dienst läuft nicht (" + (root.info.service || "?") + ")")
      if (root.running) lines.push("Backup läuft gerade …")
      lines.push("Letztes erfolgreiches Backup: " + root.ago(root.info.last_ok) + (root.info.last_ok ? " (" + root.clock(root.info.last_ok) + ")" : ""))
      if (root.failed) lines.push("Letzter Lauf fehlgeschlagen: " + (root.info.last_message || root.info.error || "siehe Backrest"))
      else if (root.info.last_status === "warning") lines.push("Letzter Lauf mit Warnungen")
      if (root.info.next) lines.push("Nächstes Backup: " + root.clock(root.info.next))
      lines.push("Klick: Backrest öffnen · Rechtsklick: aktualisieren")
      return lines.join("\n")
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.refresh()
      else if (root.bar) root.bar.run("xdg-open http://127.0.0.1:9898")
    }
  }
}
