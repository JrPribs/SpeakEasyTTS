# Implementation Notes

> Verified in the local SwiftPM package.

## Changed Files

- `SpeakEasyTTS/Sources/Core/ReadbackPipeline.swift`
- [Roadmap](ROADMAP.md)

### Tasks

- [x] Add deterministic normalizer
- [ ] Wire summaries later

1. Run `swift test`
2. Inspect Sources/Core/AppState.swift

| Area | Status |
| --- | --- |
| TTS | Passing |
| Dictation | Unchanged |

```swift
let value = "not spoken"
print(value)
```

Done.
