# Beyy native integrated hub

Native Roblox GUI for the lobby and all three chapters. Right Ctrl opens/closes it. Drag the title bar with the mouse or touch; the panel stays on screen. No UI animations, resizing, remote UI package, or UI polling while closed. Numeric settings use a text field and +/- buttons. Dropdowns expand instantly.

Existing config keys and WindUI/BeyyHub/config/*.json files remain compatible. Overview & Settings contains configs, chapter 1 farm settings, and cutscene settings. Lobby Tools follows Overview & Settings. Existing gameplay callbacks remain unchanged, including Chapter 1's two-second Replay delay.

Run this native feature branch:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sceneton/script/feature/native-integrated-hub/loader.lua?refresh=" .. tostring(os.time()) .. "-" .. tostring(math.random(1,1000000000))))()
```

The router downloads only the current place's module, checks the native branch revision, uses separate native caches, and queues the router on teleport when supported. Each module embeds native_ui.lua; editing that file alone does not update the modules.

Verification: all files compile using the official Luau compiler. Mocked native control/config and router tests cover behavior; live executor/game performance and gameplay still need an in-game check.

Optimizations: confirmed-revision module and router caches avoid repeated downloads; nine chapter farming workers are omitted in the lobby; disabled collect/sell/tool actions avoid objective checks; remote references are cached with parent validation; intro skip indexes GUI buttons once and watches additions; repeated status text writes are avoided. Config keys, action intervals, puzzle stages, farm rotations, and Replay timing are preserved.
