# Prism Groove

A rhythm game for iPhone, built for **Very Disco Game Jam 2026.3**.

> Rotate a prism to bend light into colour. Each colour is a layer of the song — play well
> and the full track comes alive; miss, and you are left with the drums.

## The loop

A prism sits at the centre of the screen and emits three beams — magenta, cyan and amber —
locked 120° apart. Four targets sit on an outer orbit, 90° apart. On every beat the chart
lights one target, and you must have the **matching colour** beam pointing at it **on the
beat**.

Because 120 and 90 do not divide into each other, **no single rotation can ever satisfy
two targets at once** — the closest two demands are 30° apart, against a 12° tolerance. You
cannot park the prism. Every note is a real movement. (`LayoutTests` sweeps a full turn to
prove it.)

What you hear is your score. On the synthesised demo track drums always play; magenta
keeps the bass, cyan the chords, amber the lead. Miss a colour and its stem ducks to 15%;
hit it again and it fades back. The bundled disco tracks are single mixes, so there a miss
muffles the whole song behind a low-pass and six clean hits open it back up.

## Songs

Seven songs, listed easiest first on the song-select screen, each with a preview of its
chorus:

| Song | Artist | BPM | Difficulty |
|---|---|---|---|
| Retro Orbit | Mazarelli | 115 | Easy |
| Hyperspace Finish | Mazarelli | 115 | Easy |
| Galaxy Launch | Mazarelli | 115 | Normal |
| Starlight Arpeggio | Mazarelli | 115 | Normal |
| Nebula Disco | Mazarelli | 115 | Normal |
| Solstice Party | gbproductions | 129 | Hard |
| Prism Groove (demo) | synthesised | 120 | Hard |

Every chart is still generated from a fixed per-song seed, but it now follows the track:
each four-bar phrase is `sparse` (a note a bar), `half`, `full` or `rest`, read off the
song's energy. Tempo and beat-0 offset were measured from the audio to the millisecond.
All of it lives in `Ane/Rhythm/SongCatalog.swift`, and `SongCatalogTests` checks that
every chart ends inside its file.

## Running it

```bash
open Ane.xcodeproj      # scheme: Ane, iPhone, portrait
swift test              # 57 tests, no simulator and no audio hardware needed
```

Requires iOS 17+.

## Architecture

The gameplay rules are pure Swift with no SpriteKit or UIKit imports, which is what makes
them testable on the host machine:

```
Ane/
├─ Rhythm/    AngleMath, Layout, Chart, ChartGenerator, BeatJudge, ScoreKeeper, GameSession,
│             Song, SongCatalog
├─ Audio/     AudioEngine (also the BeatClock), MusicLayering, ProceduralTrack,
│             TrackPreviewPlayer, Tracks/*.caf
├─ Game/      GameScene and its nodes — rendering and input only
├─ Feel/      Haptics
├─ UI/        SwiftUI shell: title, song select, HUD, results, credits
└─ App/       Entry point, AppState, GameController
```

`Package.swift` at the repo root points a `RhythmKit` target at `Ane/Rhythm`, so `swift
test` and the iOS target compile **the same files**. There is no second copy of the rules.

**`GameScene` never judges and never scores.** It reports the prism angle it is displaying;
`GameSession` decides what that was worth and emits events. Rendering, haptics, the mixer
and the HUD all react to those events, which is why a full two-minute run can be simulated
in a unit test with no audio at all.

### Timing

Song time is read from the drum player's own render position:

```swift
let playerTime = drumNode.playerTime(forNodeTime: nodeTime)
let songTime = Double(playerTime.sampleTime) / playerTime.sampleRate - outputLatency
```

`Timer`, `DispatchQueue.asyncAfter` and accumulated frame deltas were all rejected: each
drifts, and over two minutes the drift is audible long before the outro. SpriteKit's
`update(_:)` is only the tick that reads this clock, never the clock itself. All stems start
on one shared `AVAudioTime` 0.2 s in the future, because a few milliseconds of phase error
between stems reads as a flam rather than a chord.

`outputLatency` is subtracted because what the player *hears* lags what the engine has
*rendered*, and judgment has to match the ear.

## Music

Each `Song` names its audio: `.mixed(resource:)` for one bundled file, `.stems(prefix:)`
for four aligned files named `<prefix>-drums/-bass/-synth/-lead`, or `.procedural` for the
synthesised loop. Whatever the source, playback goes through real `AVAudioPlayerNode`s, so
there is **exactly one** clock path.

The shipped tracks are ALAC in `.caf` (lossless, about 16 MB each). Not AAC: an AAC
encoder adds priming samples at the start, which would move beat 0 by tens of
milliseconds against an 80 ms Perfect window.

If a song's file is missing from the bundle, `GameController` swaps in the procedural
song *and its chart* before anything is judged, rather than scoring a 115 BPM chart
against a 120 BPM fallback.

The stems path keeps its safety net: stems are scheduled on one shared start time and are
never resynchronised, so they have to be the same song cut four ways. Check them with
`swift Tools/check-stems.swift a.m4a b.m4a c.m4a d.m4a`; `AudioEngine.validate(_:)` also
logs a mismatch at launch.

## Known limits

- The `conf`/`iou`-style tuning of this game — the 0.080 s and 0.150 s judgment windows —
  are the spec's values and have **not** been calibrated against real players on real
  hardware. Validate before treating a Perfect as meaningful.
- There is no latency calibration UI. `AVAudioSession.outputLatency` is trusted as-is,
  which is right for wired output and the built-in speaker but understates Bluetooth.
- Accuracy is the share of attainable base points, so a Good counts as one third of a
  Perfect. That is a choice, not a standard.

See `CREDITS.md` before submitting.
