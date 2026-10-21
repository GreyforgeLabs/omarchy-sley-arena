import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Sley Arena: your bot's rank on the bar. The login comes from this widget's "login" setting, or
// from the player kit's session file (~/.config/sley-arena/session.json), so it usually needs no setup.
// Click for the top of the ladder and your latest matches; click a row to open it in the browser.
BarWidget {
  id: root
  property bool menu: false
  property var ladder: []          // top rows of the ladder
  property var mine: null          // my best bot's ladder row, if ranked
  property var matches: []         // my latest matches
  property string phase: "loading" // loading | ok | offline
  readonly property string api: "https://sleylang.org/arena/api"
  readonly property string site: "https://sleylang.org/arena"
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property string fam: bar ? bar.fontFamily : Style.font.family
  readonly property string mode: setting("mode", "duel") === "brawl" ? "brawl" : "duel"
  readonly property int every: Math.max(60, Math.round(Number(setting("interval", 300))) || 300)
  readonly property string login: String(setting("login", "")) || kitLogin
  property string kitLogin: ""

  function set(k, v) {  // persist one setting in this widget's shell.json entry
    const e = { id: moduleName }
    for (const x in settings) if (x !== "id") e[x] = settings[x]
    e[k] = v, settings = e
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, e)
  }
  function close() { if (card.item) card.item.open = false; menu = false }
  function get(path, done) {
    const x = new XMLHttpRequest()
    x.onreadystatechange = () => {
      if (x.readyState !== XMLHttpRequest.DONE) return
      if (x.status === 200) { try { done(JSON.parse(x.responseText)) } catch (e) { phase = "offline" } }
      else phase = "offline"
    }
    x.open("GET", api + path)
    x.send()
  }
  function refresh() {
    get("/ladder?mode=" + mode + "&limit=200", d => {
      const bots = d.bots || []
      ladder = bots.slice(0, 5)
      mine = login ? (bots.find(b => b.owner && b.owner.login.toLowerCase() === login.toLowerCase() && !b.house) || null) : null
      phase = "ok"
      if (mine) get("/matches?bot=" + mine.bot_id + "&mode=" + mode + "&limit=4", m => matches = m.matches || [])
      else matches = []
    })
  }
  function open(url) { Quickshell.execDetached(["xdg-open", url]); close() }
  function outcome(m) {
    const me = m.seats.find(s => mine && s.bot_id === mine.bot_id)
    if (!me) return ""
    const best = Math.max(...m.seats.filter(s => s !== me).map(s => s.score))
    return (me.score > best ? "won " : me.score < best ? "lost " : "drew ") + me.score + "-" + best
  }

  implicitWidth: t.implicitWidth + Style.spaceReal(16); implicitHeight: barSize

  component Label: Text { color: root.fg; font.family: root.fam; font.pixelSize: Style.font.body; renderType: Text.NativeRendering }

  FileView {  // the player kit stores the GitHub login it signed in with
    path: Quickshell.env("HOME") + "/.config/sley-arena/session.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.kitLogin = JSON.parse(text()).login || "" } catch (e) { root.kitLogin = "" } }
  }

  Label {
    id: t
    anchors.centerIn: parent
    text: root.phase === "offline" ? "◆ arena offline"
      : root.mine ? "◆ #" + root.mine.rank + " " + root.mine.name + " " + Math.round(root.mine.rating)
      : root.ladder.length ? "◆ arena #1 " + root.ladder[0].name
      : "◆ arena"
  }
  MouseArea { anchors.fill: parent; onClicked: root.menu ? root.close() : root.menu = true }

  Timer { interval: root.every * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  onModeChanged: refresh()
  onLoginChanged: refresh()

  Loader {
    id: card
    active: root.menu
    onLoaded: item.open = true
    sourceComponent: PopupCard {
      anchorItem: root; bar: root.bar; owner: root
      contentWidth: fittedContentWidth(rows.implicitWidth + Style.spacing.popupPadding * 2)
      contentHeight: fittedContentHeight(rows.implicitHeight)
      Column {
        id: rows
        spacing: Style.space(6)
        Row {
          spacing: Style.space(12)
          Label { text: "Sley Arena"; font.bold: true }
          Repeater {
            model: ["duel", "brawl"]
            Label {
              text: modelData; opacity: root.mode === modelData ? 1 : 0.4
              MouseArea { anchors.fill: parent; onClicked: root.set("mode", modelData) }
            }
          }
        }
        Repeater {
          model: root.ladder
          Label {
            text: "#" + modelData.rank + "  " + modelData.name + "  ·  " + modelData.written_by + (modelData.house ? " (house)" : "") + "  ·  " + Math.round(modelData.rating)
            MouseArea { anchors.fill: parent; onClicked: root.open(root.site + "/bot?id=" + modelData.bot_id) }
          }
        }
        Label { visible: root.mine !== null; text: root.mine ? "you: #" + root.mine.rank + " " + root.mine.name + "  " + root.mine.wins + "W " + root.mine.losses + "L" : ""; opacity: 0.8 }
        Repeater {
          model: root.matches
          Label {
            text: "  " + root.outcome(modelData) + " vs " + modelData.seats.filter(s => !root.mine || s.bot_id !== root.mine.bot_id).map(s => s.name).join(", ")
            opacity: 0.7
            MouseArea { anchors.fill: parent; onClicked: root.open(root.site + "/match?id=" + modelData.id) }
          }
        }
        Label { visible: !root.login; text: "Sign in with the player kit to see your bot here."; opacity: 0.6 }
        Label {
          text: "open the arena ↗"; opacity: 0.6
          MouseArea { anchors.fill: parent; onClicked: root.open(root.site) }
        }
      }
    }
  }
}
