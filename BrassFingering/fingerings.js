.pragma library

// Brass fingering / slide position logic. Pure functions, no MuseScore API.
//
// All pitches are CONCERT (sounding) MIDI pitches, as returned by Note.pitch.
// Each instrument is described by the fundamental of its open harmonic series;
// a note is played on the partial that needs the least valve depression
// (or the shortest slide extension).

// Semitones above the fundamental for harmonic partials 1..16.
// Partials 7, 11, 13 and 14 are badly out of tune and never used.
var PARTIAL_OFFSET = {
    1: 0, 2: 12, 3: 19, 4: 24, 5: 28, 6: 31,
    8: 36, 9: 38, 10: 40, 12: 43, 15: 47, 16: 48
};

// Valve combination by total depression in semitones (valve 1 = 2, 2 = 1, 3 = 3, 4 = 5).
var VALVES_3 = ["0", "2", "1", "12", "23", "13", "123"];
var VALVES_4 = ["0", "2", "1", "12", "23", "4", "24", "14", "234", "134", "124", "1234"];

var INSTRUMENTS = [
    { id: "bb-trumpet", name: "Trumpet / Cornet / Flugelhorn (Bb)", kind: "valves", fundamental: 46, minPartial: 2, fourthValve: false },
    { id: "c-trumpet",  name: "Trumpet (C)",                        kind: "valves", fundamental: 48, minPartial: 2, fourthValve: false },
    { id: "eb-trumpet", name: "Trumpet (Eb)",                       kind: "valves", fundamental: 51, minPartial: 2, fourthValve: false },
    { id: "f-horn",     name: "French horn (F)",                    kind: "valves", fundamental: 29, minPartial: 2, fourthValve: false },
    { id: "euphonium",  name: "Euphonium / Baritone (Bb)",          kind: "valves", fundamental: 34, minPartial: 1, fourthValve: true },
    { id: "tuba-bb",    name: "Tuba (BBb)",                         kind: "valves", fundamental: 22, minPartial: 1, fourthValve: true },
    { id: "tuba-eb",    name: "Tuba (Eb)",                          kind: "valves", fundamental: 27, minPartial: 1, fourthValve: true },
    { id: "trombone",   name: "Trombone (Bb tenor)",                kind: "slide",  fundamental: 34, minPartial: 1, fourthValve: false }
];

function instrumentById(id) {
    for (var i = 0; i < INSTRUMENTS.length; i++)
        if (INSTRUMENTS[i].id === id)
            return INSTRUMENTS[i];
    return null;
}

// Map a MuseScore instrumentId (e.g. "brass.trumpet", "trombone", "bb-trumpet") to a preset id.
function detectInstrument(instrumentId) {
    var s = ("" + instrumentId).toLowerCase();
    if (s.indexOf("trombone") >= 0) return "trombone";
    if (s.indexOf("euphonium") >= 0 || s.indexOf("baritone") >= 0) return "euphonium";
    if (s.indexOf("sousaphone") >= 0) return "tuba-bb";
    if (s.indexOf("tuba") >= 0) return (s.indexOf("eb") >= 0) ? "tuba-eb" : "tuba-bb";
    if (s.indexOf("horn") >= 0 && s.indexOf("flugel") < 0 && s.indexOf("flügel") < 0
            && s.indexOf("english") < 0 && s.indexOf("alto") < 0 && s.indexOf("post") < 0) return "f-horn";
    if (s.indexOf("trumpet") >= 0 || s.indexOf("cornet") >= 0 || s.indexOf("flugel") >= 0) {
        if (s.indexOf("eb-") >= 0 || s.indexOf("eb ") >= 0 || s.indexOf("e-flat") >= 0) return "eb-trumpet";
        if (s.indexOf("c-trumpet") >= 0 || s.indexOf("c trumpet") >= 0) return "c-trumpet";
        return "bb-trumpet";
    }
    return null;
}

// Smallest extension (semitones down from the open partial) over the usable partials,
// or -1 when the pitch is out of range (limit = maximum depression available).
function depression(inst, pitch, limit) {
    var best = -1;
    for (var n in PARTIAL_OFFSET) {
        if (+n < inst.minPartial)
            continue;
        var d = inst.fundamental + PARTIAL_OFFSET[n] - pitch;
        if (d >= 0 && d <= limit && (best < 0 || d < best))
            best = d;
    }
    return best;
}

// Fingering for a concert pitch: valve digits such as "12", "0", or a slide position "1".."7".
// Returns "" when the note is out of range for the instrument.
function fingering(inst, pitch, fourValves) {
    if (inst.kind === "slide") {
        var p = depression(inst, pitch, 6);
        return p < 0 ? "" : "" + (p + 1);
    }
    var table = (inst.fourthValve && fourValves) ? VALVES_4 : VALVES_3;
    var d = depression(inst, pitch, table.length - 1);
    return d < 0 ? "" : table[d];
}

// Text shown in the score. stack = one digit per line (valve instruments).
function formatText(inst, fing, stack) {
    if (!fing)
        return "";
    if (inst.kind === "valves")
        return fing.split("").join(stack ? "\n" : "/");
    return fing;
}

// True for text this plugin could have produced (used to find and remove old annotations).
// MuseScore 4 may return rich text (<font .../> tags, entities, <br>), so normalise first.
function plainText(text) {
    return ("" + text)
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<[^>]*>/g, "")
        .replace(/&#xa;|&#10;/gi, "\n")
        .replace(/&amp;/g, "&")
        .replace(/\r/g, "")
        .replace(/\s+$/, "")
        .replace(/^\s+/, "");
}

function isOurText(text) {
    var t = plainText(text);
    return /^[0-7]([\n\/][0-4])*$/.test(t) || /^[0-4]{1,4}$/.test(t);
}
