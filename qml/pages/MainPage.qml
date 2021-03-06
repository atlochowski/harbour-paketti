﻿/*
  Copyright (C) 2014 Juhana Virkkala <juhana.virkkala@toimii.fi>

  All rights reserved.

  You may use this file under the terms of BSD license as follows:

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Jolla Ltd nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "plug_itella.js" as PlugItella
import "plug_mh.js" as PlugMH
import "plug_pn.js" as PlugPN
import "plug_herde.js" as PlugHerDe
import "plug_laposte.js" as PlugLaPoste
import "plug_dhl.js" as PlugDHL

import harbour.org.paketti 1.0

Page {
    id: mainpage
    property var lastupd

    Connections {
        target: paketti
        onApplicationActiveChanged: {
            if (paketti.applicationActive) {
                reloadhistory(false);
            }
        }
    }

    onStatusChanged: {
        //console.log("Status changed " + status);
        if (status == PageStatus.Active) {
            mainpage.forceActiveFocus();
            //Qt.inputMethod.hide();
            reloadhistory(false);
        }
    }

    Component.onCompleted: {
        reloadhistory(true);
    }

    property bool historyvisible: historyvisible;
    property bool cautoset: false;
    property variant currentCourier: "";

    function itemUpdStarted(index) {
        historyModel.set(index, {"itmrun": "true"});
        historyModel.set(index, {"itmcolor": "yellow"});
        historyModel.set(index, {"status": 1});
    }

    function itemUpdReady(index,okStr,showdet) {
        var trackid = historyModel.get(index).title;
        lastActivityToList(index);
        historyModel.set(index, {"itmrun": "false"});

        switch (okStr) {
            case "HIT":
                historyModel.set(index, {"itmcolor": "green"});
                console.log("UPDWWW: " + trackid + " [OK]");
            break;
            case "ERR":
                historyModel.set(index, {"itmcolor": "red"});
                console.log("UPDWWW: " + trackid + " [Error]");
            break;
            case "OK":
                historyModel.set(index, {"itmcolor": "orange", "det": "NAN"});
                console.log("UPDWWW: " + trackid + " [no_data]");
            break;
        }

        if (showdet == 1) {
            pageStack.push("Details.qml", {"koodi": trackid});
        }
        else {
            historyModel.set(index, {"status": getStatus(historyModel.get(index).title)});
        }
        //setEventsShown(historyModel.get(index).title);
        saveitem(index);
    }

    function deleteitm(trackid) {
        var db = dbConnection();
        db.transaction(
            function(tx) {
                tx.executeSql('DELETE FROM shipdets WHERE trackid = UPPER(?);', [trackid]);
                var rs = tx.executeSql('DELETE FROM history WHERE trackid = UPPER(?);', [trackid]);
                if (rs.rowsAffected > 0) {
                    console.log("Deleted: " + trackid + " [OK]")
                    if (historyModel.count == 1) {
                        historyvisible = false;
                    }
                } else {
                    console.error("ERROR: Failed to delete : " + trackid );
                }
            }
        );
    }

    function populatedets() {
        for (var i = 1; i < historyModel.count; i++) {
            if (historyModel.get(i).title != "") {
                updateitem(i, 0);
            }
            setLastUpd();
        }
    }

    function updateitem(index, showdet) {
        var trackid = historyModel.get(index).title;
        if (historyModel.get(index).type == "FI") {
            PlugItella.updatedet(index, trackid, showdet);
            historyModel.set(index, {"typec": "#ff9600"});
        }
        else if (historyModel.get(index).type == "MH") {
            PlugMH.updatedet(index, trackid, showdet);
            historyModel.set(index, {"typec": "#1e00ff"});
        }
        else if (historyModel.get(index).type == "PN") {
            PlugPN.updatedet(index, trackid, showdet);
            historyModel.set(index, {"typec": "#00a9cd"});
        }
        else if (historyModel.get(index).type == "HERDE") {
            PlugHerDe.updatedet(index, trackid, showdet);
            historyModel.set(index, {"typec": "#0091cd"});
        }
        else if (historyModel.get(index).type == "DHL") {
            PlugDHL.updatedet(index, trackid, showdet);
            historyModel.set(index, {"typec": "#D40511"});
        }
        else if (historyModel.get(index).type == "LAPOSTE") {
            PlugLaPoste.updatedet(index, trackid, showdet);
            historyModel.set(index, {"typec": "#f2e435"});
        }
    }

    function addTrackable(type,trackid) {
        if (trackid != "") {
            var index = 999;
            historyvisible = true;
            trackid = trackid.toUpperCase();

            // Check if item is already on historylist, if not add and save to db
            for (var i = 0; i < historyModel.count; i++) {
                if (historyModel.get(i).title.toUpperCase() == trackid) {
                    index = i;
                }
            }

            if (index == 999) {
                index = 1;
                var tmpdate = Qt.formatDateTime(new Date(), "yyyyMMddHHmmss");
                historyModel.insert(index, {"type": type, "title": trackid, "det": "NAN", "statusstr": "", "datetime": tmpdate, "itemdesc": ""});
                saveitem(index);
            }
            updateitem(index, 1);
        }
    }

    function reloadhistory(upd) {
        var db = dbConnection();
        db.transaction(
            function(tx) {
                var rs = tx.executeSql('SELECT * FROM history ORDER BY timestamp DESC;');
                for (var i = 0; i < rs.rows.length; i++) {
                    historyModel.set(i+1, {"type": rs.rows.item(i).type, "det": "NAN", "title": rs.rows.item(i).trackid, "datetime": rs.rows.item(i).timestamp, "itemdesc": rs.rows.item(i).detstr});
                    if (rs.rows.item(i).type == "FI") {
                        historyModel.set(i+1, {"typec" : "#ff9600"});
                    }
                    else if (rs.rows.item(i).type == "MH") {
                        historyModel.set(i+1, {"typec" : "#1e00ff"});
                    }
                    else if (rs.rows.item(i).type == "PN") {
                        historyModel.set(i+1, {"typec" : "#00a9cd"});
                    }
                    else if (rs.rows.item(i).type == "HERDE") {
                        historyModel.set(i+1, {"typec" : "#00a9cd"});
                    }
                    else if (rs.rows.item(i).type == "DHL") {
                        historyModel.set(i+1, {"typec" : "#D40511"});
                    }
                    else if (rs.rows.item(i).type == "LAPOSTE") {
                        historyModel.set(i+1, {"typec" : "#f2e435"});
                    }
                    historyModel.set(i+1, {"status": getStatus(rs.rows.item(i).trackid)});
                    lastActivityToList(i+1);
                }
                if (rs.rows.length != 0) {
                    historyvisible = true;
                }
                else {
                    historyvisible = false;
                }
            }
        );
        if (upd == true) {
            populatedets();
        }
    }

    function lastActivityToList(index) {
        var trackid = historyModel.get(index).title;
        var db = dbConnection();
        db.transaction(
            function(tx) {
                var rs = tx.executeSql('SELECT * FROM shipdets WHERE trackid = ? AND type = \"EVT\" ORDER BY datetime DESC LIMIT 1;', [trackid]);
                if (rs.rows.length > 0) {
                    var det = rs.rows.item(0).label;
                    if (rs.rows.item(0).value !== null && rs.rows.item(0).value !== "") {
                        det = det + " "  + rs.rows.item(0).value;
                    }
                    historyModel.set(index, {"det": det, "datetime": rs.rows.item(0).datetime});
                }
            }
        );
    }

    function saveitem(index) {
        var type = historyModel.get(index).type;
        var trackid = historyModel.get(index).title;
        var timestamp = historyModel.get(index).datetime;
        var itemdescr = historyModel.get(index).itemdescr;
        var db = dbConnection();
        db.transaction(
            function(tx) {
                var rz = tx.executeSql('INSERT OR IGNORE INTO history (trackid) VALUES (?);', [trackid]);
                var rs = tx.executeSql('UPDATE history SET type = ?, timestamp = ? WHERE trackid = ?;', [type, timestamp, trackid]);

                //var rs = tx.executeSql('INSERT OR REPLACE INTO history (type, trackid, timestamp, detstr) VALUES (?,UPPER(?),?,?);', [type, trackid, timestamp, itemdescr]);
                //var rs = tx.executeSql('INSERT INTO history (type, trackid, timestamp) VALUES (?,UPPER(?),?) ON DUPLICATE KEY UPDATE type=?,timestamp=?;', [type, trackid, timestamp,type,timestamp]);

                if (rs.rowsAffected > 0) {
                    console.log("saved: " + trackid + " [OK]")
                } else {
                    console.error("ERROR: Failed to save : " + trackid );
                }
            }
        );
    }

    function detectCourierByTrackingCode(trackingCode) {
        trackingCode = trackingCode.toUpperCase();
        if (trackingCode.match(/^(JJFI)|(MX)/)) {
            return "FI";
        }
        else if (trackingCode.match(/^(MH)/)) {
            return "MH";
        }
        return false;
    }

    SilicaListView {
        id: lista
        anchors.fill: parent

        PullDownMenu {
            id: pdmenu
            property bool updsel: false
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push("AboutPage.qml");
            }
            MenuItem {
                text: qsTr("Update")
                //onClicked: populatedets()
                onClicked: pdmenu.updsel = true
            }
            onStateChanged: {
                if (pdmenu.state != "expanded" && updsel == true) {
                    populatedets();
                }
                updsel = false;
            }
        }
        header: PageHeader {
            id: phead
            title: qsTr("Track item")
        }
        model: ListModel {
            id: historyModel
            ListElement {title: ""; itemdesc: ""; det: " " ; type: "" ; itmrun: "" ; itmcolor: "" ; typec: "" ; datetime: "fuu" ; status: 0}
        }
        delegate: ListItem {
            contentHeight: index==0 ? hrect.height : hitemrow.height+10
            id: listitem
            menu: contextMenu
            width: index==0 ? 0 : parent.width
            onClicked: {
                historyModel.set(index, {"status": 1});
                var props = {
                    "koodi": title
                };
                if (index != 0) {
                    pageStack.push("Details.qml", props);
                }
            }
            onPressed: {
                if (index != 0) {
                    listitem.forceActiveFocus();
                    setEventsShown(historyModel.get(index).title);
                    historyModel.set(index, {"status": getStatus(historyModel.get(index).title)});
                }
            }
            ListView.onRemove: animateRemoval(listitem)

            function remove(title) {
                remorseAction(qsTr("Deleting"), function() {
                    lista.model.remove(index);
                    deleteitm(title);
                }, 3000);
            }
            ProgressBar {
                width: parent.width
                //indeterminate: true
                //label: "Indeterminate"
                id: itmBusyIndicator
                indeterminate: itmrun=="true" ? true : false
                visible: itmrun=="true" ? true : false
                //onDataChanged: console.log("Changed..")
            }
            Rectangle {
                id: hrect
                color: "transparent"
                visible: index==0
                width: lista.width
                height: courier.height + historyhead.height + koodiInput.height
                onHeightChanged: {
                    if (index == 0) {
                        listitem.height = hrect.height
                    }
                }

                ComboBox {
                    anchors.bottom: koodiBoksi.top
                    id: courier
                    width: parent.width
                    label: qsTr("Courier") + ": "
                    value: qsTr("Select")
                    description: qsTr("The courier is autoselected when entering a tracking code if possible.")

                    menu: ContextMenu {
                        Repeater {
                            model: couriers
                            MenuItem {
                                text: qsTranslate("main", model.name)
                                onClicked: {
                                    courier.value = name
                                    mainpage.currentCourier = identifier
                                }
                            }
                        }
                        onClicked: {
                            cautoset = false;
                            courier.valueColor = Theme.highlightColor;
                            koodiInput.forceActiveFocus();
                        }
                    }
                }

                Rectangle {
                    id: koodiBoksi
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    anchors.bottom: historyhead.top
                    height: koodiInput.height
                    color: "transparent"
                    //color: "#000000"

                    //Search
                    TextField {
                        id: koodiInput
                        font.pixelSize: Theme.fontSizeLarge
                        onActiveFocusChanged: {
                            if (koodiInput.focus == true) {
                                Qt.inputMethod.show();
                            }
                            else {
                                Qt.inputMethod.hide();
                            }
                        }
                        width: parent.width-enterIcon.width
                        inputMethodHints: Qt.ImhNoPredictiveText // Qt.ImhPreferUppercase | Qt.ImhNoAutoUppercase
                        placeholderText: qsTr("Enter tracking code")
                        validator: RegExpValidator { regExp: /^[0-9a-z]{5,100}$/i }
                        anchors.left: parent.left
                        onTextChanged: {
                            var cauto = detectCourierByTrackingCode(text);
                            if (cauto && courier.currentIndex == 0) {
                                cautoset = true;
                                courier.setValueByIdentifier(cauto);
                            }
                            // The courier was previously auto-set, but the code no longer matches.
                            else if (!cauto && cautoset === true) {
                                cautoset = false;
                                courier.currentIndex = 0;
                            }

                            // Remind the user of setting the courier.
                            if (courier.currentIndex == 0 && text.length != 0) {
                                courier.valueColor = "red"
                            }
                            else {
                                courier.valueColor = Theme.highlightColor
                            }
                        }

                        EnterKey.enabled: courier.currentIndex!=0 && text.length > 4
                        //EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        //EnterKey.iconSource: "image://theme/icon-m-enter-next"
                        EnterKey.text: "OK"
                        EnterKey.highlighted: true
                        EnterKey.onClicked: {
                            addTrackable(courier.currentItem.value, koodiInput.text);
                            koodiInput.text = "";
                            courier.currentIndex = 0;
                        }
                    }
                    IconButton {
                        id: enterIcon
                        icon.source: "image://theme/icon-m-enter-accept"
                        anchors.right: parent.right
                        onClicked: {
                            addTrackable(mainpage.currentCourier, koodiInput.text);
                            koodiInput.text = "";
                            courier.value = qsTr("Select");
                            mainpage.currentCourier = "";
                        }
                        enabled: courier.currentIndex!=0 && koodiInput.text.length > 4
                    }
                }
                SectionHeader {
                    anchors.bottom: parent.bottom
                    id: historyhead
                    text: qsTr("History");
                    visible: historyvisible
                }
                Label {
                    id: historytip
                    width: parent.width - (Theme.paddingMedium*2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: koodiBoksi.bottom
                    text: "<br>" + qsTr("Start by choosing a courier and entering the tracking code in the box above. Tracked shipments will be saved automatically")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeLarge
                    wrapMode: Text.WordWrap
                    visible: !historyvisible
                }
            }

            Rectangle {
                property bool menuOpen: contextMenu != null && contextMenu.parent === hitemrow
                id: hitemrow
                width: parent.width
                height: menuOpen ? hdet.height + htitle.height + descLabel.height + contextMenu.height : hdet.height + htitle.height + descLabel.height
                //height: contextMenu.active==true ? hdet.height + htitle.height + contextMenu.height : hdet.height + htitle.height
                color: "transparent"
                visible: index!=0

                Rectangle {
                    id: erotint
                    color: Theme.highlightColor
                    opacity: status==0 ? 0.6 : 0.2
                    height: listitem.height-10
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Rectangle {
                    id: erotin
                    color: itmcolor == undefined ? Theme.highlightColor : typec
                    height: listitem.height-10
                    width: Theme.paddingMedium
                    anchors.left: erotint.left
                }
                OpacityRampEffect {
                    id: effect
                    slope: 2
                    offset: 0.2
                    direction: OpacityRamp.LeftToRight
                    sourceItem: erotin
                }
                GlassItem {
                    id: pimpula
                    color:  itmcolor == undefined ?  Theme.primaryColor : itmcolor
                    height: 40
                    width: height
                    cache: false
                    anchors.verticalCenter: htitle.verticalCenter
                    anchors.right: erotint.right
                    radius: 3
                    falloffRadius: 0.2
                }
                Text {
                    id: timefield
                    text: convertDateBack(datetime)
                    anchors.verticalCenter: htitle.verticalCenter
                    anchors.right: pimpula.left
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    visible: det != "NAN"
                }

                Label {
                    width: parent.width - (Theme.paddingMedium*2)
                    id: htitle
                    text: title
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    font.capitalization: Font.AllUppercase
                    //width: parent.width - (Theme.paddingMedium*2) - timefield.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: erotin.top
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                OpacityRampEffect {
                    //TODO: RampEffect size shoud follow screen width/available space
                    id: titleEffect
                    slope: 20
                    offset: 0.5
                    direction: OpacityRamp.LeftToRight
                    sourceItem: htitle
                }
                Label {
                    id: descLabel
                    text: itemdesc
                    anchors.top: htitle.bottom
                    width: parent.width - (Theme.paddingMedium*2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                    height: itemdesc == "" ? 0 : descLabel.contentHeight
                }
                Label {
                    id: hdet
                    anchors.top: descLabel.bottom
                    width: parent.width - (Theme.paddingMedium*2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: det == "NAN" ? "<i>" + qsTr("No information available") + "</i>" : det
                    wrapMode: Text.WordWrap
                }

                Component {
                    id: contextMenu
                    ContextMenu {
                        //ContextMenu.onEnabled: Qt.inputMethod.hide();
                        MenuItem {
                            text: itemdesc == "" ? qsTr("Add description") : qsTr("Modify description")
                            onClicked: pageStack.push("DescDialog.qml", {"trackid": title, "description": itemdesc});
                        }
                        MenuItem {
                            text: qsTr("Copy tracking number")
                            onClicked: Clipboard.text = title
                        }
                        MenuItem {
                            text: qsTr("Copy text")
                            onClicked: Clipboard.text = title + " " + timefield.text + "\n" + hdet.text
                        }
                        MenuItem {
                            text: qsTr("Remove item")
                            onClicked: remove(title)
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
