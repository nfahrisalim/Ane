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

What you hear is your score. Drums always play; magenta keeps the bass, cyan the chords,
amber the lead. Miss a colour and its stem ducks to 15%; hit it again and it fades back.

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
├─ Rhythm/    AngleMath, Layout, Chart, ChartGenerator, BeatJudge, ScoreKeeper, GameSession
├─ Audio/     AudioEngine (also the BeatClock), MusicLayering, ProceduralTrack
├─ Game/      GameScene and its nodes — rendering and input only
├─ Feel/      Haptics
├─ UI/        SwiftUI shell, HUD, title and results
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

There is no music file in the repo. `ProceduralTrack` synthesises four stems — an eight-bar
120 BPM loop in A minor — into PCM buffers played by real `AVAudioPlayerNode`s.

This is deliberate, and it is a deviation from the build spec, which suggested
`AVAudioSourceNode` for the placeholder. That node has no `playerTime(forNodeTime:)`, so it
would have required a second clock implementation that the tested one could not cover.
Synthesised buffers keep **exactly one** clock path whether the stems are generated or
loaded from disk.

To swap in real music, drop `drums.m4a`, `bass.m4a`, `synth.m4a` and `lead.m4a` into the
app target. `AudioEngine` detects them and uses them with no code change. A single mixed
`song.m4a` also works and switches the game to `FilterLayering`, where a low-pass opens up
with the combo instead.

## Known limits

- The `conf`/`iou`-style tuning of this game — the 0.080 s and 0.150 s judgment windows —
  are the spec's values and have **not** been calibrated against real players on real
  hardware. Validate before treating a Perfect as meaningful.
- There is no latency calibration UI. `AVAudioSession.outputLatency` is trusted as-is,
  which is right for wired output and the built-in speaker but understates Bluetooth.
- Accuracy is the share of attainable base points, so a Good counts as one third of a
  Perfect. That is a choice, not a standard.

See `CREDITS.md` before submitting.
