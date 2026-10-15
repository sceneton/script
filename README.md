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
- chapter4.lua: universal controls for place 102537610748607 plus Farming → Candles → Auto Collect & Light Candles. This saved toggle defaults off and replaces Chapter 4's needle controls. It waits until all four candles are exposed (including candles already collected), then processes them consecutively: confirming pickup, placing in free holders, and uses server-confirmed fast lighting with normal match assistance as fallback. Hay tools/vacuum pause during candle actions; the normal client close handler restores movement and cursor after lighting. Farming → Tools also includes a saved **Auto Boss Weak-Point Pitchfork** toggle (default off). It targets the Pumpkin Golem's current animated weak point within pitchfork reach, follows the attack cooldown, and pauses for menus, candle actions, cutscenes and combat input locks. Ordinary hay pitchfork requests yield while this boss mode is engaged.
- native_ui.lua: native menu implementation embedded in all five modules.

## Settings and recovery

Existing WindUI/BeyyHub/config/*.json configs remain compatible. Config controls and farm settings are under Overview & Settings. Lobby Tools follows that tab. Anti-AFK defaults on.

Chapter 1's sequence starts with four laps at base-lower, then four original base laps, followed by the seven higher routes. The added lower route is two studs below the original base. Character inset and camera adjustments are preserved. Orbit progression waits for the character to follow its scheduled path.

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
