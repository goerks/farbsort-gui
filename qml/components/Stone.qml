import QtQuick 2.0

Item {
    id: stoneObject
    state: "CREATED"
    property alias color: circle.color
    property int startPosX: 16
    property int startPosY: parent.height/2 - stoneObject.height/2
    property int stopPosY: startPosY + 100
    property int conveyorSpeed: 800
    property int lightbarrierAfterDetectorXPos: 300
    property int trayId: 0
    property int destinationXPos: 300
    // flag to store if the color was already assigned
    property bool _colorAssigned: false

    // signalizes that the stone is ready for destruction
    signal destructionRequested(var stone)

    // starts the detection of the color
    function handleDetectionStarted() {
        stoneObject.x = stoneObject.startPosX
        stoneObject.y = stoneObject.startPosY
        stoneObject.color = "transparent"
        state = "DETECTING"
    }

    // tries to assign the detected color to the stone
    // return: true, if the operation was successful, otherwise false
    function handleColorDetected(color, trayId, destinationXPos) {
        // stone must be under the color detector and no color was assigned before
        if("DETECTING" === state && !stoneObject._colorAssigned) {
            stoneObject.color = color
            stoneObject.trayId = trayId
            stoneObject.destinationXPos = destinationXPos - radius
            stoneObject._colorAssigned = true
            console.log("Stone: handled colorDetected event for color " + color)
            return true
        }
        return false
    }

    // tries to move the stone to the end of the detector
    // return: true, if the operation was successful, otherwise false
    function handleDetectorEndReached() {
        if("DETECTING" === state) {
            stoneObject.state = "DETECTED"
            updateConveyorAnimationTime()
            stoneObject.state = "MOVING"

            console.log("Stone: handled detectorEndReached event")
            return true;
        }
        return false
    }

    function handleStartEjecting(trayId) {
        if(trayId === stoneObject.trayId &&
           ("MOVING" == stoneObject.state || "MOVED" == stoneObject.state)) {
            stoneObject.state = "MOVED"
            if(needsEjection()) {
                state = "EJECTING"
            }
            return true
        }
        return false
    }

    function handleTrayReached(trayId)
    {
        if(trayId === stoneObject.trayId && "EJECTING" == stoneObject.state) {
            stoneObject.state = "REACHED"
            return true
        }
        return false
    }

    // checks if a valid ejector id was set
    function needsEjection() {
        return trayId > 0
    }

    function updateConveyorAnimationTime() {
        conveyorAnimation.duration = conveyorSpeed / (lightbarrierAfterDetectorXPos - startPosX) * (destinationXPos - lightbarrierAfterDetectorXPos)
    }

    function handleReachedTray(trayId) {
        return "REACHED" === stoneObject.state && trayId === stoneObject.trayId
    }

    states: [
        State { name: "CREATED" },
        State { name: "DETECTING" },
        State { name: "DETECTED" },
        State { name: "MOVING" },
        State { name: "MOVED" },
        State { name: "EJECTING" },
        State { name: "REACHED" }
    ]

    transitions: [
        Transition {
            from: "CREATED";
            to: "DETECTING";
            animations:     PropertyAnimation {
                id: detectionAnimation
                loops: 1
                alwaysRunToEnd: true
                target: stoneObject
                property: "x"
                from: startPosX
                to: lightbarrierAfterDetectorXPos
                easing.type: Easing.Linear
                duration: conveyorSpeed
            }
        },
        Transition {
            from: "DETECTING";
            to: "DETECTED";
            onRunningChanged: {
                if(!running) {
                    detectionAnimation.complete()
                    stoneObject.x = lightbarrierAfterDetectorXPos
                }
            }
        },
        Transition {
            from: "DETECTED";
            to: "MOVING";
            animations: NumberAnimation {
                id: conveyorAnimation
                loops: 1
                alwaysRunToEnd: true
                target: stoneObject
                property: "x"
                from: lightbarrierAfterDetectorXPos
                to: destinationXPos
                easing.type: Easing.Linear
                duration: conveyorSpeed //conveyorAnimationTime()
            }
            onRunningChanged: {
                // stone is moved to garbage bin - set timeout to destroy stone
                if(!running && !needsEjection()) {
                    state = "REACHED"
                    deletionTimer.start()
                }
            }
        },
        Transition {
            from: "MOVING";
            to: "MOVED";
            onRunningChanged: {
                if(!running) {
                    conveyorAnimation.complete()
                    stoneObject.x = conveyorAnimation.to
                }
            }
        },
        Transition {
            from: "MOVED";
            to: "EJECTING";
            animations: NumberAnimation {
                id: ejectorChipAnimation
                target: stoneObject
                property: "y"
                from: stoneObject.startPosY
                to: stoneObject.stopPosY
                easing.type: Easing.Linear
                duration: 300
            }
        },
        Transition {
            from: "EJECTING";
            to: "REACHED";
            onRunningChanged: {
                if(!running) {
                    ejectorChipAnimation.complete()
                    stoneObject.y = stoneObject.stopPosY
                }
            }
        }
    ]

    Timer {
        id: deletionTimer
        interval: 10000; running: false; repeat: false
        onTriggered: {
            destructionRequested(stoneObject);
        }
    }

    Rectangle {
        id: circle
        anchors.fill: parent
        radius: 90
        color: "transparent"
        border.color: "black"
        border.width: parent.width * 0.05

        MouseArea {
            anchors.fill: parent
            onClicked: {
                destructionRequested(stoneObject);
            }
        }
    }
}
