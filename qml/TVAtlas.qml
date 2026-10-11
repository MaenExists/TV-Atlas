import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
  id: mainWindow
  width: 940
  height: 640
  color: "#090a0c"
  focus: true

  property bool helpVisible: false
  property bool tvCastModalVisible: false
  property var geoCountries: []
  property var catalogStations: []

  // TV Remote Navigation State Machine
  property string tvFocusArea: "channels" // "channels", "globe", "tabs", "search"
  property int tvSelectedTab: 0 // 0: WORLD, 1: FAVORITES, 2: RECENT
  property bool cinemaOsdVisible: true

  Timer {
    id: cinemaOsdTimer
    interval: 3500
    repeat: false
    running: backend && backend.isFullscreen && mainWindow.cinemaOsdVisible
    onTriggered: mainWindow.cinemaOsdVisible = false
  }

  function wakeCinemaOsd() {
    mainWindow.cinemaOsdVisible = true
    if (cinemaOsdTimer.running) {
      cinemaOsdTimer.restart()
    } else {
      cinemaOsdTimer.start()
    }
  }

  function activateTvTab(idx) {
    mainWindow.tvSelectedTab = idx
    if (idx === 0) {
      searchField.text = ""
      backend.showWorld()
    } else if (idx === 1) {
      backend.showFavorites()
    } else if (idx === 2) {
      backend.showRecent()
    }
  }

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
    mainWindow.forceActiveFocus()
  }

  Connections {
    target: backend
    function onSelectedChannelIndexChanged() {
      if (channelListView) {
        channelListView.positionViewAtIndex(backend.selectedChannelIndex, ListView.Center)
      }
    }
    function onCurrentChannelChanged() {
      if (channelListView && backend.isTvMode) {
        channelListView.positionViewAtIndex(backend.selectedChannelIndex, ListView.Center)
      }
    }
    function onTvModeChanged(val) {
      if (val) {
        mainWindow.tvFocusArea = "channels"
      }
      mainWindow.forceActiveFocus()
    }
    function onFullscreenChanged(isFs) {
      mainWindow.wakeCinemaOsd()
      mainWindow.forceActiveFocus()
    }
  }

  // Keyboard and TV Remote Navigation Controller
  Keys.onPressed: function(event) {
    // 0. Fullscreen Cinema Mode Controls
    if (backend && backend.isFullscreen) {
      mainWindow.wakeCinemaOsd()
      if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back || event.key === Qt.Key_F || event.key === Qt.Key_F11) {
        backend.toggleFullscreen()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
        backend.togglePlayPause()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
        backend.previousStation()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
        backend.nextStation()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Left) {
        backend.previousStation()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Right) {
        backend.nextStation()
        event.accepted = true
        return
      }
    }

    // 1. Search Field Active Focus Handling
    if (searchField.activeFocus) {
      if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
        searchField.text = ""
        backend.search("")
        searchField.focus = false
        mainWindow.tvFocusArea = "channels"
        mainWindow.forceActiveFocus()
        event.accepted = true
        return
      } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        searchField.focus = false
        mainWindow.tvFocusArea = "channels"
        mainWindow.forceActiveFocus()
        event.accepted = true
        return
      }
      return
    }

    // 2. Global Hotkeys
    if (event.key === Qt.Key_F || event.key === Qt.Key_F11) {
      backend.toggleFullscreen()
      mainWindow.wakeCinemaOsd()
      event.accepted = true
      return
    } else if (event.key === Qt.Key_T) {
      backend.toggleTvMode()
      event.accepted = true
      return
    } else if (event.key === Qt.Key_Space) {
      backend.togglePlayPause()
      event.accepted = true
      return
    } else if (event.key === Qt.Key_R) {
      backend.playRandom()
      event.accepted = true
      return
    } else if (event.key === Qt.Key_M) {
      backend.toggleMute()
      event.accepted = true
      return
    } else if (event.key === Qt.Key_Slash) {
      mainWindow.tvFocusArea = "search"
      searchField.forceActiveFocus()
      event.accepted = true
      return
    } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
      if (mainWindow.tvCastModalVisible) {
        mainWindow.tvCastModalVisible = false
        event.accepted = true
        return
      } else if (mainWindow.helpVisible) {
        mainWindow.helpVisible = false
        event.accepted = true
        return
      } else if (mainWindow.tvFocusArea === "globe") {
        mainWindow.tvFocusArea = "channels"
        event.accepted = true
        return
      } else if (mainWindow.tvFocusArea === "tabs") {
        mainWindow.tvFocusArea = "channels"
        event.accepted = true
        return
      } else if (searchField.text !== "") {
        searchField.text = ""
        backend.search("")
        event.accepted = true
        return
      }
    }

    // 3. TV Mode D-Pad Remote Navigation State Machine
    if (backend && backend.isTvMode) {
      // Area A: Interactive 3D Globe Navigation
      if (mainWindow.tvFocusArea === "globe") {
        if (event.key === Qt.Key_Left) {
          globe.rotateStep(15, 0)
          event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          globe.rotateStep(-15, 0)
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          globe.rotateStep(0, 10)
          event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          globe.rotateStep(0, -10)
          event.accepted = true
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.key === Qt.Key_PageUp) {
          globe.zoomStep(1.25)
          event.accepted = true
        } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_PageDown) {
          globe.zoomStep(0.8)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
          var locked = globe.lockNearestStation()
          if (locked) {
            backend.playChannel(locked)
          }
          event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
          mainWindow.tvFocusArea = "channels"
          event.accepted = true
        }
        return
      }

      // Area B: Category Tabs Navigation
      if (mainWindow.tvFocusArea === "tabs") {
        if (event.key === Qt.Key_Left) {
          mainWindow.tvSelectedTab = Math.max(0, mainWindow.tvSelectedTab - 1)
          mainWindow.activateTvTab(mainWindow.tvSelectedTab)
          event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          mainWindow.tvSelectedTab = Math.min(2, mainWindow.tvSelectedTab + 1)
          mainWindow.activateTvTab(mainWindow.tvSelectedTab)
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          mainWindow.tvFocusArea = "search"
          searchField.forceActiveFocus()
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
          mainWindow.tvFocusArea = "channels"
          event.accepted = true
        } else if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
          mainWindow.tvFocusArea = "channels"
          event.accepted = true
        }
        return
      }

      // Area C: Channel List (Default)
      if (event.key === Qt.Key_Down) {
        backend.selectNextChannel()
        event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        if (backend.selectedChannelIndex === 0) {
          mainWindow.tvFocusArea = "tabs"
        } else {
          backend.selectPreviousChannel()
        }
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
        backend.playSelectedChannel()
        event.accepted = true
      } else if (event.key === Qt.Key_Left) {
        mainWindow.tvFocusArea = "globe"
        event.accepted = true
      } else if (event.key === Qt.Key_Right) {
        if (backend.channels && backend.selectedChannelIndex < backend.channels.length) {
          backend.toggleFavorite(backend.channels[backend.selectedChannelIndex])
        }
        event.accepted = true
      } else if (event.key === Qt.Key_Tab) {
        mainWindow.tvFocusArea = "globe"
        event.accepted = true
      }
    } else {
      // Desktop Window Navigation
      if (event.key === Qt.Key_Down) {
        backend.selectNextChannel()
        event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        backend.selectPreviousChannel()
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        backend.playSelectedChannel()
        event.accepted = true
      }
    }
  }

  // ================= MAIN COLUMN =================
  ColumnLayout {
    anchors.fill: parent
    spacing: 0
    visible: backend ? !backend.isFullscreen : true

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

        // TV Mode Leanback Toggle Button
        Rectangle {
          Layout.preferredWidth: 70
          Layout.preferredHeight: 30
          radius: 4
          color: backend.isTvMode ? "#00f0ff26" : (tvModeMouse.containsMouse ? "#1a222d" : "transparent")
          border.color: backend.isTvMode ? "#00f0ff" : "#1a2a3a"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: backend.isTvMode ? "📺 TV:ON" : "📺 TV"
            color: backend.isTvMode ? "#00f0ff" : "#9099a3"
            font.pixelSize: 10
            font.bold: true
            font.family: "monospace"
          }

          MouseArea {
            id: tvModeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.toggleTvMode()
          }
        }

        // Smart TV / Google TV Cast & Pairing Button
        Rectangle {
          Layout.preferredWidth: 74
          Layout.preferredHeight: 30
          radius: 4
          color: mainWindow.tvCastModalVisible ? "#00ff6626" : (castMouse.containsMouse ? "#1a222d" : "transparent")
          border.color: mainWindow.tvCastModalVisible ? "#00ff66" : "#1a2a3a"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "📡 CAST"
            color: mainWindow.tvCastModalVisible ? "#00ff66" : "#9099a3"
            font.pixelSize: 10
            font.bold: true
            font.family: "monospace"
          }

          MouseArea {
            id: castMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mainWindow.tvCastModalVisible = !mainWindow.tvCastModalVisible
          }
        }

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

          // TV Globe Cyber Navigation HUD Pill
          Rectangle {
            id: globeTvHud
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            height: 32
            width: hudRow.implicitWidth + 28
            radius: 16
            color: mainWindow.tvFocusArea === "globe" ? "#041424ee" : "#050b12cc"
            border.color: mainWindow.tvFocusArea === "globe" ? "#00ff66" : "#00f0ff44"
            border.width: mainWindow.tvFocusArea === "globe" ? 2 : 1
            visible: backend.isTvMode
            z: 20

            Row {
              id: hudRow
              anchors.centerIn: parent
              spacing: 10

              Rectangle {
                width: 6
                height: 6
                radius: 3
                color: mainWindow.tvFocusArea === "globe" ? "#00ff66" : "#00f0ff"
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: mainWindow.tvFocusArea === "globe" ? "🌐 GLOBE D-PAD ACTIVE" : "🌐 D-PAD LEFT: CONTROL GLOBE"
                color: mainWindow.tvFocusArea === "globe" ? "#00ff66" : "#00f0ffaa"
                font.pixelSize: 10
                font.bold: true
                font.family: "monospace"
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "·"
                color: "#00f0ff44"
                visible: mainWindow.tvFocusArea === "globe"
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "▲▼◀▶ SPIN | OK LOCK | BACK RETURN"
                color: "#ffffff"
                font.pixelSize: 9
                font.bold: true
                font.family: "monospace"
                visible: mainWindow.tvFocusArea === "globe"
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                mainWindow.tvFocusArea = (mainWindow.tvFocusArea === "globe") ? "channels" : "globe"
              }
            }
          }

          // Reticle Crosshairs when Globe has TV Remote Focus
          Item {
            anchors.centerIn: parent
            width: 44
            height: 44
            visible: backend.isTvMode && mainWindow.tvFocusArea === "globe"
            z: 19

            Rectangle {
              anchors.centerIn: parent
              width: 32
              height: 32
              radius: 16
              color: "transparent"
              border.color: "#00f0ffaa"
              border.width: 1
            }
            Rectangle {
              anchors.centerIn: parent
              width: 2
              height: 16
              color: "#00ff66"
            }
            Rectangle {
              anchors.centerIn: parent
              width: 16
              height: 2
              color: "#00ff66"
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
          Layout.preferredWidth: Math.min(480, Math.max(340, mainWindow.width * (backend.isTvMode ? 0.44 : 0.42)))
          Layout.fillHeight: true

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Navigation Tabs (World, Favorites, Recent)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: backend.isTvMode ? 44 : 40
              color: "#090a0c"

              Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: backend.isTvMode ? 10 : 20

                // World Tab
                Rectangle {
                  height: backend.isTvMode ? 30 : 24
                  width: worldText.implicitWidth + (backend.isTvMode ? 18 : 8)
                  radius: 4
                  color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 0) ? "#0c283d" : "transparent"
                  border.color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 0) ? "#00f0ff" : "transparent"
                  border.width: 1

                  Text {
                    id: worldText
                    anchors.centerIn: parent
                    text: backend.isTvMode ? "WORLD [ALL]" : "WORLD [ALL_NODES]"
                    color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 0) ? "#00f0ff" :
                           (backend.mode === "world" || backend.mode === "country" ? "#00f0ff" : "#3b5870")
                    font.pixelSize: backend.isTvMode ? 12 : 11
                    font.bold: true
                    font.family: "monospace"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      mainWindow.tvSelectedTab = 0
                      searchField.text = ""
                      backend.showWorld()
                    }
                  }
                }

                // Favorites Tab
                Rectangle {
                  height: backend.isTvMode ? 30 : 24
                  width: favText.implicitWidth + (backend.isTvMode ? 18 : 8)
                  radius: 4
                  color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 1) ? "#0c283d" : "transparent"
                  border.color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 1) ? "#00ff66" : "transparent"
                  border.width: 1

                  Text {
                    id: favText
                    anchors.centerIn: parent
                    text: backend.isTvMode ? "FAVORITES" : "FAVORITES [PINNED]"
                    color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 1) ? "#00ff66" :
                           (backend.mode === "favorites" ? "#00ff66" : "#3b5870")
                    font.pixelSize: backend.isTvMode ? 12 : 11
                    font.bold: true
                    font.family: "monospace"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      mainWindow.tvSelectedTab = 1
                      backend.showFavorites()
                    }
                  }
                }

                // Recent Tab
                Rectangle {
                  height: backend.isTvMode ? 30 : 24
                  width: recText.implicitWidth + (backend.isTvMode ? 18 : 8)
                  radius: 4
                  color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 2) ? "#0c283d" : "transparent"
                  border.color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 2) ? "#00f0ff" : "transparent"
                  border.width: 1

                  Text {
                    id: recText
                    anchors.centerIn: parent
                    text: backend.isTvMode ? "RECENT" : "RECENT [CACHED]"
                    color: (backend.isTvMode && mainWindow.tvFocusArea === "tabs" && mainWindow.tvSelectedTab === 2) ? "#00f0ff" :
                           (backend.mode === "recent" ? "#00f0ff" : "#3b5870")
                    font.pixelSize: backend.isTvMode ? 12 : 11
                    font.bold: true
                    font.family: "monospace"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      mainWindow.tvSelectedTab = 2
                      backend.showRecent()
                    }
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
                height: backend.isTvMode ? 70 : 56
                color: isSelectedInTv ? "#0c283d" : (isCurrent ? "#051824" : (rowMouse.containsMouse ? "#06131c" : "transparent"))
                border.color: isSelectedInTv ? "#00f0ff" : "transparent"
                border.width: isSelectedInTv ? 2 : 0

                readonly property bool isCurrent: backend.currentChannel && backend.currentChannel.url === modelData.url
                readonly property bool isSelectedInTv: backend.isTvMode && index === backend.selectedChannelIndex

                // Left active electric indicator
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: isSelectedInTv ? 5 : 3
                  color: isSelectedInTv ? "#00ff66" : "#00f0ff"
                  visible: isCurrent || isSelectedInTv
                }

                // Station Title
                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: 16
                  anchors.right: starArea.left
                  anchors.rightMargin: 10
                  anchors.top: parent.top
                  anchors.topMargin: backend.isTvMode ? 12 : 8
                  text: modelData.name || "Station"
                  color: isSelectedInTv ? "#ffffff" : (isCurrent ? "#00f0ff" : "#e2e8f0")
                  font.pixelSize: backend.isTvMode ? 16 : 13
                  font.bold: isCurrent || isSelectedInTv
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
                  anchors.bottomMargin: backend.isTvMode ? 12 : 8
                  text: (modelData.country || "GLOBAL") + " // " + (modelData.quality || "HD") + " // " + (modelData.category || "General")
                  color: isSelectedInTv ? "#00ff66" : (isCurrent ? "#00ff66" : "#2d5a52")
                  font.pixelSize: backend.isTvMode ? 12 : 10
                  font.bold: isCurrent || isSelectedInTv
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
                    font.pixelSize: backend.isTvMode ? 18 : 16
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
                    backend.setSelectedChannelIndex(index)
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

    // ================= VERY BOTTOM FOOTER NOTE =================
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: backend.isTvMode ? 22 : 18
      color: "#05070a"

      // Hairline accent line
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: "#0d1822"
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: backend.isTvMode ? "// TV_LEANBACK_GRID · D-PAD ACTIVE" : "// SATELLITE_ORBITAL_NET · 15,444 NODES"
          color: "#22384a"
          font.pixelSize: backend.isTvMode ? 10 : 9
          font.family: "monospace"
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "Property of Maen"
          color: "#00f0ffaa"
          font.pixelSize: backend.isTvMode ? 10 : 9
          font.bold: true
          font.family: "monospace"
          font.letterSpacing: 1.2
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

  // ================= SMART TV & GOOGLE TV CAST MODAL =================
  Rectangle {
    id: tvCastOverlay
    anchors.fill: parent
    color: "#070a0eed"
    visible: mainWindow.tvCastModalVisible
    z: 20

    Rectangle {
      anchors.centerIn: parent
      width: Math.min(540, parent.width - 32)
      height: Math.min(460, parent.height - 32)
      color: "#0c131a"
      border.color: "#00f0ff"
      border.width: 1
      radius: 8

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // Header
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "📺 SMART TV & GOOGLE TV CAST HUB"
            color: "#00f0ff"
            font.pixelSize: 14
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: 1
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "✕"
            color: "#94a3b8"
            font.pixelSize: 14
            font.bold: true
            font.family: "monospace"
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: mainWindow.tvCastModalVisible = false
            }
          }
        }

        // Subtitle
        Text {
          text: "// STREAM & CONTROL LIVE TV FROM YOUR LIVING ROOM COUCH"
          color: "#00ff66"
          font.pixelSize: 10
          font.bold: true
          font.family: "monospace"
        }

        // LAN URL Badge
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          color: "#040b12"
          border.color: "#00f0ff66"
          border.width: 1
          radius: 4

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            Text {
              text: "TV ADDRESS:"
              color: "#64748b"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }
            Text {
              text: backend.webServerUrl || "http://127.0.0.1:8080"
              color: "#00f0ff"
              font.pixelSize: 13
              font.bold: true
              font.family: "monospace"
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "ONLINE ●"
              color: "#00ff66"
              font.pixelSize: 10
              font.bold: true
              font.family: "monospace"
            }
          }
        }

        // QR Code & Instructions Split
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 16

          // Left: QR Code Preview
          Rectangle {
            Layout.preferredWidth: 140
            Layout.preferredHeight: 140
            color: "#ffffff"
            radius: 6

            Image {
              anchors.fill: parent
              anchors.margins: 6
              source: backend.webServerUrl ? (backend.webServerUrl + "/api/qr") : ""
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }

          // Right: 3-Step Instructions
          Column {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "1. Open TV Browser"
              color: "#f1f5f9"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }
            Text {
              text: "   (e.g., TV Bro, Downloader, JioPages, Chrome)"
              color: "#94a3b8"
              font.pixelSize: 10
              font.family: "monospace"
            }

            Text {
              text: "2. Type TV Address above"
              color: "#f1f5f9"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }
            Text {
              text: "   or scan this QR code with your phone"
              color: "#94a3b8"
              font.pixelSize: 10
              font.family: "monospace"
            }

            Text {
              text: "3. Leanback Remote Navigation"
              color: "#00ff66"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }
            Text {
              text: "   Use ▲▼◄► and OK on your remote to tune!"
              color: "#94a3b8"
              font.pixelSize: 10
              font.family: "monospace"
            }
          }
        }

        // Action Buttons Row
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#122638"
            border.color: "#00f0ff"
            border.width: 1
            radius: 4

            Text {
              anchors.centerIn: parent
              text: "OPEN IN BROWSER"
              color: "#00f0ff"
              font.pixelSize: 11
              font.bold: true
              font.family: "monospace"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Qt.openUrlExternally(backend.webServerUrl)
            }
          }

          Rectangle {
            Layout.preferredWidth: 100
            Layout.preferredHeight: 32
            color: "#1a222d"
            radius: 4

            Text {
              anchors.centerIn: parent
              text: "CLOSE [ESC]"
              color: "#94a3b8"
              font.pixelSize: 10
              font.bold: true
              font.family: "monospace"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: mainWindow.tvCastModalVisible = false
            }
          }
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
    visible: backend ? (backend.isFullscreen && mainWindow.cinemaOsdVisible) : false
    opacity: (backend && backend.isFullscreen && mainWindow.cinemaOsdVisible) ? 1.0 : 0.0
    Behavior on opacity {
      NumberAnimation { duration: 250 }
    }
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
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      spacing: 14

      // Live pulsating dot
      Rectangle {
        Layout.preferredWidth: 8
        Layout.preferredHeight: 8
        radius: 4
        color: "#00e5ff"
        Layout.alignment: Qt.AlignVCenter
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          NumberAnimation { from: 0.3; to: 1.0; duration: 750 }
          NumberAnimation { from: 1.0; to: 0.3; duration: 750 }
        }
      }

      // Station name & metadata (Takes remaining space and elides cleanly)
      Text {
        text: backend && backend.currentChannel ? (
                (backend.currentChannel.name || "TV Atlas Cinema") + "  ·  " +
                (backend.currentChannel.countryName || backend.currentChannel.country || "Live") + "  ·  " +
                (backend.currentChannel.quality || "HD")
              ) : "TV Atlas Cinema"
        color: "#f3f4f5"
        font.pixelSize: 13
        font.bold: true
        font.family: "monospace"
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.minimumWidth: 60
        Layout.alignment: Qt.AlignVCenter
      }

      // Fullscreen Transport controls
      Row {
        spacing: 12
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "|◀"
          color: "#94a3b8"
          font.pixelSize: 13
          font.family: "monospace"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (backend) backend.previousStation()
          }
        }

        Text {
          text: backend && backend.isPlaying && !backend.isPaused ? "⏸" : "▶"
          color: "#00e5ff"
          font.pixelSize: 15
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
          font.pixelSize: 13
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
          font.pixelSize: 13
          font.family: "monospace"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.stop()
          }
        }
      }

      // Property of Maen note
      Text {
        text: "Property of Maen"
        color: "#00f0ff"
        font.pixelSize: 11
        font.bold: true
        font.family: "monospace"
        font.letterSpacing: 1.2
        Layout.alignment: Qt.AlignVCenter
      }

      // Exit Fullscreen Button
      Rectangle {
        Layout.preferredHeight: 28
        Layout.preferredWidth: 96
        radius: 4
        color: fsExitMouse.containsMouse ? "#00e5ff" : "#111b27"
        border.color: "#00e5ff88"
        border.width: 1
        Layout.alignment: Qt.AlignVCenter

        Row {
          anchors.centerIn: parent
          spacing: 5
          Text {
            text: "🗕"
            color: fsExitMouse.containsMouse ? "#090a0c" : "#00e5ff"
            font.pixelSize: 11
            font.bold: true
          }
          Text {
            text: "EXIT [ESC]"
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

  // Hover hot zone to wake cinema OSD on mouse move at top of screen
  MouseArea {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 60
    hoverEnabled: true
    propagateComposedEvents: true
    visible: backend ? backend.isFullscreen : false
    z: 99
    onPositionChanged: mainWindow.wakeCinemaOsd()
  }
}
