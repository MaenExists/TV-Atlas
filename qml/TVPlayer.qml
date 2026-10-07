import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia

Item {
  id: root

  property var currentChannel: backend.currentChannel
  property string streamUrl: backend.currentStreamUrl
  property string status: backend.playbackStatus
  property bool isMuted: false
  property real volume: 0.8
  property bool fillModeCrop: false
  property bool controlsVisible: true

  signal requestFullscreen()

  onStreamUrlChanged: {
    if (streamUrl && streamUrl.length > 0) {
      mediaPlayer.stop()
      mediaPlayer.source = streamUrl
      mediaPlayer.play()
    } else {
      mediaPlayer.stop()
    }
  }

  MediaPlayer {
    id: mediaPlayer
    audioOutput: AudioOutput {
      id: audioOutput
      volume: root.isMuted ? 0.0 : root.volume
    }
    videoOutput: videoOutput

    onErrorOccurred: function(error, errorString) {
      console.warn("TVAtlas Player error:", error, errorString)
      backend.setPlaybackStatus("error")
    }

    onPlaybackStateChanged: {
      if (playbackState === MediaPlayer.PlayingState) {
        backend.setPlaybackStatus("playing")
      } else if (playbackState === MediaPlayer.PausedState) {
        backend.setPlaybackStatus("paused")
      } else if (playbackState === MediaPlayer.StoppedState) {
        backend.setPlaybackStatus("stopped")
      }
    }
  }

  // Player container with dark border & rounded corners
  Rectangle {
    id: playerContainer
    anchors.fill: parent
    color: "#05070a"
    radius: 10
    clip: true
    border.color: "#1e293b"
    border.width: 1

    // Video Output
    VideoOutput {
      id: videoOutput
      anchors.fill: parent
      fillMode: root.fillModeCrop ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
      visible: mediaPlayer.playbackState === MediaPlayer.PlayingState || mediaPlayer.playbackState === MediaPlayer.PausedState
    }

    // Idle Screen (No stream loaded)
    Rectangle {
      id: idleScreen
      anchors.fill: parent
      color: "#0c1017"
      visible: !videoOutput.visible && backend.playbackStatus !== "loading" && backend.playbackStatus !== "error"

      Column {
        anchors.centerIn: parent
        spacing: 14

        Rectangle {
          width: 72
          height: 72
          radius: 36
          color: "#151e2e"
          anchors.horizontalCenter: parent.horizontalCenter
          border.color: "#ff7700"
          border.width: 1.5

          Text {
            anchors.centerIn: parent
            text: "📺"
            font.pixelSize: 34
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "SELECT A NETWORK TO TUNE IN"
          color: "#f8fafc"
          font.pixelSize: 15
          font.bold: true
          font.letterSpacing: 1.5
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Click any country on the 3D Earth or choose from the guide below"
          color: "#64748b"
          font.pixelSize: 12
        }

        QQC.Button {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "🎲 Tune Random Channel"
          onClicked: backend.playRandomChannel()
          contentItem: Text {
            text: parent.text
            color: "#ffffff"
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            color: parent.hovered ? "#ff8800" : "#ff6600"
            radius: 6
            implicitHeight: 36
            implicitWidth: 180
          }
        }
      }
    }

    // Buffering / Loading State
    Rectangle {
      id: loadingScreen
      anchors.fill: parent
      color: "#0f172acc"
      visible: backend.playbackStatus === "loading" || (mediaPlayer.bufferProgress < 1.0 && mediaPlayer.bufferProgress > 0.0)

      Column {
        anchors.centerIn: parent
        spacing: 12

        QQC.BusyIndicator {
          anchors.horizontalCenter: parent.horizontalCenter
          running: loadingScreen.visible
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Connecting to live broadcast stream..."
          color: "#38bdf8"
          font.pixelSize: 13
          font.bold: true
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: backend.currentChannel.name || ""
          color: "#94a3b8"
          font.pixelSize: 11
        }
      }
    }

    // Error State
    Rectangle {
      id: errorScreen
      anchors.fill: parent
      color: "#160b0bcc"
      visible: backend.playbackStatus === "error"

      Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "⚠️"
          font.pixelSize: 36
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Stream Unavailable or Blocked"
          color: "#f87171"
          font.pixelSize: 15
          font.bold: true
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Some broadcast streams require custom user-agents or MPV demuxing."
          color: "#94a3b8"
          font.pixelSize: 11
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 10

          QQC.Button {
            text: "🔄 Retry Stream"
            onClicked: {
              mediaPlayer.stop()
              mediaPlayer.source = ""
              mediaPlayer.source = root.streamUrl
              mediaPlayer.play()
            }
          }

          QQC.Button {
            text: "▶️ Open in MPV"
            onClicked: backend.openInMpv(root.streamUrl)
          }
        }
      }
    }

    // Top Header Overlay (Channel Title, Category, Quality, Country)
    Rectangle {
      id: topBar
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 48
      color: "#05070ae6"
      visible: root.controlsVisible && (backend.currentChannel.name !== undefined)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // Channel Logo
        Image {
          id: channelLogo
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          source: backend.currentChannel.logo || ""
          fillMode: Image.PreserveAspectFit
          smooth: true
          visible: status === Image.Ready
        }

        // Live Red Dot
        Rectangle {
          Layout.preferredWidth: 8
          Layout.preferredHeight: 8
          radius: 4
          color: "#ef4444"
          SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
            NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
          }
        }

        Text {
          text: "LIVE"
          color: "#ef4444"
          font.pixelSize: 11
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          text: (backend.currentChannel.name || "") + (backend.currentChannel.countryName ? " • " + backend.currentChannel.countryName : "")
          color: "#ffffff"
          font.pixelSize: 13
          font.bold: true
          elide: Text.ElideRight
        }

        // Quality Pill
        Rectangle {
          Layout.preferredHeight: 22
          Layout.preferredWidth: qualityText.implicitWidth + 12
          radius: 4
          color: "#0284c7"
          visible: backend.currentChannel.quality !== undefined

          Text {
            id: qualityText
            anchors.centerIn: parent
            text: backend.currentChannel.quality || "HD"
            color: "#ffffff"
            font.pixelSize: 10
            font.bold: true
          }
        }

        // Category Pill
        Rectangle {
          Layout.preferredHeight: 22
          Layout.preferredWidth: catText.implicitWidth + 12
          radius: 4
          color: "#334155"
          visible: backend.currentChannel.category !== undefined

          Text {
            id: catText
            anchors.centerIn: parent
            text: backend.currentChannel.category || "General"
            color: "#cbd5e1"
            font.pixelSize: 10
          }
        }

        // Favorite Toggle Button
        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 4
          color: favMouse.containsMouse ? "#334155" : "transparent"

          Text {
            anchors.centerIn: parent
            text: backend.isFavorite(root.streamUrl) ? "❤️" : "🤍"
            font.pixelSize: 14
          }

          MouseArea {
            id: favMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.toggleFavorite(backend.currentChannel)
          }
        }
      }
    }

    // Bottom Controls Bar Overlay
    Rectangle {
      id: bottomBar
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 48
      color: "#05070ae6"
      visible: root.controlsVisible && (backend.currentChannel.name !== undefined)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // Play/Pause
        Rectangle {
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          radius: 6
          color: playMouse.containsMouse ? "#334155" : "#1e293b"

          Text {
            anchors.centerIn: parent
            text: mediaPlayer.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
            color: "#ffffff"
            font.pixelSize: 14
          }

          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                mediaPlayer.pause()
              } else {
                mediaPlayer.play()
              }
            }
          }
        }

        // Mute / Volume icon
        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 4
          color: muteMouse.containsMouse ? "#334155" : "transparent"

          Text {
            anchors.centerIn: parent
            text: root.isMuted || root.volume === 0 ? "🔇" : (root.volume > 0.5 ? "🔊" : "🔉")
            font.pixelSize: 14
          }

          MouseArea {
            id: muteMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isMuted = !root.isMuted
          }
        }

        // Volume Slider
        QQC.Slider {
          id: volSlider
          Layout.preferredWidth: 90
          from: 0.0
          to: 1.0
          value: root.volume
          onMoved: {
            root.volume = value
            root.isMuted = false
          }
        }

        Item { Layout.fillWidth: true }

        // Fit / Crop Aspect ratio toggle
        Rectangle {
          Layout.preferredHeight: 26
          Layout.preferredWidth: fitText.implicitWidth + 14
          radius: 4
          color: fitMouse.containsMouse ? "#334155" : "#1e293b"
          border.color: "#475569"
          border.width: 1

          Text {
            id: fitText
            anchors.centerIn: parent
            text: root.fillModeCrop ? "Fit Window" : "Fill Aspect"
            color: "#94a3b8"
            font.pixelSize: 11
          }

          MouseArea {
            id: fitMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.fillModeCrop = !root.fillModeCrop
          }
        }

        // MPV External Launcher Button
        Rectangle {
          Layout.preferredHeight: 26
          Layout.preferredWidth: mpvText.implicitWidth + 14
          radius: 4
          color: mpvMouse.containsMouse ? "#0284c7" : "#0369a1"

          Text {
            id: mpvText
            anchors.centerIn: parent
            text: "↗ MPV Player"
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
          }

          MouseArea {
            id: mpvMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.openInMpv(root.streamUrl)
          }
        }
      }
    }

    // Hover area to show/hide controls
    HoverHandler {
      id: playerHover
      onHoveredChanged: {
        root.controlsVisible = hovered || mediaPlayer.playbackState !== MediaPlayer.PlayingState
      }
    }
  }
}
