# BeyyHub native integrated hub

A native Roblox menu for the lobby and Chapters 1–4. Right Ctrl opens or closes it; drag the title bar with mouse or touch. The menu starts minimized and uses instant controls.

Run the current main-branch loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sceneton/script/main/loader.lua?refresh=" .. tostring(os.time()) .. "-" .. tostring(math.random(1,1000000000))))()
```

The loader selects only the current place's module, checks the main-branch revision, validates immutable revision caches and queues itself on teleport when the executor supports it. Each chapter embeds the native UI; changes to native_ui.lua must also be incorporated into the modules.

## Files

- loader.lua: place routing, update checks, cache validation and teleport reload.
- lobby.lua: config controls and automatic Chapter 1 creation, prioritizing the two portals nearest lobby spawn.
- chapter1.lua: automatic win farming, orbit routes, tool usage, upgrades, needle pickup and replay handling.
- chapter2.lua: puzzle automation, key pickup, tools and upgrades.
- chapter3.lua: tools, collection, upgrades and chapter controls.
- chapter4.lua: universal controls for place 102537610748607 plus Farming → Candles → Auto Collect & Light Candles. This saved toggle defaults off and replaces Chapter 4's needle controls. It waits until all four candles are exposed (including candles already collected), then processes them consecutively: confirming pickup, placing in free holders, and uses server-confirmed fast lighting with normal match assistance as fallback. Hay tools/vacuum pause during candle actions; the normal client close handler restores movement and cursor after lighting. Farming → Tools also includes a saved **Auto Boss Weak-Point Pitchfork** toggle (default off). It resolves the Pumpkin Golem's nine configured weak-point regions from animated bone pairs and aims at their facing surface within pitchfork reach. It follows the attack cooldown and pauses for menus, candle actions, cutscenes, pumpkin snare/grab/pull actions and combat input locks; the pitchfork does not need to be equipped. Ordinary hay pitchfork requests yield while this boss mode is engaged.
- native_ui.lua: native menu implementation embedded in all five modules.

## Chapter 4 candle sprint

The existing saved **Auto Collect & Light Candles** toggle now adapts the candle sprint from [beyytu/needlehub](https://github.com/beyytu/needlehub/blob/807c07f2c36d1e43fa41c8b0429778a44691815a/chapter4.lua). It still waits for all four exposed/collected candles and confirms pickup, reservation and lighting through replicated server state. Approaches use shorter settling waits, and confirmed lighting advances immediately to the next candle.

After two candles are lit, the controller can attempt the remaining holders during the skeleton cutscene. It permits one local root-unanchor window of at most 5.5 seconds per batch; an unconfirmed placement waits for the cutscene to end. Hidden-GUI lighting requests are limited to one per holder every 1.5 seconds. Opening the menu, disabling automation, input blocking or unloading releases held input and restores an anchor owned by the controller. Existing camera and hay-tool priority gates remain active during candle actions. Finished or delayed match UI is cleaned up without closing an unlit local reservation.

The port retains the target repository's teammate-ownership checks and opt-in candle diagnostics. It does not import the source's full-console capture or automatic clipboard writes. The toggle continues to default off.

Local regression command (Node.js plus the official Luau CLI):

```sh
node tests/chapter4_candles.cjs /path/to/luau
```

The harness extracts and executes the production candle controller and its cutscene gate against mocks. Live Roblox behavior has not been tested for this port.

## Chapter 4 Auto TNT diagnostics

In **Farming → Tools**, enable **Auto TNT Diagnostics**, leave Auto Use TNT running for a few throws, then click **Export Auto TNT Diagnostics**. The export writes `BeyyHub/chapter4_auto_tnt_diagnostics.json` and copies the JSON to the clipboard when supported. Capture defaults off; enabled capture also saves dirty reports at five-second intervals. It uses the existing 256-event ring and reports overwritten events. It does not collect the full client console or send reports to a webhook.

`AttemptFinished` separates initial `SearchSeconds`, the complete `LightCallSeconds`, and post-light `RefreshSeconds`. `ReadyOverdueSeconds` measures time since the script's predicted ready deadline, including scheduler delays or time spent blocked. `TotalAfterPredictedReadySeconds` covers the remaining attempt. These are client-clock measurements, not measurements of the game's displayed cooldown.

Gate events separately report acknowledgement latency, configured lighting duration, actual time since acknowledgement, denials/retry deadlines, missing acknowledgements, local send errors, and expired/rejected throws. Current state includes the raw cooldown attribute, its effective fallback, configured light time, blockers and the last captured attempt. A sent throw means the local request succeeded; it does not prove server acceptance or a hit. Repeated no-target failures are sampled once per second to preserve the useful history.

The instrumentation keeps the existing target-selection algorithm, cooldown prediction, required lighting wait and normal polling intervals. TNT worker errors are recorded and retried on the existing polling loop. Run the source-extracted regressions with `node tests/chapter4_tnt.cjs /path/to/luau`.

## Settings and recovery

Existing WindUI/BeyyHub/config/*.json configs remain compatible. Config controls and farm settings are under Overview & Settings. Lobby Tools follows that tab. Anti-AFK defaults on.

Across the chapters, enabled Auto Vacuum Power upgrades take priority until the power track is maxed. The automation saves cash for the next power level before other cash upgrades or automatic tool purchases. Once power is maxed or disabled, other enabled upgrades resume; cooling retains its existing 75% savings threshold.

Chapter 1's sequence makes one full lap at each of nine heights: base-lower, base, base-transition, lower-middle, middle-transition, upper-middle, upper-transition, peak and inner-peak, then repeats from base-lower. The added lower route is two studs below the original base. Character inset and camera adjustments are preserved. Orbit progression waits for the character to follow its scheduled path. Route heights and the pile center use the chapter's configured geometry, so partially loaded or depleted rendered hay cannot raise the bottom routes.

The five-minute round failsafe is exclusive to Chapter 1 and defaults on, independently of Auto Farm Wins. It uses a verified upward HH:MM:SS timer, or elapsed time since intro completion if unavailable. Above five minutes it returns to lobby 77108422251420, reloads the script and resumes automatic Chapter 1 creation. Chapters 2–4 and the lobby do not run this failsafe. Automatic recovery requires executor teleport-queue support; failed requests retry with a cooldown.

No-ID Chapter 1 needle pickup selects hand slot 1 and moves closer before physical clicks. Numeric-ID pickup retains the local HoveredHayId override. Diagnostic success, failure and retry traces are saved under BeyyHub/ when executor filesystem support is available.

## Chapter 3 / Ranch

Chapter 3 has Auto Grab & Attach UFO Parts (default OFF), Auto Solve Ranch Puzzles (default ON), a one-shot instant-completion diagnostic and an object-inspection button. Both toggles use the existing saved config system. The GUI solvers match wire colors, pull vent strands and align the laser using the replicated CenterY attribute. UFO progress is confirmed through CarryingUfoPart/HeldBy and Returned/PartsReturned, rather than remote delivery alone.

These options are adapted from [BeyyTU/needlehub chapter3.lua](https://github.com/BeyyTU/needlehub/blob/main/chapter3.lua) (source blob 1e4025b9bd9d261effa6b45334038d532c08c4ed; the blob hash identifies the imported content). Farming and vacuum input yield while Ranch input is active. Opening the menu, disabling the relevant toggle or unloading cancels input; held mouse buttons are released. The instant-completion button sends one experimental PuzzleDone() request; GUI closure alone does not prove server completion.

Validation covers compilation and mocked matching-wire, laser-coordinate, vent-direction, input error/release, cancellation, busy gating and UFO candidate/ownership checks. Live Chapter 3 gameplay still needs verification.

## Chapter 3 boss workflow

The Chapter 3 Boss tab adds a saved Auto Boss Fight master switch (default OFF). Body Hits Between Weak Points, Auto Grab Escape and Auto Key Pickup & Finish default ON beneath it. Enable the master and close the menu to run the controller. It does not reposition the player during combat: stay within the boss pitchfork range. The controller sends cooldown-paced rays from the real character head toward the current animated weak-point bone, or chest/pelvis between windows. It works with the vacuum equipped; existing Auto Use Vacuum remains a separate control.

Grab weak points take priority, with server-timed prompt responses as a fallback when held. After defeat, the controller approaches TakeKeyPrompt, waits for HasCarKey, teleports to (-658.85, 3.76, 285.29), and walks one lap on a three-stud-radius route. Ending monitors observe TruckFinish.Cutscene/Blocked/Skip, NeedleRoundCompleted and completion/timer attributes without firing ending remotes. Finishing is latched per boss encounter so it does not repeat.

Boss Diagnostics is optional (default OFF). Live boss/vacuum/ending status and Export Boss Diagnostics are available in the tab. Automatic diagnostics save to BeyyHub/chapter3_boss_integrated.json when enabled. The master/menu gates apply to boss attacks and movement; unload releases held input, stops walking and disconnects listeners. Shared hay tools and UFO collection yield during the enabled boss workflow while vacuum automation remains available.

The standalone workflow was verified in user-supplied live captures, including weak/body hits while holding vacuum, Perfect grab escape, confirmed key pickup, walking and round completion. The integrated module compiles and passes mocked combat, menu/master gates, finishing latch, movement, diagnostics and cleanup checks, plus UFO/puzzle regressions; the combined native-hub workflow still needs a live check.

## Chapter 3 boss TNT

With Auto Boss Fight and Auto Use TNT enabled, TNT switches from the existing hay routine to the boss controller. It lights only when Head is the dazed weak point, BossVulnerable is true, and the exported boss fuse estimate fits the remaining BossStunEndsAt window. It waits for the server's lit acknowledgement and the replicated lighting delay, then refreshes the animated head position and solves a ballistic path within the replicated throw-speed limits. It withholds throws if vulnerability closes, input is locked, the fuse/window estimate is too short or no trajectory is feasible. Denials, missing lighting replies and cooldown reservations prevent repeated light spam. No equipment switch or camera change is made.

Boss TNT Status and optional diagnostics include lighting, denial, throw timing/slot and TNT hit feedback. Existing hay TNT remains outside the enabled boss encounter. The controller uses BossFight.Config.TntFuse as its fuse estimate; actual server fuse behavior, trajectory acceptance and TNT use while holding vacuum still require an in-game test. A lit TNT is not forcibly discarded when the head window closes, since no verified cancellation request is available; its estimated fuse is allowed to expire without sending an off-target throw.

Validation includes official Luau compilation and mocked lighting acknowledgement, vulnerability/head gates, ballistic endpoint, cooldown, denial, missing reply, closing-window and cleanup checks, plus the existing integrated boss/finish regressions.

## Validation

All seven Lua files compile with the official Luau compiler. Mocked regressions cover routing/caching, UI/config behavior, target indexes, orbit order/progression, TNT, pickup input and timeout recovery. Live Roblox execution, permissions, network failures and game changes can affect behavior; measured FPS or farming gains are not claimed.

## Universal Discord wins recorder

Overview & Settings includes Discord Win Reports, Wins Webhook URL, and Wins Recorder Status in the lobby and Chapters 1–4. Reports are enabled by default once a webhook has been configured. Paste a webhook URL into the input to replace the locally saved endpoint; the credential is deliberately excluded from hub configs and public Lua files.

The recorder observes the game's saved Data.client.Wins value, establishes a baseline on its first installation, and reports positive changes. Repeated completion events alone do not create reports. A +N change is preserved as +N, rather than assumed to be one win. Each message includes account name/ID, chapter, saved-win change, tracked wins, average wins per hour since tracking started, and round time when available. Each report also includes Average round time (last 100), with the number of timed rounds used (for example, 1:23 (42/100 rounds)). Times display as minutes:seconds, rounded to the nearest second; full precision is retained for averaging. This rolling window is per account across all chapters, persists across teleports and re-execution, imports valid times from existing local win history, excludes unknown/invalid times, and counts each observed round once even if the saved-win increase is greater than one. It does not include remote captures or inventory dumps.

Local executor files:

- BeyyHub/wins_webhook.json: shared webhook URL and report toggle.
- BeyyHub/wins_recorder_<userId>.json: per-account baseline, tracking totals and pending deliveries.
- BeyyHub/wins_history_<userId>.jsonl: observed win increases.

Pending reports survive normal re-execution and teleports. Confirmed deliveries are removed from the queue; HTTP failures retry, respecting Discord's retry_after on HTTP 429. A lost HTTP response after Discord accepts a message can still cause a duplicate retry; the record ID in the footer identifies the observed increase. Disabling Discord Win Reports pauses sending while local tracking continues. Requires executor filesystem and HTTP request support.

Uses [Discord Execute Webhook](https://docs.discord.com/developers/resources/webhook#execute-webhook) with wait=true for delivery confirmation, and [Discord rate-limit retry guidance](https://docs.discord.com/developers/topics/rate-limits). The webhook is never embedded in the public source.

## Weekly lobby leaderboard tracking

Overview & Settings in the lobby includes Weekly Leaderboard Tracking (enabled by default), Capture Leaderboards Now, and Leaderboard Tracker Status. On each lobby execution, the tracker selects WEEKLY on the existing wins-board UI and saves one stable snapshot of its loaded rows plus the current clan's displayed member wins. The prior clan tab is restored. Clan wins are explicitly labelled as an unspecified period, not weekly wins. The snapshot does not force a server refresh or include players absent from the loaded leaderboard.

Auto Farm Wins waits for the first capture, up to 20 seconds, before creating a round. Collection retries for up to 60 seconds if the account stays in the lobby; it does not continually poll or repost after success. Disabling the tracker releases the lobby wait and pauses leaderboard deliveries. The manual capture button starts another snapshot attempt.

Snapshots use the existing local BeyyHub/wins_webhook.json destination; no separate cloud service or Discord bot is required. Each successful delivery is one webhook message with a top-10 preview, player/clan counts, reset countdown, and complete weekly-leaderboard.txt and weekly-leaderboard.json attachments. The existing Discord Win Reports toggle also controls whether this shared destination can send. Ordinary win reports remain separate.

Local files:

- needle-weekly-live.json: latest valid snapshot.
- needle-weekly-history.jsonl: successful snapshot history.
- needle-weekly-diagnostics.json: rejected/incomplete row diagnostics.
- BeyyHub/weekly_leaderboard_settings.json: tracking preference.
- BeyyHub/weekly_leaderboard_delivery.json: pending captures and recent delivered capture IDs.

Incomplete/conflicting reads preserve the last valid snapshot. Pending uploads persist across lobby visits and retry HTTP failures, including Discord rate limits. Capture IDs prevent ordinary duplicate submissions; an accepted HTTP request whose response is lost can still produce a duplicate retry. Uploads include the displayed leaderboard and clan membership data. No webhook credential is embedded in source or attachments.

## Runtime efficiency pass

The lobby, Chapters 1–4, and the embedded/standalone native UI use private caches for stable services, constructors and camera math helpers. Roblox instance methods retain their colon/namecall form, consistent with [Luau's method-call guidance](https://luau.org/performance/#fast-method-calls).

The third-person cutscene camera reuses RaycastParams and only replaces its character exclusion list when the character changes. Camera restoration, controller stop and respawn release these cached references. HUD state records are updated in place. Chapter 1's orbit status is formatted only when its displayed inputs change, and immutable hay-probe coordinates are captured before scanning. Known-size private orbit buffers and selector connection arrays use table.create; sparse/public tables keep their original handling.

Polling intervals, startup waits, remote-call statements, render/simulation bindings, selection order and return values remain unchanged in the changed paths. The loader was reviewed and left unchanged. No spatial query, UI traversal or wait was moved across a yield boundary merely to cache its result.

Validation: all six changed Lua files and the unchanged loader compile with the official Luau compiler. Before/after mocked tests cover camera output and filtering, collisions/errors/character changes, orbit labels and heights, hay scan order/slicing/cancellation, native UI/config behavior, saved-win reporting and selector cleanup. In the isolated camera test, 1,000 continuous third-person updates allocated 1,000 RaycastParams objects before and one after; the orbit test reduced 6,005 formatting calls to six with identical displayed output. These are test workload results, not a measured Studio frame-rate improvement. Live Studio CPU/heap measurements remain to be taken with the [MicroProfiler and Developer Console](https://create.roblox.com/docs/performance-optimization/improve).

## Reset webhook statistics

Overview & Settings in the lobby and Chapters 1–4 includes Reset Webhook Wins/hr & Average. Clicking it resets the per-account tracking clock and tracked-win count, and clears the rolling last-100-round time window. The next new win report starts rebuilding these metrics. The empty time window persists across teleports and re-execution instead of reimporting pre-reset rounds from local history. A duplicate completion event for a round already finished before the reset cannot add that old round back to the average.

The action leaves the game's saved wins, the recorder's saved-win baseline, webhook settings, local win-history file and queued reports intact. Already queued reports retain the metrics captured before the reset. It does not send a reset message or change farming settings. If reset during an unfinished round, that round contributes its time when it subsequently finishes.
