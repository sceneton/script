# Beyy Chapter 2 Standalone 1.3.1

A separate Chapter 2 puzzle and automatic tool controller with a native Roblox GUI. Runs only in PlaceId `83445806734780`.

```lua
local r=game:GetService("HttpService"):JSONDecode(game:HttpGet("https://api.github.com/repos/sceneton/script/commits/feature%2Fchapter2-standalone?refresh="..tostring(os.time()))); loadstring(game:HttpGet("https://raw.githubusercontent.com/sceneton/script/"..r.sha.."/chapter2_standalone.lua"))()
```

## Automatic startup

When the saved puzzle toggle is ON, the script attempts visible intro Skip controls and starts the complete puzzle sequence once intro Skip UI has disappeared, intro/input flags have cleared and the character, camera and three lever targets are ready. With a confirmed IntroCutsceneFinished flag there is no extra fixed startup delay. If that attribute is absent, a 0.25-second neutral interval prevents racing initial scene replication. A scene without a usable Skip control must finish normally. Intro/outro handling remains available when the puzzle toggle is OFF.

Skip activation uses the original integrated routine's virtual mouse click plus optional firesignal activation of MouseButton1Click, MouseButton1Down/Up and Activated signals, including visible nested buttons. Intro skips retry every 0.5 seconds; outro skips retry every second. Outro/results UI is identified separately and pauses key/tool actions. Visible outro Skip controls are clicked once active puzzle/key interactions have released input. The script does not auto-vote Replay or change server cutscene timers. Cutscene status is shown in the GUI.

The puzzle sequence launches once per enabled run. Switching OFF cancels the active workers; switching ON re-arms the sequence, waiting for cancelled workers and normal readiness before starting. Right Ctrl opens the menu for manual control; Unload cancels all workers. Key pickup and turn-in are permanently enabled and resume when game controls allow it. TNT starts enabled. Drone auto-deployment starts enabled and sends one request as soon as ownership and the remote are available, without waiting for intro/puzzle input control. It does not repeat successful requests or redeploy an already active drone.

## Controls

- **Auto Solve Puzzles: ON/OFF** controls the complete lever, number, picture and colour sequence. Changes automatically save; OFF cancels and ON starts once readiness checks pass. The menu hides while the automatic startup is active.
- **TNT / Pitchfork / Drone / Vacuum** turn automatic usage on or off. TNT and Drone start on; Pitchfork and Vacuum start off. TNT, Pitchfork and Vacuum pause while the GUI is open or puzzle/key interactions own input. Drone deployment uses no mouse/camera and can be sent during intro/puzzles.
- **Vacuum slot** cycles through hotbar slots 1–9; default is 5.
- **Auto Pick Up Key: ALWAYS ON** finds `Workspace.NeedleObjectiveServer.Key`, moves beside it, aims and clicks until ownership is confirmed. The target requires a numeric `HayId` and must not be marked hidden.
- **Auto Turn In Key: ALWAYS ON** moves beneath `Workspace.Laser` and submits through the existing `NeedleHandIn` remote, checking that ownership clears. These are fixed enabled indicators; there are no off toggles.
- **Stop tools** switches automatic tool requests off and releases input. An already deployed drone continues its autonomous collection; turning its toggle off does not recall it.
- **Unload** cancels workers, releases mouse/key input, restores controls and removes the GUI.
- Drag the title to reposition the panel. Progress appears in the puzzle and tool status rows.

## Runtime changes

No WindUI or other external UI download. One adaptive background scheduler handles the four tools and key pickup/turn-in; solver workers exist only while requested. Tool remotes and the vacuum heat HUD are cached, and nearest-hay scans run only while Pitchfork is enabled and owned. TNT and vacuum equipment timing use scheduler deadlines rather than additional permanent worker loops. The embedded number-solver factory compiles once and is reused for retries.

TNT, Pitchfork and Vacuum pause while puzzle workers or key interactions own input, while the GUI is open, during flagged cutscenes and when game input is locked. The one-time drone request is independent of these input locks. Key automation waits for puzzle workers to finish. The scheduler releases Mouse1 before a puzzle or key interaction starts. Vacuum uses the live heat bar when available, with timed fallback when the HUD is unavailable. Opening the GUI cancels an active pickup and restores the temporary hay/camera changes.

This script closes an already-running Beyy hub before taking camera/mouse control in Chapter 2. Re-executing the standalone unloads its previous instance. It does not need the split hub loader and does not change the split hub files. TNT/Drone default on, Pitchfork/Vacuum default off, and both key options are always enabled on each execution.

## Minimal config

Only the puzzle toggle is saved, automatically, in `BeyyHub/ch2_standalone_puzzles.txt`. Its entire contents are one byte: `1` for ON or `0` for OFF. The saved value is read on execution, including teleport reloads. A missing or invalid file defaults to ON. No named presets, Save/Load buttons, UI library or extra config settings are used. If filesystem saving is unsupported or a write fails, the Config status reports it and the toggle still applies for the current session.

## Teleport reload

The script listens for a teleport and queues a bootstrap using supported queue_on_teleport / queueonteleport / queue_on_tp APIs. On arrival it waits for game/player readiness, resolves the latest feature-branch commit and downloads the standalone from that exact revision. If the revision API is unavailable it tries the branch's raw URL with a fresh query parameter. Invalid downloads or execution failures are reported; rerun the standalone loader in that case.

Run it once in the lobby to arm reloads without creating a GUI, or run it directly in Chapter 2. It keeps the teleport listener armed in other destinations and runs gameplay automation only in Chapter 2. Duplicate teleport events queue once, and the destination bootstrap prevents duplicate executions. Unload disconnects the listener before a new teleport is queued. A payload already queued for an ongoing teleport cannot be revoked by the script.

The Teleport status row reports whether reload is armed, queued or unavailable. Automatic reload requires the execution environment's teleport queue support. The saved puzzle toggle is restored on arrival; other defaults are reapplied and temporary tool settings are not transferred.

## Verification

The standalone and its embedded number worker compile with Luau. Mocked checks cover native GUI startup, intro gating of manual solver actions, a single background scheduler, other-place standby, unload/connection cleanup and removal of the Stop/Number-only controls. Nine scheduler checks cover one-shot drone deployment during startup/puzzles/menu, delayed ownership, missing acknowledgement, an already deployed drone, TNT timing and key/mouse release. Additional checks cover ten pickup cases, nine turn-in cases, ten intro/outro cases and nine teleport reload cases. Existing puzzle timings are retained, including the six-second post-lever wait.

The native UI and full puzzle completion have not been tested in a live Roblox session. Smaller downloads and fewer idle workers are measurable; an FPS or completion-speed improvement has not been benchmarked. Successful actions still depend on game state and server acceptance.
