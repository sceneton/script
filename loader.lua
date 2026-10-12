-- beyy v103.00 | GitHub PlaceId router
-- Upload this file and the four chapter modules to the same public GitHub repository.
-- Change only BASE_RAW_URL to your repository's RAW URL.
local VERSION = "103.00"
local BASE_RAW_URL = "https://raw.githubusercontent.com/sceneton/script/feature/native-integrated-hub"
local CACHE_FOLDER = "BeyyHub"
local CACHE_PREFIX = CACHE_FOLDER .. "/v103_00_native_tabs3_"
local REVISION_FILE = CACHE_FOLDER .. "/native_github_revision.txt"

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

local function fetchFresh(url)
    return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) .. "-" .. tostring(math.random(1, 1000000000)))
end
local function readCache(path)
    if type(readfile) ~= "function" then return nil end
    local ok, value = pcall(readfile, path)
    return ok and type(value) == "string" and value or nil
end
local function validRevision(value)
    return type(value) == "string" and #value == 40 and value:match("^%x+$") ~= nil
end
local previousRevision = readCache(REVISION_FILE)
if not validRevision(previousRevision) then previousRevision = nil end
local revision
local checked, response = pcall(function()
    local raw = fetchFresh("https://api.github.com/repos/sceneton/script/commits/feature%2Fnative-integrated-hub")
    return game:GetService("HttpService"):JSONDecode(raw)
end)
if checked and type(response) == "table" and validRevision(response.sha) then revision = response.sha end
local selectedRevision = revision or previousRevision
if selectedRevision then CACHE_PREFIX = CACHE_FOLDER .. "/v103_00_native_" .. selectedRevision .. "_" end
local downloadBase = selectedRevision and ("https://raw.githubusercontent.com/sceneton/script/" .. selectedRevision) or BASE_RAW_URL
if not revision then
    warn("[BeyyHub] Could not check the latest GitHub revision; this run may use an older release")
end
local moduleCache = CACHE_PREFIX .. target.file
local source = nil
local url = downloadBase .. "/" .. target.file
-- A confirmed SHA names immutable source; validate and reuse its local cache.
if revision then
    local cached = readCache(moduleCache)
    if valid(cached, target.name) then source = cached end
end
if not source then
    local onlineOK, onlineSource = pcall(fetchFresh, url)
    if onlineOK and valid(onlineSource, target.name) then
        source = onlineSource
        if type(writefile) == "function" then pcall(writefile, moduleCache, source) end
    end
end
-- Without a confirmed revision, retain the online attempt before offline fallback.
if not source and type(readfile) == "function" then
    local ok, result = pcall(readfile, moduleCache)
    if ok and valid(result, target.name) then source = result end
end

if not source then
    warn("[BeyyHub] Could not load " .. target.name .. " online or from a valid cache")
    return
end

-- Invalidate old script caches only after the selected revision has a valid module.
-- Revision-specific paths also prevent stale reuse when deletion is unsupported.
if revision then
    if revision ~= previousRevision then
        if type(delfile) == "function" then
            local oldPrefixes = {"v103_00_native_", "v103_00_native_ui1_", "v103_00_native_rot2_", "v103_00_native_tabs3_"}
            if previousRevision then table.insert(oldPrefixes, "v103_00_native_" .. previousRevision .. "_") end
            for _, prefix in ipairs(oldPrefixes) do
                for _, file in ipairs({"loader.lua", "lobby.lua", "chapter1.lua", "chapter2.lua", "chapter3.lua"}) do
                    pcall(delfile, CACHE_FOLDER .. "/" .. prefix .. file)
                end
            end
        end
        print("[BeyyHub] GitHub update detected: " .. revision:sub(1, 7) .. "; old script caches invalidated")
    end
    if type(writefile) == "function" then pcall(writefile, REVISION_FILE, revision) end
end
print("[BeyyHub] Loading " .. target.name .. " | revision " .. (selectedRevision and selectedRevision:sub(1, 7) or "unverified"))

-- Keep the tiny router available offline for queued teleport reloads.
-- Only the module for the current place is downloaded and executed.
local loaderCache = CACHE_PREFIX .. "loader.lua"
local loaderURL = BASE_RAW_URL .. "/loader.lua"
local cachedLoader = revision and readCache(loaderCache)
local cachedLoaderValid = type(cachedLoader) == "string" and #cachedLoader > 1500
    and cachedLoader:find("-- beyy v103.00 | GitHub PlaceId router", 1, true) and loadstring(cachedLoader)
if type(writefile) == "function" and not cachedLoaderValid then
        local ok, data = pcall(fetchFresh, downloadBase .. "/loader.lua")
        if ok and type(data) == "string" and #data > 1500
            and data:find("-- beyy v103.00 | GitHub PlaceId router", 1, true)
            and loadstring(data) then
            pcall(writefile, loaderCache, data)
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
        local function validLoader(value)
            return type(value) == "string" and #value > 1500
                and value:find("-- beyy v103.00 | GitHub PlaceId router", 1, true)
                and loadstring(value)
        end
        local ok, value = pcall(function()
            local nonce = "?refresh=" .. tostring(os.time()) .. "-" .. tostring(math.random(1, 1000000000))
            local checked, info = pcall(function()
                return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://api.github.com/repos/sceneton/script/commits/feature%%2Fnative-integrated-hub" .. nonce))
            end)
            if checked and type(info) == "table" and type(info.sha) == "string"
                and #info.sha == 40 and info.sha:match("^%%x+$") then
                remoteUrl = "https://raw.githubusercontent.com/sceneton/script/" .. info.sha .. "/loader.lua"
            end
            return game:HttpGet(remoteUrl .. nonce)
        end)
        if ok and validLoader(value) then body = value end
        if not body and type(readfile) == "function" then
            local cachedOK, cached = pcall(readfile, cachePath)
            if cachedOK and validLoader(cached) then body = cached end
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
