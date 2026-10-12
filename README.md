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

When filesystem functions exist, v103.00 modules and the router are cached under BeyyHub/v103_00_ui1_*.lua. A valid module cache takes precedence over the remote file: editing GitHub files alone does not invalidate an existing same-version cache. Remove the corresponding v103_00_ui1_ cache files to fetch a fresh release, including the loader cache when changing its URL. WindUI uses BeyyHub/windui.lua.

Teleport reload is queued when a supported queue function exists; otherwise rerun the loader after changing places. The queued payload prefers the cached router. These environment-provided HTTP, loadstring, filesystem and teleport functions are not a standard Roblox LocalScript interface.

## Verification

All five Lua files compile with the official Luau compiler. Mocked loader tests cover every supported place with online loading, cache hits, invalid cache fallback, network failure, wrong module metadata and queue failure, plus unsupported-place exit. Gameplay is not executed by those tests, and live Roblox gameplay and teleport behavior have not been verified.

This README was prepared for publication because the original generated README was not supplied.

## Overview & Settings update

Saved-config selection, refresh, load and save controls are available under Overview & Settings in every module. Chapter 1 combines its previous Main and Settings tabs there. In the lobby, Chapter 1 round creation and Auto Farm Wins have moved from Lobby to Overview & Settings; Lobby Tools remains separate. Shared configs retain settings for other chapters when saved. Existing config files remain in WindUI/BeyyHub/config/. The updated router uses v103_00_ui1_ script caches; rerun the normal online loader once to fetch this UI revision. Live UI interaction has not been verified in Roblox.
