import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts

Item {
  id: root

  property int currentTab: 0 // 0: Country Channels, 1: Global Highlights, 2: Favorites, 3: History

  function getDisplayList() {
    if (currentTab === 1) return backend.featuredChannels
    if (currentTab === 2) return backend.favorites
    if (currentTab === 3) return backend.history
    return backend.filteredChannels
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 10

    // Top Navigation Tabs
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Repeater {
        model: [
          { label: backend.activeCountryName ? "📡 " + backend.activeCountryName : "📡 Networks (" + backend.filteredChannels.length + ")", index: 0 },
          { label: "🌐 Global Highlights", index: 1 },
          { label: "❤️ Favorites (" + backend.favorites.length + ")", index: 2 },
          { label: "🕒 History", index: 3 }
        ]

        Rectangle {
          Layout.preferredHeight: 32
          Layout.preferredWidth: tabText.implicitWidth + 20
          radius: 6
          color: root.currentTab === modelData.index ? "#ff6600" : (tabMouse.containsMouse ? "#222c3a" : "#131a24")
          border.color: root.currentTab === modelData.index ? "#ff7700" : "#1e293b"
          border.width: 1

          Text {
            id: tabText
            anchors.centerIn: parent
            text: modelData.label
            color: root.currentTab === modelData.index ? "#ffffff" : "#94a3b8"
            font.pixelSize: 12
            font.bold: root.currentTab === modelData.index
          }

          MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentTab = modelData.index
          }
        }
      }

      Item { Layout.fillWidth: true }
    }

    // Search bar & status row
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.currentTab === 0 || root.currentTab === 1

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 6
        color: "#0f172a"
        border.color: searchInput.activeFocus ? "#ff7700" : "#334155"
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 6

          Text {
            text: "🔍"
            font.pixelSize: 13
          }

          TextInput {
            id: searchInput
            Layout.fillWidth: true
            color: "#f8fafc"
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onTextChanged: backend.setSearchQuery(text)

            Text {
              anchors.fill: parent
              text: "Search channels, topics, or countries..."
              color: "#475569"
              font.pixelSize: 13
              visible: !searchInput.text && !searchInput.activeFocus
            }
          }

          Text {
            text: "✕"
            color: "#94a3b8"
            font.pixelSize: 12
            visible: searchInput.text.length > 0
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                searchInput.text = ""
                backend.setSearchQuery("")
              }
            }
          }
        }
      }
    }

    // Category Filter Chips
    QQC.ScrollView {
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      contentWidth: categoryRow.implicitWidth
      clip: true
      visible: (root.currentTab === 0 || root.currentTab === 1) && backend.categories.length > 1
      QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff

      Row {
        id: categoryRow
        spacing: 6

        Repeater {
          model: backend.categories

          Rectangle {
            height: 28
            width: catLabel.implicitWidth + 18
            radius: 14
            color: backend.selectedCategory === modelData ? "#ff6600" : (chipMouse.containsMouse ? "#334155" : "#1e293b")
            border.color: backend.selectedCategory === modelData ? "#ff7700" : "#334155"
            border.width: 1

            Text {
              id: catLabel
              anchors.centerIn: parent
              text: modelData
              color: backend.selectedCategory === modelData ? "#ffffff" : "#94a3b8"
              font.pixelSize: 11
              font.bold: backend.selectedCategory === modelData
            }

            MouseArea {
              id: chipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: backend.setCategory(modelData)
            }
          }
        }
      }
    }

    // Channel List View
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "#0c1017"
      radius: 8
      border.color: "#1e293b"
      border.width: 1
      clip: true

      ListView {
        id: channelListView
        anchors.fill: parent
        anchors.margins: 6
        model: root.getDisplayList()
        spacing: 6
        clip: true

        QQC.ScrollBar.vertical: QQC.ScrollBar {
          policy: QQC.ScrollBar.AsNeeded
        }

        delegate: Rectangle {
          width: channelListView.width
          height: 52
          radius: 6
          color: isCurrentlyPlaying ? "#ff770022" : (cardMouse.containsMouse ? "#1c2534" : "#131b26")
          border.color: isCurrentlyPlaying ? "#ff7700" : (cardMouse.containsMouse ? "#334155" : "#1e293b")
          border.width: isCurrentlyPlaying ? 1.5 : 1

          readonly property bool isCurrentlyPlaying: backend.currentStreamUrl === (modelData.url || "")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            // Channel Thumbnail / Logo
            Rectangle {
              Layout.preferredWidth: 42
              Layout.preferredHeight: 34
              radius: 4
              color: "#090d14"
              border.color: "#1e293b"
              border.width: 1

              Image {
                anchors.fill: parent
                anchors.margins: 2
                source: modelData.logo || ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready
              }

              Text {
                anchors.centerIn: parent
                text: "📺"
                font.pixelSize: 16
                visible: !modelData.logo || modelData.logo === ""
              }
            }

            // Channel Name & Country
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                Layout.fillWidth: true
                text: modelData.name || "Channel"
                color: isCurrentlyPlaying ? "#ff8800" : "#f1f5f9"
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
              }

              Row {
                spacing: 6
                Text {
                  text: (modelData.category || "General") + (modelData.countryName ? " • " + modelData.countryName : "")
                  color: "#64748b"
                  font.pixelSize: 11
                }
              }
            }

            // Quality Badge
            Rectangle {
              Layout.preferredHeight: 20
              Layout.preferredWidth: qText.implicitWidth + 10
              radius: 4
              color: "#0369a1"
              visible: modelData.quality !== undefined && modelData.quality !== ""

              Text {
                id: qText
                anchors.centerIn: parent
                text: modelData.quality || "HD"
                color: "#ffffff"
                font.pixelSize: 10
                font.bold: true
              }
            }

            // Favorite button
            Rectangle {
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26
              radius: 4
              color: favCardMouse.containsMouse ? "#334155" : "transparent"

              Text {
                anchors.centerIn: parent
                text: backend.isFavorite(modelData.url || "") ? "❤️" : "🤍"
                font.pixelSize: 13
              }

              MouseArea {
                id: favCardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.toggleFavorite(modelData)
              }
            }

            // Play Icon / Playing Indicator
            Rectangle {
              Layout.preferredWidth: 30
              Layout.preferredHeight: 30
              radius: 15
              color: isCurrentlyPlaying ? "#ff6600" : (cardMouse.containsMouse ? "#0284c7" : "#1e293b")

              Text {
                anchors.centerIn: parent
                text: isCurrentlyPlaying ? "▶" : "▷"
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
              }
            }
          }

          MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.playChannel(modelData)
          }
        }
      }

      // Empty state
      Text {
        anchors.centerIn: parent
        visible: channelListView.count === 0 && !backend.isLoading
        text: root.currentTab === 2 ? "No favorite channels saved yet.\nClick ❤️ on any channel to pin it here!" :
              root.currentTab === 3 ? "No viewing history yet.\nClick any channel to start streaming!" :
              "No channels found.\nTry rotating the globe or searching another topic."
        color: "#64748b"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.4
      }

      // Loading state
      Rectangle {
        anchors.fill: parent
        color: "#0c1017dd"
        visible: backend.isLoading

        Column {
          anchors.centerIn: parent
          spacing: 12

          QQC.BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: backend.isLoading
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: backend.statusMessage
            color: "#38bdf8"
            font.pixelSize: 13
            font.bold: true
          }
        }
      }
    }
  }
}
