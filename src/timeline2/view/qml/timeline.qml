import QtQuick 2.4
import QtQml.Models 2.1
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.3
import Kdenlive.Controls 1.0
import QtGraphicalEffects 1.0
import QtQuick.Window 2.2
import 'Timeline.js' as Logic

Rectangle {
    id: root
    objectName: "timelineview"

    SystemPalette { id: activePalette }
    color: activePalette.window

    signal clipClicked()

    FontMetrics {
        id: fontMetrics
        font.family: "Arial"
    }

    function zoomByWheel(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            //TODO
            timeline.setScaleFactor(timeline.scaleFactor + 0.2 * wheel.angleDelta.y / 120);
        } else {
            scrollView.flickableItem.contentX += wheel.angleDelta.y
        }
        //Logic.scrollIfNeeded()
    }

    property int headerWidth: 140
    property int baseUnit: fontMetrics.height * 0.8
    property int currentTrack: 0
    property color selectedTrackColor: activePalette.highlight //.rgba(0.8, 0.8, 0, 0.3);
    property alias trackCount: tracksRepeater.count
    property bool stopScrolling: false
    property color shotcutBlue: Qt.rgba(23/255, 92/255, 118/255, 1.0)
    //property alias ripple: toolbar.ripple

    onCurrentTrackChanged: timeline.selection = []

    DropArea {
        anchors.fill: parent
        onEntered: {
            if (drag.formats.indexOf('application/mlt+xml') >= 0)
                drag.acceptProposedAction()
        }
        onExited: Logic.dropped()
        onPositionChanged: {
            if (drag.formats.indexOf('application/mlt+xml') >= 0)
                Logic.dragging(drag, drag.text)
        }
        onDropped: {
            if (drop.formats.indexOf('application/mlt+xml') >= 0) {
                if (currentTrack >= 0) {
                    Logic.acceptDrop(drop.getDataAsString('application/mlt+xml'))
                    drop.acceptProposedAction()
                }
            }
            Logic.dropped()
        }
    }
    Menu {
        id: menu
        MenuItem {
            text: qsTr('Add Audio Track')
            shortcut: 'Ctrl+U'
            onTriggered: timeline.addAudioTrack();
        }
    }

    Row {
        Column {
            z: 1
            Rectangle {
                id: cornerstone
                property bool selected: false
                // Padding between toolbar and track headers.
                width: headerWidth
                height: ruler.height
                color: selected? shotcutBlue : activePalette.window
                border.color: selected? 'red' : 'transparent'
                border.width: selected? 1 : 0
                z: 1
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: timeline.selectMultitrack()
                }
            }
            Flickable {
                // Non-slider scroll area for the track headers.
                //contentY: scrollView.flickableItem.contentY
                width: headerWidth
                height: trackHeaders.height
                interactive: false

                Column {
                    id: trackHeaders
                    Repeater {
                        id: trackHeaderRepeater
                        model: multitrack
                        TrackHead {
                            trackName: model.name
                            isMute: model.mute
                            isHidden: model.hidden
                            isComposite: model.composite
                            isLocked: model.locked
                            isVideo: !model.audio
                            width: headerWidth
                            height: model.trackHeight
                            selected: false
                            current: index === currentTrack
                            onIsLockedChanged: tracksRepeater.itemAt(index).isLocked = isLocked
                            onMyTrackHeightChanged: {
                                tracksRepeater.itemAt(index).height = myTrackHeight
                                height = myTrackHeight
                            }
                            onClicked: {
                                currentTrack = index
                                timeline.selectTrackHead(currentTrack)
                            }
                    }
                }
            }
            Rectangle {
                    // thin dividing line between headers and tracks
                    //color: activePalette.windowText
                    width: 1
                    x: parent.x + parent.width
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
            }
            }
        }
        MouseArea {
            id: tracksArea
            width: root.width - headerWidth
            height: root.height

            // This provides continuous scrubbing and scimming at the left/right edges.
            focus: true
            hoverEnabled: true
            onClicked: {
                console.log("Position changed: ",timeline.position)
                timeline.position = (scrollView.flickableItem.contentX + mouse.x) / timeline.scaleFactor
            }
            property bool scim: false
            onReleased: scim = false
            onExited: scim = false
            onPositionChanged: {
                if (mouse.modifiers === Qt.ShiftModifier || mouse.buttons === Qt.LeftButton) {
                    timeline.position = (scrollView.flickableItem.contentX + mouse.x) / timeline.scaleFactor
                    scim = true
                }
                else
                    scim = false
            }
            Timer {
                id: scrubTimer
                interval: 25
                repeat: true
                running: parent.scim && parent.containsMouse
                         && (parent.mouseX < 50 || parent.mouseX > parent.width - 50)
                         && (timeline.position * timeline.scaleFactor >= 50)
                onTriggered: {
                    if (parent.mouseX < 50)
                        timeline.position -= 10
                    else
                        timeline.position += 10
                }
            }

            Column {
                Flickable {
                    // Non-slider scroll area for the Ruler.
                    contentX: scrollView.flickableItem.contentX
                    width: root.width - headerWidth
                    height: ruler.height
                    interactive: false

                    Ruler {
                        id: ruler
                        width: tracksContainer.width
                        index: index
                        timeScale: timeline.scaleFactor
                    }
                }
                ScrollView {
                    id: scrollView
                    width: root.width - headerWidth
                    height: root.height - ruler.height

                    Rectangle {
                        width: tracksContainer.width + headerWidth
                        height: trackHeaders.height + 30 // 30 is padding
                        Column {
                            // These make the striped background for the tracks.
                            // It is important that these are not part of the track visual hierarchy;
                            // otherwise, the clips will be obscured by the Track's background.
                            Repeater {
                                model: multitrack
                                delegate: Rectangle {
                                    width: tracksContainer.width
                                    //Layout.fillWidth: true
                                    color: (index === currentTrack)? selectedTrackColor : (index % 2)? activePalette.alternateBase : activePalette.base
                                    opacity: 0.3
                                    height: tracksRepeater.itemAt(index).height
                                }
                            }
                        }
                        Column {
                            id: tracksContainer
                            Repeater { id: tracksRepeater; model: trackDelegateModel }
                        }
                    }
                }
            }
            CornerSelectionShadow {
                y: tracksRepeater.count ? tracksRepeater.itemAt(currentTrack).y + ruler.height - scrollView.flickableItem.contentY : 0
                clip: timeline.selection.length ?
                        tracksRepeater.itemAt(currentTrack).clipAt(timeline.selection[0]) : null
                opacity: clip && clip.x + clip.width < scrollView.flickableItem.contentX ? 1 : 0
            }

            CornerSelectionShadow {
                y: tracksRepeater.count ? tracksRepeater.itemAt(currentTrack).y + ruler.height - scrollView.flickableItem.contentY : 0
                clip: timeline.selection.length ?
                        tracksRepeater.itemAt(currentTrack).clipAt(timeline.selection[timeline.selection.length - 1]) : null
                opacity: clip && clip.x > scrollView.flickableItem.contentX + scrollView.width ? 1 : 0
                anchors.right: parent.right
                mirrorGradient: true
            }

            Rectangle {
                id: cursor
                visible: timeline.position > -1
                color: activePalette.text
                width: 1
                height: root.height - scrollView.__horizontalScrollBar.height
                x: timeline.position * timeline.scaleFactor - scrollView.flickableItem.contentX
                y: 0
            }
            TimelinePlayhead {
                id: playhead
                visible: timeline.position > -1
                height: baseUnit * 0.8
                width: baseUnit
                y: ruler.height - height
                x: timeline.position * timeline.scaleFactor - scrollView.flickableItem.contentX - (width / 2)
            }
        }
    }
    Rectangle {
        id: dropTarget
        height: multitrack.trackHeight
        opacity: 0.5
        visible: false
        Text {
            anchors.fill: parent
            anchors.leftMargin: 100
            text: timeline.ripple? qsTr('Insert') : qsTr('Overwrite')
            style: Text.Outline
            styleColor: 'white'
            font.pixelSize: Math.min(Math.max(parent.height * 0.8, 15), 30)
            verticalAlignment: Text.AlignVCenter
        }
    }

    Rectangle {
        id: bubbleHelp
        property alias text: bubbleHelpLabel.text
        //color: application.toolTipBaseColor
        width: bubbleHelpLabel.width + 8
        height: bubbleHelpLabel.height + 8
        radius: 4
        states: [
            State { name: 'invisible'; PropertyChanges { target: bubbleHelp; opacity: 0} },
            State { name: 'visible'; PropertyChanges { target: bubbleHelp; opacity: 1} }
        ]
        state: 'invisible'
        transitions: [
            Transition {
                from: 'invisible'
                to: 'visible'
                OpacityAnimator { target: bubbleHelp; duration: 200; easing.type: Easing.InOutQuad }
            },
            Transition {
                from: 'visible'
                to: 'invisible'
                OpacityAnimator { target: bubbleHelp; duration: 200; easing.type: Easing.InOutQuad }
            }
        ]
        Label {
            id: bubbleHelpLabel
            //color: application.toolTipTextColor
            anchors.centerIn: parent
        }
        function show(x, y, text) {
            bubbleHelp.x = x + tracksArea.x - scrollView.flickableItem.contentX - bubbleHelpLabel.width
            bubbleHelp.y = y + tracksArea.y - scrollView.flickableItem.contentY - bubbleHelpLabel.height
            bubbleHelp.text = text
            if (bubbleHelp.state !== 'visible')
                bubbleHelp.state = 'visible'
        }
        function hide() {
            bubbleHelp.state = 'invisible'
            bubbleHelp.opacity = 0
        }
    }
    DropShadow {
        source: bubbleHelp
        anchors.fill: bubbleHelp
        opacity: bubbleHelp.opacity
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8
        color: '#80000000'
        transparentBorder: true
        fast: true
    }

    DelegateModel {
        id: trackDelegateModel
        model: multitrack
        Track {
            model: multitrack
            rootIndex: trackDelegateModel.modelIndex(index)
            height: trackHeight
            width: timeline.duration * timeScale
            isAudio: audio
            isCurrentTrack: currentTrack === index
            timeScale: timeline.scaleFactor
            trackId: item
            selection: timeline.selection
            onClipClicked: {
                currentTrack = track.DelegateModel.itemsIndex
                timeline.selection = [ clip.DelegateModel.itemsIndex ];
                root.clipClicked()
            }
            onClipDragged: {
                // This provides continuous scrolling at the left/right edges.
                if (x > scrollView.flickableItem.contentX + scrollView.width - 50) {
                    scrollTimer.item = clip
                    scrollTimer.backwards = false
                    scrollTimer.start()
                } else if (x < 50) {
                    scrollView.flickableItem.contentX = 0;
                    scrollTimer.stop()
                } else if (x < scrollView.flickableItem.contentX + 50) {
                    scrollTimer.item = clip
                    scrollTimer.backwards = true
                    scrollTimer.start()
                } else {
                    scrollTimer.stop()
                }
                // Show distance moved as time in a "bubble" help.
                var track = tracksRepeater.itemAt(clip.trackIndex)
                var delta = Math.round((clip.x - clip.originalX) / timeline.scaleFactor)
                var s = timeline.timecode(Math.abs(delta))
                // remove leading zeroes
                if (s.substring(0, 3) === '00:')
                    s = s.substring(3)
                s = ((delta < 0)? '-' : (delta > 0)? '+' : '') + s
                bubbleHelp.show(x, track.y + height, s)
            }
            onClipDropped: {
                console.log(" + + + ++ + DROPPED  + + + + + + +");
                scrollTimer.running = false
                bubbleHelp.hide()
            }
            onClipDraggedToTrack: {
                var i = clip.trackIndex + direction
                var frame = Math.round(clip.x / timeScale)
                if (i >= 0  && i < tracksRepeater.count) {
                    var track = tracksRepeater.itemAt(i)
                    if (timeline.allowMoveClip(track.trackId, clip.clipId, frame)) {
                        clip.reparent(track)
                        clip.trackIndex = track.DelegateModel.itemsIndex
                        clip.trackId = track.trackId
                    }
                }
            }
            onCheckSnap: {
                for (var i = 0; i < tracksRepeater.count; i++)
                    tracksRepeater.itemAt(i).snapClip(clip)
            }
            Image {
                anchors.fill: parent
                source: "qrc:///icons/light/16x16/track-locked.png"
                fillMode: Image.Tile
                opacity: parent.isLocked
                visible: opacity
                Behavior on opacity { NumberAnimation {} }
                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                        mouse.accepted = true;
                        trackHeaderRepeater.itemAt(index).pulseLockButton()
                    }
                }
            }
        }
    }
    Connections {
        target: timeline
        onPositionChanged: if (!stopScrolling) Logic.scrollIfNeeded()
        /*onDragging: Logic.dragging(pos, duration)
        onDropped: Logic.dropped()
        onDropAccepted: Logic.acceptDrop(xml)*/
        onSelectionChanged: {
            cornerstone.selected = timeline.isMultitrackSelected()
            var selectedTrack = timeline.selectedTrack()
            for (var i = 0; i < trackHeaderRepeater.count; i++)
                trackHeaderRepeater.itemAt(i).selected = (i === selectedTrack)
        }
    }

    // This provides continuous scrolling at the left/right edges.
    Timer {
        id: scrollTimer
        interval: 25
        repeat: true
        triggeredOnStart: true
        property var item
        property bool backwards
        onTriggered: {
            var delta = backwards? -10 : 10
            if (item) item.x += delta
            scrollView.flickableItem.contentX += delta
            if (scrollView.flickableItem.contentX <= 0)
                stop()
        }
    }
}
