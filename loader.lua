-- beyy v103.00 | GitHub PlaceId router
-- Upload this file and the four chapter modules to the same public GitHub repository.
-- Change only BASE_RAW_URL to your repository's RAW URL.
local VERSION = "103.00"
local BASE_RAW_URL = "https://raw.githubusercontent.com/sceneton/script/main"
local CACHE_FOLDER = "BeyyHub"
local CACHE_PREFIX = CACHE_FOLDER .. "/v103_00_rot2_"

local MODULES = {
    [77108422251420] = {file="lobby.lua", name="Lobby"},
    [108628039999641] = {file="chapter1.lua", name="Chapter1"},
    [83445806734780] = {file="chapter2.lua", name="Chapter2"},
    [82626725163709] = {file="chapter3.lua", name="Chapter3"},
}

local target = MODULES[game.PlaceId]
if not target then
    warn("[BeyyHub] Unsupported PlaceId: " .. tostring(game.PlaceId))
    return
end

local function valid(source, moduleName)
    if type(source) ~= "string" or #source < 1500 then return nil end
    if not source:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true) then return nil end
    if not source:find('local __BEYY_MODULE = "' .. moduleName .. '"', 1, true) then return nil end
    return loadstring(source)
end

pcall(function()
    if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(CACHE_FOLDER)) then
        makefolder(CACHE_FOLDER)
    end
end)

local moduleCache = CACHE_PREFIX .. target.file
local source = nil
local useCache = type(readfile) == "function"
if useCache then
    local ok, result = pcall(readfile, moduleCache)
    if ok and valid(result, target.name) then source = result end
end

if not source then
    local url = BASE_RAW_URL .. "/" .. target.file
    local ok, result = pcall(function() return game:HttpGet(url) end)
    if ok and valid(result, target.name) then
        source = result
        if type(writefile) == "function" then
            pcall(writefile, moduleCache, result)
        end
    else
        warn("[BeyyHub] Could not load " .. target.name .. " from " .. url .. "; check raw URL/public repository")
        return
    end
end

-- Keep the tiny router available offline for queued teleport reloads.
-- Only the module for the current place is downloaded and executed.
local loaderCache = CACHE_PREFIX .. "loader.lua"
local loaderURL = BASE_RAW_URL .. "/loader.lua"
if type(writefile) == "function" then
    local cached = nil
    if type(readfile) == "function" then
        local ok, data = pcall(readfile, loaderCache)
        if ok and type(data) == "string" and data:find("-- beyy v103.00 | GitHub PlaceId router", 1, true) then
            cached = data
        end
    end
    if not cached then
        local ok, data = pcall(function() return game:HttpGet(loaderURL) end)
        if ok and type(data) == "string" and #data > 1500
            and data:find("-- beyy v103.00 | GitHub PlaceId router", 1, true)
            and loadstring(data) then
            pcall(writefile, loaderCache, data)
        end
    end
end

local getEnv = (type(getgenv) == "function" and getgenv) or function() return _G end
local okEnv, env = pcall(getEnv)
if not okEnv or type(env) ~= "table" then env = _G end
local queue = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(env.queue_on_teleport) == "function" and env.queue_on_teleport)
    or (type(env.queueonteleport) == "function" and env.queueonteleport)
    or (type(env.queue_on_tp) == "function" and env.queue_on_tp)
if queue then
    local payload = string.format([==[
        local cachePath = %q
        local remoteUrl = %q
        local body
        if type(readfile) == "function" then
            local ok, value = pcall(readfile, cachePath)
            if ok and type(value) == "string" and #value > 1500 then body = value end
        end
        if not body then
            local ok, value = pcall(function() return game:HttpGet(remoteUrl) end)
            if ok and type(value) == "string" and #value > 1500 then body = value end
        end
        if body then
            local fn, compileError = loadstring(body)
            if fn then
                local ok, err = pcall(fn)
                if not ok then warn("[BeyyHub] Teleport reload error: " .. tostring(err)) end
            else warn("[BeyyHub] Teleport loader compile error: " .. tostring(compileError)) end
        else warn("[BeyyHub] No cached or online v103.00 loader after teleport") end
    ]==], loaderCache, loaderURL)
    local ok, err = pcall(queue, payload)
    if not ok then warn("[BeyyHub] Could not register teleport reload: " .. tostring(err)) end
else
    warn("[BeyyHub] queue_on_teleport unavailable; rerun loader after changing chapters")
end

local fn, compileError = loadstring(source)
if not fn then error("[BeyyHub] " .. target.name .. " compile error: " .. tostring(compileError)) end
local ok, err = pcall(fn)
if not ok then warn("[BeyyHub] " .. target.name .. " error: " .. tostring(err)) end
