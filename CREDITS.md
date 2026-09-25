# Credits

## Team

- Muhamad Ega Nugraha
- Muh. Naufal Fahri Salim

> Add the remaining team members before submitting. The itch.io page requires every
> contributor to be named.

## Assets

**This build ships no third-party assets.** Everything is generated at runtime or drawn
in code, which is why this list is short:

| Asset | Source | Licence |
|---|---|---|
| Music (drums, bass, synth, lead) | Synthesised at runtime by `Ane/Audio/ProceduralTrack.swift` | Original work, this team |
| App icon | Rendered with CoreGraphics from the in-game emblem | Original work, this team |
| Prism, beams, targets, particles | Drawn procedurally in SpriteKit; the spark texture is generated at launch | Original work, this team |
| Typeface | SF Pro Rounded (system font) | Apple system font, used under the standard Apple platform terms; not redistributed |
| Icons | SF Symbols (`play.fill`, `pause.fill`, `arrow.clockwise`) | Apple SF Symbols, used under the SF Symbols licence; not redistributed |

## If you replace the music

Drop `drums.m4a`, `bass.m4a`, `synth.m4a` and `lead.m4a` into the app target and
`AudioEngine` picks them up automatically, with no code change. **Add a row to the table
above for each file** with its source and licence before the build is submitted.

The same applies to a single mixed `song.m4a`, which switches the game to the filter
fallback.
