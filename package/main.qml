import QtQuick 2.15
import org.deepin.ds 1.0
import org.deepin.ds.dock 1.0

AppletItem {
    id: root
    property int dockOrder: 9
    property bool useColumnLayout: Panel.position % 2
    implicitWidth: useColumnLayout ? Panel.rootObject.dockSize : metrics.implicitWidth + 12
    implicitHeight: useColumnLayout ? metrics.implicitWidth + 12 : Panel.rootObject.dockSize

    readonly property color muted: "#A9BAC7"
    readonly property color cyan: "#67E8F9"
    readonly property color green: "#6EE7B7"
    readonly property color statusColor: Applet.activeTasks < 0 ? muted :
                                         Applet.activeTasks === 0 ? "#6EE7B7" :
                                         Applet.activeTasks === 1 ? "#FBBF24" : "#F87171"

    component MetricCell: Item {
        property string title
        property string value
        property int cellWidth: 62
        property int valueWidth: 36
        property color titleColor: root.cyan
        width: cellWidth
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.title
            color: parent.titleColor
            font.family: "Noto Sans CJK SC"
            font.pixelSize: 12
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.valueWidth
            horizontalAlignment: Text.AlignRight
            text: parent.value
            color: "#E8F1F5"
            font.family: "Noto Sans CJK SC"
            font.pixelSize: 12
        }
    }

    component SpeedCell: Item {
        property string direction
        property string value
        width: 70
        height: 18
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            text: parent.direction
            color: root.muted
            font.pixelSize: 12
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            text: parent.value
            color: root.green
            font.pixelSize: 11
        }
    }

    Row {
        id: metrics
        anchors.centerIn: parent
        spacing: 2
        rotation: root.useColumnLayout ? -90 : 0

        Rectangle {
            width: 9; height: 9; radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: root.statusColor
        }
        MetricCell {
            title: "Codex"
            value: Applet.codexRemaining < 0 ? "--" : Applet.codexRemaining + "%"
            cellWidth: 76
            valueWidth: 35
            titleColor: "#E8F1F5"
        }
        Text { text: "│"; width: 6; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.pixelSize: 12 }
        MetricCell { title: "CPU"; value: Applet.cpu + "%"; cellWidth: 58 }
        Text { text: "│"; width: 6; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.pixelSize: 12 }
        MetricCell { title: "内存"; value: Applet.memory + "%"; cellWidth: 62 }
        Text { text: "│"; width: 6; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.pixelSize: 12 }
        MetricCell { title: "磁盘"; value: Applet.disk + "%"; cellWidth: 62 }
        Text { text: "│"; width: 6; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.pixelSize: 12 }
        SpeedCell { direction: "↓"; value: Applet.down }
        SpeedCell { direction: "↑"; value: Applet.up }
    }

    PanelToolTip {
        id: tooltip
        text: "任务: " + (Applet.activeTasks < 0 ? "状态未知" : Applet.activeTasks + " 个运行中") +
              "\n额度剩余: " + (Applet.codexRemaining < 0 ? "未知" : Applet.codexRemaining + "%") +
              "\n网络接口: " + (Applet.interfaceName || "未检测到")
        toolTipX: DockPanelPositioner.x
        toolTipY: DockPanelPositioner.y
    }
    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                const point = root.mapToItem(null, root.width / 2, root.height / 2)
                tooltip.DockPanelPositioner.bounding = Qt.rect(point.x, point.y, tooltip.width, tooltip.height)
                tooltip.open()
            } else {
                tooltip.close()
            }
        }
    }
}
