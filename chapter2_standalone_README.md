# Beyy Chapter 2 Standalone 1.2.0

A separate Chapter 2 puzzle and automatic tool controller with a native Roblox GUI. Runs only in PlaceId `83445806734780`.

```lua
local r=game:GetService("HttpService"):JSONDecode(game:HttpGet("https://api.github.com/repos/sceneton/script/commits/feature%2Fchapter2-standalone?refresh="..tostring(os.time()))); loadstring(game:HttpGet("https://raw.githubusercontent.com/sceneton/script/"..r.sha.."/chapter2_standalone.lua"))()
```

## Automatic startup

On execution the script hides its GUI, attempts visible intro Skip controls, and starts the complete puzzle sequence once the intro/input lock has cleared and the character, camera and three lever targets are ready. With a confirmed IntroCutsceneFinished flag there is no extra fixed startup delay. If that attribute is absent, a 0.25-second neutral interval prevents racing initial scene replication. Skip attempts are limited to every 0.5 seconds and exclude ending/results controls. A scene without a usable Skip control must finish normally.

The puzzle sequence launches once per execution. The Stop button cancels it without automatic restart. Right Ctrl opens the menu for manual control. Key pickup and turn-in are permanently enabled and resume after the puzzle sequence when game controls allow it.

## Controls

- **Auto Solve Puzzles** runs the existing lever, number, picture and colour sequence. The panel hides during the sequence and returns afterwards.
- **Stop Auto Solve Puzzles** cancels remaining work. Right Ctrl reopens the panel if you need this button while a sequence is running.
- **Auto Number Puzzle (only)** runs the number note finder and keypad submission.
- **TNT / Pitchfork / Drone / Vacuum** turn automatic usage on or off. Tools start off. Close the GUI with Right Ctrl to allow tool usage.
- **Vacuum slot** cycles through hotbar slots 1–9; default is 5.
- **Auto Pick Up Key: ALWAYS ON** finds `Workspace.NeedleObjectiveServer.Key`, moves beside it, aims and clicks until ownership is confirmed. The target requires a numeric `HayId` and must not be marked hidden.
- **Auto Turn In Key: ALWAYS ON** moves beneath `Workspace.Laser` and submits through the existing `NeedleHandIn` remote, checking that ownership clears. These are fixed enabled indicators; there are no off toggles.
- **Stop tools** switches all automatic tools off and releases input.
- **Unload** cancels workers, releases mouse/key input, restores controls and removes the GUI.
- Drag the title to reposition the panel. Progress appears in the puzzle and tool status rows.

## Runtime changes

No WindUI or other external UI download. One adaptive background scheduler handles the four tools and key pickup/turn-in; solver workers exist only while requested. Tool remotes and the vacuum heat HUD are cached, and nearest-hay scans run only while Pitchfork is enabled and owned. TNT and vacuum equipment timing use scheduler deadlines rather than additional permanent worker loops. The embedded number-solver factory compiles once and is reused for retries.

Tools pause while puzzle workers or key interactions own input, while the GUI is open, during flagged cutscenes and when game input is locked. Key automation waits for puzzle workers to finish. The scheduler releases Mouse1 before a puzzle or key interaction starts. Vacuum uses the live heat bar when available, with timed fallback when the HUD is unavailable. Opening the GUI cancels an active pickup and restores the temporary hay/camera changes.

This script closes an already-running Beyy hub before taking camera/mouse control. Re-executing the standalone unloads its previous instance. It does not need the split hub loader and does not change the split hub files. This version contains puzzles, tools and key pickup/turn-in; it has no upgrades, gem exploit, config manager or cutscene camera bypass. Tool settings reset off on each execution; both key options are always enabled. Run it again after teleporting into Chapter 2.

## Verification

The standalone and its embedded number worker compile with Luau. Mocked checks cover native GUI startup, solver failure with missing puzzle assets, single background scheduler, wrong-place rejection, unload/connection cleanup, TNT timing, puzzle/menu tool pauses and vacuum key/mouse release. Additional checks cover ten pickup cases, nine turn-in cases and eight automatic startup cases, including delayed confirmation, retry exhaustion, missing assets, intro skipping, one-shot launch and cancellation. Existing puzzle timings are retained, including the six-second post-lever wait.

The native UI and full puzzle completion have not been tested in a live Roblox session. Smaller downloads and fewer idle workers are measurable; an FPS or completion-speed improvement has not been benchmarked. Successful actions still depend on game state and server acceptance.
