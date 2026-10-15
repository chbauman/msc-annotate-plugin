import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import "fingerings.js" as Brass

MuseScore {
    version: "1.0"
    title: "Brass Fingering"
    description: "Annotate notes with valve fingerings or trombone slide positions"
    categoryCode: "composing-arranging-tools"
    menuPath: "Plugins.Brass Fingering"
    requiresScore: true
    pluginType: "dock"
    dockArea: "right"

    implicitWidth: 240
    implicitHeight: panel.implicitHeight + 20

    // First combo entry is "auto", then one entry per preset in Brass.INSTRUMENTS.
    property var instrumentModel: {
        var m = [{ text: qsTr("Auto (from staff instrument)"), id: "auto" }];
        for (var i = 0; i < Brass.INSTRUMENTS.length; i++)
            m.push({ text: Brass.INSTRUMENTS[i].name, id: Brass.INSTRUMENTS[i].id });
        return m;
    }

    property string status: ""

    function instrumentIdOfStaff(staffIdx) {
        try {
            var c = curScore.newCursor();
            c.staffIdx = staffIdx;
            c.voice = 0;
            c.rewind(Cursor.SCORE_START);
            var part = c.element ? c.element.staff.part : null;
            if (!part)
                return "";
            if (part.instrumentId)
                return part.instrumentId;
            if (part.instruments && part.instruments.length > 0)
                return part.instruments[0].instrumentId;
        } catch (e) {
            console.log("instrument lookup failed: " + e);
        }
        return "";
    }

    function presetForStaff(staffIdx) {
        var sel = instrumentModel[instrumentBox.currentIndex].id;
        if (sel !== "auto")
            return Brass.instrumentById(sel);
        var iid = instrumentIdOfStaff(staffIdx);
        console.log("staff " + staffIdx + " instrumentId '" + iid + "'");
        return Brass.instrumentById(Brass.detectInstrument(iid));
    }

    // An explicit part wins over the selection's staves; a range selection still limits the ticks.
    // Otherwise: the selected staves, or the whole score.
    function targetRange() {
        var r = { first: 0, last: curScore.nstaves - 1, startTick: 0, endTick: -1 };
        var sel = curScore.selection;
        var part = partModel[partBox.currentIndex];
        var rangeSel = sel && sel.isRange;
        if (rangeSel) {
            r.first = sel.startStaff;
            r.last = sel.endStaff - 1;
            r.startTick = sel.startSegment ? sel.startSegment.tick : 0;
            r.endTick = sel.endSegment ? sel.endSegment.tick : -1;
        }
        if (part && part.last >= 0) {
            r.first = part.first;
            r.last = part.last;
        }
        return r;
    }

    property int removedCount: 0

    function removeOurs(segment, track) {
        var ann = segment.annotations;
        for (var i = ann.length - 1; i >= 0; i--) {
            var a = ann[i];
            if (a.track !== track || a.type !== Element.STAFF_TEXT)
                continue;
            if (Brass.isOurText(a.text)) {
                removeElement(a);
                removedCount++;
            } else {
                console.log("kept staff text: " + JSON.stringify("" + a.text));
            }
        }
    }

    // Lyrics we may have added: a single digit, or digits joined by "/".
    function removeOurLyrics(chord) {
        var ly = chord.lyrics;
        for (var i = ly.length - 1; i >= 0; i--) {
            if (/^[0-7](\/[0-4])*$/.test(Brass.plainText(ly[i].text))) {
                removeElement(ly[i]);
                removedCount++;
            }
        }
    }

    // Stacked: one lyric per digit on its own verse line, so digits align under the note.
    // Not stacked: a single lyric such as "1/3".
    function addAsLyrics(cursor, inst, fing) {
        var parts = stackBox.checked ? fing.split("") : [Brass.formatText(inst, fing, false)];
        for (var v = 0; v < parts.length; v++) {
            var l = newElement(Element.LYRICS);
            l.text = parts[v];
            l.verse = v;
            l.fontSize = sizeBox.value;
            cursor.add(l);
        }
    }

    // One entry per part, plus "all" first. Rebuilt whenever the dropdown is opened.
    property var partModel: [{ text: qsTr("All parts"), first: 0, last: -1 }]

    function refreshParts() {
        var m = [{ text: qsTr("All parts / selection"), first: 0, last: -1 }];
        try {
            var parts = curScore.parts;
            for (var i = 0; i < parts.length; i++) {
                var p = parts[i];
                var name = p.longName || p.partName || p.shortName || qsTr("Part %1").arg(i + 1);
                m.push({ text: name, first: Math.floor(p.startTrack / 4), last: Math.floor((p.endTrack - 1) / 4) });
            }
        } catch (e) {
            console.log("part listing failed: " + e);
        }
        var keep = partBox.currentIndex;
        partModel = m;
        partBox.currentIndex = keep < m.length ? keep : 0;
    }

    onRun: refreshParts()

    // add = true: (re)write annotations; add = false: only remove them.
    function process(add) {
        var r = targetRange();
        var done = 0, skipped = 0, staves = 0, unknown = 0;
        var fourValves = valveBox.currentIndex === 1;
        removedCount = 0;

        curScore.startCmd();
        for (var staff = r.first; staff <= r.last; staff++) {
            var inst = presetForStaff(staff);
            if (add && !inst) {
                unknown++;
                continue;
            }
            staves++;
            for (var voice = 0; voice < 4; voice++) {
                var cursor = curScore.newCursor();
                cursor.staffIdx = staff;
                cursor.voice = voice;
                cursor.rewindToTick(r.startTick);
                var last = "";
                while (cursor.segment && (r.endTick < 0 || cursor.tick < r.endTick)) {
                    removeOurs(cursor.segment, cursor.track);
                    var el = cursor.element;
                    if (el && el.type === Element.CHORD)
                        removeOurLyrics(el);
                    if (add && el && el.type === Element.CHORD) {
                        var low = el.notes[0];
                        for (var i = 1; i < el.notes.length; i++)
                            if (el.notes[i].pitch < low.pitch)
                                low = el.notes[i];
                        var f = Brass.fingering(inst, low.pitch, fourValves);
                        if (f === "") {
                            skipped++;
                        } else if (low.tieBack) {
                            // tied continuation: no new fingering
                        } else if (hideRepeatBox.checked && f === last) {
                            // same as previous note
                        } else if (lyricsBox.checked) {
                            addAsLyrics(cursor, inst, f);
                            done++;
                        } else {
                            var t = newElement(Element.STAFF_TEXT);
                            t.text = Brass.formatText(inst, f, stackBox.checked);
                            t.placement = aboveButton.checked ? Placement.ABOVE : Placement.BELOW;
                            t.fontSize = sizeBox.value;
                            cursor.add(t);
                            done++;
                        }
                        if (f !== "")
                            last = f;
                    }
                    cursor.next();
                }
            }
        }
        curScore.endCmd();

        if (add) {
            status = qsTr("%1 fingerings added").arg(done)
                + (skipped ? qsTr(", %1 notes out of range").arg(skipped) : "")
                + (unknown ? qsTr(", %1 staves skipped (unknown instrument)").arg(unknown) : "");
        } else {
            status = qsTr("%1 fingerings removed").arg(removedCount);
        }
    }

    ColumnLayout {
        id: panel
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 8

        Label { text: qsTr("Part") }
        ComboBox {
            id: partBox
            Layout.fillWidth: true
            model: partModel
            textRole: "text"
            onPressedChanged: if (pressed) refreshParts()
        }

        Label { text: qsTr("Instrument") }
        ComboBox {
            id: instrumentBox
            Layout.fillWidth: true
            model: instrumentModel
            textRole: "text"
        }

        Label {
            text: qsTr("Valves")
            visible: valveBox.visible
        }
        ComboBox {
            id: valveBox
            Layout.fillWidth: true
            model: [qsTr("3 valves"), qsTr("4 valves")]
            // Only euphonium and tuba presets have a 4th valve.
            visible: {
                var id = instrumentModel[instrumentBox.currentIndex].id;
                if (id === "auto")
                    return true;
                var p = Brass.instrumentById(id);
                return p && p.fourthValve;
            }
        }

        CheckBox {
            id: lyricsBox
            text: qsTr("Insert as lyrics (aligned under notes)")
        }

        Label { text: qsTr("Position"); enabled: !lyricsBox.checked }
        RowLayout {
            enabled: !lyricsBox.checked
            RadioButton { id: belowButton; text: qsTr("Below"); checked: true }
            RadioButton { id: aboveButton; text: qsTr("Above") }
        }

        RowLayout {
            Label { text: qsTr("Font size") }
            SpinBox { id: sizeBox; from: 4; to: 24; value: 9 }
        }

        CheckBox {
            id: stackBox
            text: qsTr("Stack valves vertically")
            checked: true
        }
        CheckBox { id: hideRepeatBox; text: qsTr("Don't repeat unchanged fingering"); checked: true }

        RowLayout {
            Layout.fillWidth: true
            Button {
                Layout.fillWidth: true
                text: qsTr("Apply")
                onClicked: process(true)
            }
            Button {
                Layout.fillWidth: true
                text: qsTr("Remove")
                onClicked: process(false)
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.italic: true
            text: status !== "" ? status : qsTr("Select a range to limit the change; otherwise the whole score is used.")
        }
    }
}
