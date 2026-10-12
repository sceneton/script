-- beyy v103.00 | Lobby module | PlaceId 77108422251420
local __BEYY_MODULE = "Lobby"
local __BEYY_SCRIPT_VERSION = "103.00"
if game.PlaceId ~= 77108422251420 then
    warn("[BeyyHub] Refusing to load Lobby module in another place")
    return
end

local CACHE_FOLDER = "BeyyHub"
local WINDUIT_CACHE = CACHE_FOLDER .. "/windui.lua"
local WINDUIT_URL = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"

pcall(function()
    if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(CACHE_FOLDER)) then
        makefolder(CACHE_FOLDER)
    end
end)

local function safeRead(path)
    if type(readfile) ~= "function" then return nil end
    local ok, content = pcall(readfile, path)
    if ok and type(content) == "string" and #content > 0 then return content end
    return nil
end

local function safeWrite(path, content)
    if not content or #content == 0 or type(writefile) ~= "function" then return false end
    local ok = pcall(writefile, path, content)
    return ok
end

local function isValidWindUI(content)
    if not content or #content < 5000 then return false end
    local head = content:sub(1, 200):lower()
    if head:sub(1, 1) == "<" or head:find("<!doctype", 1, true) then return false end
    return loadstring(content) ~= nil
end

local function fetchValidated(url, validator)
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if not ok or type(content) ~= "string" or not validator(content) then return nil end
    return content
end

local cachedWindUI = safeRead(WINDUIT_CACHE)
if not isValidWindUI(cachedWindUI) then
    cachedWindUI = fetchValidated(WINDUIT_URL, isValidWindUI)
    if cachedWindUI then safeWrite(WINDUIT_CACHE, cachedWindUI) end
end

if _G.__BEYY_HUB_LOADED then
    pcall(function()
        if type(_G.__BEYY_HUB_CLEANUP) == "function" then _G.__BEYY_HUB_CLEANUP() end
    end)
    task.wait(0.5)
end
_G.__BEYY_HUB_LOADED = true

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local waited = 0
    while not Players.LocalPlayer and waited < 10 do
        task.wait(0.05)
        waited = waited + 0.05
    end
    LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
    warn("[BeyyHub] LocalPlayer never became available.")
    return
end

print("[BeyyHub] LocalPlayer ready: ".. LocalPlayer.Name)

local function installMenuCursorRelease(menu, isRunning)
    local bindName = "BeyyV103_00MenuCursor_" .. tostring(LocalPlayer.UserId)
    local wasOpen = false
    local previousBehavior, previousIcon

    local function restoreMouse()
        if not wasOpen then return end
        wasOpen = false
        pcall(function()
            if previousBehavior then UserInputService.MouseBehavior = previousBehavior end
            if previousIcon ~= nil then UserInputService.MouseIconEnabled = previousIcon end
        end)
        previousBehavior, previousIcon = nil, nil
    end

    local function updateCursor()
        if not isRunning() then return end
        local menuOpen = menu and menu.Closed == false
        if menuOpen then
            if not wasOpen then
                previousBehavior = UserInputService.MouseBehavior
                previousIcon = UserInputService.MouseIconEnabled
                wasOpen = true
            end

            if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
            if not UserInputService.MouseIconEnabled then
                UserInputService.MouseIconEnabled = true
            end
        else
            restoreMouse()
        end
    end

    pcall(function() RunService:UnbindFromRenderStep(bindName) end)
    RunService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value + 100, updateCursor)
    return function()
        pcall(function() RunService:UnbindFromRenderStep(bindName) end)
        restoreMouse()
    end
end

local BEYY_PLACE_IDS = {
    Lobby = 77108422251420,
    Chapter1 = 108628039999641,
    Chapter2 = 83445806734780,
    Chapter3 = 82626725163709,
}
local BEYY_CHAPTER = "Unknown"
for chapter, placeId in pairs(BEYY_PLACE_IDS) do
    if game.PlaceId == placeId then
        BEYY_CHAPTER = chapter
        break
    end
end
print(string.format("[BeyyHub] Place %s -> %s", tostring(game.PlaceId), BEYY_CHAPTER))


do
    local hubUnloaded = false
    local hubWindow
    local hubWindUI
    local hubRestoreAction = nil
    local hubCursorCleanup = nil
    _G.__BEYY_HUB_CLEANUP = function()
        hubUnloaded = true
        if hubRestoreAction then pcall(hubRestoreAction) end
        if hubCursorCleanup then pcall(hubCursorCleanup) end
        if hubWindow then pcall(function() hubWindow:Destroy() end) end
    end
    local windSource = cachedWindUI
    if not windSource then windSource = fetchValidated(WINDUIT_URL, isValidWindUI) end
    if not windSource then
        warn("[BeyyHub] Cannot show " .. BEYY_CHAPTER .. " menu: WindUI unavailable")
        return
    end
    local windFunction, windError = loadstring(windSource)
    if not windFunction then
        warn("[BeyyHub] WindUI compile failed: " .. tostring(windError))
        return
    end
    local windOK, windResult = pcall(windFunction)
    if not windOK or not windResult then
        warn("[BeyyHub] WindUI startup failed: " .. tostring(windResult))
        return
    end
    hubWindUI = windResult
    hubWindow = hubWindUI:CreateWindow({
        Title = "Search For The Needle v103.00 | " .. BEYY_CHAPTER,
        Author = "by beyy",
        Icon = "search",
        Folder = "BeyyHub",
        Size = UDim2.fromOffset(640, 480),
        Theme = "Dark",
        Transparent = false,
        Resizable = true,
        SideBarWidth = 200,
        HideSearchBar = true,
        OpenButton = { Enabled = false },
    })
    pcall(function() hubWindow:SetToggleKey(Enum.KeyCode.RightControl) end)
    pcall(function() hubWindow:EditOpenButton({ Enabled = false }) end)

    local function hideNonFarmMenu()
        if not hubUnloaded and hubWindow and not hubWindow.Closed then
            pcall(function() hubWindow:Close() end)
        end
    end
    hideNonFarmMenu()

    if BEYY_CHAPTER == "Chapter2" or BEYY_CHAPTER == "Chapter3" then
        hubCursorCleanup = installMenuCursorRelease(hubWindow, function() return not hubUnloaded end)
    end

    local overviewTab = hubWindow:Tab({ Title = "Overview & Settings", Icon = "house" })
    overviewTab:Section({ Title = "Detected chapter" })
    overviewTab:Paragraph({
        Title = BEYY_CHAPTER .. " (Place ID " .. tostring(game.PlaceId) .. ")",
        Desc = "Farming and Inventory are available in every chapter. Right Ctrl opens or closes the menu.",
    })
    overviewTab:Section({ Title = "Shared menu" })
    overviewTab:Keybind({
        Title = "Menu keybind", Value = "RightControl",
        Callback = function(value)
            local key = typeof(value) == "EnumItem" and value or Enum.KeyCode[value]
            if key then pcall(function() hubWindow:SetToggleKey(key) end) end
        end,
    })
    overviewTab:Button({
        Title = "Unload Hub",
        Callback = function() pcall(_G.__BEYY_HUB_CLEANUP) end,
    })

    local Registry = {}
    local sharedFarmPuzzleBusy = function() return false end
    local sharedFarmDefaults = {
        AutoPickHay=false, AutoCollectDroppedHay=false, AutoCollectGems=false, CollectInterval=0.5,
        AutoSellHay=false, SellThreshold=25, SellOnlyIfFull=false,
        AutoUseTNT=false, AutoUsePitchfork=false, AutoDeployDrone=false,
        AutoUseVacuum=false, VacuumHotbarSlot=5, ToolInterval=0.5,
        AutoFindNeedle=false, AutoPickupNeedle=false, AutoHandInNeedle=false, NeedleInterval=1,
        AutoBuyTools=false, BuyToolsList={"Pitchfork"}, BuyInterval=1,
        UpgBagSize=false, UpgExtraTake=false, UpgGemValue=false, UpgHayValue=false, PermInterval=1,
        UpgCapacity=false, UpgHandSpeed=false, UpgHandGrab=false, UpgHandHold=false,
        UpgTntLuck=false, UpgTntCooldown=false, UpgTntPower=false,
        UpgPitchCooldown=false, UpgPitchHold=false, UpgPitchSweep=false,
        UpgDroneSpeed=false, UpgDroneGrab=false, UpgDroneCapacity=false,
        UpgVacPower=false, UpgVacCooling=false, UpgVacRuntime=false,
    }
    local sharedFarmState = {}
    for key, value in pairs(sharedFarmDefaults) do sharedFarmState[key] = value end
    local sharedFarmPath = CACHE_FOLDER .. "/farming_inventory_shared.json"
    local httpService = game:GetService("HttpService")
    local function importSharedFarmSettings()
        local raw = safeRead(sharedFarmPath)
        if not raw then return end
        local ok, decoded = pcall(function() return httpService:JSONDecode(raw) end)
        if not ok or type(decoded) ~= "table" then return end
        local sourceSettings = decoded.__elements or decoded
        for key, default in pairs(sharedFarmDefaults) do
            local value = sourceSettings[key]
            if type(value) == "table" and value.__type then value = value.value end
            if type(default) == "boolean" and type(value) == "boolean" then
                sharedFarmState[key] = value
            elseif type(default) == "number" and type(value) == "number" then
                sharedFarmState[key] = value
            elseif type(default) == "table" and type(value) == "table" then
                sharedFarmState[key] = value
            end
        end
    end
    importSharedFarmSettings()
    local function saveSharedFarmSettings()
        pcall(function() safeWrite(sharedFarmPath, httpService:JSONEncode(sharedFarmState)) end)
    end
    local farmingSection = hubWindow:Section({ Title = "Farming", Icon = "wheat", Opened = true })
    local collectingTab = farmingSection:Tab({ Title = "Collecting", Icon = "wheat" })
    local sellingTab = farmingSection:Tab({ Title = "Selling", Icon = "coins" })
    local toolsTab = farmingSection:Tab({ Title = "Tools", Icon = "hammer" })
    local needleTab = farmingSection:Tab({ Title = "Needle", Icon = "search" })
    local inventorySection = hubWindow:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
    local shopTab = inventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
    local upgradesTab = inventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
    local function farmToggle(tab, key, title, desc)
        local element = tab:Toggle({
            Title=title, Desc=desc, Value=sharedFarmState[key],
            Callback=function(enabled)
                sharedFarmState[key] = enabled == true
                saveSharedFarmSettings()
            end,
        })
        Registry[key] = element
        return element
    end
    local function farmSlider(tab, key, title, low, high, step, desc)
        local element = tab:Slider({
            Title=title, Desc=desc, Step=step,
            Value={Min=low, Max=high, Default=sharedFarmState[key]},
            Callback=function(value)
                sharedFarmState[key] = tonumber(value) or sharedFarmDefaults[key]
                saveSharedFarmSettings()
            end,
        })
        Registry[key] = element
        return element
    end
    collectingTab:Section({ Title="Resource Collecting" })
    farmToggle(collectingTab,"AutoPickHay","Auto Pick Hay")
    farmToggle(collectingTab,"AutoCollectDroppedHay","Auto Collect Dropped Hay")
    farmToggle(collectingTab,"AutoCollectGems","Auto Collect Gems")
    farmSlider(collectingTab,"CollectInterval","Loop Interval (s)",0.1,3,0.1)
    sellingTab:Section({ Title="Selling" })
    farmToggle(sellingTab,"AutoSellHay","Auto Sell Hay")
    farmSlider(sellingTab,"SellThreshold","Sell When Hay >=",1,250,1)
    farmToggle(sellingTab,"SellOnlyIfFull","Only Sell If Full")
    toolsTab:Section({ Title="Auto Tool Usage" })
    toolsTab:Paragraph({ Title="Tools operate when the chapter supplies the required hay and tool remotes." })
    farmToggle(toolsTab,"AutoUseTNT","Auto Use TNT")
    farmToggle(toolsTab,"AutoUsePitchfork","Auto Use Pitchfork")
    farmToggle(toolsTab,"AutoDeployDrone","Auto Deploy Drone")
    farmToggle(toolsTab,"AutoUseVacuum","Auto Use Vacuum (live heat + cooldown)",
        "Releases suction during menus, cutscenes and needle interactions.")
    farmSlider(toolsTab,"VacuumHotbarSlot","Vacuum Hotbar Slot (fallback)",1,9,1)
    farmSlider(toolsTab,"ToolInterval","Tool Interval (s)",0.2,5,0.1)
    needleTab:Section({ Title="Needle (TOP PRIORITY)" })
    needleTab:Paragraph({ Title="When a needle is exposed, harvesting pauses automatically." })
    farmToggle(needleTab,"AutoFindNeedle","Auto Find Needle")
    farmToggle(needleTab,"AutoPickupNeedle","Auto Pick Up Needle")
    farmToggle(needleTab,"AutoHandInNeedle","Auto Hand In Needle")
    farmSlider(needleTab,"NeedleInterval","Needle Scan Interval (s)",0.2,3,0.1)
    shopTab:Section({ Title="Purchasing" })
    Registry.BuyToolsList = shopTab:Dropdown({
        Title="Buy Tools Selection",
        Values={"Pitchfork","TNT","Drone","Infinite Bag","Capacity Bag"},
        Value=sharedFarmState.BuyToolsList, Multi=true, AllowNone=true,
        Callback=function(value)
            sharedFarmState.BuyToolsList=value
            saveSharedFarmSettings()
        end,
    })
    farmToggle(shopTab,"AutoBuyTools","Auto Buy Selected Tools")
    farmSlider(shopTab,"BuyInterval","Buy Interval (s)",0.5,5,0.1)
    upgradesTab:Section({ Title="Permanent (Gems)" })
    farmToggle(upgradesTab,"UpgBagSize","Auto Upgrade Bag Size")
    farmToggle(upgradesTab,"UpgExtraTake","Auto Upgrade Hand Grab Amount")
    farmToggle(upgradesTab,"UpgGemValue","Auto Upgrade Gem Value")
    farmToggle(upgradesTab,"UpgHayValue","Auto Upgrade Hay Value")
    farmSlider(upgradesTab,"PermInterval","Permanent Loop (s)",0.5,5,0.1)
    upgradesTab:Section({ Title="Hand (Cash)" })
    farmToggle(upgradesTab,"UpgHandSpeed","Auto Hand Speed")
    farmToggle(upgradesTab,"UpgHandGrab","Auto Hand Grasp")
    farmToggle(upgradesTab,"UpgHandHold","Auto Hand Hold")
    upgradesTab:Section({ Title="TNT (Cash)" })
    farmToggle(upgradesTab,"UpgTntLuck","Auto TNT Lucky Blast")
    farmToggle(upgradesTab,"UpgTntCooldown","Auto TNT Cooldown")
    farmToggle(upgradesTab,"UpgTntPower","Auto TNT Power")
    upgradesTab:Section({ Title="Pitchfork (Cash)" })
    farmToggle(upgradesTab,"UpgPitchCooldown","Auto Pitchfork Cooldown")
    farmToggle(upgradesTab,"UpgPitchHold","Auto Pitchfork Hold")
    farmToggle(upgradesTab,"UpgPitchSweep","Auto Pitchfork Sweep")
    upgradesTab:Section({ Title="Drone (Cash)" })
    farmToggle(upgradesTab,"UpgDroneSpeed","Auto Drone Speed")
    farmToggle(upgradesTab,"UpgDroneGrab","Auto Drone Grasp")
    farmToggle(upgradesTab,"UpgDroneCapacity","Auto Drone Capacity")
    upgradesTab:Section({ Title="Vacuum (Cash)" })
    farmToggle(upgradesTab,"UpgVacPower","Auto Vacuum Power")
    farmToggle(upgradesTab,"UpgVacCooling","Auto Vacuum Cooling")
    farmToggle(upgradesTab,"UpgVacRuntime","Auto Vacuum Runtime")
    upgradesTab:Section({ Title="Capacity (Cash)" })
    farmToggle(upgradesTab,"UpgCapacity","Auto Upgrade Carry Capacity")

    local needleFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local sharedGameConfig, sharedUpgradeConfig
    if needleFolder then
        pcall(function() sharedGameConfig=require(needleFolder:WaitForChild("Config",2)) end)
        pcall(function()
            local shared=ReplicatedStorage:FindFirstChild("Shared")
            local configs=shared and shared:FindFirstChild("Configs")
            local module=configs and configs:FindFirstChild("UpgradeConfig")
            if module then sharedUpgradeConfig=require(module) end
        end)
    end
    local function farmRemote(name)
        local folder=ReplicatedStorage:FindFirstChild("NeedleHaystack")
        local result=folder and folder:FindFirstChild(name)
        return result and result:IsA("RemoteEvent") and result or nil
    end
    local function sendFarmRemote(name,...)
        local remote=farmRemote(name)
        if not remote then return false end
        local args=table.pack(...)
        return pcall(function() remote:FireServer(table.unpack(args,1,args.n)) end)
    end
    local function farmRoot()
        local character=LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end
    local function farmBlocked()
        return hubUnloaded or BEYY_CHAPTER=="Lobby"
            or (BEYY_CHAPTER=="Chapter2" and sharedFarmPuzzleBusy())
            or LocalPlayer:GetAttribute("NeedleInputLocked")==true
            or LocalPlayer:GetAttribute("CutsceneActive")==true
            or LocalPlayer:GetAttribute("HintViewerOpen")==true
    end
    local function exposedNeedle()
        local folder=Workspace:FindFirstChild("NeedleObjectiveServer")
        folder=folder and folder:FindFirstChild("Needle")
        if not folder then return nil end
        for _,item in ipairs(folder:GetDescendants()) do
            if item:IsA("BasePart") and item:GetAttribute("IsNeedleObjective")==true
                and item:GetAttribute("HIDDEN_WITHIN")==nil
                and type(item:GetAttribute("HayId"))=="number" then
                return item
            end
        end
    end
    local needleBusy=false
    local function needlePriority()
        if needleBusy then return true end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then
            return sharedFarmState.AutoHandInNeedle or sharedFarmState.AutoPickupNeedle
        end
        return sharedFarmState.AutoPickupNeedle and exposedNeedle()~=nil
    end
    local function closestInFolder(folderName,idName,limit)
        local folder=Workspace:FindFirstChild(folderName)
        local root=farmRoot()
        if not folder or not root then return nil,nil end
        local best,bestId,dist=nil,nil,limit
        for _,obj in ipairs(folder:GetChildren()) do
            local part=obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)))
            if part then
                local id=part:GetAttribute(idName) or obj:GetAttribute(idName)
                if idName=="Dropped" then id=obj end
                local d=(part.Position-root.Position).Magnitude
                if id and d<dist then best,bestId,dist=part,id,d end
            end
        end
        return best,bestId
    end
    local function bagFull()
        return (tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0)
            >= (tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25)
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.1,tonumber(sharedFarmState.CollectInterval) or 0.5))
            if needleFolder and not farmBlocked() and not needlePriority() then
                if (sharedFarmState.AutoPickHay or (sharedFarmState.AutoFindNeedle and not exposedNeedle())) and not bagFull() then
                    local hay,id=closestInFolder("HaystackClient","HayId",30)
                    if id then
                        local nearby={}
                        local radius=tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                        if radius>0 and hay then
                            local folder=Workspace:FindFirstChild("HaystackClient")
                            if folder then
                                for _,other in ipairs(folder:GetChildren()) do
                                    if other~=hay and other:IsA("BasePart")
                                        and other:GetAttribute("HayId")
                                        and (other.Position-hay.Position).Magnitude<=radius+1 then
                                        nearby[#nearby+1]=other:GetAttribute("HayId")
                                        if #nearby>=6 then break end
                                    end
                                end
                            end
                        end
                        sendFarmRemote("PickHay",id,nearby)
                    end
                end
                if sharedFarmState.AutoCollectDroppedHay and not bagFull() then
                    local _,d=closestInFolder("DroppedHay","Dropped",28)
                    if d then sendFarmRemote("PickDroppedHay",d) end
                end
                if sharedFarmState.AutoCollectGems then
                    local _,id=closestInFolder("GemsClient","GemId",35)
                    if id then sendFarmRemote("CollectGem",id) end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(1)
            if needleFolder and not farmBlocked() and not needlePriority() and sharedFarmState.AutoSellHay then
                local held=tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0
                local threshold=tonumber(sharedFarmState.SellThreshold) or 25
                if held>0 and ((sharedFarmState.SellOnlyIfFull and bagFull())
                    or (not sharedFarmState.SellOnlyIfFull and held>=threshold)) then
                    sendFarmRemote("SellHay")
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            if needleFolder and not farmBlocked() and not needlePriority() then
                if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                    local _,id=closestInFolder("HaystackClient","HayId",30)
                    if id then sendFarmRemote("PitchforkDig",id) end
                end
                if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                    and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                    sendFarmRemote("DeployDrone")
                end
                if sharedFarmState.AutoUseTNT and LocalPlayer:GetAttribute("TntOwned")==true then
                    sendFarmRemote("TntAction","light")
                    task.wait(0.4)
                    if not farmBlocked() and not needlePriority() then
                        local camera=Workspace.CurrentCamera
                        if camera then
                            sendFarmRemote("TntAction","throw",camera.CFrame,
                                camera.CFrame.LookVector*40+Vector3.new(0,8,0))
                        end
                    end
                end
            end
        end
    end)
    local vacuumHeld=false
    local vacuumPoint=Vector2.zero
    local vacuumStart=0
    local vacuumCooldown=0
    local vacuumCooling=false
    local function releaseSharedVacuum()
        if vacuumHeld then
            vacuumHeld=false
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
            end)
        end
    end
    local oldCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        releaseSharedVacuum()
        if oldCleanup then pcall(oldCleanup) end
    end
    task.spawn(function()
        local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
            Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
            Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
        while not hubUnloaded do
            task.wait(0.08)
            local active=needleFolder and BEYY_CHAPTER~="Lobby" and sharedFarmState.AutoUseVacuum
                and not farmBlocked() and not needlePriority() and hubWindow.Closed==true
            if not active then
                releaseSharedVacuum()
            elseif os.clock()>=vacuumCooldown then
                local cam=Workspace.CurrentCamera
                local point=cam and cam.ViewportSize/2
                if point then
                    local gui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    local hud=gui and gui:FindFirstChild("HUD")
                    local heat=hud and hud:FindFirstChild("Overheat")
                    local fill=heat and heat:FindFirstChild("Fill")
                    local level=fill and fill:IsA("GuiObject") and fill.Size.Y.Scale or nil
                    if level and level>=0.999 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    elseif vacuumCooling and (not level or level>0.001) then
                        releaseSharedVacuum()
                    elseif not vacuumHeld then
                        vacuumCooling=false
                        local slot=math.clamp(math.floor(tonumber(sharedFarmState.VacuumHotbarSlot) or 5),1,9)
                        local key=hotbar[slot]
                        pcall(function() VirtualInputManager:SendKeyEvent(true,key,false,game) end)
                        task.wait(0.05)
                        pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
                        task.wait(0.15)
                        if not farmBlocked() and hubWindow.Closed and not needlePriority() then
                            vacuumPoint=point
                            local pressed=pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
                            end)
                            if pressed then vacuumHeld=true; vacuumStart=os.clock() end
                        end
                    elseif not level and os.clock()-vacuumStart>=30 then
                        releaseSharedVacuum()
                        vacuumCooldown=os.clock()+13.5
                    elseif level and level>=0.98 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    end
                end
            end
        end
        releaseSharedVacuum()
    end)
    local handInBusy = false
    local lastHandInWarning = -math.huge
    local function handInWarning(message)
        if os.clock() - lastHandInWarning >= 5 then
            lastHandInWarning = os.clock()
            warn("[BeyyHub] Needle turn-in: " .. tostring(message))
        end
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.NeedleInterval) or 1))
            if needleFolder and not farmBlocked() and sharedFarmState.AutoHandInNeedle
                and not needleBusy and not handInBusy
                and LocalPlayer:GetAttribute("NeedleOwned")==true then
                handInBusy = true
                local ok, err = pcall(function()
                    local root = farmRoot()
                    if not root then return end
                    if BEYY_CHAPTER == "Chapter2" then
                        local laser = Workspace:FindFirstChild("Laser")
                        if not (laser and laser:IsA("Model")) then
                            handInWarning("Workspace.Laser missing; waiting for the Chapter 2 hand-in location")
                            return
                        end
                        local destination = laser:GetPivot().Position - Vector3.new(0, 2.5, 0)
                        root.CFrame = CFrame.new(destination) * root.CFrame.Rotation
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        task.wait(0.2)
                        if hubUnloaded or farmBlocked() or not sharedFarmState.AutoHandInNeedle
                            or LocalPlayer:GetAttribute("NeedleOwned") ~= true then return end
                        if not sendFarmRemote("NeedleHandIn") then
                            handInWarning("NeedleHandIn remote unavailable or send failed")
                            return
                        end
                        local deadline = os.clock() + 1.5
                        while not hubUnloaded and LocalPlayer:GetAttribute("NeedleOwned")==true
                            and os.clock() < deadline do
                            task.wait(0.05)
                        end
                        if not hubUnloaded and LocalPlayer:GetAttribute("NeedleOwned")==true then
                            handInWarning("no server confirmation; will retry from beneath Laser")
                        end
                    else
                        local npc = Workspace:FindFirstChild("NPC")
                        local farmer = npc and npc:FindFirstChild("Farmer_NPC")
                        if farmer then
                            local location = farmer:GetPivot()
                            if (root.Position - location.Position).Magnitude > 15 then
                                root.CFrame = location * CFrame.new(0, 0, 4)
                            end
                            sendFarmRemote("NeedleHandIn")
                        end
                    end
                end)
                if not ok then handInWarning(err) end
                handInBusy = false
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.NeedleInterval) or 1))
            if needleFolder and not farmBlocked() and not needleBusy
                and sharedFarmState.AutoPickupNeedle and LocalPlayer:GetAttribute("NeedleOwned")~=true then
                local needle=exposedNeedle()
                local root=farmRoot()
                local camera=Workspace.CurrentCamera
                if needle and root and camera and hubWindow.Closed==true then
                    needleBusy=true
                    releaseSharedVacuum()
                    local previousRoot=root.CFrame
                    local previousCameraType=camera.CameraType
                    local previousCameraCF=camera.CFrame
                    local renderName="BeyySharedNeedleAim_"..tostring(LocalPlayer.UserId)
                    local bound=false
                    local mouseDown=false
                    local function clear()
                        if mouseDown then
                            mouseDown=false
                            local center=camera.ViewportSize/2
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            end)
                        end
                        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
                        if camera then
                            pcall(function()
                                camera.CameraType=previousCameraType
                                camera.CFrame=previousCameraCF
                            end)
                        end
                        if root and root.Parent then pcall(function() root.CFrame=previousRoot end) end
                        needleBusy=false
                    end
                    local ok,err=xpcall(function()
                        local id=needle:GetAttribute("HayId")
                        local spot=needle.Position+Vector3.new(2,2.5,0)
                        root.CFrame=CFrame.lookAt(spot,needle.Position)
                        camera.CameraType=Enum.CameraType.Scriptable
                        local cameraSpot=spot+Vector3.new(0,0,0.5)
                        camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+30,function()
                            if needle.Parent then
                                camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                                LocalPlayer:SetAttribute("HoveredHayId",id)
                            end
                        end)
                        bound=true
                        task.wait(0.1)
                        for _=1,8 do
                            if hubUnloaded or farmBlocked() or not sharedFarmState.AutoPickupNeedle
                                or not needle.Parent or LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            local center=camera.ViewportSize/2
                            LocalPlayer:SetAttribute("HoveredHayId",id)
                            VirtualInputManager:SendMouseMoveEvent(center.X,center.Y,game)
                            task.wait(0.025)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,true,game,0)
                            mouseDown=true
                            task.wait(0.1)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            mouseDown=false
                            task.wait(0.1)
                        end
                    end,function(e) return tostring(e) end)
                    clear()
                    if not ok then warn("[BeyyHub] Other-chapter needle pickup: "..tostring(err)) end
                end
            end
        end
    end)
    local function owned(attr) return LocalPlayer:GetAttribute(attr)==true end
    local function cash()
        local ls=LocalPlayer:FindFirstChild("leaderstats")
        local value=ls and ls:FindFirstChild("Cash")
        return value and tonumber(value.Value) or 0
    end
    local function tryTrack(name)
        if not sharedGameConfig then return end
        local track=sharedGameConfig.UPGRADE_TRACKS and sharedGameConfig.UPGRADE_TRACKS[name]
        if not track then return end
        local level=tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1
        if level>=#track.Levels then return end
        local nextLevel=track.Levels[level+1]
        if nextLevel and cash()>=(nextLevel.Cost or 0) then
            sendFarmRemote("BuyUpgrade",name)
        end
    end
    local function tryPermanent(name)
        if not sharedUpgradeConfig then return end
        local ok,upgrade=pcall(function() return sharedUpgradeConfig.getUpgrade(name) end)
        if not ok or not upgrade then return end
        local level=tonumber(LocalPlayer:GetAttribute("Upgrade"..name)) or 0
        local levelOK,maxLevel=pcall(function() return sharedUpgradeConfig:getMaxLevel(upgrade) end)
        if not levelOK or level>=maxLevel then return end
        local priceOK,price=pcall(function() return sharedUpgradeConfig:getPrice(upgrade,level) end)
        if priceOK and price and (tonumber(LocalPlayer:GetAttribute("Gems")) or 0)>=price then
            sendFarmRemote("BuyUpgrade",name)
        end
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.BuyInterval) or 1))
            if needleFolder and sharedFarmState.AutoBuyTools and BEYY_CHAPTER~="Lobby" then
                local selected=sharedFarmState.BuyToolsList or {}
                local choices={}
                for k,value in pairs(selected) do
                    if type(k)=="number" and type(value)=="string" then
                        choices[#choices+1]=value
                    elseif type(k)=="string" and value then
                        choices[#choices+1]=k
                    end
                end
                for _,name in ipairs(choices) do
                    if name=="Pitchfork" and not owned("PitchforkOwned") then
                        sendFarmRemote("BuyShopItem","Pitchfork")
                    elseif name=="TNT" and not owned("TntOwned") then
                        sendFarmRemote("BuyShopItem","Tnt")
                    elseif name=="Drone" and not owned("DroneOwned") then
                        sendFarmRemote("BuyShopItem","Drone")
                    elseif name=="Infinite Bag" and not owned("InfiniteBagOwned") then
                        sendFarmRemote("BuyShopItem","InfiniteBag")
                    elseif name=="Capacity Bag" then
                        tryTrack("Capacity")
                    end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.PermInterval) or 1))
            if needleFolder and BEYY_CHAPTER~="Lobby" then
                local mapped={UpgBagSize="ExtraHoldAmount",UpgExtraTake="ExtraTakeAmount",
                    UpgGemValue="GemValue",UpgHayValue="ExtraHayValuePercentage"}
                for key,name in pairs(mapped) do
                    if sharedFarmState[key] then tryPermanent(name) end
                end
            end
        end
    end)
    task.spawn(function()
        local tracks={
            UpgCapacity="Capacity",UpgHandSpeed="Speed",UpgHandGrab="Grab",UpgHandHold="HandHold",
            UpgTntLuck="TntLuck",UpgTntCooldown="TntCooldown",UpgTntPower="TntPower",
            UpgPitchCooldown="PitchforkCooldown",UpgPitchHold="PitchforkHold",UpgPitchSweep="Pitchfork",
            UpgDroneSpeed="DroneSpeed",UpgDroneGrab="DroneGrab",UpgDroneCapacity="DroneCapacity",
            UpgVacPower="VacuumPower",UpgVacCooling="VacuumCooling",UpgVacRuntime="VacuumRuntime",
        }
        while not hubUnloaded do
            task.wait(3)
            if needleFolder and BEYY_CHAPTER~="Lobby" then
                for key,name in pairs(tracks) do
                    if sharedFarmState[key] then tryTrack(name) end
                end
            end
        end
    end)



        local sharedPath = CACHE_FOLDER .. "/autofarmwins_shared.txt"
        local function readAutoFarmPreference()
            local shared = safeRead(sharedPath)
            if shared == "true" then return true end
            if shared == "false" then return false end
            local cfgText = safeRead("WindUI/BeyyHub/config/default.json")
            if cfgText then
                local parsedOK, json = pcall(function() return game:GetService("HttpService"):JSONDecode(cfgText) end)
                if parsedOK and type(json) == "table" then
                    local item = (json.__elements or json).AutoFarmWins
                    if type(item) == "table" and type(item.value) == "boolean" then return item.value end
                    if type(item) == "boolean" then return item end
                end
            end
            return false
        end
        local lobbyState = { AutoFarmWins = readAutoFarmPreference(), ArcadeFarm = false,
            ClassRoller = false, ClassTarget = "The Chosen One", ClassRollInterval = 1.1 }
        local lobbyTab = overviewTab
        local lobbyToolsTab = hubWindow:Tab({ Title = "Lobby Tools", Icon = "zap" })
        lobbyTab:Section({ Title = "Auto round creation" })
        lobbyTab:Paragraph({ Title = "Chapter 1 farming", Desc = "The lobby creates a Chapter 1 round if Auto Farm Wins is enabled. Farming and Inventory settings are accessible here." })
        Registry.AutoFarmWins = lobbyTab:Toggle({
            Title = "Auto Farm Wins (shared)", Value = lobbyState.AutoFarmWins,
            Desc = "Used by the lobby round creator and by Chapter 1 after teleport.",
            Callback = function(enabled)
                lobbyState.AutoFarmWins = enabled
                if not safeWrite(sharedPath, tostring(enabled)) then
                    warn("[BeyyHub] Could not persist shared Auto Farm Wins preference")
                end
            end,
        })
        lobbyToolsTab:Section({ Title = "Lobby utilities" })
        Registry.ArcadeFarm = lobbyToolsTab:Toggle({ Title = "Arcade Gem Farm", Value = false,
            Callback = function(enabled) lobbyState.ArcadeFarm = enabled end })
        Registry.ClassRoller = lobbyToolsTab:Toggle({ Title = "Auto Class Roller", Value = false,
            Callback = function(enabled) lobbyState.ClassRoller = enabled end })
        Registry.ClassTarget = lobbyToolsTab:Dropdown({
            Title = "Target Class", Values = { "The Chosen One", "Ultimate Farmer", "Hoover", "Drone Specialist", "Prospector" },
            Value = "The Chosen One", Callback = function(value) lobbyState.ClassTarget = value end,
        })
        Registry.ClassRollInterval = lobbyToolsTab:Slider({ Title = "Class Roll Interval (s)", Step = 0.1,
            Value = { Min = 0.5, Max = 3, Default = 1.1 },
            Callback = function(value) lobbyState.ClassRollInterval = tonumber(value) or 1.1 end })

        local Unloaded = false
        local IN_GAME = false
        local function afkFarmModeActive() return lobbyState.AutoFarmWins and not hubUnloaded end
        local function getHRP()
            local char = LocalPlayer.Character
            return char and char:FindFirstChild("HumanoidRootPart")
        end
        local function getTeleportCircles()
            local teleporter = Workspace:FindFirstChild("Teleporter")
            if not teleporter then return {} end
            local hrp = getHRP()
            if not hrp then return {} end
            local circles = {}
            for _, obj in ipairs(teleporter:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name == "InnerCylinder" then
                    table.insert(circles, { part = obj, dist = (obj.Position - hrp.Position).Magnitude })
                end
            end
            table.sort(circles, function(a, b) return a.dist < b.dist end)
            return circles
        end
        local function clickGuiObjectEarly(obj)
            if not obj or not obj:IsA("GuiObject") or not obj.Visible then return false end
            local absPos, absSize = obj.AbsolutePosition, obj.AbsoluteSize
            if absSize.X <= 0 or absSize.Y <= 0 then return false end
            local inset = GuiService:GetGuiInset()
            local cx = absPos.X + absSize.X / 2 + inset.X
            local cy = absPos.Y + absSize.Y / 2 + inset.Y
            pcall(function() VirtualInputManager:SendMouseMoveEvent(cx, cy, game) end)
            task.wait(0.02)
            pcall(function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0) end)
            task.wait(0.04)
            pcall(function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
            return true
        end

do
    local autoCreating = false
    local occupiedCircles = {}

    local function findInTree(root, path)
        local current = root
        for _, name in ipairs(path) do
            if not current then return nil end
            current = current:FindFirstChild(name)
        end
        return current
    end

    local function isCircleOccupied(circle)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local otherHrp = char and char:FindFirstChild("HumanoidRootPart")
                if otherHrp then
                    local dx = otherHrp.Position.X - circle.Position.X
                    local dz = otherHrp.Position.Z - circle.Position.Z
                    if math.sqrt(dx*dx + dz*dz) < 5 then return true end
                end
            end
        end
        return false
    end

    local function walkToCircle(circle)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = getHRP()
        if not hum or not hrp then return false end
        local target = Vector3.new(circle.Position.X, hrp.Position.Y, circle.Position.Z)
        hum:MoveTo(target)
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local createUI = pg and pg:FindFirstChild("CreatePartyUI")
        local container = createUI and createUI.Main and createUI.Main.Container
        if not container then return false end
        local t = 0
        while not container.Visible and t < 3.5 do
            if (hrp.Position - target).Magnitude > 4 then hum:MoveTo(target) end
            task.wait(0.08)
            t += 0.08
        end
        pcall(function() hum:MoveTo(hrp.Position) end)
        return container.Visible
    end

    local function monitorCircle(circle)
        local running = true
        task.spawn(function()
            while running and not hubUnloaded do
                task.wait(0.3)
                local hrp = getHRP()
                if hrp then
                    local dx = hrp.Position.X - circle.Position.X
                    local dz = hrp.Position.Z - circle.Position.Z
                    if math.sqrt(dx*dx + dz*dz) > 4 then
                        local char = LocalPlayer.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then hum:MoveTo(Vector3.new(circle.Position.X, hrp.Position.Y, circle.Position.Z)) end
                    end
                end
            end
        end)
        return function() running = false end
    end

    local function tryCreateFromCircle(circle)
        if not walkToCircle(circle) then return false end
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local createUI = pg and pg:FindFirstChild("CreatePartyUI")
        local container = createUI and createUI.Main and createUI.Main.Container
        if not container then return false end
        local stopMonitor = monitorCircle(circle)
        task.wait(0.2)
        local normalMode = findInTree(container, {"DifficultyChoosingFrame", "NormalMode"})
        if normalMode then clickGuiObjectEarly(normalMode); task.wait(0.12) end
        local numberLabel = container:FindFirstChild("Number")
        local minusBtn = container:FindFirstChild("Minus")
        if numberLabel and minusBtn then
            local attempts = 0
            while attempts < 6 do
                local n = tonumber(numberLabel.Text)
                if not n or n <= 1 then break end
                clickGuiObjectEarly(minusBtn)
                task.wait(0.1)
                attempts += 1
            end
        end
        local createBtn = container:FindFirstChild("Create")
        if createBtn then
            for _ = 1, 6 do
                if game.PlaceId ~= BEYY_PLACE_IDS.Lobby or not container.Visible then break end
                clickGuiObjectEarly(createBtn)
                local deadline = tick() + 0.9
                while tick() < deadline do
                    if game.PlaceId ~= BEYY_PLACE_IDS.Lobby or not container.Visible then break end
                    task.wait(0.05)
                end
                if game.PlaceId ~= BEYY_PLACE_IDS.Lobby or not container.Visible then
                    print("[Round] Create successful")
                    stopMonitor()
                    return true
                end
            end
        end
        stopMonitor()
        return false
    end

    local function attemptAutoCreate()
        if autoCreating then return end
        if game.PlaceId ~= BEYY_PLACE_IDS.Lobby then return end
        autoCreating = true
        local circles = getTeleportCircles()
        if #circles == 0 then autoCreating = false; return end
        for _, entry in ipairs(circles) do
            if game.PlaceId ~= BEYY_PLACE_IDS.Lobby then break end
            local circle = entry.part
            if isCircleOccupied(circle) then
                occupiedCircles[circle] = tick() + 15
            else
                if tryCreateFromCircle(circle) then autoCreating = false; return end
                occupiedCircles[circle] = tick() + 4
            end
        end
        autoCreating = false
    end

    task.spawn(function()
        while not hubUnloaded do
            task.wait(0.5)
            if afkFarmModeActive() and game.PlaceId == BEYY_PLACE_IDS.Lobby then
                pcall(attemptAutoCreate)
            end
        end
    end)
end

        local arcadeFolder = ReplicatedStorage:FindFirstChild("Arcade")
        local arcadeReport = arcadeFolder and arcadeFolder:FindFirstChild("ArcadeReport")
        local arcadeSession = arcadeFolder and arcadeFolder:FindFirstChild("ArcadeSession")
        local arcadeMachine = Workspace:FindFirstChild("Arcade Machine")
        local arcadePrompt = arcadeMachine and arcadeMachine:FindFirstChild("PlayPrompt", true)
        local classSystem = ReplicatedStorage:FindFirstChild("ClassSystem")
        local rollClass = classSystem and classSystem:FindFirstChild("RollClass")
        task.spawn(function()
            while not hubUnloaded do
                task.wait(0.2)
                if lobbyState.ArcadeFarm and arcadePrompt and arcadeReport then
                    pcall(function()
                        if type(fireproximityprompt) == "function" then fireproximityprompt(arcadePrompt) end
                        for _ = 1, 20 do arcadeReport:FireServer("kills", 40, 0) end
                        if arcadeSession then arcadeSession:FireServer("quit", 0, 0) end
                    end)
                end
            end
        end)
        task.spawn(function()
            while not hubUnloaded do
                task.wait(lobbyState.ClassRollInterval)
                if lobbyState.ClassRoller and rollClass then
                    local ok, result = pcall(function() return rollClass:InvokeServer() end)
                    if ok and type(result) == "table" and result.success and result.className == lobbyState.ClassTarget then
                        print("[BeyyHub] Desired class found: " .. result.className)
                        lobbyState.ClassRoller = false
                    end
                end
            end
        end)

    do
        local SettingsTab = overviewTab
        local ConfigManager = hubWindow.ConfigManager
        local function Header(tab, title) tab:Section({ Title = title }) end
        local function Notify(title, content, duration, icon)
            pcall(function() hubWindUI:Notify({ Title=title, Content=content, Duration=duration or 3, Icon=icon }) end)
        end
    Header(SettingsTab, "Config")
    local saveConfigName = "default"
    local selectedConfigName = nil
    local configDropdown = nil
    local EMPTY_CONFIG = "(No saved configs)"
    local function buildConfig(name)
        local cfg = ConfigManager:CreateConfig(name)
        for key, el in pairs(Registry) do cfg:Register(key, el) end
        -- Preserve settings belonging to other chapters when saving a shared config.
        local originalSave = cfg.Save
        function cfg:Save()
            local previous
            local raw = safeRead(self.Path)
            if raw then
                local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
                if not ok or type(data) ~= "table" then error("Existing config is unreadable; choose a new name") end
                previous = data
            end
            local saved = originalSave(self)
            if previous then
                for key, value in pairs(previous.__elements or previous) do
                    if saved.__elements[key] == nil then saved.__elements[key] = value end
                end
                if previous.__custom then saved.__custom = previous.__custom end
                if previous.__autoload ~= nil then saved.__autoload = previous.__autoload end
                writefile(self.Path, game:GetService("HttpService"):JSONEncode(saved))
            end
            return saved
        end
        return cfg
    end
    local function getConfigNames()
        local ok, names = pcall(function() return ConfigManager:AllConfigs() end)
        if not ok or type(names) ~= "table" then
            warn("[Config] Unable to list saved configs: ".. tostring(names))
            return {}
        end
        local result, seen = {}, {}
        for _, name in ipairs(names) do
            if type(name) == "string" and #name > 0 and not seen[name] then
                seen[name] = true
                table.insert(result, name)
            end
        end
        table.sort(result, function(a, b) return a:lower() < b:lower() end)
        return result
    end
    local function containsConfig(list, name)
        for _, entry in ipairs(list) do if entry == name then return true end end
        return false
    end
    local function refreshConfigDropdown(preferredName)
        local names = getConfigNames()
        local chosen = nil
        if preferredName and containsConfig(names, preferredName) then
            chosen = preferredName
        elseif selectedConfigName and containsConfig(names, selectedConfigName) then
            chosen = selectedConfigName
        elseif containsConfig(names, "default") then
            chosen = "default"
        else
            chosen = names[1]
        end
        selectedConfigName = chosen
        if configDropdown then
            local values = #names > 0 and names or { EMPTY_CONFIG }
            local ok, err = pcall(function()
                configDropdown:Refresh(values)
                configDropdown:Select(chosen or EMPTY_CONFIG)
            end)
            if not ok then warn("[Config] Dropdown refresh failed: ".. tostring(err)) end
        end
        return #names
    end
    if ConfigManager then
        local saved = getConfigNames()
        local initialConfig = containsConfig(saved, "default") and "default" or saved[1]
        selectedConfigName = initialConfig
        configDropdown = SettingsTab:Dropdown({
            Title = "Select Config to Load",
            Desc = "Choose from your saved config files",
            Values = #saved > 0 and saved or { EMPTY_CONFIG },
            Value = initialConfig or EMPTY_CONFIG,
            AllowNone = false,
            Callback = function(value)
                selectedConfigName = (type(value) == "string" and value ~= EMPTY_CONFIG) and value or nil
            end,
        })
        SettingsTab:Button({
            Title = "Refresh Config List",
            Callback = function()
                local count = refreshConfigDropdown()
                Notify("Config", "Found ".. tostring(count).. " saved config(s)", 3, "refresh-cw")
            end,
        })
        SettingsTab:Button({
            Title = "Load Selected Config",
            Callback = function()
                local name = selectedConfigName
                if not name or not containsConfig(getConfigNames(), name) then
                    Notify("Config", "Select an existing config first", 3, "x")
                    return
                end
                local ok, loaded, err = pcall(function() return buildConfig(name):Load() end)
                local success = ok and loaded ~= false and loaded ~= nil
                Notify("Config", success and ("Loaded: ".. name) or ("Failed: ".. tostring(ok and err or loaded)), 3, success and "check" or "x")
            end,
        })
        SettingsTab:Input({
            Title = "Save Config As", Value = saveConfigName, Placeholder = "default",
            Callback = function(value)
                if type(value) == "string" and value:match("%S") then saveConfigName = value end
            end,
        })
        SettingsTab:Button({
            Title = "Save Config",
            Callback = function()
                local name = saveConfigName
                if not name or not name:match("^[%w_%-%s]+$") then
                    Notify("Config", "Use letters, numbers, spaces, _ or -", 3, "x")
                    return
                end
                local ok, savedData = pcall(function() return buildConfig(name):Save() end)
                local success = ok and savedData ~= false and savedData ~= nil
                if success then refreshConfigDropdown(name) end
                Notify("Config", success and ("Saved: ".. name) or ("Failed: ".. tostring(savedData)), 3, success and "check" or "x")
            end,
        })
    else
        SettingsTab:Paragraph({ Title = "Configs unavailable", Desc = "Saving configs requires filesystem support in your environment." })
    end
    end

    task.defer(function()
        if not hubUnloaded then hideNonFarmMenu() end
    end)
    print("[BeyyHub] v103.00 " .. BEYY_CHAPTER .. " module loaded (RightControl to open)")
end
