# Universal diagnostics

Unskippable Cutscene Diagnostics is available in every chapter and the lobby. Auto TNT Diagnostics is also available under Farming > Tools. Both are optional and off by default.

Enable Auto TNT Diagnostics before reproducing a delay, then use Export Auto TNT Diagnostics. Each module writes its own BeyyHub/<module>_auto_tnt_diagnostics.json and only an explicit export copies JSON to the clipboard. Capture is bounded to 256 events, periodically saved, and cleaned up when the hub unloads.

TNT capture includes lighting requests/replies, acknowledgement and required-lighting timing, throw requests, target search/refresh timing, and post-cooldown blockers. CooldownBlockStarted/Ongoing/Ended and Current.Feature.CooldownBlocks report observed durations and reason changes. Chapters 1–3 sample blockers every 0.5 seconds; Chapter 4 samples the worker loop. Durations start at the first observed block after predicted readiness; no historical duration is inferred. The lobby has no hay-target search and only predicts readiness after observing a server lighting/denial reply while capture is enabled. These observations do not change gameplay gates or request cadence.

Chapter 1 preserves AFK orbit targeting and checks; Chapter 2 preserves its cinematic/input exception; Chapter 3 preserves boss-tool priority. Candle, key, puzzle, UFO and boss diagnostics remain specific to their encounters. A successful FireServer call does not prove server acceptance or a hit.

Run adapter tests: node tests/universal_tnt_diagnostics.cjs /path/to/luau
Run Chapter 4 gate/worker tests: node tests/chapter4_tnt.cjs /path/to/luau
