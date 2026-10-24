import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

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
  // Same overrides as the player kit (SLEY_ARENA_API, SLEY_ARENA_SITE, SLEY_ARENA_HOME).
  // The API is not sleylang.org by default: its bot checkpoint blocks non-browser clients.
  readonly property string api: (Quickshell.env("SLEY_ARENA_API") || "https://arena-api.greyforge.tech/arena/api").replace(/\/+$/, "")
  readonly property string site: (Quickshell.env("SLEY_ARENA_SITE") || "https://sleylang.org/arena").replace(/\/+$/, "")
  readonly property string kitHome: Quickshell.env("SLEY_ARENA_HOME") || Quickshell.env("HOME") + "/.config/sley-arena"
  readonly property color fg: bar ? bar.barForeground : Commons.Color.foreground
  readonly property string fam: bar ? bar.fontFamily : Style.font.family
  readonly property string mode: setting("mode", "duel") === "brawl" ? "brawl" : "duel"
  readonly property int every: Math.max(60, Math.round(Number(setting("interval", 300))) || 300)
  // After a failed refresh, try again within a minute instead of a whole interval.
  readonly property int pollMs: (phase === "offline" ? 60 : every) * 1000
  readonly property string login: cleanLogin(setting("login", "")) || cleanLogin(kitLogin)
  property string kitLogin: ""
  property int generation: 0       // bumps per refresh; replies to an older one are dropped

  function cleanLogin(v) { return String(v || "").trim().replace(/^@/, "") }
  function set(k, v) {  // persist one setting in this widget's shell.json entry
    const e = { id: moduleName }
    for (const x in settings) if (x !== "id") e[x] = settings[x]
    e[k] = v
    settings = e
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, e)
  }
  function close() { if (card.item) card.item.open = false; menu = false }
  // GET api + path; done(json) on success, failed() otherwise. Replies that arrive after a newer
  // refresh started (a mode switch, a new login) are ignored, so they cannot overwrite it.
  function get(path, gen, done, failed) {
    const x = new XMLHttpRequest()
    x.onreadystatechange = () => {
      if (x.readyState !== XMLHttpRequest.DONE || gen !== generation) return
      if (x.status === 200) { try { done(JSON.parse(x.responseText)); return } catch (e) {} }
      failed()
    }
    x.open("GET", api + path)
    x.send()
  }
  function refresh() {
    const gen = ++generation, m = mode, who = login.toLowerCase()
    const load = limit => get("/ladder?mode=" + m + "&limit=" + limit, gen, d => {
      const bots = Array.isArray(d.bots) ? d.bots : []
      const me = who ? bots.find(b => !b.house && b.owner && String(b.owner.login || "").toLowerCase() === who) : undefined
      if (who && !me && bots.length >= limit && limit < 1000) return load(1000)  // ranked below the first page
      ladder = bots.slice(0, 5)
      mine = me || null
      phase = "ok"
      if (mine) get("/matches?bot=" + mine.bot_id + "&mode=" + m + "&limit=4", gen,
                    r => matches = Array.isArray(r.matches) ? r.matches : [], () => matches = [])
      else matches = []
    }, () => phase = "offline")
    load(200)
  }
  // Start-up and setting changes arrive in a burst (settings, then the kit's login file):
  // one refresh after they settle instead of one per change.
  function schedule() { soon.restart() }
  function open(url) { Quickshell.execDetached(["xdg-open", url]); close() }
  // Compares seats by bot id: inside a Repeater, modelData hands out a fresh copy of a seat on
  // every access, so `s !== me` never matched and every popup row read "drew <my score>".
  function outcome(m) {
    const seats = m && m.seats ? Array.prototype.slice.call(m.seats) : []
    const me = mine ? seats.find(s => s.bot_id === mine.bot_id) : undefined
    const others = me ? seats.filter(s => s.bot_id !== me.bot_id) : []
    if (!me || !others.length) return ""
    const best = Math.max(...others.map(s => s.score))
    return (me.score > best ? "won " : me.score < best ? "lost " : "drew ") + me.score + "-" + best
  }

  implicitWidth: t.implicitWidth + Style.spaceReal(16); implicitHeight: barSize

  // Plain text: bot and player names come from other people.
  component Label: Text { color: root.fg; font.family: root.fam; font.pixelSize: Style.font.body; renderType: Text.NativeRendering; textFormat: Text.PlainText }

  FileView {  // the player kit stores the GitHub login it signed in with
    path: root.kitHome + "/session.json"
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

  Timer { id: poll; interval: root.pollMs; running: true; repeat: true; onTriggered: root.refresh() }
  Timer { id: soon; interval: 200; onTriggered: { root.refresh(); poll.restart() } }
  Component.onCompleted: schedule()
  onModeChanged: schedule()
  onLoginChanged: schedule()

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
        Label { visible: root.mine !== null; text: root.mine ? "you: #" + root.mine.rank + " " + root.mine.name + "  " + root.mine.wins + "W " + root.mine.losses + "L" + (root.mine.draws ? " " + root.mine.draws + "D" : "") : ""; opacity: 0.8 }
        Repeater {
          model: root.matches
          Label {
            text: "  " + root.outcome(modelData) + " vs " + (modelData.seats || []).filter(s => !root.mine || s.bot_id !== root.mine.bot_id).map(s => s.name).join(", ")
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
