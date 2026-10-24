import QtQml

// Test stand-in for Quickshell.Io.FileView: reads `path` once through a
// file:// XMLHttpRequest (QML_XHR_ALLOW_FILE_READ=1) and emits loaded() or
// loadFailed(). No watching.
QtObject {
  id: fv
  property string path: ""
  property bool watchChanges: false
  property bool printErrors: true
  property string content: ""
  signal loaded()
  signal loadFailed(int error)
  signal fileChanged()
  function text() { return content }
  function reload() {
    if (!path) return
    const x = new XMLHttpRequest()
    x.onreadystatechange = () => {
      if (x.readyState !== XMLHttpRequest.DONE) return
      if (x.responseText) { fv.content = x.responseText; fv.loaded() } else fv.loadFailed(1)
    }
    x.open("GET", "file://" + path)
    x.send()
  }
  onPathChanged: reload()
  Component.onCompleted: reload()
}
