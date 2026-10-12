# Beyy Hub v103.00

Place-specific split release. The four supplied gameplay modules are preserved unchanged.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sceneton/script/main/loader.lua"))()
```

The loader uses BASE_RAW_URL = https://raw.githubusercontent.com/sceneton/script/main (no trailing slash).

| PlaceId | Module |
| --- | --- |
| 77108422251420 | lobby.lua |
| 108628039999641 | chapter1.lua |
| 83445806734780 | chapter2.lua |
| 82626725163709 | chapter3.lua |

Unsupported places return without downloading a module. Each module also checks its PlaceId.
The router validates module length, version and module markers, and compilation before execution.

## Caching and teleport reload

Only the selected gameplay module is fetched. On the first run the router may additionally fetch itself for teleport caching. Modules load WindUI separately from its upstream latest release, with a local cache.

When filesystem functions exist, v103.00 modules and the router are cached under BeyyHub/v103_00_tabs3_*.lua. Each run requests a fresh module from GitHub with a unique query parameter, validates it and updates its cache. A validated local cache is used only when the online response is unavailable or invalid. WindUI uses BeyyHub/windui.lua.

Teleport reload is queued when a supported queue function exists; otherwise rerun the loader after changing places. The queued payload requests a fresh router first and falls back to a validated cached router. These environment-provided HTTP, loadstring, filesystem and teleport functions are not a standard Roblox LocalScript interface.

## Verification

All five Lua files compile with the official Luau compiler. Mocked loader tests cover every supported place with online loading, cache hits, invalid cache fallback, network failure, wrong module metadata and queue failure, plus unsupported-place exit. Gameplay is not executed by those tests, and live Roblox gameplay and teleport behavior have not been verified.

This README was prepared for publication because the original generated README was not supplied.

## Overview & Settings update

Saved-config selection, refresh, load and save controls are available under Overview & Settings in every module. Chapter 1 combines its previous Main and Settings tabs there. In the lobby, Chapter 1 round creation and Auto Farm Wins have moved from Lobby to Overview & Settings; Lobby Tools remains separate. Shared configs retain settings for other chapters when saved. Existing config files remain in WindUI/BeyyHub/config/. The updated router uses v103_00_tabs3_ script caches; rerun the normal online loader once to fetch this UI revision. Live UI interaction has not been verified in Roblox.

## Reference rotations and cutscene control

Chapter 1 uses the v101.57 reference four-band sweep at 48 degrees per second: 22, 18, 14 and 8 stud bands with fixed measured hay surfaces, smooth band transitions, and matching character movement. A lap takes about 7.5 seconds and the four-band cycle about 30 seconds at normal frame rates.

Every module includes an optional Unskippable Cutscene Bypass under Overview & Settings, saved in named configs. It uses the reference camera/movement controller with generalized CutsceneActive detection and Chapter2ReleaseActive support. It yields to explicit unfinished intros, visible Skip/results UI, the hub menu, and active needle/puzzle automation. Scenes without these replicated attributes cannot be identified automatically. This changes local camera, controls and cutscene overlays only; server timers and progression are unchanged. Turning it off or unloading cleans up its callbacks and restores the camera/HUD. Live compatibility with individual chapter scenes is not yet verified.

Rerun the normal online loader to select the new v103_00_tabs3_ script cache. Saved configs are retained.
