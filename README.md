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
- chapter4.lua: universal controls for place 102537610748607, including configs, anti-AFK, tools, upgrades, cutscene controls, vacuum recovery. Chapter-specific puzzles are not implemented.
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

## Validation

All seven Lua files compile with the official Luau compiler. Mocked regressions cover routing/caching, UI/config behavior, target indexes, orbit order/progression, TNT, pickup input and timeout recovery. Live Roblox execution, permissions, network failures and game changes can affect behavior; measured FPS or farming gains are not claimed.
