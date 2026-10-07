import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
  id: mainWindow
  width: 940
  height: 640
  color: "#090a0c"

  property bool helpVisible: false
  property var geoCountries: []
  property var catalogStations: []

  Component.onCompleted: {
    try {
      var geo = JSON.parse(backend.countriesJson || "{}")
      if (geo && geo.features) {
        geoCountries = geo.features
        globe.countries = geo.features
      }
    } catch(e) {
      console.warn("Error parsing countries JSON:", e)
    }
    globe.stations = backend.worldSignals
  }

  // Keyboard controls (only active when not typing in search bar)
  Item {
    focus: true
    Keys.onPressed: function(event) {
      if (searchField.activeFocus) {
        if (event.key === Qt.Key_Escape) {
          searchField.text = ""
          backend.search("")
          mainWindow.forceActiveFocus()
          event.accepted = true
        }
        return
      }

      if (event.key === Qt.Key_Space) {
        backend.togglePlayPause()
        event.accepted = true
      } else if (event.key === Qt.Key_R) {
        backend.playRandom()
        event.accepted = true
      } else if (event.key === Qt.Key_F || event.key === Qt.Key_F11) {
        backend.toggleFullscreen()
        event.accepted = true
      } else if (event.key === Qt.Key_M) {
        backend.toggleMute()
        event.accepted = true
      } else if (event.key === Qt.Key_Slash) {
        searchField.forceActiveFocus()
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        if (backend.isFullscreen) {
          backend.toggleFullscreen()
        } else if (mainWindow.helpVisible) {
          mainWindow.helpVisible = false
        }
        event.accepted = true
      }
    }
  }

  // ================= MAIN COLUMN =================
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ================= TOP HEADER BAR =================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 46
      color: "#090a0c"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 12

        // App Title & Hacker Telemetry
        Row {
          spacing: 8
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: "#00ff66"
            anchors.verticalCenter: parent.verticalCenter
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              NumberAnimation { from: 0.3; to: 1.0; duration: 900 }
              NumberAnimation { from: 1.0; to: 0.3; duration: 900 }
            }
          }

          Text {
            text: "TV_ATLAS"
            color: "#00f0ff"
            font.pixelSize: 14
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: 2.0
          }

          Text {
            text: "// SAT.GRID"
            color: "#00ff66"
            font.pixelSize: 10
            font.bold: true
            font.family: "monospace"
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Item { Layout.fillWidth: true }

        // Centered Terminal Search Field (Hacker Cyber Input)
        Rectangle {
          Layout.preferredWidth: Math.min(320, mainWindow.width * 0.35)
          Layout.preferredHeight: 30
          radius: 4
          color: "#050b12"
          border.color: searchField.activeFocus ? "#00f0ff" : "#0d2233"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
              text: "SCAN>"
              color: searchField.activeFocus ? "#00f0ff" : "#00ff66"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }

            TextInput {
              id: searchField
              Layout.fillWidth: true
              Layout.fillHeight: true
              verticalAlignment: TextInput.AlignVCenter
              color: "#00f0ff"
              selectionColor: "#00ff6644"
              font.pixelSize: 12
              font.family: "monospace"
              clip: true
              selectByMouse: true
              onTextEdited: backend.search(text)
              onAccepted: backend.search(text)

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: backend.activeCountryName ? (backend.activeCountryName + " // ALL CHANNELS") : "15,444 NODES // SEARCH..."
                color: "#2a4d69"
                font.pixelSize: 11
                font.family: "monospace"
                visible: !searchField.text && !searchField.activeFocus
              }
            }

            Text {
              text: "✕"
              color: "#00f0ff88"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
              visible: searchField.text !== ""
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  searchField.text = ""
                  backend.search("")
                }
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Shuffle / Random Tune Button
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 4
          color: randomMouse.containsMouse ? "#1a222d" : "transparent"

          Text {
            anchors.centerIn: parent
            text: "🔀"
            font.pixelSize: 13
          }

          MouseArea {
            id: randomMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.playRandom()
          }
        }

        // Help Button
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 4
          color: mainWindow.helpVisible ? "#1e293b" : (helpMouse.containsMouse ? "#1a222d" : "transparent")

          Text {
            anchors.centerIn: parent
            text: "?"
            color: "#9099a3"
            font.pixelSize: 14
            font.bold: true
            font.family: "monospace"
          }

          MouseArea {
            id: helpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mainWindow.helpVisible = !mainWindow.helpVisible
          }
        }

        // Fullscreen / Cinema Toggle Button
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 4
          color: backend.isFullscreen ? "#00e5ff33" : (fsHeaderMouse.containsMouse ? "#1a222d" : "transparent")
          border.color: backend.isFullscreen ? "#00e5ff" : "transparent"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: backend.isFullscreen ? "🗕" : "⛶"
            color: backend.isFullscreen || fsHeaderMouse.containsMouse ? "#00e5ff" : "#9099a3"
            font.pixelSize: 13
            font.bold: true
            font.family: "monospace"
          }

          MouseArea {
            id: fsHeaderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.toggleFullscreen()
          }
        }

        // Close Button
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 4
          color: closeMouse.containsMouse ? "#3b1818" : "transparent"

          Text {
            anchors.centerIn: parent
            text: "✕"
            color: closeMouse.containsMouse ? "#f87171" : "#9099a3"
            font.pixelSize: 13
            font.bold: true
            font.family: "monospace"
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mainWindow.close()
          }
        }
      }

      // Thin hairline separator
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: "#18202b"
      }
    }

    // ================= MAIN BODY SPLIT =================
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      RowLayout {
        anchors.fill: parent
        spacing: 0

        // ================= LEFT: 3D EARTH GLOBE =================
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Globe {
            id: globe
            anchors.fill: parent
            anchors.margins: 14
            anchors.bottomMargin: 32
            activeCountryCode: backend.activeCountryCode
            accentColor: "#00f0ff"
            signalColor: "#00ff66"
            landColor: "#081320"
            sphereColor: "#040b12"
            backgroundColor: "#03070c"
            gridColor: "#00f0ff22"
            outlineColor: "#00f0ff66"

            onCountryActivated: function(code, name) {
              backend.selectCountry(code, name)
            }

            onStationActivated: function(station) {
              backend.playChannel(station)
            }
          }

          // Bottom Status Line below the Globe (Hacker Telemetry)
          Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 28

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 16
              anchors.right: signalCount.left
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              text: backend.activeCountryName
                ? ("// TARGET LOCK: " + backend.activeCountryName + " // FREQ GRID LOADED")
                : "// SAT.GRID: " + globe.stations.length + " TRANSMITTERS PINNED · ALL 15,444 CHANNELS ACCESSIBLE VIA SEARCH"
              color: backend.activeCountryName ? "#00ff66" : "#00f0ffaa"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
              elide: Text.ElideRight
            }

            Text {
              id: signalCount
              anchors.right: parent.right
              anchors.rightMargin: 16
              anchors.verticalCenter: parent.verticalCenter
              text: "[" + backend.channels.length + " NODES]"
              color: "#00ff66"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }
          }
        }

        // Vertical divider line
        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          color: "#18202b"
        }

        // ================= RIGHT: TERMINAL CHANNEL HUB & PLAYER =================
        Item {
          id: sidebar
          Layout.preferredWidth: Math.min(440, Math.max(340, mainWindow.width * 0.42))
          Layout.fillHeight: true

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Navigation Tabs (World, Favorites, Recent)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 40
              color: "#090a0c"

              Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20

                // World Tab
                Text {
                  text: "WORLD [ALL_NODES]"
                  color: backend.mode === "world" || backend.mode === "country" ? "#00f0ff" : "#3b5870"
                  font.pixelSize: 11
                  font.bold: true
                  font.family: "monospace"

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      searchField.text = ""
                      backend.showWorld()
                    }
                  }
                }

                // Favorites Tab
                Text {
                  text: "FAVORITES [PINNED]"
                  color: backend.mode === "favorites" ? "#00ff66" : "#3b5870"
                  font.pixelSize: 11
                  font.bold: true
                  font.family: "monospace"

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.showFavorites()
                  }
                }

                // Recent Tab
                Text {
                  text: "RECENT [CACHED]"
                  color: backend.mode === "recent" ? "#00f0ff" : "#3b5870"
                  font.pixelSize: 11
                  font.bold: true
                  font.family: "monospace"

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.showRecent()
                  }
                }
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#0c1e2e"
              }
            }

            // Directory Notice Bar
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 20
              color: "#050b12"

              Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "// DIRECTORY · UNPINNED STATIONS FULLY SEARCHABLE"
                color: "#00f0ff55"
                font.pixelSize: 9
                font.bold: true
                font.family: "monospace"
                elide: Text.ElideRight
              }
            }

            // Station List View
            ListView {
              id: channelListView
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: backend.channels
              boundsBehavior: Flickable.StopAtBounds

              QQC.ScrollBar.vertical: QQC.ScrollBar {
                policy: QQC.ScrollBar.AsNeeded
              }

              delegate: Rectangle {
                id: rowDelegate
                width: channelListView.width
                height: 56
                color: isCurrent ? "#051824" : (rowMouse.containsMouse ? "#06131c" : "transparent")

                readonly property bool isCurrent: backend.currentChannel && backend.currentChannel.url === modelData.url

                // Left active electric indicator
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 3
                  color: "#00f0ff"
                  visible: isCurrent
                }

                // Station Title
                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: 16
                  anchors.right: starArea.left
                  anchors.rightMargin: 10
                  anchors.top: parent.top
                  anchors.topMargin: 8
                  text: modelData.name || "Station"
                  color: isCurrent ? "#00f0ff" : "#e2e8f0"
                  font.pixelSize: 13
                  font.bold: isCurrent
                  font.family: "monospace"
                  elide: Text.ElideRight
                }

                // Station Metadata (Hacker Tag Style)
                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: 16
                  anchors.right: starArea.left
                  anchors.rightMargin: 10
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 8
                  text: (modelData.country || "GLOBAL") + " // " + (modelData.quality || "HD") + " // " + (modelData.category || "General")
                  color: isCurrent ? "#00ff66" : "#2d5a52"
                  font.pixelSize: 10
                  font.bold: isCurrent
                  font.family: "monospace"
                  elide: Text.ElideRight
                }

                // Star / Favorite Button (Hacker Green / Gold)
                Item {
                  id: starArea
                  anchors.right: parent.right
                  anchors.rightMargin: 14
                  anchors.verticalCenter: parent.verticalCenter
                  width: 24
                  height: 24

                  Text {
                    anchors.centerIn: parent
                    text: backend.isFavorite(modelData.url || modelData.id || "") ? "★" : "☆"
                    color: backend.isFavorite(modelData.url || modelData.id || "") ? "#00ff66" : "#2a4254"
                    font.pixelSize: 16
                    font.family: "monospace"
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleFavorite(modelData)
                  }
                }

                // Row click handler
                MouseArea {
                  id: rowMouse
                  anchors.left: parent.left
                  anchors.right: starArea.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    backend.playChannel(modelData)
                    globe.selectedStation = modelData
                  }
                }

                // Bottom hairline
                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 1
                  color: "#121722"
                }
              }

              // Empty text
              Text {
                anchors.centerIn: parent
                text: backend.mode === "favorites" ? "No favorite stations saved.\nClick ☆ to star a station." :
                      backend.mode === "recent" ? "No recent stations played yet." :
                      "No stations found.\nTry rotating the globe or searching."
                color: "#64748b"
                font.pixelSize: 12
                font.family: "monospace"
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
                visible: channelListView.count === 0
              }
            }

            // Monitor Header Bar (Always visible above video feed)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 28
              color: "#080e14"
              border.color: backend.isPlaying ? "#00ff6633" : "#00f0ff1a"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10

                Text {
                  text: backend.isPlaying ? (backend.streamStatusText || "● LIVE STREAM // DECRYPTED [1080P]") : "MONITOR // STANDBY · AWAITING SIGNAL"
                  color: backend.isPlaying ? "#00ff66" : "#4a6878"
                  font.pixelSize: 10
                  font.bold: true
                  font.family: "monospace"
                  font.letterSpacing: 1
                }

                Item { Layout.fillWidth: true }

                // Fullscreen button right on the monitor header
                Rectangle {
                  Layout.preferredWidth: 26
                  Layout.preferredHeight: 20
                  radius: 3
                  color: fsMonitorMouse.containsMouse ? "#0d2030" : "transparent"
                  border.color: backend.isFullscreen ? "#00f0ff" : (fsMonitorMouse.containsMouse ? "#00f0ff66" : "transparent")
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: backend.isFullscreen ? "🗕" : "⛶"
                    color: backend.isFullscreen || fsMonitorMouse.containsMouse ? "#00f0ff" : "#00f0ff88"
                    font.pixelSize: 12
                    font.bold: true
                  }

                  MouseArea {
                    id: fsMonitorMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleFullscreen()
                  }
                }
              }
            }

            // Inbuilt Video Player Container Area (16:9 aspect ratio)
            Item {
              id: videoContainerArea
              objectName: "videoContainerArea"
              Layout.fillWidth: true
              Layout.preferredHeight: {
                if (!backend.isPlaying) {
                  return mainWindow.height < 500 ? 0 : 70;
                }
                var w = sidebar.width > 50 ? sidebar.width : 360;
                var h = Math.round(w * 9.0 / 16.0);
                return mainWindow.height < 500 ? 140 : Math.min(220, Math.max(160, h));
              }
              Layout.minimumHeight: backend.isPlaying ? (mainWindow.height < 500 ? 120 : 160) : 0
              clip: true

              Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: "#03070c"
                border.color: backend.isPlaying ? "#00f0ff44" : "#0d2030"
                border.width: 1
                radius: 4

                // Standby radar / grid pattern when idle
                Canvas {
                  anchors.fill: parent
                  opacity: 0.16
                  onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = "#00f0ff";
                    ctx.lineWidth = 1;
                    for (var x = 0; x < width; x += 20) {
                      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                    }
                    for (var y = 0; y < height; y += 20) {
                      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                    }
                  }
                }

                Column {
                  anchors.centerIn: parent
                  spacing: 4
                  visible: !backend.isPlaying && mainWindow.height >= 500

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TV_ATLAS // SIGNAL DECODER"
                    color: "#00f0ff77"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "monospace"
                    font.letterSpacing: 2
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "STANDBY · SELECT A TRANSMITTER ON THE GLOBE"
                    color: "#00ff6655"
                    font.pixelSize: 9
                    font.family: "monospace"
                  }
                }

                // Fullscreen button in video viewport corner
                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: 8
                  width: 26
                  height: 22
                  radius: 3
                  color: fsTopHover.containsMouse ? "#00e5ff" : "#0d131caa"
                  border.color: "#00e5ff66"
                  border.width: 1
                  visible: backend.isPlaying
                  z: 5

                  Text {
                    anchors.centerIn: parent
                    text: backend.isFullscreen ? "🗕" : "⛶"
                    color: fsTopHover.containsMouse ? "#090a0c" : "#00e5ff"
                    font.pixelSize: 12
                    font.bold: true
                  }

                  MouseArea {
                    id: fsTopHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleFullscreen()
                  }
                }
              }
            }

            // ================= BOTTOM PLAYER PANEL =================
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: mainWindow.height < 500 ? 76 : 110
              color: "#090a0c"

              // Top hairline
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#18202b"
              }

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: mainWindow.height < 500 ? 8 : 12
                spacing: mainWindow.height < 500 ? 3 : 6

                // Station Title
                Text {
                  Layout.fillWidth: true
                  text: backend.isPlaying
                    ? (backend.currentChannel.name || "Playing Station")
                    : "NO SIGNAL // STANDBY"
                  color: backend.isPlaying ? "#00f0ff" : "#4a6878"
                  font.pixelSize: mainWindow.height < 500 ? 11 : 13
                  font.bold: true
                  font.family: "monospace"
                  font.letterSpacing: 0.5
                  elide: Text.ElideRight
                }

                // Station Subtitle
                Text {
                  Layout.fillWidth: true
                  visible: mainWindow.height >= 500
                  text: backend.isPlaying
                    ? ((backend.currentChannel.countryName || backend.currentChannel.country || "") + " // " + (backend.currentChannel.category || "General") + " // " + (backend.currentChannel.quality || "HD") + (backend.isPaused ? " [PAUSED]" : " [LIVE]"))
                    : "SCAN FREQUENCIES OR SELECT A TARGET NODE"
                  color: backend.isPlaying ? "#00ff66aa" : "#324858"
                  font.pixelSize: 11
                  font.family: "monospace"
                  elide: Text.ElideRight
                }

                // Transport Controls Row (|◀   ▶ / ⏸   ▶|   ■)
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 16

                  // Previous
                  Text {
                    text: "|◀"
                    color: backend.isPlaying ? "#00f0ff" : "#2a4254"
                    font.pixelSize: 13
                    font.family: "monospace"
                    font.bold: true
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: backend.previousStation()
                    }
                  }

                  // Play / Pause
                  Text {
                    text: backend.isPlaying && !backend.isPaused ? "⏸" : "▶"
                    color: backend.isPlaying ? "#00ff66" : "#00f0ff"
                    font.pixelSize: 14
                    font.family: "monospace"
                    font.bold: true
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: backend.togglePlayPause()
                    }
                  }

                  // Next
                  Text {
                    text: "▶|"
                    color: backend.isPlaying ? "#00f0ff" : "#2a4254"
                    font.pixelSize: 13
                    font.family: "monospace"
                    font.bold: true
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: backend.nextStation()
                    }
                  }

                  // Stop
                  Text {
                    text: "■"
                    color: backend.isPlaying ? "#ff0055" : "#2a4254"
                    font.pixelSize: 13
                    font.family: "monospace"
                    font.bold: true
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: backend.stop()
                    }
                  }

                  Item { Layout.fillWidth: true }

                  // Live Video Indicator
                  Rectangle {
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: videoPillText.implicitWidth + 12
                    radius: 3
                    color: backend.isPlaying ? "#00ff661a" : "#0d1520"
                    border.color: backend.isPlaying ? "#00ff66" : "#1a2c3d"
                    border.width: 1

                    Text {
                      id: videoPillText
                      anchors.centerIn: parent
                      text: backend.isPlaying ? (backend.isPaused ? "⏸ PAUSED" : "● FEED ACTIVE") : "IDLE // READY"
                      color: backend.isPlaying ? "#00ff66" : "#4a6878"
                      font.pixelSize: 9
                      font.bold: true
                      font.family: "monospace"
                    }
                  }

                  // Fullscreen Toggle Button
                  Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: 32
                    radius: 3
                    color: fsBarHover.containsMouse ? "#00f0ff22" : "#0d1b28"
                    border.color: backend.isFullscreen ? "#00f0ff" : (fsBarHover.containsMouse ? "#00f0ff88" : "#1a334a")
                    border.width: 1
                    visible: true

                    Text {
                      anchors.centerIn: parent
                      text: backend.isFullscreen ? "🗕" : "⛶"
                      color: backend.isFullscreen || fsBarHover.containsMouse ? "#00f0ff" : "#7aa2c0"
                      font.pixelSize: 13
                      font.family: "monospace"
                      font.bold: true
                    }

                    MouseArea {
                      id: fsBarHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: backend.toggleFullscreen()
                    }
                  }
                }

                // Volume Slider Row
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  // Mute toggle icon
                  Text {
                    text: backend.isMuted || backend.volume === 0 ? "🕪" : "🔊"
                    color: backend.isMuted ? "#ff0055" : "#00f0ff88"
                    font.pixelSize: 12
                    font.family: "monospace"
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: backend.toggleMute()
                    }
                  }

                  // Minimalist Volume Line Slider
                  Rectangle {
                    id: volumeTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: 1.5
                    color: "#0d2030"

                    // Filled Portion
                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: parent.width * (backend.isMuted ? 0 : backend.volume / 100.0)
                      radius: 1.5
                      color: "#00ff66"
                    }

                    // Thumb
                    Rectangle {
                      x: (volumeTrack.width * (backend.isMuted ? 0 : backend.volume / 100.0)) - 4
                      anchors.verticalCenter: parent.verticalCenter
                      width: 8
                      height: 8
                      radius: 4
                      color: "#00f0ff"
                    }

                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: -8
                      cursorShape: Qt.PointingHandCursor
                      onPositionChanged: function(mouse) {
                        var ratio = Math.max(0, Math.min(1.0, mouse.x / volumeTrack.width))
                        backend.setVolume(Math.round(ratio * 100))
                      }
                      onClicked: function(mouse) {
                        var ratio = Math.max(0, Math.min(1.0, mouse.x / volumeTrack.width))
                        backend.setVolume(Math.round(ratio * 100))
                      }
                    }
                  }

                  // Volume Percentage Text
                  Text {
                    text: (backend.isMuted ? 0 : backend.volume) + "%"
                    color: "#00f0ffaa"
                    font.pixelSize: 11
                    font.family: "monospace"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Help Overlay
  Rectangle {
    anchors.fill: parent
    color: "#090a0cee"
    visible: mainWindow.helpVisible
    z: 10

    Column {
      anchors.centerIn: parent
      spacing: 14

      Text {
        text: "TV ATLAS — CONTROLS"
        color: "#f3f4f5"
        font.pixelSize: 15
        font.bold: true
        font.family: "monospace"
        font.letterSpacing: 1.5
        anchors.horizontalCenter: parent.horizontalCenter
      }

      Text {
        text: "Drag or flick globe    Rotate with kinetic momentum\n" +
              "Scroll wheel           Zoom Earth in / out\n" +
              "Click signal / country Tune station or browse country\n" +
              "Space                  Play or pause\n" +
              "R                      Tune random station anywhere on Earth\n" +
              "F / F11                Toggle Fullscreen Cinema mode\n" +
              "M                      Mute or unmute\n" +
              "/                      Focus search\n" +
              "Esc                    Exit fullscreen / close help / clear search"
        color: "#9099a3"
        font.pixelSize: 12
        font.family: "monospace"
        lineHeight: 1.5
      }

      Rectangle {
        width: 100
        height: 28
        radius: 4
        color: "#18202b"
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
          anchors.centerIn: parent
          text: "CLOSE"
          color: "#f3f4f5"
          font.pixelSize: 11
          font.family: "monospace"
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: mainWindow.helpVisible = false
        }
      }
    }
  }

  // ================= FULLSCREEN CINEMA TOP CONTROL BAR =================
  Rectangle {
    id: fullscreenTopBar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 48
    color: "#05070ae6"
    visible: backend.isFullscreen
    z: 100

    // Bottom hairline accent
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 1
      color: "#00e5ff44"
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 20
      anchors.rightMargin: 20
      spacing: 16

      // Live pulsating dot
      Rectangle {
        width: 8
        height: 8
        radius: 4
        color: "#00e5ff"
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          NumberAnimation { from: 0.3; to: 1.0; duration: 750 }
          NumberAnimation { from: 1.0; to: 0.3; duration: 750 }
        }
      }

      // Station name & metadata
      Text {
        text: (backend.currentChannel.name || "TV Atlas Cinema") + "  ·  " +
              (backend.currentChannel.countryName || backend.currentChannel.country || "Live") + "  ·  " +
              (backend.currentChannel.quality || "HD")
        color: "#f3f4f5"
        font.pixelSize: 14
        font.bold: true
        font.family: "monospace"
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      // Fullscreen Transport controls
      Row {
        spacing: 16
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "|◀"
          color: "#94a3b8"
          font.pixelSize: 14
          font.family: "monospace"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.previousStation()
          }
        }

        Text {
          text: backend.isPlaying && !backend.isPaused ? "⏸" : "▶"
          color: "#00e5ff"
          font.pixelSize: 16
          font.bold: true
          font.family: "monospace"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.togglePlayPause()
          }
        }

        Text {
          text: "▶|"
          color: "#94a3b8"
          font.pixelSize: 14
          font.family: "monospace"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.nextStation()
          }
        }

        Text {
          text: "■"
          color: "#94a3b8"
          font.pixelSize: 14
          font.family: "monospace"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.stop()
          }
        }
      }

      // Exit Fullscreen Button
      Rectangle {
        Layout.preferredHeight: 30
        Layout.preferredWidth: 170
        radius: 4
        color: fsExitMouse.containsMouse ? "#00e5ff" : "#111b27"
        border.color: "#00e5ff88"
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: 6
          Text {
            text: "🗕"
            color: fsExitMouse.containsMouse ? "#090a0c" : "#00e5ff"
            font.pixelSize: 12
            font.bold: true
          }
          Text {
            text: "EXIT CINEMA [ESC]"
            color: fsExitMouse.containsMouse ? "#090a0c" : "#00e5ff"
            font.pixelSize: 10
            font.bold: true
            font.family: "monospace"
          }
        }

        MouseArea {
          id: fsExitMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: backend.toggleFullscreen()
        }
      }
    }
  }
}
