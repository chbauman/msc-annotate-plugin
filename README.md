# Brass Fingering for MuseScore 4

A dock-panel plugin that annotates notes with valve fingerings (trumpet, horn, euphonium, tuba) or trombone slide positions.

## Install

Copy the `BrassFingering` folder to `Documents\MuseScore4\Plugins\`, restart MuseScore, then enable **Brass Fingering** under *Plugins → Manage plugins*.

## Usage

Open the panel, choose options, click **Apply**. **Remove** deletes fingerings the plugin added. Applying again replaces earlier ones.

- **Part**: process one part, or all parts / the current range selection (a range also limits the measures).
- **Instrument**: auto-detected from the staff, or pick one: Bb/C/Eb trumpet, F horn, euphonium, tuba (BBb/Eb), Bb tenor trombone.
- **Valves**: 3 or 4 valves for euphonium and tuba.
- **Insert as lyrics**: digits sit directly under the notes. Otherwise they are staff text, placed **above** or **below** the staff.
- **Stack valves vertically**: `1`/`3` on separate lines, or on one line as `1/3`.
- **Don't repeat unchanged fingering** (default on): skips notes whose fingering equals the previous note's, and tied notes.
- **Font size**.

Fingerings are computed from the instrument's harmonic series using concert pitch, so transposing instruments work without setup. Chords use their lowest note. Notes outside the instrument's range are skipped and counted in the status line.

## Notes

- Remove and Apply treat any staff text or lyric that looks like a fingering (digits `0`–`7`, optionally joined by `/`) as theirs, so avoid using lyrics on the same staff in lyrics mode.
- Trombone: first-choice positions only, no F-attachment or alternates.
- Horn: single F only.

GPL-3.0; see `LICENSE`.
