#!/usr/bin/env swift
import AVFoundation

// Checks stem files before they go into the app target.
//
//   swift Tools/check-stems.swift drums.m4a bass.m4a synth.m4a lead.m4a
//
// Prism Groove schedules every stem on one shared start time and never resynchronises
// them, so the stems have to be the same song cut four ways: identical length, identical
// sample rate, downbeat on sample 0. This catches that on the desk rather than on a phone.

let bpm = 120.0
let beat = 60.0 / bpm

let paths = Array(CommandLine.arguments.dropFirst())
guard !paths.isEmpty else {
    print("usage: swift Tools/check-stems.swift <file> [file ...]")
    exit(2)
}

struct Stem {
    let name: String
    let sampleRate: Double
    let channels: UInt32
    let frames: Int64
    var duration: Double { sampleRate > 0 ? Double(frames) / sampleRate : 0 }
    var beats: Double { duration / beat }
}

var stems: [Stem] = []
var failed = false

for path in paths {
    let url = URL(fileURLWithPath: path)
    do {
        let file = try AVAudioFile(forReading: url)
        stems.append(
            Stem(
                name: url.lastPathComponent,
                sampleRate: file.processingFormat.sampleRate,
                channels: file.processingFormat.channelCount,
                frames: file.length
            )
        )
    } catch {
        print("✗ \(url.lastPathComponent): cannot read — \(error.localizedDescription)")
        failed = true
    }
}

guard let reference = stems.first else { exit(1) }

print("")
print("file                 rate     ch   duration    beats@120   vs first")
print(String(repeating: "-", count: 68))

for stem in stems {
    let delta = stem.duration - reference.duration
    let beatsOff = abs(stem.beats.rounded() - stem.beats)

    var flags: [String] = []
    if stem.sampleRate != reference.sampleRate { flags.append("RATE MISMATCH") }
    if abs(delta) > 0.05 { flags.append("LENGTH MISMATCH") }
    if beatsOff > 0.02 { flags.append("NOT A WHOLE NUMBER OF BEATS") }
    if !flags.isEmpty { failed = true }

    let name = stem.name.padding(toLength: 20, withPad: " ", startingAt: 0)
    let rate = String(format: "%7.0f", stem.sampleRate)
    let dur = String(format: "%8.3fs", stem.duration)
    let beats = String(format: "%9.2f", stem.beats)
    let vs = String(format: "%+8.3fs", delta)
    let mark = flags.isEmpty ? "✓" : "✗"
    print("\(mark) \(name) \(rate)  \(stem.channels)   \(dur)  \(beats)   \(vs)  \(flags.joined(separator: ", "))")
}

print("")
if failed {
    print("Not ready. Stems must share a sample rate and a length, with the downbeat on")
    print("sample 0 and no fades. Trim them in a DAW and run this again.")
    exit(1)
}

print("All stems agree. Drop them into the Ane target and AudioEngine will pick them up.")
if abs(reference.duration - 120.0) > 0.5 {
    print("Note: the song is \(String(format: "%.1f", reference.duration))s, not 120s.")
    print("Set ChartGenerator.Config.totalBeats to \(Int((reference.duration / beat).rounded())).")
}
