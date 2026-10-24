import QtQuick

// Test stand-in for Omarchy's qs.Ui PopupCard: lays its content out in place.
Item {
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  property int contentWidth: 280
  property int contentHeight: 200
  function fittedContentWidth(w) { return Math.ceil(w) }
  function fittedContentHeight(h) { return Math.ceil(h) }
  default property alias contentItem: holder.children
  Item { id: holder }
}
