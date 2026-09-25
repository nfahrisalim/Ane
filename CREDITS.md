# Credits

## Team

- Muhamad Ega Nugraha
- Muh. Naufal Fahri Salim

> Add the remaining team members before submitting. The itch.io page requires every
> contributor to be named, and the in-game list lives in `Ane/UI/CreditsView.swift`.

## Music

| Track | Artist | Source | Terms |
|---|---|---|---|
| Galaxy Launch, Nebula Disco, Retro Orbit, Starlight Arpeggio, Hyperspace Finish | Mazarelli — *Cosmic Synth Disco* pack (tagged AI-assisted by the author) | https://mazarelli.itch.io/cosmic-synth-disco-game-music-pack | "Free for non-commercial and personal projects. If you are developing a commercial game, please support the creator by leaving a donation." |
| Solstice Party | gbproductions | https://gbproductions.itch.io/solstice-party-free-jrpg-disco-funk-music-loop | Creative Commons, commercial and non-commercial use allowed; "just make sure to credit me" |
| Prism Groove (demo track) | This team | Synthesised at runtime by `Ane/Audio/ProceduralTrack.swift` | Original work |

The bundled files in `Ane/Audio/Tracks/` are lossless ALAC re-encodes of the downloaded
WAVs (resampled to 44.1 kHz, otherwise unaltered). The original downloads are kept in
`MusicSource/`, which is outside the app target and git-ignored.

**Before submitting:** paste the Music table into the itch.io page description — the
jam rules ask for credits there. If the game is ever sold, the Mazarelli tracks need the
author's blessing (a donation, per the page) first.

## Other assets

| Asset | Source | Licence |
|---|---|---|
| App icon | Rendered with CoreGraphics from the in-game emblem | Original work, this team |
| Prism, beams, targets, particles, song artwork | Drawn procedurally in SpriteKit / SwiftUI | Original work, this team |
| Typeface | SF Pro Rounded (system font) | Apple system font, used under the standard Apple platform terms; not redistributed |
| Icons | SF Symbols | Apple SF Symbols, used under the SF Symbols licence; not redistributed |

## Adding a song

1. Convert to ALAC in CAF so beat 0 does not move (AAC adds encoder priming):
   `ffmpeg -i in.wav -ar 44100 -c:a alac -sample_fmt s16p Ane/Audio/Tracks/<id>.caf`
2. Measure its BPM and beat-0 offset, and read its sections off the energy per four bars.
3. Add a `Song` to `Ane/Rhythm/SongCatalog.swift` and its file length to
   `SongCatalogTests`.
4. Add a row to the Music table above and to `CreditsView`.
