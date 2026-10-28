# Chapter 4 vine snare float test

A standalone experiment using the hub's embedded native menu. It does not load or alter the main hub, send combat/escape remotes, or merge changes into chapter4.lua.

## Run

Execute `experiments/chapter4_vine_snare_float_test.lua` in Chapter 4. The native menu opens immediately. F8 shows/hides this separate menu; the main hub's RightControl binding is unchanged.

Enable **Auto Float Before Vine Snare**. The default settings are:

- Height: **7.5 studs** above the root's position when the float starts (range 5–10).
- Lead: **0.25 seconds** before the targeted Vines payload's server-time trigger (range 0.05–0.6).
- Hold: **0.8 seconds after the trigger** (range 0.2–2).

The test targets only the local user's Vines entry, so the misleading PumpkinPatch attack name does not control it. It captures the current position at lift time, briefly holds that elevated position without anchoring or changing collision, then returns to the captured starting transform while safe. It skips expired warnings. Cancel/Finish messages clear the matching attempt. Cutscenes, input locks, holds, stun, ragdoll, anchored/dead characters, respawn, encounter changes and unload stop or prevent the test. If the game has taken control or moved the character far away, the script releases its position override rather than restoring an old position.

**Test Float Now** runs the same short float manually, even with Auto Float off. **Release Float Now** cancels it. **Unload Standalone Test** disconnects the test and destroys only its own menu. Re-executing the standalone cleans up its previous instance using a separate singleton; it does not replace the hub's cleanup function.

## Diagnostics

Use **Export Float Diagnostics** to save `workspace/BeyyHub/chapter4_snare_float_test.json` (and copy JSON if supported). Attempts also save when they finish or a snare result arrives. The bounded 2048-event log includes the targeted warning, server trigger time, actual lift lead, starting/target positions, float samples, relevant feedback, combat flags and a SnaredDuringTest event if a snare arrives while an attempt is pending or floating. Any later Snared feedback is also recorded, so absence of SnaredDuringTest alone is not proof of avoidance.

The main Boss Attack Recorder can run alongside this test for a wider trace. Compare the same attack ID's warning, float interval, grounded/vertical position and Snared outcome.

## Validation and limits

Luau compilation passed. Source-extracted mocked controller tests passed for default-off behavior, local-user targeting, server timing, current-position lift, hold/return, cancel, Snared handoff, disable, blocked/late cases, height bounds, manual testing, ragdoll, external relocation, respawn and unload. Native UI is embedded from the current Chapter 4 module with separate GUI/render-binding names and F8; no remote UI code is fetched.

Not live-tested. Client-side altitude may not prevent server-selected snares. This PR creates an experiment to measure that behavior, not a proven dodge. Main chapter scripts and loader are unchanged.
