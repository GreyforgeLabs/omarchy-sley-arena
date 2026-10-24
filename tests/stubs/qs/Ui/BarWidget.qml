import QtQuick

// Test stand-in with the same surface as Omarchy's qs.Ui BarWidget.
Item {
  property QtObject bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: false
  readonly property int barSize: 26
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }
}
