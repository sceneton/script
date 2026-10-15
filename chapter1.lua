-- beyy v103.00 | Chapter1 module | PlaceId 108628039999641
local __BEYY_MODULE = "Chapter1"
local __BEYY_SCRIPT_VERSION = "103.00"
if game.PlaceId ~= 108628039999641 then
    warn("[BeyyHub] Refusing to load Chapter1 module in another place")
    return
end

local CACHE_FOLDER = "BeyyHub"

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

local function installAntiIdle(tab, registry, isRunning)
    local enabled, alive, warned = true, true, false
    local virtualUser
    local status = tab:Paragraph({Title="Anti AFK Status",Desc="Enabled; waiting for idle signal"})
    registry.AntiAFK = tab:Toggle({
        Title = "Anti AFK Kick", Value = true,
        Callback = function(value) enabled = value == true; status:SetDesc(enabled and "Enabled; waiting for idle signal" or "Disabled") end,
    })
    local idleConnection = LocalPlayer.Idled:Connect(function()
        if not alive or not enabled or not isRunning() then return end
        local ok,err = pcall(function()
            virtualUser = virtualUser or game:GetService("VirtualUser")
            local camera = Workspace.CurrentCamera
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.zero, camera and camera.CFrame or CFrame.new())
        end)
        local method = "VirtualUser"
        if not ok then
            method = "VirtualInputManager"
            local pressed=false
            ok,err=pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0,0,1,true,game,0)
                pressed=true
            end)
            if pressed then
                local released,releaseErr=pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,1,false,game,0) end)
                if not released then ok=false;err=releaseErr end
            end
        end
        status:SetDesc(ok and ("Idle input sent via "..method) or ("Idle input failed: "..tostring(err)))
        if ok then
            print("[BeyyHub] Anti AFK idle input sent via "..method)
        elseif not warned then
            warned = true
            warn("[BeyyHub] Anti AFK input unavailable: " .. tostring(err))
        end
    end)
    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
    stopEarlyIntro()
    stopPitchforkSelector()
    stopCollectHay(); stopDroppedHay(); stopCollectGem()
        alive = false
        idleConnection:Disconnect()
        if previousCleanup then previousCleanup() end
    end
end

-- Pitchfork-only targeting: maintain child slots and budget large searches.
local function createPitchforkSelector(allowModels, preferHovered, options)
    options=options or {}
    local folderName=options.FolderName or "HaystackClient"
    local idName=options.IdName or "HayId"
    local range=options.Range or 30
    local function targetId(part,obj)
        if options.ObjectId then return obj end
        return part:GetAttribute(idName) or (allowModels and not options.PartIdOnly and obj:GetAttribute(idName))
    end
    local alive, folder = true, nil
    local slots, positions, freeSlots, connections = {}, {}, {}, {}
    local slotCount = 0
    local lastTarget, lastTargetTime
    local function clearFolder()
        for _,c in ipairs(connections) do c:Disconnect() end
        table.clear(connections); table.clear(slots); table.clear(positions); table.clear(freeSlots)
        slotCount=0; lastTarget=nil; lastTargetTime=nil
    end
    local function add(obj)
        if positions[obj] or not (obj:IsA("BasePart") or (allowModels and (obj:IsA("Model") or options.AllowContainers))) then return end
        local index=table.remove(freeSlots)
        if not index then slotCount+=1; index=slotCount end
        slots[index]=obj; positions[obj]=index
    end
    local function remove(obj)
        local index=positions[obj]
        if not index then return end
        positions[obj]=nil; slots[index]=false; freeSlots[#freeSlots+1]=index
        if lastTarget==obj or (lastTarget and lastTarget:IsDescendantOf(obj)) then lastTarget=nil end
    end
    local function watchFolder(current)
        if current==folder then return end
        clearFolder(); folder=current
        if not folder then return end
        connections[1]=folder.ChildAdded:Connect(add)
        connections[2]=folder.ChildRemoved:Connect(remove)
        local scanFolder=folder
        local sliceStarted=os.clock()
        for index,obj in ipairs(folder:GetChildren()) do
            if not alive or folder~=scanFolder then return end
            if obj.Parent==scanFolder then add(obj) end
            if index%32==0 and os.clock()-sliceStarted>=0.002 then task.wait(); sliceStarted=os.clock() end
        end
    end
    local function stop()
        alive=false; clearFolder(); folder=nil
    end
    local function selectTarget(isAllowed, cacheSeconds)
        if not alive or not isAllowed() then return nil end
        local current=Workspace:FindFirstChild(folderName)
        watchFolder(current)
        if not alive or not isAllowed() then return nil end
        local character=LocalPlayer.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not folder or not root then return nil end
        local hovered=preferHovered and LocalPlayer:GetAttribute("HoveredHayId") or nil
        if lastTarget and lastTarget.Parent and lastTarget:IsDescendantOf(folder)
            and os.clock()-(lastTargetTime or 0)<(cacheSeconds or 0)
            and not options.ObjectId and lastTarget:GetAttribute(idName) then return lastTarget,lastTarget:GetAttribute(idName) end
        local best,bestId,hoveredPart,hoveredId=nil,nil,nil,nil
        local bestObject,hoveredObject
        local bestDistance=range*range
        local sliceStarted=os.clock()
        local origin=root.Position
        local scanFolder=folder
        local index=1
        while index<=slotCount do
            if not alive or folder~=scanFolder or not scanFolder.Parent then return nil end
            local obj=slots[index]
            if obj and obj.Parent==scanFolder then
                local part=obj:IsA("BasePart") and obj or ((obj:IsA("Model") and obj.PrimaryPart) or obj:FindFirstChildWhichIsA("BasePart",options.Recursive~=false))
                if part then
                    local id=targetId(part,obj)
                    if id then
                        if hovered and id==hovered then hoveredPart,hoveredId,hoveredObject=part,id,obj end
                        local delta=part.Position-origin
                        local distance=delta:Dot(delta)
                        if distance<bestDistance then best,bestId,bestDistance,bestObject=part,id,distance,obj end
                    end
                end
            end
            index+=1
            if index%32==0 and os.clock()-sliceStarted>=0.002 then
                if not isAllowed() then return nil end
                task.wait()
                sliceStarted=os.clock()
            end
        end
        best,bestId=hoveredPart or best,hoveredId or bestId
        bestObject=hoveredObject or bestObject
        if not best or not best.Parent or not best:IsDescendantOf(scanFolder) then return nil end
        if not alive or not isAllowed() or Workspace:FindFirstChild(folderName)~=scanFolder
            or LocalPlayer.Character~=character then return nil end
        -- Recheck range after any yield; hovered selection keeps Chapter 1's rules.
        local delta=best.Position-root.Position
        if not hoveredPart and delta:Dot(delta)>=range*range then return nil end
        lastTarget,lastTargetTime=best,os.clock()
        local currentId=targetId(best,bestObject)
        if not currentId then lastTarget=nil; return nil end
        return options.ReturnObject and bestObject or best,currentId
    end
    return selectTarget,stop
end
local function budgetedFolderChildren(folder,isAllowed,descendants)
    local children=descendants and folder:GetDescendants() or folder:GetChildren()
    local index,started=0,os.clock()
    return function()
        if not folder.Parent or not isAllowed() then return nil end
        index+=1
        local obj=children[index]
        if not obj then return nil end
        if index%32==0 and os.clock()-started>=0.002 then task.wait(); started=os.clock() end
        if not folder.Parent or not isAllowed() then return nil end
        return index,obj
    end
end

local selectPitchforkHay, stopPitchforkSelector = createPitchforkSelector(false, true)
-- Start intro input before constructing the menu or waiting for gameplay assets.
local earlyIntroPending, stopEarlyIntro
do
local earlyIntroRunning = true
earlyIntroPending = false
local earlyIntroGui, earlyIntroConnection
local earlyIntroButtons = setmetatable({}, {__mode="k"})
stopEarlyIntro = function()
    earlyIntroRunning = false; earlyIntroPending = false
    if earlyIntroConnection then earlyIntroConnection:Disconnect(); earlyIntroConnection=nil end
    table.clear(earlyIntroButtons)
end
local function watchEarlyIntroGui(pg)
    if pg==earlyIntroGui then return end
    if earlyIntroConnection then earlyIntroConnection:Disconnect(); earlyIntroConnection=nil end
    earlyIntroGui=pg; table.clear(earlyIntroButtons)
    if not pg then return end
    local function index(obj) if obj:IsA("GuiButton") then earlyIntroButtons[obj]=true end end
    earlyIntroConnection=pg.DescendantAdded:Connect(index)
    for _,obj in ipairs(pg:GetDescendants()) do index(obj) end
end
local function earlyIntroVisible(obj)
    if not obj or not obj.Parent then return false end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ancestor = obj
    while ancestor and ancestor ~= pg do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
        if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
        if ancestor.Name == "BeyyNativeHub" or ancestor.Name == "NeedleEndingUI" then return false end
        ancestor = ancestor.Parent
    end
    return ancestor == pg and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end
local function findEarlyIntroSkip()
    if LocalPlayer:GetAttribute("IntroCutsceneFinished") == true or LocalPlayer:GetAttribute("NeedleOwned") == true then return nil end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    watchEarlyIntroGui(pg)
    if not pg then return nil end
    for obj in pairs(earlyIntroButtons) do
        if not obj.Parent then earlyIntroButtons[obj]=nil
        elseif earlyIntroVisible(obj) then
            local context = obj.Name:lower()
            if obj:IsA("TextButton") then context = context .. " " .. obj.Text:lower() end
            for _,child in ipairs(obj:GetDescendants()) do
                if child:IsA("TextLabel") then context = context .. " " .. child.Text:lower() end
            end
            local ancestor = obj.Parent
            while ancestor and ancestor ~= pg do
                context = context .. " " .. ancestor.Name:lower()
                ancestor = ancestor.Parent
            end
            if context:find("skip",1,true) and not context:find("ending",1,true)
                and not context:find("outro",1,true) and not context:find("replay",1,true) then return obj end
        end
    end
end
task.spawn(function()
    local deadline = os.clock() + 20
    local lastAttempt = -math.huge
    while earlyIntroRunning and os.clock() < deadline do
        if LocalPlayer:GetAttribute("IntroCutsceneFinished") == true then break end
        pcall(function()
            local btn = findEarlyIntroSkip()
            earlyIntroPending = btn ~= nil
            if not btn or os.clock() - lastAttempt < 0.2 then return end
            lastAttempt = os.clock()
            -- Signals avoid an overlapping startup menu when supported.
            if type(firesignal) == "function" then
                pcall(function() firesignal(btn.Activated) end)
                pcall(function() firesignal(btn.MouseButton1Click) end)
                task.wait(0.05)
            end
            if not earlyIntroRunning or not earlyIntroVisible(btn)
                or LocalPlayer:GetAttribute("IntroCutsceneFinished") == true then return end
            local inset = GuiService:GetGuiInset()
            local pos,size = btn.AbsolutePosition,btn.AbsoluteSize
            local x,y = pos.X+size.X/2+inset.X,pos.Y+size.Y/2+inset.Y
            VirtualInputManager:SendMouseMoveEvent(x,y,game)
            local pressed = false
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0)
                pressed = true
                task.wait(0.03)
            end)
            if pressed then pcall(function() VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0) end) end
        end)
        task.wait(0.05)
    end
    stopEarlyIntro()
end)

end -- intro private state remains captured by its callbacks

local selectCollectHay,stopCollectHay=createPitchforkSelector(false,true)
local selectDroppedHay,stopDroppedHay=createPitchforkSelector(true,false,{FolderName="DroppedHay",ObjectId=true,Range=28,ReturnObject=true,Recursive=false,AllowContainers=true})
local selectCollectGem,stopCollectGem=createPitchforkSelector(true,false,{FolderName="GemsClient",IdName="GemId",Range=35,Recursive=false,PartIdOnly=true})
local replayStatus
local replayStatusText="Waiting for results"
local function setReplayStatus(text)
    replayStatusText=text
    if replayStatus then replayStatus:SetDesc(text) end
end
local function createAutoUpgradeRuntime(options)
    local config, configModule, pending
    local tracks = {
        {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
        {"UpgVacRuntime","VacuumRuntime"},{"UpgTntCooldown","TntCooldown"},
        {"UpgTntPower","TntPower"},{"UpgTntLuck","TntLuck"},
        {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
        {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
        {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
    }
    local function status(text) options.Status(text) end
    local function level(name) return tonumber(options.Player:GetAttribute("HayUpgrade"..name)) or 1 end
    local function cost(name, entry)
        local price=tonumber(entry.Cost)
        if not price or price<0 or price~=price or price==math.huge then return nil end
        price*=tonumber(options.Player:GetAttribute("UpgradeCostMultiplier")) or 1
        if name:sub(1,9)=="Pitchfork" then price*=tonumber(options.Player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
        return math.round(price*100)/100
    end
    local function tick()
        local folder=options.Folder()
        local module=folder and folder:FindFirstChild("Config")
        local remote=folder and folder:FindFirstChild("BuyUpgrade")
        if not module or not remote or not remote:IsA("RemoteEvent") then status("Waiting for upgrade config / remote"); return end
        if configModule~=module or not config then
            local loaded=require(module)
            assert(type(loaded)=="table" and type(loaded.UPGRADE_TRACKS)=="table","Invalid upgrade config")
            config,configModule=loaded,module
            if options.OnConfig then options.OnConfig(loaded) end
        end
        if pending then
            if level(pending.Name)~=pending.Level or not options.State[pending.Flag] then pending=nil
            elseif os.clock()<pending.Until then status("Waiting for "..pending.Name.." purchase confirmation"); return
            else
                status("Server did not confirm "..pending.Name.."; retrying")
                pending=nil
                return
            end
        end
        local cash=tonumber(options.Cash()) or 0
        local selected, available, vacuum=0,{},nil
        for _,entry in ipairs(tracks) do
            if options.State[entry[1]] then
                selected+=1
                local track=config.UPGRADE_TRACKS[entry[2]]
                local current=level(entry[2])
                local nextLevel=track and track.Levels and track.Levels[current+1]
                local price=nextLevel and cost(entry[2],nextLevel)
                if price then
                    local target={Flag=entry[1],Name=entry[2],Level=current,Cost=price}
                    available[#available+1]=target
                    if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                end
            end
        end
        if selected==0 then status("No cash upgrades enabled"); return end
        if #available==0 then status("Selected cash upgrades are maxed or unavailable"); return end
        local target
        if vacuum and cash>=vacuum.Cost*0.75 then
            if cash<vacuum.Cost then status(string.format("Saving for %s: $%.2f / $%.2f",vacuum.Name,cash,vacuum.Cost)); return end
            target=vacuum
        else
            for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
        end
        if not target then
            local cheapest=available[1]
            for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
            status(string.format("Waiting for cash: $%.2f / $%.2f (%s)",cash,cheapest.Cost,cheapest.Name)); return
        end
        remote:FireServer(target.Name)
        pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Until=os.clock()+3}
        status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
    end
    return {Tick=function()
        local ok,err=pcall(tick)
        if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
    end}
end

local function createTntRetryGate(getRemote, getCooldown)
    local remote, connection
    local alive, nextLightAt, phase, expiresAt = true, 0, nil, 0
    local function cooldown()
        local value=tonumber(getCooldown())
        return value and value==value and value>0 and value<math.huge and value or 20
    end
    local function bind()
        if not alive then return false end
        local current=getRemote()
        if not current or not current:IsA("RemoteEvent") then return false end
        if current~=remote then
            if connection then connection:Disconnect() end
            remote=current; phase=nil; nextLightAt=0
            connection=remote.OnClientEvent:Connect(function(action,value)
                local now=os.clock()
                if action=="denied" then
                    local remaining=tonumber(value)
                    if not remaining or remaining~=remaining or remaining<0 or remaining==math.huge then remaining=1 end
                    nextLightAt=now+remaining+0.05
                    phase=nil
                elseif action=="lit" then
                    nextLightAt=now+cooldown()+0.05
                    if phase=="waiting" then
                        phase="lit"
                        local fuse=tonumber(value)
                        expiresAt=now+((fuse and fuse>0 and fuse<math.huge) and fuse or 2.9)
                    end
                end
            end)
        end
        return true
    end
    local gate={}
    function gate.Remaining() return math.max(0,nextLightAt-os.clock()) end
    function gate.Ready() return bind() and os.clock()>=nextLightAt end
    function gate.Light()
        if not gate.Ready() then return false end
        phase="waiting"
        nextLightAt=os.clock()+cooldown()+0.05 -- Lost acknowledgements must not cause rapid retries.
        local ok=pcall(remote.FireServer,remote,"light")
        if not ok then phase=nil;nextLightAt=os.clock()+1;return false end
        local deadline=os.clock()+2
        while alive and phase=="waiting" and os.clock()<deadline do task.wait(0.03) end
        if not alive or phase~="lit" then phase=nil;return false end
        task.wait(0.4)
        return alive and phase=="lit" and os.clock()<expiresAt
    end
    function gate.Throw(...)
        if not alive or phase~="lit" or os.clock()>=expiresAt then return false end
        phase=nil -- Exactly one throw for a confirmed lighting request.
        return pcall(remote.FireServer,remote,"throw",...)
    end
    function gate.Stop()
        alive=false;phase=nil
        if connection then connection:Disconnect();connection=nil end
    end
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        gate.Stop()
        if previous then pcall(previous) end
    end
    bind()
    return gate
end

local function createVacuumUpgradePriority(state, getConfig, getCash, getLevel, send)
    local pending
    local function nextVacuum()
        local config=getConfig()
        local tracks=config and config.UPGRADE_TRACKS
        if not tracks then return nil end
        local best
        for _,entry in ipairs({{Flag="UpgVacPower",Name="VacuumPower"},{Flag="UpgVacCooling",Name="VacuumCooling"}}) do
            if state[entry.Flag] then
                local track=tracks[entry.Name]
                local level=getLevel(entry.Name)
                local nextLevel=track and track.Levels and track.Levels[level+1]
                local cost=nextLevel and tonumber(nextLevel.Cost or 0)
                if cost then cost=math.round(cost*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)*100)/100 end
                if cost and cost>=0 and cost<math.huge and (not best or cost<best.Cost) then
                    best={Name=entry.Name,Level=level,Cost=cost}
                end
            end
        end
        return best
    end
    local function awaiting()
        if pending and (getLevel(pending.Name)~=pending.Level or os.clock()>=pending.Until) then pending=nil end
        return pending~=nil
    end
    local priority={}
    function priority.Reserve()
        if awaiting() then return true end
        local target=nextVacuum()
        return target~=nil and (tonumber(getCash()) or 0)>=target.Cost*0.75
    end
    function priority.Purchase()
        if awaiting() then return false end
        local target=nextVacuum()
        if not target or (tonumber(getCash()) or 0)<target.Cost then return false end
        if send(target.Name) then
            pending={Name=target.Name,Level=target.Level,Until=os.clock()+2}
            return true
        end
        return false
    end
    return priority
end

local function watchVacuumFocus(onTransition)
    local alive,generation,resumeAt=true,0,0
    local function changed()
        if not alive then return end
        generation+=1
        resumeAt=os.clock()+0.25
        onTransition()
    end
    local connections={}
    if BEYY_CHAPTER~="Lobby" then
        connections[1]=UserInputService.WindowFocused:Connect(changed)
        connections[2]=UserInputService.WindowFocusReleased:Connect(changed)
    end
    return {
        Generation=function() return generation end,
        Ready=function() return alive and os.clock()>=resumeAt end,
        Stop=function()
            alive=false
            for _,connection in ipairs(connections) do connection:Disconnect() end
            table.clear(connections)
        end,
    }
end

local function createVacuumHeatWatchdog()
    local running,lastHeat,lastProgress,lastPeak=false,nil,0,nil
    local watchdog={}
    function watchdog.Start(heat)
        running=true;lastHeat=heat;lastPeak=heat;lastProgress=os.clock()
    end
    function watchdog.Stop() running=false;lastHeat=nil;lastPeak=nil end
    function watchdog.Check(heat)
        if not running or type(heat)~="number" or heat~=heat then return nil end
        local previous=lastHeat
        if lastPeak==nil or heat>lastPeak+0.002 then lastProgress=os.clock();lastPeak=heat end
        lastHeat=heat
        if previous and heat<previous-0.005 then return "cooling" end
        if os.clock()-lastProgress>=4 then return "stalled" end
        return nil
    end
    return watchdog
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


local sharedAFKAtChapterEntry = safeRead(CACHE_FOLDER .. "/autofarmwins_shared.txt")
local NeedleHaystack = ReplicatedStorage:FindFirstChild("NeedleHaystack")
local IN_GAME = (NeedleHaystack ~= nil)
print("[BeyyHub] IN_GAME = ".. tostring(IN_GAME))

local State = {}
local Registry = {}
local Unloaded = false
local cutsceneBypassActive = false

_G.__BEYY_HUB_CLEANUP = function()
    print("[BeyyHub] Cleanup requested by new session")
    Unloaded = true
end

local function defaultState()
    return {
        AutoPickHay = false, AutoCollectDroppedHay = false, AutoCollectGems = false,
        CollectInterval = 0.5,
        AutoSellHay = false, SellThreshold = 25, SellOnlyIfFull = false,
        AutoUseTNT = false, AutoUsePitchfork = false, AutoDeployDrone = false,
        AutoUseVacuum = false, AutoFarmVacuum = true, VacuumHotbarSlot = 5,
        ToolInterval = 0.5,
        AutoFindNeedle = false, AutoPickupNeedle = false, AutoHandInNeedle = false,
        NeedleInterval = 1.0,
        AutoBuyTools = false, BuyToolsList = { "Pitchfork" }, BuyInterval = 1.0,
        UpgBagSize = false, UpgExtraTake = false, UpgGemValue = false, UpgHayValue = false,
        PermInterval = 1.0,
        UpgCapacity = false, UpgHandSpeed = false, UpgHandGrab = false, UpgHandHold = false,
        UpgTntLuck = false, UpgTntCooldown = false, UpgTntPower = false,
        UpgPitchCooldown = false, UpgPitchHold = false, UpgPitchSweep = false,
        UpgDroneSpeed = false, UpgDroneGrab = false, UpgDroneCapacity = false,
        UpgVacPower = false, UpgVacCooling = false, UpgVacRuntime = false,
        AutoFarmWins = false,
    }
end

State = defaultState()

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

-- Beyy native UI. Embedded into each module; no remote UI dependency.
local function createNativeUI()
    local UI = {}
    local input = game:GetService("UserInputService")
    local run = game:GetService("RunService")
    local http = game:GetService("HttpService")
    local colors = {bg=Color3.fromRGB(20,22,27), row=Color3.fromRGB(32,35,42), text=Color3.fromRGB(231,234,240), accent=Color3.fromRGB(58,104,153)}
    local function node(class, parent, props)
        local obj = Instance.new(class)
        for k,v in pairs(props or {}) do obj[k]=v end
        obj.Parent=parent
        return obj
    end
    local function label(parent, text, height)
        return node("TextLabel", parent, {Size=UDim2.new(1,0,0,height or 24), BackgroundTransparency=1, Text=tostring(text or ""), TextColor3=colors.text, TextSize=14, Font=Enum.Font.SourceSans, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left})
    end
    local function button(parent,text,size,pos)
        return node("TextButton",parent,{Size=size or UDim2.new(1,0,0,28),Position=pos or UDim2.new(),BackgroundColor3=colors.row,BorderSizePixel=0,AutoButtonColor=false,Text=tostring(text or ""),TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans})
    end
    local function layout(parent)
        node("UIListLayout",parent,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        node("UIPadding",parent,{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
    end
    local function configManager(folder)
        local manager={Path="WindUI/"..folder.."/config/"}
        if type(makefolder)=="function" then
            for _,path in ipairs({"WindUI","WindUI/"..folder,manager.Path}) do
                pcall(function() if type(isfolder)~="function" or not isfolder(path) then makefolder(path) end end)
            end
        end
        function manager:AllConfigs()
            local names={}
            if type(listfiles)=="function" then
                local ok,files=pcall(listfiles,self.Path)
                if ok then for _,path in ipairs(files) do local name=path:match("([^/\\]+)%.json$"); if name then table.insert(names,name) end end end
            end
            return names
        end
        function manager:CreateConfig(name)
            assert(type(name)=="string" and name~="" and not name:find("[/\\]"),"Invalid config name")
            local cfg={Path=self.Path..name..".json",Elements={},CustomData={},Version=1.2,AutoLoad=false}
            function cfg:Register(key,el) self.Elements[key]=el end
            function cfg:Save()
                assert(type(writefile)=="function","Config saving requires writefile")
                local saved={__version=self.Version,__elements={},__custom=self.CustomData,__autoload=self.AutoLoad}
                for key,el in pairs(self.Elements) do
                    local value=el.Value
                    if el.__type=="Slider" then value=value.Default end
                    saved.__elements[key]={__type=el.__type,value=value}
                end
                writefile(self.Path,http:JSONEncode(saved))
                return saved
            end
            function cfg:Load()
                if type(readfile)~="function" then return false,"Config loading requires readfile" end
                local ok,data=pcall(function() return http:JSONDecode(readfile(self.Path)) end)
                if not ok or type(data)~="table" then return false,"Failed to read config" end
                for key,entry in pairs(data.__elements or data) do
                    local el=self.Elements[key]
                    if el and type(entry)=="table" and entry.__type==el.__type then
                        if el.__type=="Dropdown" then el:Select(entry.value) else el:Set(entry.value) end
                    end
                end
                self.CustomData=data.__custom or {}
                return self.CustomData
            end
            return cfg
        end
        return manager
    end
    function UI:Notify(options)
        if self.Window and not self.Window.Destroyed then
            local text=tostring(options.Title or "Beyy")..": "..tostring(options.Content or "")
            if self.Window.Notice.Text~=text then self.Window.Notice.Text=text end
        end
    end
    function UI:CreateWindow(options)
        local w={Closed=false,Destroyed=false,Connections={},Tabs={},ToggleKey=Enum.KeyCode.RightControl}
        self.Window=w
        local parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        if type(gethui)=="function" then local ok,value=pcall(gethui); if ok and value then parent=value end end
        local gui=node("ScreenGui",parent,{Name="BeyyNativeHub",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
        w.Gui=gui
        local root=node("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(640,480),BackgroundColor3=colors.bg,BorderSizePixel=0})
        node("UISizeConstraint",root,{MaxSize=Vector2.new(640,480),MinSize=Vector2.new(320,240)})
        -- UIScale keeps the fixed panel inside small screens, without layout animation.
        local scale=node("UIScale",root,{Scale=1})
        local function fit()
            local viewport=gui.AbsoluteSize
            scale.Scale=math.min(1,math.max(.1,(viewport.X-12)/640),math.max(.1,(viewport.Y-12)/480))
        end
        local function connect(signal,fn) local c=signal:Connect(fn); table.insert(w.Connections,c); return c end
        connect(gui:GetPropertyChangedSignal("AbsoluteSize"),fit); fit()
        local title=label(root,options.Title or "Beyy Hub",30); title.Position=UDim2.fromOffset(10,0); title.Size=UDim2.new(1,-48,0,30)
        title.Active=true
        local dragInput,dragX,dragY,dragPosition
        connect(title.InputBegan,function(event)
            if w.Closed or dragInput then return end
            if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
                dragInput=event; dragX=event.Position.X; dragY=event.Position.Y; dragPosition=root.Position
            end
        end)
        connect(input.InputChanged,function(event)
            if not dragInput or w.Closed then return end
            local mouse=dragInput.UserInputType==Enum.UserInputType.MouseButton1
            if (mouse and event.UserInputType~=Enum.UserInputType.MouseMovement) or (not mouse and event~=dragInput) then return end
            local viewport=gui.AbsoluteSize
            local halfWidth,halfHeight=320*scale.Scale,240*scale.Scale
            local x=dragPosition.X.Scale*viewport.X+dragPosition.X.Offset+event.Position.X-dragX
            local y=dragPosition.Y.Scale*viewport.Y+dragPosition.Y.Offset+event.Position.Y-dragY
            x=math.clamp(x,halfWidth,math.max(halfWidth,viewport.X-halfWidth))
            y=math.clamp(y,halfHeight,math.max(halfHeight,viewport.Y-halfHeight))
            root.Position=UDim2.new(dragPosition.X.Scale,x-dragPosition.X.Scale*viewport.X,dragPosition.Y.Scale,y-dragPosition.Y.Scale*viewport.Y)
        end)
        connect(input.InputEnded,function(event)
            if event==dragInput or (dragInput and dragInput.UserInputType==Enum.UserInputType.MouseButton1 and event.UserInputType==Enum.UserInputType.MouseButton1) then dragInput=nil end
        end)
        local close=button(root,"X",UDim2.fromOffset(28,24),UDim2.new(1,-34,0,3))
        local sidebar=node("ScrollingFrame",root,{Position=UDim2.fromOffset(0,34),Size=UDim2.new(0,180,1,-72),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
        layout(sidebar)
        w.Notice=label(root,"",32); w.Notice.Position=UDim2.new(0,10,1,-34); w.Notice.Size=UDim2.new(1,-20,0,32)
        local bind="BeyyNativeCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
        local cursorBound
        local function releaseCursor()
            if cursorBound then return end
            cursorBound=true
            run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+100,function()
                input.MouseBehavior=Enum.MouseBehavior.Default; input.MouseIconEnabled=true
            end)
        end
        local function restoreCursor()
            if not cursorBound then return end
            run:UnbindFromRenderStep(bind); cursorBound=false
            -- Release menu ownership; Roblox's camera resumes its current mode.
            -- A saved lock may belong to an earlier cutscene or camera state.
            input.MouseBehavior=Enum.MouseBehavior.Default; input.MouseIconEnabled=true
        end
        function w:Open() if self.Destroyed then return end; self.Closed=false; gui.Enabled=true; releaseCursor() end
        function w:Close() self.Closed=true; gui.Enabled=false; self.Capture=nil; dragInput=nil; restoreCursor() end
        function w:SetToggleKey(key) self.ToggleKey=typeof(key)=="EnumItem" and key or Enum.KeyCode[tostring(key)] or Enum.KeyCode.RightControl end
        function w:EditOpenButton() end
        function w:Destroy()
            if self.Destroyed then return end
            self:Close(); self.Destroyed=true
            for _,c in ipairs(self.Connections) do c:Disconnect() end
            table.clear(self.Connections); gui:Destroy()
        end
        connect(close.Activated,function() w:Close() end)
        connect(input.InputBegan,function(event,processed)
            if w.Capture and event.UserInputType==Enum.UserInputType.Keyboard and event.KeyCode~=Enum.KeyCode.Unknown then
                local capture=w.Capture; w.Capture=nil; capture:Set(event.KeyCode.Name); return
            end
            if not processed and not input:GetFocusedTextBox() and event.KeyCode==w.ToggleKey then if w.Closed then w:Open() else w:Close() end end
        end)
        w.ConfigManager=configManager(options.Folder or "BeyyHub")
        function w:Tab(opts)
            local tab={Window=self}
            local nav=button(sidebar,opts.Title)
            local page=node("ScrollingFrame",root,{Position=UDim2.fromOffset(184,34),Size=UDim2.new(1,-190,1,-72),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false})
            layout(page)
            tab.Page=page; tab.Nav=nav; table.insert(self.Tabs,tab)
            function tab:Select() for _,other in ipairs(w.Tabs) do other.Page.Visible=other==self; other.Nav.BackgroundColor3=other==self and colors.accent or colors.row end end
            connect(nav.Activated,function() tab:Select() end)
            if #self.Tabs==1 then tab:Select() end
            local function row(opts,height)
                local frame=node("Frame",page,{Size=UDim2.new(1,-2,0,height or 42),BackgroundColor3=colors.row,BorderSizePixel=0})
                local heading=label(frame,opts.Title,24); heading.Position=UDim2.fromOffset(8,2); heading.Size=UDim2.new(1,-160,0,24)
                return frame
            end
            local function control(kind,opts,value)
                local el={__type=kind,Value=value}
                function el:Callback(v)
                    if opts.Callback then local ok,err=pcall(opts.Callback,v); if not ok then UI:Notify({Title="Control error",Content=tostring(err)}) end end
                end
                return el
            end
            function tab:Section(opts) return label(page,opts.Title,26) end
            function tab:Paragraph(opts)
                -- Static help paragraphs are omitted; live status panels remain.
                local live=opts.Title=="Session" or tostring(opts.Title):find("Status",1,true)~=nil
                if not live and opts.Title~="Configs unavailable" then
                    return {SetDesc=function() end,SetTitle=function() end}
                end
                local frame=node("Frame",page,{Size=UDim2.new(1,-2,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
                layout(frame)
                local heading=label(frame,opts.Title); heading.AutomaticSize=Enum.AutomaticSize.Y
                local desc=label(frame,live and opts.Desc or ""); desc.AutomaticSize=Enum.AutomaticSize.Y
                local el={}
                function el:SetDesc(v) local text=tostring(v or ""); if desc.Text~=text then desc.Text=text end end
                function el:SetTitle(v) local text=tostring(v or ""); if heading.Text~=text then heading.Text=text end end
                return el
            end
            function tab:Button(opts)
                local b=button(page,opts.Title)
                connect(b.Activated,function() if opts.Callback then local ok,err=pcall(opts.Callback); if not ok then UI:Notify({Title="Action error",Content=tostring(err)}) end end end)
                return b
            end
            function tab:Toggle(opts)
                local el=control("Toggle",opts,opts.Value==true)
                local frame=row(opts); local b=button(frame,"",UDim2.fromOffset(100,28),UDim2.new(1,-108,0,5))
                local function redraw() b.Text=el.Value and "ON" or "OFF"; b.BackgroundColor3=el.Value and colors.accent or colors.bg end
                function el:Set(v) self.Value=v==true; redraw(); self:Callback(self.Value) end
                connect(b.Activated,function() el:Set(not el.Value) end); redraw(); return el
            end
            function tab:Slider(opts)
                local spec=opts.Value or {}; local el=control("Slider",opts,{Min=spec.Min or 0,Max=spec.Max or 100,Default=spec.Default or 0})
                local frame=row(opts); local field=node("TextBox",frame,{Size=UDim2.fromOffset(64,28),Position=UDim2.new(1,-100,0,5),Text=tostring(el.Value.Default),BackgroundColor3=colors.bg,TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans,ClearTextOnFocus=false})
                function el:Set(v)
                    local n=tonumber(v); if not n then field.Text=tostring(self.Value.Default); return end
                    local step=tonumber(opts.Step) or 1
                    if step>0 then n=self.Value.Min+math.round((n-self.Value.Min)/step)*step end
                    self.Value.Default=math.clamp(n,self.Value.Min,self.Value.Max); field.Text=tostring(self.Value.Default); self:Callback(self.Value.Default)
                end
                local minus=button(frame,"-",UDim2.fromOffset(26,28),UDim2.new(1,-130,0,5)); local plus=button(frame,"+",UDim2.fromOffset(26,28),UDim2.new(1,-32,0,5))
                connect(minus.Activated,function() el:Set(el.Value.Default-(opts.Step or 1)) end)
                connect(plus.Activated,function() el:Set(el.Value.Default+(opts.Step or 1)) end)
                connect(field.FocusLost,function() el:Set(field.Text) end); return el
            end
            function tab:Input(opts)
                local el=control("Input",opts,tostring(opts.Value or "")); local frame=row(opts,70)
                local field=node("TextBox",frame,{Position=UDim2.fromOffset(8,32),Size=UDim2.new(1,-16,0,28),Text=el.Value,PlaceholderText=opts.Placeholder or "",BackgroundColor3=colors.bg,TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans,ClearTextOnFocus=false})
                function el:Set(v) self.Value=tostring(v or ""); field.Text=self.Value; self:Callback(self.Value) end
                connect(field.FocusLost,function() el:Set(field.Text) end); return el
            end
            function tab:Keybind(opts)
                local initial=opts.Value or "RightControl"; if typeof(initial)=="EnumItem" then initial=initial.Name end
                local el=control("Keybind",opts,initial); local frame=row(opts)
                local b=button(frame,initial,UDim2.fromOffset(140,28),UDim2.new(1,-148,0,5))
                function el:Set(v) self.Value=typeof(v)=="EnumItem" and v.Name or tostring(v); b.Text=self.Value; self:Callback(self.Value) end
                connect(b.Activated,function() w.Capture=el; b.Text="Press a key" end); return el
            end
            function tab:Dropdown(opts)
                local el=control("Dropdown",opts,opts.Value or (opts.Multi and {} or ""))
                local frame=row(opts); local b=button(frame,"",UDim2.fromOffset(140,28),UDim2.new(1,-148,0,5))
                local choices=node("ScrollingFrame",page,{Size=UDim2.new(1,-2,0,160),Visible=false,BackgroundColor3=colors.bg,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y}); layout(choices)
                local choiceButtons={}; local choiceConnections={}
                local function selected(value) if type(el.Value)~="table" then return el.Value==value end; for k,v in pairs(el.Value) do if v==value or (k==value and v==true) then return true end end; return false end
                local function redraw()
                    local values={}; if type(el.Value)=="table" then for k,v in pairs(el.Value) do table.insert(values,tostring(v==true and k or v)) end else table.insert(values,tostring(el.Value)) end
                    b.Text=#values>0 and table.concat(values,", ") or "Choose"
                    for value,cb in pairs(choiceButtons) do cb.Text=(selected(value) and "[x] " or "[ ] ")..tostring(value) end
                end
                function el:Select(v) self.Value=opts.Multi and (type(v)=="table" and table.clone(v) or {v}) or v; redraw(); self:Callback(self.Value) end
                el.Set=el.Select
                function el:Refresh(values)
                    for _,c in ipairs(choiceConnections) do
                        c:Disconnect()
                        local index=table.find(w.Connections,c)
                        if index then table.remove(w.Connections,index) end
                    end
                    table.clear(choiceConnections)
                    for _,cb in pairs(choiceButtons) do cb:Destroy() end; table.clear(choiceButtons)
                    for _,value in ipairs(values or {}) do
                        local cb=button(choices,tostring(value)); choiceButtons[value]=cb
                        local c=cb.Activated:Connect(function()
                            if opts.Multi then
                                local nextValues={}; for _,candidate in ipairs(values) do if (candidate==value and not selected(candidate)) or (candidate~=value and selected(candidate)) then table.insert(nextValues,candidate) end end
                                el:Select(nextValues)
                            else el:Select(value); choices.Visible=false end
                        end)
                        table.insert(choiceConnections,c); table.insert(w.Connections,c)
                    end
                    redraw()
                end
                connect(b.Activated,function() choices.Visible=not choices.Visible end); el:Refresh(opts.Values); return el
            end
            return tab
        end
        function w:Section(opts)
            label(sidebar,opts.Title,24)
            local group={}; function group:Tab(tabOpts) return w:Tab(tabOpts) end
            return group
        end
        w:Open()
        return w
    end
    return UI
end
local NativeUI = createNativeUI()

local Window = NativeUI:CreateWindow({
    Title = "Search For The Needle v103.00",
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
print("[BeyyHub] Window created")
pcall(function() Window:SetToggleKey(Enum.KeyCode.RightControl) end)
pcall(function() Window:EditOpenButton({ Enabled = false }) end)

local function closeMenuOnStartup()
    if Unloaded then return false end
    if Window.Closed then return true end
    local ok, err = pcall(function() Window:Close() end)
    if not ok then
        warn("[BeyyHub] Startup close failed: " .. tostring(err))
        return false
    end
    print("[BeyyHub] Entire menu minimized immediately (RightControl to reopen)")
    return true
end

closeMenuOnStartup()
local menuCursorCleanup = function() Window:Destroy() end
local previousMenuCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    if menuCursorCleanup then pcall(menuCursorCleanup) end
    if previousMenuCleanup then pcall(previousMenuCleanup) end
end

local ConfigManager = Window.ConfigManager

local function Notify(title, content, duration, icon)
    pcall(function()
        NativeUI:Notify({ Title = title, Content = content, Duration = duration or 3, Icon = icon })
    end)
end

local function Header(tab, title)
    pcall(function() tab:Section({ Title = title }) end)
end

local function Info(tab, text)
    return tab:Paragraph({ Title = text })
end

local SAVE_WHITELIST = {
    AutoRoundFailsafe = true,
    AutoPickHay = true, AutoCollectDroppedHay = true, AutoCollectGems = true,
    CollectInterval = true,
    AutoSellHay = true, SellThreshold = true, SellOnlyIfFull = true,
    AutoUseTNT = true, AutoUsePitchfork = true, AutoDeployDrone = true,
    AutoUseVacuum = true, AutoFarmVacuum = true, VacuumHotbarSlot = true,
    ToolInterval = true,
    AutoFindNeedle = true, AutoPickupNeedle = true, AutoHandInNeedle = true,
    NeedleInterval = true,
    AutoBuyTools = true, BuyToolsList = true, BuyInterval = true,
    UpgBagSize = true, UpgExtraTake = true, UpgGemValue = true, UpgHayValue = true,
    PermInterval = true,
    UpgCapacity = true, UpgHandSpeed = true, UpgHandGrab = true, UpgHandHold = true,
    UpgTntLuck = true, UpgTntCooldown = true, UpgTntPower = true,
    UpgPitchCooldown = true, UpgPitchHold = true, UpgPitchSweep = true,
    UpgDroneSpeed = true, UpgDroneGrab = true, UpgDroneCapacity = true,
    UpgVacPower = true, UpgVacCooling = true, UpgVacRuntime = true,
    AutoFarmWins = true,
}

local function AddToggle(tab, key, title, default, desc, callback)
    State[key] = default and true or false
    local el = tab:Toggle({
        Title = title, Desc = desc, Value = State[key],
        Callback = function(v)
            State[key] = v
            if callback then pcall(callback, v) end
        end,
    })
    if SAVE_WHITELIST[key] then Registry[key] = el end
    return el
end

local function AddSlider(tab, key, title, min, max, default, step, desc)
    State[key] = default
    local el = tab:Slider({
        Title = title, Desc = desc, Step = step or 1,
        Value = { Min = min, Max = max, Default = default },
        Callback = function(v) State[key] = tonumber(v) or default end,
    })
    if SAVE_WHITELIST[key] then Registry[key] = el end
    return el
end

local GameConfig, UpgradeConfig
local BuyUpgrade, BuyShopItem, PickHay, PickDroppedHay, SellHay
local CollectGem, DeployDrone, PitchforkDig, TntAction, NeedleHandIn

if IN_GAME then
    GameConfig = require(NeedleHaystack:WaitForChild("Config"))
    UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("UpgradeConfig"))
    BuyUpgrade = NeedleHaystack:WaitForChild("BuyUpgrade")
    BuyShopItem = NeedleHaystack:WaitForChild("BuyShopItem")
    PickHay = NeedleHaystack:WaitForChild("PickHay")
    PickDroppedHay = NeedleHaystack:WaitForChild("PickDroppedHay")
    SellHay = NeedleHaystack:WaitForChild("SellHay")
    CollectGem = NeedleHaystack:WaitForChild("CollectGem")
    DeployDrone = NeedleHaystack:WaitForChild("DeployDrone")
    PitchforkDig = NeedleHaystack:WaitForChild("PitchforkDig")
    TntAction = NeedleHaystack:WaitForChild("TntAction")
    NeedleHandIn = NeedleHaystack:WaitForChild("NeedleHandIn")
end

local HayFolder = Workspace:FindFirstChild("HaystackClient")
local DroppedFolder = Workspace:FindFirstChild("DroppedHay")
local GemsFolder = Workspace:FindFirstChild("GemsClient")

task.spawn(function()
    while not Unloaded do
        task.wait(5)
        if not HayFolder or not HayFolder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient") end
        if not DroppedFolder or not DroppedFolder.Parent then DroppedFolder = Workspace:FindFirstChild("DroppedHay") end
        if not GemsFolder or not GemsFolder.Parent then GemsFolder = Workspace:FindFirstChild("GemsClient") end
    end
end)

local function getCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    return cash and cash.Value or 0
end

local function getGems() return tonumber(LocalPlayer:GetAttribute("Gems")) or 0 end
local function getHayHeld() return tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0 end
local function getHayCapacity() return tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25 end
local function owns(attr) return LocalPlayer:GetAttribute(attr) == true end
local function isBagFull() return getHayHeld() >= getHayCapacity() end

local HayCache = { part = nil, id = nil, time = 0, ttl = 1.5 }

local function findHayById(hayId)
    if not hayId then return nil end
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return nil end
    for _, inst in ipairs(folder:GetChildren()) do
        if inst:IsA("BasePart") and inst:GetAttribute("HayId") == hayId then return inst end
    end
    return nil
end

local function findClosestHayCached()
    return selectCollectHay(function() return not Unloaded and (State.AutoPickHay or State.AutoFindNeedle) end,HayCache.ttl)
end

local function isPileHay(part)
    if not part or not part:IsA("BasePart") or part:GetAttribute("HayId") == nil then return false end
    if part:GetAttribute("IsHeld") == true or part:GetAttribute("Held") == true then return false end
    local character = LocalPlayer.Character
    local parent = part
    for _ = 1, 10 do
        if not parent then break end
        if character and parent == character then return false end
        if parent:IsA("Tool") or parent:IsA("Accessory") then return false end
        parent = parent.Parent
    end
    return true
end

local function getHaystackCenter()
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return nil end
    local sumPos = Vector3.zero
    local count = 0
    for _, inst in ipairs(folder:GetChildren()) do
        if inst:IsA("BasePart") and inst:GetAttribute("HayId") then
            local p = inst.Parent
            local isHeld = false
            local hops = 0
            while p and hops < 6 do
                if p == LocalPlayer.Character then isHeld = true; break end
                if p:IsA("Tool") or p:IsA("Accessory") then isHeld = true; break end
                p = p.Parent
                hops = hops + 1
            end
            if not isHeld then
                sumPos = sumPos + inst.Position
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return sumPos / count
end

local function getGrabCandidates(centerPart, radiusHint)
    if not centerPart then return {} end
    local radius = radiusHint or tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
    if radius <= 0 then return {} end
    local out = {}
    local cp = centerPart.Position
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return out end
    for _, inst in budgetedFolderChildren(folder,function() return not Unloaded and centerPart.Parent~=nil and (State.AutoPickHay or State.AutoFindNeedle) end) do
        if inst ~= centerPart and inst:IsA("BasePart") and inst:GetAttribute("HayId") then
            if (inst.Position - cp).Magnitude <= radius + 1 then
                table.insert(out, inst:GetAttribute("HayId"))
                if #out >= 6 then break end
            end
        end
    end
    return out
end

local DroppedCache = { part = nil, time = 0, ttl = 1.5 }

local function findClosestDroppedCached()
    return selectDroppedHay(function() return not Unloaded and State.AutoCollectDroppedHay end)
end

local GemsCache = { part = nil, id = nil, time = 0, ttl = 1.5 }

local function findClosestGemCached()
    return selectCollectGem(function() return not Unloaded and State.AutoCollectGems end,GemsCache.ttl)
end

local needlePickupActive = false
local autoUiMouseBusy = false

local introSkipPending = false
local function guiReallyVisible(obj)
    if not obj then return false end
    local node = obj
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        if node:IsA("PlayerGui") then return true end
        node = node.Parent
    end
    return false
end
local function roundEndingVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    local results = ending and ending:FindFirstChild("ReturnToLobby")
    return guiReallyVisible(results)
end
local lastNeedleDiagnostic=-math.huge
local function recordNeedleDiagnostic(needle)
    if os.clock()-lastNeedleDiagnostic<60 then return end
    lastNeedleDiagnostic=os.clock()
    task.spawn(function()
        local ok,err=pcall(function()
            local function describe(obj)
                local attributes={}
                for key,value in pairs(obj:GetAttributes()) do attributes[key]={Type=typeof(value),Value=tostring(value)} end
                return {Path=obj:GetFullName(),Class=obj.ClassName,Attributes=attributes}
            end
            local report={PlayerAttributes=describe(LocalPlayer).Attributes,Target=describe(needle),Parents={},EquippedTools={},ClientCandidates={}}
            local position=needle.Position
            local ancestor=needle.Parent
            for i=1,5 do
                if not ancestor or ancestor==Workspace then break end
                report.Parents[#report.Parents+1]=describe(ancestor)
                ancestor=ancestor.Parent
            end
            local character=LocalPlayer.Character
            if character then for _,obj in ipairs(character:GetChildren()) do if obj:IsA("Tool") then report.EquippedTools[#report.EquippedTools+1]=describe(obj) end end end
            local folder=Workspace:FindFirstChild("HaystackClient")
            if folder then
                for _,part in budgetedFolderChildren(folder,function() return not Unloaded end,true) do
                    if part:IsA("BasePart") and (part:GetAttribute("IsNeedleObjective")==true or (part.Position-position).Magnitude<=0.5) then
                        local entry=describe(part);entry.Distance=(part.Position-position).Magnitude
                        report.ClientCandidates[#report.ClientCandidates+1]=entry
                        if #report.ClientCandidates>=20 then break end
                    end
                end
            end
            local json=game:GetService("HttpService"):JSONEncode(report)
            _G.__BEYY_NEEDLE_DIAGNOSTIC=json
            if type(writefile)=="function" then pcall(writefile,"BeyyHub/needle_diagnostic.json",json) end
            warn("[Needle Diagnostic] Target "..report.Target.Path.."; full report in BeyyHub/needle_diagnostic.json or _G.__BEYY_NEEDLE_DIAGNOSTIC")
        end)
        if not ok then warn("[Needle Diagnostic] Capture failed: "..tostring(err)) end
    end)
end

local function resolveNeedleHayId(part)
    local server=Workspace:FindFirstChild("NeedleObjectiveServer")
    local node=part
    while node and node~=server do
        local id=node:GetAttribute("HayId")
        if type(id)=="number" then return id end
        node=node.Parent
    end
    return nil
end
local needlePickupStatus
local function setNeedlePickupStatus(text)
    if needlePickupStatus then needlePickupStatus:SetDesc(text) end
end
local lastUnusableNeedleLogAt = -math.huge
local function createObjectiveIndex()
    local current, items, positions, connections = nil, {}, {}, {}
    local function stop()
        for _,connection in ipairs(connections) do connection:Disconnect() end
        current, items, positions, connections = nil, {}, {}, {}
    end
    local function add(item)
        if item:IsA("BasePart") and not positions[item] then
            items[#items+1]=item; positions[item]=#items
        end
    end
    local function remove(item)
        local index=positions[item]
        if not index then return end
        local last=items[#items]
        items[index]=last; positions[last]=index
        items[#items]=nil; positions[item]=nil
    end
    local function get(folder)
        if folder~=current then
            stop(); current=folder
            if folder then
                connections[1]=folder.DescendantAdded:Connect(add)
                connections[2]=folder.DescendantRemoving:Connect(remove)
                for _,item in ipairs(folder:GetDescendants()) do add(item) end
            end
        end
        return items
    end
    return get,stop
end

local indexedObjectives, stopObjectiveIndex = createObjectiveIndex()
local previousObjectiveCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    stopObjectiveIndex()
    if previousObjectiveCleanup then pcall(previousObjectiveCleanup) end
end
local function findExposedNeedlePart()
    if not IN_GAME then return nil end
    local server = Workspace:FindFirstChild("NeedleObjectiveServer")
    local folder = server and server:FindFirstChild("Needle")
    if not folder then indexedObjectives(nil); return nil end
    local invalidCount, invalidIdType, physicalCandidate = 0, nil, nil
    for _, part in ipairs(indexedObjectives(folder)) do
        if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective") == true
            and part:GetAttribute("HIDDEN_WITHIN") == nil then
            local id = resolveNeedleHayId(part)
            if type(id) == "number" then return part end
            if part.CanQuery and part.Transparency<0.98 and part.LocalTransparencyModifier<0.98 then physicalCandidate=physicalCandidate or part end
            invalidCount += 1
            invalidIdType = type(id)
        end
    end
    if invalidCount > 0 and State.AutoPickupNeedle and os.clock() - lastUnusableNeedleLogAt >= 30 then
        lastUnusableNeedleLogAt = os.clock()
        warn(string.format("[Needle] %d exposed marker(s) have unusable HayId (%s); using verified physical-click fallback when the objective is visible", invalidCount, tostring(invalidIdType)))
    end
    return physicalCandidate
end
local function needleHasPriority()
    if Unloaded or not IN_GAME then return false end
    if roundEndingVisible() then return false end
    if needlePickupActive then return true end
    if LocalPlayer:GetAttribute("NeedleOwned") == true then
        return State.AutoPickupNeedle or State.AutoHandInNeedle
    end
    if not State.AutoPickupNeedle then return false end
    return findExposedNeedlePart() ~= nil
end

local function trySell()
    if needleHasPriority() then return end
    pcall(function() SellHay:FireServer() end)
    task.spawn(function()
        local before = getHayHeld()
        task.wait(0.6)
        if not needleHasPriority() and before > 0 and getHayHeld() == before then
            pcall(function() SellHay:FireServer() end)
        end
    end)
end

local vacuumUpgradePriority=createVacuumUpgradePriority(State,function() return GameConfig end,getCash,
    function(name) return tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1 end,
    function(name) return pcall(function() BuyUpgrade:FireServer(name) end) end)
local function tryBuyTrack(trackName)
    if not IN_GAME or not GameConfig then return end
    if trackName=="VacuumPower" or trackName=="VacuumCooling" then vacuumUpgradePriority.Purchase(); return end
    if vacuumUpgradePriority.Reserve() then return end
    local track = GameConfig.UPGRADE_TRACKS[trackName]
    if not track then return end
    local cur = tonumber(LocalPlayer:GetAttribute("HayUpgrade"..trackName)) or 1
    if cur >= #track.Levels then return end
    local nxt = track.Levels[cur + 1]
    if not nxt then return end
    if getCash() >= (nxt.Cost or 0) then
        pcall(function() BuyUpgrade:FireServer(trackName) end)
    end
end

local function tryBuyPermanent(id)
    if not IN_GAME or not UpgradeConfig then return end
    local u = UpgradeConfig.getUpgrade(id)
    if not u then return end
    local cur = tonumber(LocalPlayer:GetAttribute("Upgrade"..id)) or 0
    local max = UpgradeConfig:getMaxLevel(u)
    if cur >= max then return end
    local price = UpgradeConfig:getPrice(u, cur)
    if price and getGems() >= price then
        pcall(function() BuyUpgrade:FireServer(id) end)
    end
end

task.spawn(function()
    local wasActive = false
    while not Unloaded do
        task.wait(0.05)
        local active = needleHasPriority()
        if active ~= wasActive then
            wasActive = active
            if active then
                local reason = needlePickupActive and "pickup active" or
                    (State.AutoHandInNeedle and LocalPlayer:GetAttribute("NeedleOwned") == true and "hand-in pending" or "needle exposed")
                print("[Priority] NEEDLE FIRST: " .. reason .. "; AFK/UI clicks suspended")
            else
                print("[Priority] Needle phase ended; AFK farming resumed")
            end
        end
    end
end)

local tntTelemetry={}
function tntTelemetry.SetStatus(text)
    local message=text.." | phase: "..tostring(LocalPlayer:GetAttribute("TntPhase"))
    if message~=tntTelemetry.LastText then
        tntTelemetry.LastText=message
        if tntTelemetry.Element then tntTelemetry.Element:SetDesc(message) end
    end
end
local afkOrbitTelemetry={}
local vacuumSuctionActive = false
local function farmLoopEnabled()
    return not Unloaded and not afkOrbitTelemetry.RecoveryPending and not cutsceneBypassActive and not needleHasPriority() and not roundEndingVisible()
end

local function afkFarmModeActive()
    return State.AutoFarmWins == true and not cutsceneBypassActive
end
local function afkVacuumOrbitEnabled()
    return afkFarmModeActive() and State.AutoFarmVacuum == true
end
local function vacuumRequested()
    return State.AutoUseVacuum == true or afkVacuumOrbitEnabled()
end

local AFK_CAMERA_BIND = "BeyyV103_00AFKCamera_" .. tostring(LocalPlayer.UserId)
local AFK_ORBIT_SPEED_DEG = 48.0
local AFK_ORBIT_BANDS = {
    { name = "base-lower", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = -2.0 },
    { name = "base-lower-second-lap", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = -2.0 },
    { name = "base-lower-third-lap", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = -2.0 },
    { name = "base-lower-fourth-lap", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = -2.0 },
    { name = "base", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5 },
    { name = "base-second-lap", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5 },
    { name = "base-third-lap", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5 },
    { name = "base-fourth-lap", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5 },
    { name = "base-transition", radius = 20.0, standoff = 2.1, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 0.7 },
    { name = "lower-middle", radius = 18.0, standoff = 2.0, characterInset = 1.5, cameraLift = 5.0, focusYOffset = -0.1 },
    { name = "middle-transition", radius = 16.0, standoff = 1.95, characterInset = 1.5, cameraLift = 5.1, focusYOffset = -0.8 },
    { name = "upper-middle", radius = 14.0, standoff = 1.9, characterInset = 1.5, cameraLift = 5.2, focusYOffset = -1.5 },
    { name = "upper-transition", radius = 11.0, standoff = 1.8, characterInset = 1.0, cameraLift = 5.6, focusYOffset = -0.75 },
    { name = "peak", radius = 8.0, standoff = 1.7, cameraLift = 6.0, focusYOffset = 0.0 },
    { name = "inner-peak", radius = 5.0, standoff = 1.6, cameraLift = 6.0, focusYOffset = 0.2 },
}
local afkOrbitAngle = 0
local afkOrbitLap = 0
local afkOrbitRadius = 16

local afkSweepRadius = nil
local afkSweepSurfaceY = nil
local afkSweepFocusOffsetY = nil
local afkBandSurfaceHeights = nil
local afkCameraPileTopY = nil
local afkVacuumTargetReady = false
local function afkCurrentBand()
    return AFK_ORBIT_BANDS[(afkOrbitLap % #AFK_ORBIT_BANDS) + 1]
end
local function afkCurrentRingRadius()
    return afkCurrentBand().radius
end
local function afkCurrentRingName()
    return afkCurrentBand().name
end
local afkCameraBound = false
local afkCameraSuspended = false
local afkCameraAnchor = nil
local afkPreviousCamera = nil
local afkPreviousType = nil
local afkPreviousSubject = nil
local afkPreviousCFrame = nil

local function releaseAfkCamera()
    if afkCameraBound then
        pcall(function() RunService:UnbindFromRenderStep(AFK_CAMERA_BIND) end)
        afkCameraBound = false
    end
    afkCameraSuspended = false
    if afkPreviousCamera and afkPreviousCamera.Parent then
        pcall(function()
            afkPreviousCamera.CameraType = afkPreviousType or Enum.CameraType.Custom
            if afkPreviousSubject and afkPreviousSubject.Parent then
                afkPreviousCamera.CameraSubject = afkPreviousSubject
            else
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then afkPreviousCamera.CameraSubject = hum end
            end
            if afkPreviousType == Enum.CameraType.Scriptable and afkPreviousCFrame then
                afkPreviousCamera.CFrame = afkPreviousCFrame
            end
        end)
    end
    afkPreviousCamera = nil
    afkPreviousType = nil
    afkPreviousSubject = nil
    afkPreviousCFrame = nil
    afkCameraAnchor = nil
    afkSweepRadius = nil
    afkSweepSurfaceY = nil
    afkSweepFocusOffsetY = nil
    afkBandSurfaceHeights = nil
    afkCameraPileTopY = nil
end

local function measureAfkBandSurfaces(center)
    local folder = HayFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("HaystackClient")
        HayFolder = folder
    end
    local radialTops = {}
    for i = 1, #AFK_ORBIT_BANDS do radialTops[i] = {} end
    local floorY, highestY = math.huge, -math.huge
    if folder then
        for _, part in ipairs(folder:GetChildren()) do
            if isPileHay(part) then
                local p = part.Position
                local topY = p.Y + part.Size.Y * 0.5
                floorY = math.min(floorY, p.Y - part.Size.Y * 0.5)
                highestY = math.max(highestY, topY)
                local dx, dz = p.X - center.X, p.Z - center.Z
                local r = math.sqrt(dx * dx + dz * dz)
                for i, band in ipairs(AFK_ORBIT_BANDS) do
                    if math.abs(r - band.radius) <= 5.5 then
                        local values = radialTops[i]
                        values[#values + 1] = topY
                    end
                end
            end
        end
    end
    if floorY == math.huge then floorY = center.Y - 4 end
    if highestY == -math.huge then highestY = center.Y + 8 end
    local fractions = {0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.24, 0.36, 0.495, 0.63, 0.755, 0.88, 0.97}
    local surfaces = {}
    for i, samples in ipairs(radialTops) do
        local baseline = floorY + (highestY - floorY) * fractions[i]
        if #samples >= 6 then
            table.sort(samples)
            local observed = samples[math.max(1, math.ceil(#samples * 0.90))]

            surfaces[i] = math.clamp(observed, floorY, highestY)
        else
            surfaces[i] = baseline
        end
        if i > 1 then surfaces[i] = math.max(surfaces[i], surfaces[i - 1]) end
    end
    -- Apply intentional lower rings after the ascending surface calculation.
    for i, band in ipairs(AFK_ORBIT_BANDS) do surfaces[i] += band.heightOffset or 0 end
    local heightLabels = {}
    for i, band in ipairs(AFK_ORBIT_BANDS) do heightLabels[i] = string.format("%s=%.1f", band.name, surfaces[i]) end
    print("[AFK Orbit] Fixed level heights: " .. table.concat(heightLabels, " "))
    return surfaces, highestY
end

local function estimateAfkOrbitRadius(center)
    local folder = HayFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("HaystackClient")
        HayFolder = folder
    end
    if not folder then return 16 end
    local radii = {}
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil then
            local dx, dz = part.Position.X - center.X, part.Position.Z - center.Z
            radii[#radii + 1] = math.sqrt(dx * dx + dz * dz)
        end
    end
    if #radii == 0 then return 16 end
    table.sort(radii)
    local outer = radii[math.max(1, math.ceil(#radii * 0.90))]
    return math.clamp(outer * 0.95, 9, 55)
end

local needleCameraMode = false
local function enterNeedleCamera()
    if needleCameraMode then return end
    needleCameraMode = true

    releaseAfkCamera()
    local camera = Workspace.CurrentCamera
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if camera then
        pcall(function()
            camera.CameraType = Enum.CameraType.Custom
            if humanoid then camera.CameraSubject = humanoid end
        end)
    end
    print("[Camera] Needle exposed; AFK overhead view OFF (normal camera)")
end
function afkOrbitTelemetry.CanAdvance()
    if afkOrbitTelemetry.RecoveryPending then return false,"Returning to lobby" end
    if not afkVacuumOrbitEnabled() then return true,"Running" end
    local root=getHRP()
    if not root or not root.Parent or not afkCameraAnchor or not afkSweepRadius or not afkSweepSurfaceY then
        return false,"Waiting for character and orbit position"
    end
    local band=afkCurrentBand()
    local radius=afkSweepRadius-(band.characterInset or 0)
    local wanted=Vector3.new(afkCameraAnchor.X+math.cos(afkOrbitAngle)*radius,
        afkSweepSurfaceY+3.25,afkCameraAnchor.Z+math.sin(afkOrbitAngle)*radius)
    if (root.Position-wanted).Magnitude>3 then return false,"Waiting for character to reach this ring" end
    return true,"Running"
end
function afkOrbitTelemetry.Update(allowed,reason)
    local band=afkCurrentBand()
    local text=string.format("%s | %s | route %d/%d",reason,band.name,(afkOrbitLap % #AFK_ORBIT_BANDS)+1,#AFK_ORBIT_BANDS)
    if text~=afkOrbitTelemetry.LastText then
        afkOrbitTelemetry.LastText=text
        if afkOrbitTelemetry.Element then afkOrbitTelemetry.Element:SetDesc(text) end
        if afkOrbitTelemetry.Paused~=not allowed then
            print("[AFK Orbit] "..text)
        end
        afkOrbitTelemetry.Paused=not allowed
    end
end
local function bindAfkCameraView()
    local ok, err = pcall(function()
        RunService:BindToRenderStep(AFK_CAMERA_BIND, Enum.RenderPriority.Last.Value + 10, function(dt)
            if Unloaded or not IN_GAME or not afkFarmModeActive() or needleHasPriority() or roundEndingVisible() then return end
            local current = Workspace.CurrentCamera
            if not current or not afkCameraAnchor then return end
            local delta = math.max(0, math.min(dt, 0.25))
            local advance,reason=afkOrbitTelemetry.CanAdvance()
            afkOrbitTelemetry.Update(advance,reason)
            local nextAngle = afkOrbitAngle + math.rad(AFK_ORBIT_SPEED_DEG) * (advance and delta or 0)
            if nextAngle >= 2 * math.pi then
                afkOrbitLap += 1
                local nextBand = afkCurrentBand()
                print(string.format("[AFK Orbit] Lap %d complete; next fixed band %s (%.1f studs)",
                    afkOrbitLap, nextBand.name, nextBand.radius))
            end
            afkOrbitAngle = nextAngle % (2 * math.pi)
            local bandIndex = (afkOrbitLap % #AFK_ORBIT_BANDS) + 1
            local band = AFK_ORBIT_BANDS[bandIndex]
            if afkVacuumOrbitEnabled() then

                local alpha = 1 - math.exp(-3.0 * delta)
                local wantedRadius = band.radius + band.standoff
                local wantedSurface = (afkBandSurfaceHeights and afkBandSurfaceHeights[bandIndex])
                    or afkCameraPileTopY or afkCameraAnchor.Y
                afkSweepRadius = (afkSweepRadius or wantedRadius) + (wantedRadius - (afkSweepRadius or wantedRadius)) * alpha
                afkSweepSurfaceY = (afkSweepSurfaceY or wantedSurface) + (wantedSurface - (afkSweepSurfaceY or wantedSurface)) * alpha
                local wantedFocusOffsetY = band.focusYOffset
                afkSweepFocusOffsetY = (afkSweepFocusOffsetY or wantedFocusOffsetY)
                    + (wantedFocusOffsetY - (afkSweepFocusOffsetY or wantedFocusOffsetY)) * alpha
                local radial = Vector3.new(math.cos(afkOrbitAngle), 0, math.sin(afkOrbitAngle))
                local camAt = Vector3.new(
                    afkCameraAnchor.X + radial.X * (afkSweepRadius + 0.6),
                    afkSweepSurfaceY + band.cameraLift,
                    afkCameraAnchor.Z + radial.Z * (afkSweepRadius + 0.6)
                )
                local focus = Vector3.new(
                    afkCameraAnchor.X + radial.X * math.max(0, afkSweepRadius - 5),
                    afkSweepSurfaceY + afkSweepFocusOffsetY,
                    afkCameraAnchor.Z + radial.Z * math.max(0, afkSweepRadius - 5)
                )
                current.CameraType = Enum.CameraType.Scriptable
                current.CFrame = CFrame.lookAt(camAt, focus, Vector3.yAxis)
            else
                local anchor = afkCameraAnchor
                local camAt = anchor + Vector3.new(
                    math.cos(afkOrbitAngle) * afkOrbitRadius,
                    math.max(34, afkOrbitRadius * 1.35),
                    math.sin(afkOrbitAngle) * afkOrbitRadius
                )
                current.CameraType = Enum.CameraType.Scriptable
                current.CFrame = CFrame.lookAt(camAt, anchor, Vector3.yAxis)
            end
        end)
    end)
    if ok then
        afkCameraBound = true
        afkCameraSuspended = false
        return true
    end
    warn("[Camera] Failed to bind stable 4-band orbit: " .. tostring(err))
    releaseAfkCamera()
    return false
end
function afkOrbitTelemetry.BeginTeleportRound()
    if afkOrbitTelemetry.RoundJob == game.JobId then return end
    releaseAfkCamera()
    afkOrbitTelemetry.RoundJob = game.JobId
    afkOrbitAngle = 0
    afkOrbitLap = 0
    afkVacuumTargetReady = false
    afkOrbitTelemetry.LastText = nil
    afkOrbitTelemetry.Paused = nil
    print("[AFK Orbit] New teleport session: reset to base-lower | route 1/" .. tostring(#AFK_ORBIT_BANDS))
end
local function startAfkCamera()
    afkOrbitTelemetry.BeginTeleportRound()
    if afkCameraBound or not IN_GAME or not afkFarmModeActive() then return end
    if afkCameraSuspended and afkCameraAnchor then
        bindAfkCameraView()
        return
    end
    local center = getHaystackCenter()
    local cam = Workspace.CurrentCamera
    if not center or not cam then return end
    afkCameraAnchor = center
    afkOrbitRadius = estimateAfkOrbitRadius(center)
    afkBandSurfaceHeights, afkCameraPileTopY = measureAfkBandSurfaces(center)
    afkSweepRadius = afkCurrentBand().radius + afkCurrentBand().standoff
    afkSweepSurfaceY = afkBandSurfaceHeights[(afkOrbitLap % #AFK_ORBIT_BANDS)+1]
    afkSweepFocusOffsetY = afkCurrentBand().focusYOffset
    afkPreviousCamera = cam
    afkPreviousType = cam.CameraType
    afkPreviousSubject = cam.CameraSubject
    afkPreviousCFrame = cam.CFrame
    pcall(function() RunService:UnbindFromRenderStep(AFK_CAMERA_BIND) end)
    if bindAfkCameraView() then
        print(string.format("[Camera] FIXED 8-band sweep started: %.1f deg/s, %ds full sweep, bands = 22/20/18/16/14/11/8/5 studs",
            AFK_ORBIT_SPEED_DEG, math.floor(360 / AFK_ORBIT_SPEED_DEG * #AFK_ORBIT_BANDS + 0.5)))
    end
end

local previousHubCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    if previousHubCleanup then pcall(previousHubCleanup) end
    releaseAfkCamera()
end

local function doUnload()
    if _G.__BEYY_HUB_CLEANUP then pcall(_G.__BEYY_HUB_CLEANUP) end
    Unloaded = true
    pcall(function() if Window then Window:Destroy() end end)
end

task.spawn(function()
    while not Unloaded do
        task.wait(0.05)
        if IN_GAME and afkFarmModeActive() then
            if needleHasPriority() then
                if not needleCameraMode then enterNeedleCamera() end
            else
                if needleCameraMode then
                    needleCameraMode = false
                    print("[Camera] Needle phase finished; AFK overhead view restored")
                end
                if not afkCameraBound then startAfkCamera() end
            end
        else
            needleCameraMode = false
            if afkCameraBound or afkCameraSuspended then releaseAfkCamera() end
        end
    end
    releaseAfkCamera()
end)

local afkPlayerAnchor = nil
local afkLastPositionAttempt = 0
local afkPositionConfirmed = false
local afkPositionCharacter = nil
local function afkHorizontalDistance(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end
local function afkLandingPosition(center)
    local highestTop = nil
    local folder = HayFolder
    if folder and folder.Parent then
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil
                and afkHorizontalDistance(part.Position, center) <= 8 then
                local top = part.Position.Y + part.Size.Y * 0.5
                if not highestTop or top > highestTop then highestTop = top end
            end
        end
    end
    return Vector3.new(center.X, (highestTop or center.Y) + 3.0, center.Z)
end
task.spawn(function()
    while not Unloaded do
        task.wait(0.45)
        if not IN_GAME or not afkFarmModeActive() then
            afkPlayerAnchor = nil
            afkPositionConfirmed = false
            afkPositionCharacter = nil
        elseif not afkVacuumOrbitEnabled() and not needleHasPriority() and not roundEndingVisible() then
            local char = LocalPlayer.Character
            local root = getHRP()
            if char and root then
                if afkPositionCharacter ~= char then
                    afkPositionCharacter = char
                    afkPositionConfirmed = false
                    afkPlayerAnchor = nil
                end
                afkPlayerAnchor = afkPlayerAnchor or afkCameraAnchor or getHaystackCenter()
                local center = afkPlayerAnchor
                if center then
                    local distance = afkHorizontalDistance(root.Position, center)
                    if not afkPositionConfirmed or distance > 13 then
                        if os.clock() - afkLastPositionAttempt >= 1.0 then
                            afkLastPositionAttempt = os.clock()
                            local destination = afkLandingPosition(center)
                            if distance <= 6 and math.abs(root.Position.Y - destination.Y) < 7 then
                                afkPositionConfirmed = true
                                print("[Hay] AFK character already on haypile")
                            else
                                local offset = root.CFrame:ToObjectSpace(char:GetPivot())
                                local forward = root.CFrame.LookVector
                                local horizontal = Vector3.new(forward.X, 0, forward.Z)
                                if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0, 0, -1) end
                                local wantedRoot = CFrame.lookAt(destination, destination + horizontal, Vector3.yAxis)
                                local succeeded, err = pcall(function()
                                    if needleHasPriority() then return end
                                    char:PivotTo(wantedRoot * offset)
                                    root.AssemblyLinearVelocity = Vector3.zero
                                    root.AssemblyAngularVelocity = Vector3.zero
                                end)
                                if succeeded and not needleHasPriority() then
                                    task.wait(0.12)
                                    if not needleHasPriority() and char.Parent and root.Parent and afkHorizontalDistance(root.Position, center) <= 6 then
                                        afkPositionConfirmed = true
                                        print(string.format("[Hay] AFK player moved onto pile (distance %.1f studs)", afkHorizontalDistance(root.Position, center)))
                                    else
                                        afkPositionConfirmed = false
                                        warn("[Hay] AFK player teleport did not stick; retrying")
                                    end
                                elseif not needleHasPriority() then
                                    afkPositionConfirmed = false
                                    warn("[Hay] AFK character teleport failed: " .. tostring(err))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local scanBusy = false
    local lastHayReadinessScan = -math.huge
    local scanSamples, scanTotalMs, scanMaxMs, scannedHayParts = 0, 0, 0, 0
    local lastPerfReport = os.clock()
    while not Unloaded do
        task.wait(0.08)
        if not IN_GAME or not afkVacuumOrbitEnabled() or needleHasPriority() or roundEndingVisible() then
            afkVacuumTargetReady = false
            lastHayReadinessScan = -math.huge
        else
            local character = LocalPlayer.Character
            local root = getHRP()
            local anchor = afkCameraAnchor
            local radius = afkSweepRadius
            if radius then radius -= afkCurrentBand().characterInset or 0 end
            local surface = afkSweepSurfaceY
            if character and root and anchor and radius and surface then
                local radial = Vector3.new(math.cos(afkOrbitAngle), 0, math.sin(afkOrbitAngle))
                local wanted = Vector3.new(
                    anchor.X + radial.X * radius,
                    surface + 3.25,
                    anchor.Z + radial.Z * radius
                )

                if (root.Position - wanted).Magnitude > 0.4 then
                    local charToRoot = root.CFrame:ToObjectSpace(character:GetPivot())
                    local facing = Vector3.new(anchor.X, wanted.Y - 1.25, anchor.Z)
                    local goalRoot = CFrame.lookAt(wanted, facing, Vector3.yAxis)
                    pcall(function()
                        if not Unloaded and not needleHasPriority() and not roundEndingVisible()
                            and character.Parent and root.Parent then
                            character:PivotTo(goalRoot * charToRoot)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                        end
                    end)
                end

                local now = os.clock()
                if not scanBusy and now - lastHayReadinessScan >= 0.45 then
                    lastHayReadinessScan = now
                    scanBusy = true
                    local scanBand = afkCurrentBand()
                    task.spawn(function()
                    local scanStart = os.clock()
                    local cpuMs, sliceStart = 0, scanStart
                    local function stillCurrent()
                        return not Unloaded and IN_GAME and afkVacuumOrbitEnabled()
                            and not needleHasPriority() and not roundEndingVisible()
                            and LocalPlayer.Character == character and root.Parent ~= nil
                            and afkCameraAnchor == anchor and afkCurrentBand() == scanBand
                    end
                    local scanOK, scanError = pcall(function()
                    local folder = HayFolder
                    if not folder or not folder.Parent then
                        folder = Workspace:FindFirstChild("HaystackClient")
                        HayFolder = folder
                    end
                    local nearby, checked = false, 0
                    if folder then
                        local probe = anchor + radial * scanBand.radius
                        for _, hay in ipairs(folder:GetChildren()) do
                            checked += 1
                            -- Most pieces are far away; avoid attributes/ancestry until geometry matches.
                            if hay.Parent == folder and hay:IsA("BasePart") then
                                local position = hay.Position
                                local dx, dz = position.X - probe.X, position.Z - probe.Z
                                if dx * dx + dz * dz <= 12 * 12
                                    and math.abs(position.Y - surface) <= 12 and isPileHay(hay) then
                                    nearby = true
                                    break
                                end
                            end
                            if checked % 64 == 0 and os.clock() - sliceStart >= 0.001 then
                                cpuMs += (os.clock() - sliceStart) * 1000
                                task.wait()
                                sliceStart = os.clock()
                                if not stillCurrent() or folder.Parent == nil then return end
                            end
                        end
                    end
                    if not stillCurrent() then return end
                    afkVacuumTargetReady = nearby
                    local spentMs = cpuMs + (os.clock() - sliceStart) * 1000
                    scanSamples += 1
                    scannedHayParts += checked
                    scanTotalMs += spentMs
                    scanMaxMs = math.max(scanMaxMs, spentMs)
                    if now - lastPerfReport >= 30 then
                        print(string.format("[Perf] v103.00 hay scans=%d, parts examined=%d, average=%.2fms CPU, max=%.2fms CPU per scan (1ms slices)",
                            scanSamples, scannedHayParts, scanTotalMs / math.max(1, scanSamples), scanMaxMs))
                        scanSamples, scannedHayParts, scanTotalMs, scanMaxMs = 0, 0, 0, 0
                        lastPerfReport = now
                    end
                    end)
                    scanBusy = false
                    if not scanOK then warn("[Hay] Readiness scan failed: " .. tostring(scanError)) end
                    end)
                end
            else
                afkVacuumTargetReady = false
            end
        end
    end
end)

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
            while running and not Unloaded do
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
                if IN_GAME or not container.Visible then break end
                clickGuiObjectEarly(createBtn)
                local deadline = tick() + 0.9
                while tick() < deadline do
                    if IN_GAME or not container.Visible then break end
                    task.wait(0.05)
                end
                if IN_GAME or not container.Visible then
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
        if IN_GAME then return end
        autoCreating = true
        local circles = getTeleportCircles()
        if #circles == 0 then autoCreating = false; return end
        for _, entry in ipairs(circles) do
            if IN_GAME then break end
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
        while not Unloaded do
            task.wait(0.5)
            if afkFarmModeActive() and not IN_GAME then
                pcall(attemptAutoCreate)
            end
        end
    end)
end

do
    print("[AutoUI] Skip/Replay block starting (v103.00)")

    local lastIntroSkipTime = 0
    local lastReplayClickTime = 0
    local introSkipStreak = 0
    local replayClickStreak = 0
    local endSkipStreak = 0
    local lastEndSkipClickTime = 0
    local INTRO_SKIP_COOLDOWN = 1.5
    local INTRO_FAILSAFE_DELAY = 3.0
    local INTRO_FAILSAFE_COOLDOWN = 0.65
    local introSkipFirstSeenAt = nil
    local introFailsafeActive = false
    local SKIP_COOLDOWN = 1.0

    local replayFiredForThisEnding = false
    local hasOwnedNeedleThisRound = false

    local function getClickCoords(obj)
        if not obj or not obj:IsA("GuiObject") then return nil end
        if not obj.Visible then return nil end
        local absPos, absSize = obj.AbsolutePosition, obj.AbsoluteSize
        if absSize.X <= 0 or absSize.Y <= 0 then return nil end
        local inset = GuiService:GetGuiInset()
        return absPos.X + absSize.X / 2 + inset.X, absPos.Y + absSize.Y / 2 + inset.Y
    end

    local function vimClick(cx, cy)
        if needleHasPriority() then return false end
        local mouseDown = false
        local ok = pcall(function()
            VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
            task.wait(0.03)
            if needleHasPriority() then return end
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            mouseDown = true
            task.wait(0.06)
        end)
        if mouseDown then
            pcall(function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
        end
        return ok and mouseDown and not needleHasPriority()
    end

    local function activateButton(obj)
        if not obj or needleHasPriority() or autoUiMouseBusy then return false end
        autoUiMouseBusy = true
        local ok, result = xpcall(function()
            local anyHit = false
            local cx, cy = getClickCoords(obj)
            if cx and cy then
                if not vimClick(cx, cy) then return false end
                anyHit = true
            end
            local function fireOn(o)
                if not o or needleHasPriority() then return end
                if firesignal then
                    pcall(function() firesignal(o.MouseButton1Click) end)
                    if needleHasPriority() then return end
                    pcall(function() firesignal(o.MouseButton1Down) end)
                    task.wait(0.03)
                    if needleHasPriority() then return end
                    pcall(function() firesignal(o.MouseButton1Up) end)
                    if needleHasPriority() then return end
                    pcall(function() firesignal(o.Activated) end)
                    anyHit = true
                end
            end
            if obj:IsA("TextButton") or obj:IsA("ImageButton") then fireOn(obj) end
            if needleHasPriority() then return anyHit end
            for _, child in ipairs(obj:GetDescendants()) do
                if needleHasPriority() then break end
                if child:IsA("TextButton") or child:IsA("ImageButton") then fireOn(child) end
            end
            return anyHit
        end, function(err) return tostring(err) end)
        autoUiMouseBusy = false
        if not ok then warn("[AutoUI] Button click failed: " .. tostring(result)) end
        return ok and result
    end

    local function collectVisibleText(obj)
        local parts = {}
        if obj:IsA("TextButton") or obj:IsA("TextLabel") then
            pcall(function() if obj.Text and obj.Text ~= "" then table.insert(parts, obj.Text) end end)
        end
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                pcall(function() if child.Text and child.Text ~= "" then table.insert(parts, child.Text) end end)
            end
        end
        return table.concat(parts, " "):lower()
    end

    local function contextFor(gui)
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local context = string.lower(gui.Name).. " ".. collectVisibleText(gui)
        local p = gui.Parent
        local hops = 0
        while p and p ~= pg and hops < 5 do
            context = context.. " ".. string.lower(p.Name)
            p = p.Parent
            hops = hops + 1
        end
        return context
    end

    local function findReplayButton()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        local endingUI = pg:FindFirstChild("NeedleEndingUI")
        if not endingUI then return nil end
        local frame = endingUI:FindFirstChild("ReturnToLobby")
        if not frame then return nil end
        local replayBtn = frame:FindFirstChild("ReplayButton")
        if not guiReallyVisible(replayBtn) then return nil end
        if replayBtn:IsA("GuiButton") then return replayBtn end
        for _, child in ipairs(replayBtn:GetDescendants()) do
            if child:IsA("GuiButton") and guiReallyVisible(child) then return child end
        end
        return replayBtn
    end

    local function findSkipButton()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        local best, bestScore = nil, 0
        for _, gui in ipairs(pg:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and guiReallyVisible(gui) then
                local context = contextFor(gui)
                if context:find("skip", 1, true) then
                    local score = 1
                    if score > bestScore then
                        best = gui
                        bestScore = score
                    end
                end
            end
        end
        return best
    end

    local function isEndingVisible()
        return roundEndingVisible()
    end

    local function hasReplayVote(replayButton)
        if not replayButton then return false end
        local voteText = collectVisibleText(replayButton)
        local count, total = voteText:match("(%d+)%s*/%s*(%d+)")
        count,total=tonumber(count),tonumber(total)
        -- The label is a shared count, not a local-player acknowledgement.
        return count~=nil and total~=nil and total>0 and count>=total
    end
    local function replayCounts(button)
        local a,b=collectVisibleText(button):match("(%d+)%s*/%s*(%d+)")
        return tonumber(a),tonumber(b)
    end
    local function activateReplayButton(button)
        if autoUiMouseBusy or not Window.Closed or needlePickupActive then
            setReplayStatus(not Window.Closed and "Waiting for the hub menu to close" or "Waiting for mouse input to be free")
            return false
        end
        local x,y=getClickCoords(button)
        if not x then setReplayStatus("Replay target is not visible or has no click area"); return false end
        local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return false end
        local before,total=replayCounts(button)
        autoUiMouseBusy=true
        local method="VIM click"
        -- Works for frame wrappers too; no signal access or hit-stack gate.
        local clicked,result=pcall(vimClick,x,y)
        setReplayStatus("Attempt "..tostring(replayClickStreak)..": "..method.."; votes "..tostring(before).."/"..tostring(total))
        local confirmed=false
        if clicked and result then
            local deadline=os.clock()+0.8
            repeat
                if Unloaded or not isEndingVisible() or not guiReallyVisible(button) then confirmed=not Unloaded; break end
                local current=replayCounts(button)
                if before and current and current>before then confirmed=true; break end
                task.wait(0.05)
            until os.clock()>=deadline
        end
        autoUiMouseBusy=false
        if confirmed then setReplayStatus("Replay count advanced or results closed; waiting for the group")
        else setReplayStatus("No Replay confirmation via "..method.."; retry pending") end
        return clicked and result==true and confirmed
    end

    local function getReplayCooldown()
        local s = replayClickStreak
        if s < 2 then return 0.8
        elseif s < 5 then return 1.5
        elseif s < 10 then return 3.0
        else return 6.0 end
    end

    local resultsScreenWasVisible = false
    local replayVoteLogged = false
    local replayButtonFirstSeenAt = nil
    local trackedReplayButton = nil
    local REPLAY_READY_DELAY = 0.25

    task.spawn(function()
        while not Unloaded do
            task.wait(resultsScreenWasVisible and 0.05 or 0.35)
            if not IN_GAME then
                hasOwnedNeedleThisRound = false
                replayFiredForThisEnding = false
                replayVoteLogged = false
                resultsScreenWasVisible = false
                replayButtonFirstSeenAt, trackedReplayButton = nil, nil
                introSkipStreak = 0
                introSkipPending = false
                introSkipFirstSeenAt = nil
                introFailsafeActive = false
                replayClickStreak = 0
                endSkipStreak = 0
                lastReplayClickTime = 0
                lastEndSkipClickTime = 0
            else
                local now = tick()
                local endingVisible = isEndingVisible()
                if endingVisible then

                    introSkipPending = false
                    introSkipFirstSeenAt = nil
                    introFailsafeActive = false
                    if not resultsScreenWasVisible then
                        resultsScreenWasVisible = true
                        replayButtonFirstSeenAt, trackedReplayButton = nil, nil
                        replayFiredForThisEnding = false
                        replayClickStreak = 0
                        lastReplayClickTime = 0
                        replayVoteLogged = false
                        print("[AutoUI] Results screen visible; replay enabled")
                    end

                    if afkFarmModeActive() then
                        local replayButton = findReplayButton()
                        if replayButton then
                            if trackedReplayButton ~= replayButton then
                                trackedReplayButton = replayButton
                                replayButtonFirstSeenAt = now
                            end
                            if hasReplayVote(replayButton) then
                                replayFiredForThisEnding = true
                                if not replayVoteLogged then
                                    replayVoteLogged = true
                                    setReplayStatus("All Replay votes registered; waiting for teleport")
                                    print("[AutoUI] All Replay votes registered; waiting for next round")
                                end
                            elseif not replayFiredForThisEnding then
                                local cooldown = getReplayCooldown()
                                if now - replayButtonFirstSeenAt >= REPLAY_READY_DELAY
                                    and now - lastReplayClickTime >= cooldown and not autoUiMouseBusy and not needlePickupActive then
                                    replayClickStreak = replayClickStreak + 1
                                    lastReplayClickTime = now
                                    local clicked = activateReplayButton(replayButton)
                                    if clicked then
                                        replayFiredForThisEnding = true
                                        print("[AutoUI] Local Replay click sent; waiting for other players or teleport")
                                    end
                                    if not clicked then
                                        warn("[AutoUI] Replay input was blocked; retry pending")
                                    end

                                end
                            end
                        else
                            replayButtonFirstSeenAt, trackedReplayButton = nil, nil
                        end
                    end
                else
                    if resultsScreenWasVisible then
                        print("[AutoUI] Results screen closed")
                    end
                    resultsScreenWasVisible = false
                    replayButtonFirstSeenAt, trackedReplayButton = nil, nil
                    replayFiredForThisEnding = false
                    replayVoteLogged = false
                    replayClickStreak = 0
                    lastReplayClickTime = 0

                    local btn = nil
                    if not earlyIntroPending and not needleHasPriority() then btn = findSkipButton() end
                    if btn then
                        introSkipPending = true
                        if not introSkipFirstSeenAt then
                            introSkipFirstSeenAt = now
                            introFailsafeActive = false
                            print("[AutoUI] Intro Skip detected; reserving Mouse1 for skip")
                        end

                        if not introFailsafeActive and now - introSkipFirstSeenAt >= INTRO_FAILSAFE_DELAY then
                            introFailsafeActive = true
                            warn("[AutoUI] Intro Skip still visible after 3s; failsafe retries enabled")
                        end
                        local interval = introFailsafeActive and INTRO_FAILSAFE_COOLDOWN or INTRO_SKIP_COOLDOWN
                        if now - lastIntroSkipTime >= interval then
                            lastIntroSkipTime = now
                            introSkipStreak = introSkipStreak + 1
                            if not activateButton(btn) then

                                print("[AutoUI] Intro Skip input blocked; still pending")
                            end
                        end
                    else
                        if introSkipPending then
                            print("[AutoUI] Intro Skip button no longer visible; releasing input priority")
                        end
                        introSkipPending = false
                        introSkipFirstSeenAt = nil
                        introFailsafeActive = false
                    end
                end
            end
        end
    end)
end

local CollectingTab
do
local MainTab = Window:Tab({ Title = "Overview & Settings", Icon = "house" })
local FarmingSection = Window:Section({ Title = "Farming", Icon = "wheat", Opened = true })
CollectingTab = FarmingSection:Tab({ Title = "Collecting", Icon = "wheat" })
local SellingTab = FarmingSection:Tab({ Title = "Selling", Icon = "coins" })
local ToolsTab = FarmingSection:Tab({ Title = "Tools", Icon = "hammer" })
local NeedleTab = FarmingSection:Tab({ Title = "Needle", Icon = "search" })
local InventorySection = Window:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
local ShopTab = InventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
local UpgradesTab = InventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
local SettingsTab = MainTab

do
    Header(MainTab, "Dashboard")
    AddToggle(MainTab,"AutoRoundFailsafe","Restart Stalled Rounds After 5 Minutes",true)
    afkOrbitTelemetry.TimeoutStatus=MainTab:Paragraph({Title="Round Failsafe Status",Desc="Waiting for round timer"})
    afkOrbitTelemetry.Element=MainTab:Paragraph({Title="Orbit Status",Desc="Waiting for auto farm"})
    replayStatus=MainTab:Paragraph({Title="Replay Status",Desc=replayStatusText})
    installAntiIdle(MainTab, Registry, function() return not Unloaded end)
    Info(MainTab, "Game: ".. (IN_GAME and "Chapter 1 (FARMHOUSE)" or "Lobby"))
    Info(MainTab, "Toggle UI: RightControl")

    AddToggle(MainTab, "AutoFarmWins", "Auto Farm Wins (AFK Farm Mode)", false,
        "AFK round-create, 48 deg/s eight-band sweep (22 / 20 / 18 / 16 / 14 / 11 / 8 / 5 studs), and automatic vacuum when enabled below.",
        function(v)
            if not v then releaseAfkCamera() end
            safeWrite(CACHE_FOLDER .. "/autofarmwins_shared.txt", tostring(v))
            print("[Mode] AFK Farm Mode = ".. tostring(State.AutoFarmWins))
        end)
    AddToggle(MainTab, "AutoFarmVacuum", "Vacuum During Auto Farm Wins", true,
        "Use heat-bar-controlled suction while the character follows the eight circular sweep routes.")

    local sessionPara = MainTab:Paragraph({ Title = "Session", Desc = "0s elapsed" })
    task.spawn(function()
        local s = 0
        while not Unloaded do
            task.wait(3); s += 3
            pcall(function()
                sessionPara:SetDesc(string.format(
                    "Session: %dm %ds | Cash: $%s | Gems: %s | Hay: %d/%d",
                    s // 60, s % 60, tostring(getCash()), tostring(getGems()),
                    getHayHeld(), getHayCapacity()
                ))
            end)
        end
    end)
end

do
    Header(CollectingTab, "Resource Collecting")
    AddToggle(CollectingTab, "AutoPickHay", "Auto Pick Hay", false)
    AddToggle(CollectingTab, "AutoCollectDroppedHay", "Auto Collect Dropped Hay", false)
    AddToggle(CollectingTab, "AutoCollectGems", "Auto Collect Gems", false)
    AddSlider(CollectingTab, "CollectInterval", "Loop Interval (s)", 0.1, 3, 0.5, 0.1)
end

do
    Header(SellingTab, "Selling")
    AddToggle(SellingTab, "AutoSellHay", "Auto Sell Hay", false)
    AddSlider(SellingTab, "SellThreshold", "Sell When Hay >=", 1, 250, 25, 1)
    AddToggle(SellingTab, "SellOnlyIfFull", "Only Sell If Full", false)
end

do
    Header(ToolsTab, "Auto Tool Usage")
    afkOrbitTelemetry.VacuumStatus=ToolsTab:Paragraph({Title="Vacuum Status",Desc="Waiting for vacuum automation"})
    Info(ToolsTab, "Tools work independently of AFK mode. With AFK enabled, TNT targets remaining hay around the orbiting camera's current angle.")
    AddToggle(ToolsTab, "AutoUseTNT", "Auto Use TNT", false)
    tntTelemetry.Element=ToolsTab:Paragraph({Title="TNT Status",Desc="Waiting for automatic TNT"})
    AddToggle(ToolsTab, "AutoUsePitchfork", "Auto Use Pitchfork", false)
    AddToggle(ToolsTab, "AutoDeployDrone", "Auto Deploy Drone", false)
    AddToggle(ToolsTab, "AutoUseVacuum", "Auto Use Vacuum (live heat + cooldown)", false,
        "Holds Mouse1 until the overheat bar reaches 100%, waits until it returns to 0%, and releases for needle pickup/results.")
    AddSlider(ToolsTab, "VacuumHotbarSlot", "Vacuum Hotbar Slot (fallback)", 1, 9, 5, 1,
        "Default: slot 5. Used when the vacuum is not a Roblox Tool in Backpack.")
    AddSlider(ToolsTab, "ToolInterval", "Tool Interval (s)", 0.2, 5, 0.5, 0.1)
end

do
    Header(NeedleTab, "Needle (TOP PRIORITY)")
    Info(NeedleTab, "When the needle is exposed, all farm loops pause automatically.")
    AddToggle(NeedleTab, "AutoFindNeedle", "Auto Find Needle", false)
    AddToggle(NeedleTab, "AutoPickupNeedle", "Auto Pick Up Needle", false)
    AddToggle(NeedleTab, "AutoHandInNeedle", "Auto Hand In Needle", false)
    needlePickupStatus = NeedleTab:Paragraph({Title="Needle Pickup Status",Desc="Waiting for an exposed needle"})
    AddSlider(NeedleTab, "NeedleInterval", "Needle Scan Interval (s)", 0.2, 3, 1, 0.1)
end

do
    Header(ShopTab, "Purchasing")
    State.BuyToolsList = { "Pitchfork" }
    local dd = ShopTab:Dropdown({
        Title = "Buy Tools Selection",
        Values = { "Pitchfork", "TNT", "Drone", "Infinite Bag", "Capacity Bag" },
        Value = { "Pitchfork" },
        Multi = true,
        AllowNone = true,
        Callback = function(v) State.BuyToolsList = v end,
    })
    Registry.BuyToolsList = dd
    AddToggle(ShopTab, "AutoBuyTools", "Auto Buy Selected Tools", false)
    AddSlider(ShopTab, "BuyInterval", "Buy Interval (s)", 0.5, 5, 1, 0.1)
end

do
    Header(UpgradesTab, "Permanent (Gems)")
    AddToggle(UpgradesTab, "UpgBagSize", "Auto Upgrade Bag Size", false)
    AddToggle(UpgradesTab, "UpgExtraTake", "Auto Upgrade Hand Grab Amount", false)
    AddToggle(UpgradesTab, "UpgGemValue", "Auto Upgrade Gem Value", false)
    AddToggle(UpgradesTab, "UpgHayValue", "Auto Upgrade Hay Value", false)
    AddSlider(UpgradesTab, "PermInterval", "Permanent Loop (s)", 0.5, 5, 1, 0.1)
    afkOrbitTelemetry.UpgradeStatus=UpgradesTab:Paragraph({Title="Auto Upgrade Status",Desc="Waiting for upgrade check"})
    Header(UpgradesTab, "Hand (Cash)")
    AddToggle(UpgradesTab, "UpgHandSpeed", "Auto Hand Speed", false)
    AddToggle(UpgradesTab, "UpgHandGrab", "Auto Hand Grasp", false)
    AddToggle(UpgradesTab, "UpgHandHold", "Auto Hand Hold", false)
    Header(UpgradesTab, "TNT (Cash)")
    AddToggle(UpgradesTab, "UpgTntLuck", "Auto TNT Lucky Blast", false)
    AddToggle(UpgradesTab, "UpgTntCooldown", "Auto TNT Cooldown", false)
    AddToggle(UpgradesTab, "UpgTntPower", "Auto TNT Power", false)
    Header(UpgradesTab, "Pitchfork (Cash)")
    AddToggle(UpgradesTab, "UpgPitchCooldown", "Auto Pitchfork Cooldown", false)
    AddToggle(UpgradesTab, "UpgPitchHold", "Auto Pitchfork Hold", false)
    AddToggle(UpgradesTab, "UpgPitchSweep", "Auto Pitchfork Sweep", false)
    Header(UpgradesTab, "Drone (Cash)")
    AddToggle(UpgradesTab, "UpgDroneSpeed", "Auto Drone Speed", false)
    AddToggle(UpgradesTab, "UpgDroneGrab", "Auto Drone Grasp", false)
    AddToggle(UpgradesTab, "UpgDroneCapacity", "Auto Drone Capacity", false)
    Header(UpgradesTab, "Vacuum (Cash)")
    AddToggle(UpgradesTab, "UpgVacPower", "Auto Vacuum Power", false)
    AddToggle(UpgradesTab, "UpgVacCooling", "Auto Vacuum Cooling", false)
    AddToggle(UpgradesTab, "UpgVacRuntime", "Auto Vacuum Runtime", false)
    Header(UpgradesTab, "Capacity (Cash)")
    AddToggle(UpgradesTab, "UpgCapacity", "Auto Upgrade Carry Capacity", false)
end

do
    local overview = MainTab
local function cutsceneResultsVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    return ending and ending:IsA("ScreenGui") and ending.Enabled == true
end
local function shouldYieldCutsceneBypass()
    return Unloaded or not Window.Closed or needleHasPriority() or roundEndingVisible() or cutsceneResultsVisible()
end
local function setCutsceneBypassActive(value)
    if value then releaseAfkCamera() end
    cutsceneBypassActive = value
end
local cutsceneBypassStop = nil
local function launchCutsceneBypass()
    if BEYY_CHAPTER == "Lobby" then return true end
    if cutsceneBypassStop then return true end
    local ok, result = pcall(function()

        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

        local env = _G
        if type(getgenv) == "function" then
            local ok, tbl = pcall(getgenv)
            if ok and type(tbl) == "table" then env = tbl end
        end
        local older = env.__BEYY_CUTSCENE_BYPASS_STOP or _G.__BEYY_CUTSCENE_BYPASS_STOP
        if type(older) == "function" then pcall(older) end

        local alive, enabled, active = true, true, false
        local scene = nil
        local recoveryEnd = 0
        local lastNormalDistance, lastNormalYaw, lastNormalPitch = 0.6, nil, nil
        local normalFirstPerson, cameraFirstPerson = true, true
        local yaw, pitch, distance = nil, -0.18, 0.6
        local lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil
        local controls, cachedCamera = nil, nil
        local originalMouseBehavior = nil
        local connections = {}
        local hudEnabled = true
        local faceCameraEnabled = true
        local hudNormal, hudForced = {}, {}
        local headTransparencyBefore = {}
        local finalVisualsEnabled = true
        local finalVisualBefore = {}
        local cameraWatch = nil
        local inCameraWrite, cameraErrorWarned = false, false
        local renderId = "BeyyCutsceneCameraV103Last"
        local renderPriority = Enum.RenderPriority.Last.Value + 2000
        local RECOVERY_GRACE_SECONDS = 0.035
        local INTRO_SETTLE_SECONDS = 1.0
        local introConfirmedAt = player:GetAttribute("IntroCutsceneFinished") == true and (os.clock() - 2) or nil
        local introNeutralSeen = introConfirmedAt ~= nil and player:GetAttribute("CutsceneActive") ~= true
        local chapter2ReleaseSeen = player:GetAttribute("Chapter2ReleaseActive") == true
        local yieldingToEnding = false
        local lastEndingSkipScan, lastEndingSkipVisible = 0, false
        local skipCandidates = setmetatable({}, { __mode = "k" })
        local skipGui, skipGuiAddedConnection = nil, nil
        local lastSkipFallbackScan = 0
        local lastRenderTime = os.clock()

        local function log(s)
            -- Keep the controller quiet during normal scene transitions.
        end
        local function hook(c)
            if c then connections[#connections+1] = c end
        end
        local function humanoid()
            local char = player.Character
            return char and char:FindFirstChildOfClass("Humanoid")
        end
        local function root()
            local char = player.Character
            return char and char:FindFirstChild("HumanoidRootPart")
        end
        local function camera()
            return workspace.CurrentCamera
        end
        local function getControls()
            if controls then return controls end
            local ps = player:FindFirstChild("PlayerScripts")
            local pm = ps and ps:FindFirstChild("PlayerModule")
            if not pm then return nil end
            local ok, mod = pcall(require, pm)
            if not ok or type(mod) ~= "table" then return nil end
            local ok2, obj = pcall(function() return mod:GetControls() end)
            if ok2 then controls = obj end
            return controls
        end
        local function rememberGameplay()
            local hum = humanoid()
            if hum then
                if hum.WalkSpeed > 0 then lastSavedSpeed = hum.WalkSpeed end
                if hum.JumpPower > 0 then lastSavedJump = hum.JumpPower end
                lastSavedRotate = hum.AutoRotate
            end
            local cam, rt = camera(), root()
            if cam and rt and cam.CameraType == Enum.CameraType.Custom then
                local look = cam.CFrame.LookVector
                if look.Magnitude > 0.5 then
                    local planar = Vector3.new(look.X, 0, look.Z)
                    if planar.Magnitude > 0.1 then
                        lastNormalYaw = math.atan2(planar.X, planar.Z)
                    end
                    lastNormalPitch = math.asin(math.max(-0.97, math.min(0.97, look.Y)))
                end
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local eye = head and head.Position or (rt.Position + Vector3.new(0, 1.6, 0))
                local d = (cam.CFrame.Position - eye).Magnitude
                if d <= 22 then
                    lastNormalDistance = d
                    normalFirstPerson = (d < 2.5 or player.CameraMode == Enum.CameraMode.LockFirstPerson)
                end
            end
        end
        local function kind()
            if shouldYieldCutsceneBypass() then return nil end
            -- Explicit unfinished intros and visible skip/results UI keep normal behavior.
            if player:GetAttribute("IntroCutsceneFinished") == false then return nil end
            if introConfirmedAt and os.clock() - introConfirmedAt < INTRO_SETTLE_SECONDS then return nil end
            if yieldingToEnding then return nil end
            if player:GetAttribute("Chapter2ReleaseActive") == true then return "THREE PUZZLES" end
            if player:GetAttribute("CutsceneActive") == true then return "THREE LEVERS" end
            return nil
        end
        local function clamp(v, lo, hi)
            return math.max(lo, math.min(hi, v))
        end
        local function setupPlayableCamera()
            local rt = root()
            local facing = rt and rt.CFrame.LookVector or Vector3.new(0,0,-1)
            local planar = Vector3.new(facing.X, 0, facing.Z)
            if planar.Magnitude < 0.01 then planar = Vector3.new(0,0,-1) end
            yaw = lastNormalYaw or math.atan2(planar.X, planar.Z)
            pitch = clamp(lastNormalPitch or -0.16, -1.20, 1.05)
            cameraFirstPerson = normalFirstPerson or player.CameraMode == Enum.CameraMode.LockFirstPerson
            distance = clamp(lastNormalDistance or 0.6, 0.0, 22)
            log(string.format("Normal camera calibration: %s d=%.2f pitch=%.2f (no forced 6+ stud zoom)",
                cameraFirstPerson and "FIRST PERSON" or "THIRD PERSON", distance, pitch))
            cameraErrorWarned = false
            if originalMouseBehavior == nil then originalMouseBehavior = UserInputService.MouseBehavior end
        end
        local function lookVector()
            local cp = math.cos(pitch)
            return Vector3.new(math.sin(yaw)*cp, math.sin(pitch), math.cos(yaw)*cp)
        end
        local function hideHeadForFirstPerson()
            if not cameraFirstPerson then return end
            local char = player.Character
            if not char then return end
            local function hidePart(inst)
                if not inst or not inst:IsA("BasePart") then return end
                if headTransparencyBefore[inst] == nil then
                    headTransparencyBefore[inst] = inst.LocalTransparencyModifier
                end
                inst.LocalTransparencyModifier = 1
            end
            hidePart(char:FindFirstChild("Head"))
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Accessory") then
                    hidePart(item:FindFirstChild("Handle"))
                end
            end
        end
        local function restoreHeadTransparency()
            for part, before in pairs(headTransparencyBefore) do
                if part.Parent then
                    pcall(function() part.LocalTransparencyModifier = before end)
                end
                headTransparencyBefore[part] = nil
            end
        end
        local function forceCamera()
            if not alive or not enabled or not active or inCameraWrite or shouldYieldCutsceneBypass() then return end
            local cam, rt = camera(), root()
            if not cam or not rt or not yaw then return end
            inCameraWrite = true
            local safe, err = pcall(function()
                local vec = lookVector()
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local eye = head and head.Position or (rt.Position + Vector3.new(0, 1.6, 0))
                local result, focus
                if cameraFirstPerson then
                    result = CFrame.lookAt(eye, eye + vec * 8, Vector3.yAxis)
                    focus = eye + vec * 8
                    hideHeadForFirstPerson()
                else
                    local target = rt.Position + Vector3.new(0, 1.6, 0)
                    local desired = target - vec * distance
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = char and {char} or {}
                    params.RespectCanCollide = true
                    local hit = workspace:Raycast(target, desired - target, params)
                    if hit then
                        local hitDistance = (hit.Position - target).Magnitude
                        desired = target - vec * math.max(0.35, math.min(distance, hitDistance - 0.40))
                    end
                    result = CFrame.lookAt(desired, target, Vector3.yAxis)
                    focus = target
                end
                cam.CameraType = Enum.CameraType.Scriptable
                local hum = humanoid()
                if hum then cam.CameraSubject = hum end
                cam.CFrame = result
                cam.Focus = CFrame.new(focus)
            end)
            inCameraWrite = false
            if not safe and not cameraErrorWarned then
                cameraErrorWarned = true
                warn("[BeyyHub Cutscene] Camera write failed: " .. tostring(err))
            end
        end
        local function unwatchLeverCamera()
            if cameraWatch then pcall(function() cameraWatch:Disconnect() end) end
            cameraWatch, cachedCamera = nil, nil
        end
        local function watchLeverCamera()
            if not alive or not enabled or not active or scene ~= "THREE LEVERS" then
                unwatchLeverCamera()
                return
            end
            local cam = camera()
            if cam == cachedCamera and cameraWatch then return end
            unwatchLeverCamera()
            cachedCamera = cam
            if not cam then return end
            cameraWatch = cam:GetPropertyChangedSignal("CFrame"):Connect(function()
                if alive and enabled and active and scene == "THREE LEVERS" and not inCameraWrite then
                    forceCamera()
                end
            end)
        end
        hook(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if active and scene == "THREE LEVERS" then watchLeverCamera() end
        end))

        local SAFE_HUD_NAMES = { hud = true, needlehud = true, notifications = true }
        local function rememberGameplayHud()
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") and SAFE_HUD_NAMES[gui.Name:lower()] then
                    hudNormal[gui] = { enabled = gui.Enabled, order = gui.DisplayOrder }
                end
            end
        end
        local function showGameplayHud()
            if not hudEnabled then return end
            for gui, before in pairs(hudNormal) do
                if gui.Parent and before.enabled then
                    if not hudForced[gui] then hudForced[gui] = { enabled = gui.Enabled, order = gui.DisplayOrder } end
                    if not gui.Enabled then
                        pcall(function() gui.Enabled = true end)
                    end
                    local targetOrder = math.max(before.order or 0, 10000)
                    if gui.DisplayOrder ~= targetOrder then
                        pcall(function() gui.DisplayOrder = targetOrder end)
                    end
                end
            end
        end
        local function restoreGameplayHud()
            for gui, saved in pairs(hudForced) do
                if gui.Parent then
                    local wasNormal = hudNormal[gui]
                    pcall(function()
                        gui.DisplayOrder = saved.order
                        if wasNormal and wasNormal.enabled then gui.Enabled = true end
                    end)
                end
                hudForced[gui] = nil
            end
        end

        local function isFinalOverlay(gui)
            if not gui:IsA("ScreenGui") then return false end
            local name = gui.Name:lower()
            if name:find("ending", 1, true) or name:find("needle", 1, true) then return false end
            return name == "cutscenefade" or name:find("cutscene", 1, true) ~= nil
                or name:find("cinematic", 1, true) ~= nil
                or name:find("chapter2release", 1, true) ~= nil
        end
        local function maskFinalProperty(inst, key)
            local ok, previous = pcall(function() return inst[key] end)
            if not ok or type(previous) ~= "number" or previous >= 1 then return end
            local saved = finalVisualBefore[inst]
            if not saved then saved = {}; finalVisualBefore[inst] = saved end
            if saved[key] == nil then saved[key] = previous end
            pcall(function() inst[key] = 1 end)
        end
        local function hideFinalCutsceneVisuals()
            if not finalVisualsEnabled or not scene then return end
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if isFinalOverlay(gui) then
                    for _, el in ipairs(gui:GetDescendants()) do
                        if el:IsA("GuiObject") then
                            maskFinalProperty(el, "BackgroundTransparency")
                            if el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox") then
                                maskFinalProperty(el, "TextTransparency")
                                maskFinalProperty(el, "TextStrokeTransparency")
                            end
                            if el:IsA("ImageLabel") or el:IsA("ImageButton") then
                                maskFinalProperty(el, "ImageTransparency")
                            end
                        elseif el:IsA("UIStroke") then
                            maskFinalProperty(el, "Transparency")
                        end
                    end
                end
            end
        end
        local function restoreFinalCutsceneVisuals()
            for inst, props in pairs(finalVisualBefore) do
                if inst.Parent then
                    for key, original in pairs(props) do
                        pcall(function() inst[key] = original end)
                    end
                end
                finalVisualBefore[inst] = nil
            end
        end

        local function indexSkipCandidate(inst)
            if not inst then return end
            local btn = nil
            if inst:IsA("GuiButton") then
                btn = inst
            elseif inst:IsA("TextLabel") and inst.Text:lower():find("skip", 1, true) then
                local ancestor = inst.Parent
                while ancestor and not ancestor:IsA("GuiButton") do
                    ancestor = ancestor.Parent
                end
                btn = ancestor
            end
            if not btn then return end
            local name = btn.Name:lower()
            local text = btn:IsA("TextButton") and btn.Text:lower() or ""
            local marked = name:find("skip", 1, true) or text:find("skip", 1, true)
            if not marked then
                for _, child in ipairs(btn:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text:lower():find("skip", 1, true) then
                        marked = true
                        break
                    end
                end
            end
            if marked then skipCandidates[btn] = true end
        end
        local function scanSkipCandidates(pg)
            for _, obj in ipairs(pg:GetDescendants()) do indexSkipCandidate(obj) end
        end
        local function watchSkipGui()
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if pg == skipGui and skipGuiAddedConnection then return pg end
            if skipGuiAddedConnection then pcall(function() skipGuiAddedConnection:Disconnect() end) end
            skipGuiAddedConnection, skipGui = nil, pg
            if pg then
                scanSkipCandidates(pg)
                skipGuiAddedConnection = pg.DescendantAdded:Connect(indexSkipCandidate)
            end
            return pg
        end
        local function skipButtonVisible(pg)
            for btn in pairs(skipCandidates) do
                if not btn.Parent or not btn:IsDescendantOf(pg) then
                    skipCandidates[btn] = nil
                else
                    local visible, parent = true, btn
                    while parent and parent ~= pg do
                        if parent:IsA("GuiObject") and not parent.Visible then visible = false; break end
                        if parent:IsA("ScreenGui") and not parent.Enabled then visible = false; break end
                        parent = parent.Parent
                    end
                    if visible then return true end
                end
            end
            return false
        end
        local function skipButtonOnScreen()
            local now = os.clock()
            if now - lastEndingSkipScan < 0.08 then return lastEndingSkipVisible end
            lastEndingSkipScan = now
            local pg = watchSkipGui()
            if not pg then lastEndingSkipVisible = false; return false end
            lastEndingSkipVisible = skipButtonVisible(pg)
            local endingUI = pg:FindFirstChild("NeedleEndingUI")
            local endingLikely = player:GetAttribute("NeedleOwned") == true
                or player:GetAttribute("CutsceneActive") == true
                or (endingUI and endingUI.Enabled == true)
            local fallbackEvery = endingLikely and 0.1 or 4
            if not lastEndingSkipVisible and now - lastSkipFallbackScan >= fallbackEvery then
                lastSkipFallbackScan = now
                scanSkipCandidates(pg)
                lastEndingSkipVisible = skipButtonVisible(pg)
            end
            return lastEndingSkipVisible
        end
        local function releaseEndingCursor()
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
            pcall(function() UserInputService.MouseIconEnabled = true end)
        end

        local function restoreInputs()
            local hum = humanoid()
            if hum then
                if hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
                if hum.Sit then pcall(function() hum.Sit = false end) end
                if hum.WalkSpeed <= 0 and lastSavedSpeed then hum.WalkSpeed = lastSavedSpeed end
                if hum.JumpPower <= 0 and lastSavedJump then hum.JumpPower = lastSavedJump end
                if not faceCameraEnabled and lastSavedRotate ~= nil and hum.AutoRotate ~= lastSavedRotate then
                    hum.AutoRotate = lastSavedRotate
                end
            end
            local ctrl = getControls()
            if ctrl and ctrl.enabled == false then
                pcall(function() ctrl:Enable() end)
            end
            if player:GetAttribute("NeedleInputLocked") == true then
                pcall(function() player:SetAttribute("NeedleInputLocked", nil) end)
            end
        end
        local function alignCharacterFacing()
            if not alive or not enabled or not active or not faceCameraEnabled then return end
            local hum, rt = humanoid(), root()
            if not hum or not rt or rt.Anchored or not yaw then return end
            local forward = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
            local oldLook = rt.CFrame.LookVector
            local flatOld = Vector3.new(oldLook.X, 0, oldLook.Z)
            local dot = flatOld.Magnitude > 0.01 and flatOld.Unit:Dot(forward) or 0
            if hum.AutoRotate then hum.AutoRotate = false end
            if dot < 0.9995 then
                local desired = CFrame.lookAt(rt.Position, rt.Position + forward, Vector3.yAxis)
                pcall(function() rt.CFrame = rt.CFrame:Lerp(desired, 0.35) end)
            end
        end
        local function directMovement()
            local hum = humanoid()
            if not hum or UserInputService:GetFocusedTextBox() then return end
            local function down(key)
                return UserInputService:IsKeyDown(key)
            end
            local x = (down(Enum.KeyCode.D) and 1 or 0) - (down(Enum.KeyCode.A) and 1 or 0)
            local z = (down(Enum.KeyCode.W) and 1 or 0) - (down(Enum.KeyCode.S) and 1 or 0)
            if x ~= 0 or z ~= 0 then
                if not yaw then return end
                local front = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
                local right = Vector3.new(-front.Z, 0, front.X)
                local motion = front*z + right*x
                if motion.Magnitude > 1 then motion = motion.Unit end
                pcall(function() hum:Move(motion, false) end)
            end
            if down(Enum.KeyCode.Space) then pcall(function() hum.Jump = true end) end
        end
        local function restoreCamera()
            restoreHeadTransparency()
            local cam = camera()
            if cam then
                local hum = humanoid()
                if hum then pcall(function() cam.CameraSubject = hum end) end
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            end
            local hum = humanoid()
            if hum and lastSavedRotate ~= nil then
                pcall(function() hum.AutoRotate = lastSavedRotate end)
            end
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            if originalMouseBehavior then
                pcall(function() UserInputService.MouseBehavior = originalMouseBehavior end)
                originalMouseBehavior = nil
            end
        end
        local function enablePlayableCamera(reason)
            if active then return end
            setCutsceneBypassActive(true)
            active = true
            setupPlayableCamera()
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            log("PLAYABLE CAMERA ENABLED: " .. tostring(reason))
            if scene == "THREE LEVERS" then watchLeverCamera() end
            forceCamera()
        end
        local function disablePlayableCamera(reason)
            unwatchLeverCamera()
            if not active then return end
            active = false
            restoreCamera()
            setCutsceneBypassActive(false)
            log("ROBLOX CAMERA RETURNED: " .. tostring(reason))
        end
        local function updateScene()
            if not alive then return end
            local now = os.clock()
            if player:GetAttribute("Chapter2ReleaseActive") == true then chapter2ReleaseSeen = true end
            local hasSkip = skipButtonOnScreen()
            if not hasSkip then yieldingToEnding = false end
            if hasSkip and not yieldingToEnding then
                yieldingToEnding = true
                recoveryEnd = 0
                log("SKIPPABLE NEEDLE ENDING DETECTED — camera bypass released; mouse unlocked for SKIP / hub AutoSkip")
            end
            local current = enabled and kind() or nil
            if current then
                if current ~= scene then
                    scene = current
                    if current == "THREE PUZZLES" then
                        unwatchLeverCamera()
                        log("CHAPTER 2 RELEASE: camera/movement override; optional transparency-only cutscene visual mask")
                    end
                    log("CUTSCENE DETECTED: " .. current)
                    if current == "THREE PUZZLES" then
                        log("Final cinematic: preserve normal viewing distance and hide cutscene visuals only; ending AutoSkip UI untouched")
                    end
                    recoveryEnd = 0
                    if not active then enablePlayableCamera(current) end
                end
            elseif scene then
                log("CUTSCENE FLAG CLEARED: " .. scene .. " — restoring Roblox camera in " .. RECOVERY_GRACE_SECONDS .. "s")
                restoreFinalCutsceneVisuals()
                unwatchLeverCamera()
                scene = nil
                recoveryEnd = now + RECOVERY_GRACE_SECONDS
                task.delay(RECOVERY_GRACE_SECONDS + 0.008, function()
                    if alive then updateScene() end
                end)
            end
            local shouldKeep = enabled and not yieldingToEnding and (current ~= nil or now < recoveryEnd)
            if shouldKeep then
                if not active then enablePlayableCamera("recovery / F7") end
                restoreInputs()
                showGameplayHud()
                hideFinalCutsceneVisuals()
            else
                restoreFinalCutsceneVisuals()
                restoreGameplayHud()
                if active then disablePlayableCamera("recovered / bypass disabled") end
            end
            if yieldingToEnding and lastEndingSkipVisible then releaseEndingCursor() end
        end

        hook(UserInputService.InputBegan:Connect(function(input, processed)
            if processed or UserInputService:GetFocusedTextBox() or shouldYieldCutsceneBypass() then return end
            if input.KeyCode == Enum.KeyCode.F3 then
                finalVisualsEnabled = not finalVisualsEnabled
                if not finalVisualsEnabled then restoreFinalCutsceneVisuals() end
                log("F3: final cinematic visual masking " .. (finalVisualsEnabled and "ENABLED" or "DISABLED"))
            elseif input.KeyCode == Enum.KeyCode.F4 then
                faceCameraEnabled = not faceCameraEnabled
                local hum = humanoid()
                if hum and not faceCameraEnabled and lastSavedRotate ~= nil then
                    pcall(function() hum.AutoRotate = lastSavedRotate end)
                end
                log("F4: camera-facing character alignment " .. (faceCameraEnabled and "ENABLED" or "DISABLED"))
                if faceCameraEnabled then alignCharacterFacing() end
            elseif input.KeyCode == Enum.KeyCode.F5 then
                hudEnabled = not hudEnabled
                if not hudEnabled then restoreGameplayHud() end
                log("F5: gameplay HUD preservation " .. (hudEnabled and "ENABLED" or "DISABLED"))
            elseif input.KeyCode == Enum.KeyCode.F7 then
                recoveryEnd = 0
                log("F7: Roblox camera recovery requested")
                updateScene()
            end
        end))
        hook(UserInputService.InputChanged:Connect(function(input)
            if not active or shouldYieldCutsceneBypass() then return end
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                if not cameraFirstPerson then
                    distance = clamp(distance - input.Position.Z * 1.5, 0.4, 22)
                end
            end
        end))
        hook(player.AttributeChanged:Connect(function(attr)
            if attr == "IntroCutsceneFinished" then
                if player:GetAttribute("IntroCutsceneFinished") == true and not introConfirmedAt then
                    introConfirmedAt = os.clock()
                    introNeutralSeen = player:GetAttribute("CutsceneActive") ~= true
                    log("SKIPPABLE INTRO COMPLETED — waiting for clean lever trigger; intro ignored")
                elseif player:GetAttribute("IntroCutsceneFinished") ~= true then
                    introConfirmedAt, introNeutralSeen = nil, false
                    chapter2ReleaseSeen, yieldingToEnding = false, false
                    lastEndingSkipScan, lastEndingSkipVisible = 0, false
                end
            elseif attr == "CutsceneActive" and player:GetAttribute("CutsceneActive") ~= true
                and introConfirmedAt then
                introNeutralSeen = true
            end
            if attr == "CutsceneActive" or attr == "Chapter2ReleaseActive" or
                attr == "IntroCutsceneFinished" or attr == "NeedleInputLocked" or attr == "NeedleOwned" then
                task.defer(updateScene)
            end
        end))
        hook(player.CharacterAdded:Connect(function()
            controls, lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil, nil
            task.delay(0.4, function() if alive and not active then rememberGameplay() end end)
        end))

        local function handleCameraInput()
            if not alive or not enabled or not active or not yaw then return end
            pcall(function()
                local dragging = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                local desired = cameraFirstPerson and Enum.MouseBehavior.LockCenter
                    or (dragging and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default)
                if UserInputService.MouseBehavior ~= desired then
                    UserInputService.MouseBehavior = desired
                end
            end)
            local ok, md = pcall(function() return UserInputService:GetMouseDelta() end)
            if ok and md and (cameraFirstPerson or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
                if math.abs(md.X) > 0 or math.abs(md.Y) > 0 then
                    yaw = yaw - md.X * 0.004
                    pitch = clamp(pitch - md.Y * 0.004, -1.0, 0.85)
                end
            end
            local now = os.clock()
            local dt = clamp(now - lastRenderTime, 0, 0.08)
            lastRenderTime = now
            local function down(key) return UserInputService:IsKeyDown(key) end
            if not UserInputService:GetFocusedTextBox() then
                local h = (down(Enum.KeyCode.Right) and 1 or 0) - (down(Enum.KeyCode.Left) and 1 or 0)
                local v = (down(Enum.KeyCode.Up) and 1 or 0) - (down(Enum.KeyCode.Down) and 1 or 0)
                if h ~= 0 or v ~= 0 then
                    yaw = yaw - h * dt * 1.9
                    pitch = clamp(pitch + v * dt * 1.3, -1.0, 0.85)
                end
            end
        end
        RunService:BindToRenderStep(renderId, renderPriority, function()
            if alive and yieldingToEnding and skipButtonOnScreen() then
                if active then updateScene() end
                releaseEndingCursor()
            end
            if alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then
                handleCameraInput()
                forceCamera()
                alignCharacterFacing()
                directMovement()
                showGameplayHud()
                if scene then hideFinalCutsceneVisuals() end
            else
                lastRenderTime = os.clock()
            end
        end)
        local simulationSignal = RunService.PreSimulation or RunService.Heartbeat
        hook(simulationSignal:Connect(function()
            if alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then directMovement() end
        end))

        local function stop()
            if not alive then return end
            local wasActive = active
            alive, enabled, active = false, false, false
            pcall(function() RunService:UnbindFromRenderStep(renderId) end)
            unwatchLeverCamera()
            if skipGuiAddedConnection then pcall(function() skipGuiAddedConnection:Disconnect() end) end
            skipGuiAddedConnection = nil
            restoreGameplayHud()
            restoreFinalCutsceneVisuals()
            for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
            if wasActive then restoreCamera() end
            setCutsceneBypassActive(false)
            if env.__BEYY_CUTSCENE_BYPASS_STOP == stop then env.__BEYY_CUTSCENE_BYPASS_STOP = nil end
            if _G.__BEYY_CUTSCENE_BYPASS_STOP == stop then _G.__BEYY_CUTSCENE_BYPASS_STOP = nil end
            if lastEndingSkipVisible then releaseEndingCursor() end
            log("STOPPED")
        end

        rememberGameplay()
        rememberGameplayHud()
        updateScene()
        task.spawn(function()
            while alive do
                task.wait(0.1)
                if not active and not scene then
                    rememberGameplay()
                    rememberGameplayHud()
                end
                updateScene()
            end
        end)
        log("READY: three-lever and three-puzzle cutscenes only; intro and needle ending excluded")
        log("F3 visual mask | F4 facing | F5 HUD | F7 restore | Exploit-tab toggle controls enable/disable")
        log("Mouse / arrows aim, WASD moves. Normal camera restores immediately after cutscenes.")
        log("Visual/client-side bypass only; no server cutscene timers or progression changed.")

        env.__BEYY_CUTSCENE_BYPASS_STOP = stop
        return stop
    end)
    if not ok or type(result) ~= "function" then
        warn("[BeyyHub] Cutscene bypass failed to start: " .. tostring(result))
        return false
    end
    cutsceneBypassStop = result
    return true
end
local function shutdownCutsceneBypass()
    local stopFn = cutsceneBypassStop
    cutsceneBypassStop = nil
    if stopFn then pcall(stopFn) end
end
local previousCutsceneHubCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    shutdownCutsceneBypass()
    if previousCutsceneHubCleanup then pcall(previousCutsceneHubCleanup) end
end

    overview:Section({ Title = "Cutscenes" })
    Registry.CutsceneBypass = overview:Toggle({
        Title = "Unskippable Cutscene Bypass", Value = false,
        Desc = "Keep local camera and movement during flagged unskippable scenes. Server timers still apply; menus, intro/skip screens and automation take priority.",
        Callback = function(enabled)
            if enabled then
                if not launchCutsceneBypass() then warn("[BeyyHub] Cutscene bypass could not start") end
            else shutdownCutsceneBypass() end
        end,
    })
end

do
    Header(SettingsTab, "Menu")
    Registry.MenuKeybind = SettingsTab:Keybind({
        Title = "Menu keybind", Value = "RightControl",
        Callback = function(v)
            pcall(function()
                local key = typeof(v) == "EnumItem" and v or Enum.KeyCode[v]
                Window:SetToggleKey(key)
            end)
        end,
    })
    SettingsTab:Button({
        Title = "Unload",
        Callback = function() doUnload() end,
    })

    Header(SettingsTab, "Config")
    SettingsTab:Paragraph({ Title = "Shared configs", Desc = "The last successfully loaded or saved config loads on startup in every chapter. If none is remembered, default is used when available." })
    local activeConfigPath = CACHE_FOLDER .. "/active_config.txt"
    local rememberedConfig = safeRead(activeConfigPath)
    if type(rememberedConfig) ~= "string" or not rememberedConfig:match("^[%w_%-%s]+$") then rememberedConfig = nil end
    local function rememberConfig(name)
        if not safeWrite(activeConfigPath, name) then
            Notify("Config", "Loaded/saved, but could not remember the startup config", 4, "x")
        end
    end
    local saveConfigName = rememberedConfig or "default"
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
        local startupConfig = rememberedConfig and containsConfig(saved, rememberedConfig) and rememberedConfig
            or (containsConfig(saved, "default") and "default" or nil)
        local initialConfig = startupConfig or saved[1]
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
                if success then rememberConfig(name) end
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
                if success then refreshConfigDropdown(name); rememberConfig(name) end
                Notify("Config", success and ("Saved: ".. name) or ("Failed: ".. tostring(savedData)), 3, success and "check" or "x")
            end,
        })
        task.defer(function()
            if Unloaded or not startupConfig then return end
            local ok, loaded, err = pcall(function() return buildConfig(startupConfig):Load() end)
            if ok and loaded ~= false and loaded ~= nil then
                print("[Config] Startup config loaded; waiting for saved toggle callbacks")
                task.spawn(function()

                    task.wait(0.75)
                    if Unloaded then return end
                    local persistedAFK
                    local readOK, configData = pcall(function()
                        local raw = readfile("WindUI/BeyyHub/config/" .. startupConfig .. ".json")
                        return game:GetService("HttpService"):JSONDecode(raw)
                    end)
                    if readOK and type(configData) == "table" then
                        local stored = (configData.__elements or configData).AutoFarmWins
                        if type(stored) == "table" and stored.__type == "Toggle" and type(stored.value) == "boolean" then
                            persistedAFK = stored.value
                        elseif type(stored) == "boolean" then
                            persistedAFK = stored
                        end
                    end
                    local sharedAFK = sharedAFKAtChapterEntry
                    if sharedAFK == "true" then persistedAFK = true end
                    if sharedAFK == "false" then persistedAFK = false end
                    if persistedAFK ~= nil and State.AutoFarmWins ~= persistedAFK then

                        local element = Registry.AutoFarmWins
                        if element and type(element.Set) == "function" then
                            local setOK, setErr = pcall(function() element:Set(persistedAFK) end)
                            if not setOK then warn("[BeyyHub] Restore AutoFarmWins toggle failed: ".. tostring(setErr)) end
                        end
                        State.AutoFarmWins = persistedAFK
                    end
                    print("[BeyyHub] Startup AutoFarmWins=".. tostring(State.AutoFarmWins)
                        .. " (saved=".. tostring(persistedAFK) .. ")")

                end)
            elseif containsConfig(getConfigNames(), startupConfig) then
                warn("[Config] Startup config auto-load failed: ".. tostring(ok and err or loaded))
            end
        end)
    end
end

end -- release menu construction locals before installing farming workers

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.CollectInterval) or 0.5)
        if not IN_GAME then break end
        local findingNeedle = State.AutoFindNeedle and LocalPlayer:GetAttribute("NeedleOwned") ~= true
            and findExposedNeedlePart() == nil
        if (State.AutoPickHay or findingNeedle) and farmLoopEnabled() and not isBagFull() then
            HayCache.ttl = 1.5
            local hay = findClosestHayCached()
            if hay then
                local id = hay:GetAttribute("HayId")
                if id then
                    local radiusHint = tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                    local candidates = getGrabCandidates(hay, radiusHint)
                    if hay.Parent and hay:GetAttribute("HayId")==id and (State.AutoPickHay or State.AutoFindNeedle) and farmLoopEnabled() then pcall(function() PickHay:FireServer(id, candidates) end) end
                else
                    if not needleHasPriority() then pcall(function() PickDroppedHay:FireServer(hay) end) end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.CollectInterval) or 0.5)
        if not IN_GAME then break end
        if State.AutoCollectDroppedHay and farmLoopEnabled() and not isBagFull() then
            DroppedCache.ttl = 1.5
            local d = findClosestDroppedCached()
            if d and State.AutoCollectDroppedHay and farmLoopEnabled() then
                pcall(function() PickDroppedHay:FireServer(d) end)
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.CollectInterval) or 0.5)
        if not IN_GAME then break end
        if State.AutoCollectGems and farmLoopEnabled() then
            GemsCache.ttl = 1.5
            local gemPart, id = findClosestGemCached()
            if gemPart and id and State.AutoCollectGems and farmLoopEnabled() then
                pcall(function() CollectGem:FireServer(id) end)
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(1)
        if not IN_GAME then break end
        if State.AutoSellHay and farmLoopEnabled() then
            local held = getHayHeld()
            local thresh = tonumber(State.SellThreshold) or 25
            if (State.SellOnlyIfFull and isBagFull()) or (held >= thresh) then
                if held > 0 then trySell() end
            end
        end
    end
end)

do
local tntRetry=createTntRetryGate(function() return TntAction end,function() return LocalPlayer:GetAttribute("TntCooldown") end)
local function tntScanChildren(folder)
    local children=folder:GetChildren()
    local index,started=0,os.clock()
    return function()
        if Unloaded or not State.AutoUseTNT then return nil end
        index+=1
        if index%32==0 and os.clock()-started>=0.002 then task.wait(); started=os.clock() end
        if Unloaded or not State.AutoUseTNT then return nil end
        local obj=children[index]
        if not obj then return nil end
        return index,obj
    end
end
local function findOrbitHayTarget(anchor)
    local folder = HayFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("HaystackClient")
        HayFolder = folder
    end
    if not folder then return nil end
    local aimX = anchor.X + math.cos(afkOrbitAngle) * afkOrbitRadius * 0.82
    local aimZ = anchor.Z + math.sin(afkOrbitAngle) * afkOrbitRadius * 0.82
    local closest, bestScore = nil, math.huge
    for _, part in tntScanChildren(folder) do
        if part.Parent==folder and part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil then
            local dx, dz = part.Position.X - anchor.X, part.Position.Z - anchor.Z
            local distFromCentre = math.sqrt(dx * dx + dz * dz)
            if distFromCentre > 3 and distFromCentre <= afkOrbitRadius * 1.45 then
                local aimDx, aimDz = part.Position.X - aimX, part.Position.Z - aimZ
                local score = aimDx * aimDx + aimDz * aimDz
                if score < bestScore then
                    closest = part
                    bestScore = score
                end
            end
        end
    end
    return closest
end
local function afkTntDistanceLimit()
    if not afkVacuumOrbitEnabled() then return 10 end
    local band=afkCurrentBand()
    local planned=band.radius+band.standoff-(band.characterInset or 0)
    -- Include the smoothed radius while changing rings, plus the original tolerance.
    return math.max(afkOrbitRadius,planned,afkSweepRadius or 0)+9
end
local function afkTntThrow(root, anchor)
    local origin = root.Position + Vector3.new(0, 1.5, 0)
    local hay = findOrbitHayTarget(anchor)
    local target = anchor + Vector3.new(math.cos(afkOrbitAngle) * afkOrbitRadius * 0.82, 1, math.sin(afkOrbitAngle) * afkOrbitRadius * 0.82)
    if hay and hay.Parent then
        target = hay.Position + Vector3.new(0, math.max(0.5, hay.Size.Y * 0.5), 0)
    end
    local displacement = target - origin
    if displacement.Magnitude < 1.5 then
        local look = root.CFrame.LookVector
        local planar = Vector3.new(look.X, 0, look.Z)
        if planar.Magnitude < 0.1 then planar = Vector3.new(0, 0, -1) end
        target = origin + planar.Unit * 4 + Vector3.new(0, -2, 0)
        displacement = target - origin
    end
    local up = math.abs(displacement.Unit:Dot(Vector3.yAxis)) > 0.97 and Vector3.zAxis or Vector3.yAxis
    local fromCharacter = CFrame.lookAt(origin, target, up)
    local travelSeconds = 0.45
    local throwVelocity = displacement / travelSeconds + Vector3.new(0, 0.5 * Workspace.Gravity * travelSeconds, 0)
    return fromCharacter, throwVelocity
end
task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ToolInterval) or 0.5)
        if not IN_GAME then break end
        local ok,err=xpcall(function()
            if not State.AutoUseTNT then tntTelemetry.SetStatus("Disabled");return end
            if not farmLoopEnabled() then
                tntTelemetry.SetStatus(needleHasPriority() and "Paused for needle pickup/turn-in" or "Paused for cutscene or round ending");return
            end
            if not owns("TntOwned") then tntTelemetry.SetStatus("Waiting for TNT ownership");return end
            if LocalPlayer:GetAttribute("NeedleInputLocked") then tntTelemetry.SetStatus("Paused: NeedleInputLocked");return end
            local afk=afkFarmModeActive()
            local root=getHRP()
            local target=afkPlayerAnchor or afkCameraAnchor
            local function positionAllowed()
                if not afk then return true end
                if not root or not target then tntTelemetry.SetStatus("Waiting for character or pile anchor");return false end
                local distance=afkHorizontalDistance(root.Position,target)
                local limit=afkTntDistanceLimit()
                if distance>limit then
                    tntTelemetry.SetStatus(string.format("Paused: outside orbit allowance (%.1f / %.1f studs)",distance,limit));return false
                end
                return true
            end
            if not positionAllowed() then return end
            if not tntRetry.Ready() then
                tntTelemetry.SetStatus(string.format("Cooldown: %.1fs",tntRetry.Remaining()));return
            end
            tntTelemetry.SetStatus("Waiting for server lighting confirmation")
            if not tntRetry.Light() then tntTelemetry.SetStatus("Lighting denied or unconfirmed; waiting before retry");return end
            if not State.AutoUseTNT or not farmLoopEnabled() or LocalPlayer:GetAttribute("NeedleInputLocked") then
                tntTelemetry.SetStatus("Cancelled before throw: priority or setting changed");return
            end
            local camera=Workspace.CurrentCamera
            root=getHRP();target=afkPlayerAnchor or afkCameraAnchor
            if not positionAllowed() then return end
            if afk then
                local from,velocity=afkTntThrow(root,target)
                -- Target selection can yield; respect priority again before sending.
                if not State.AutoUseTNT or not farmLoopEnabled() or LocalPlayer:GetAttribute("NeedleInputLocked") then
                    tntTelemetry.SetStatus("Cancelled during target selection");return
                end
                if not root.Parent or root~=getHRP() or not positionAllowed() then return end
                tntRetry.Throw(from,velocity)
            elseif camera then
                tntRetry.Throw(camera.CFrame,camera.CFrame.LookVector*40+Vector3.new(0,8,0))
            else tntTelemetry.SetStatus("Waiting for camera");return end
            tntTelemetry.SetStatus("Throw request sent")
        end,function(errorText) return tostring(errorText) end)
        if not ok then tntTelemetry.SetStatus("Worker error (will retry): "..err) end
    end
end)

end

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ToolInterval) or 0.5)
        if not IN_GAME then break end
        if State.AutoUsePitchfork and farmLoopEnabled() and owns("PitchforkOwned") then
            local hay = selectPitchforkHay(function() return not Unloaded and State.AutoUsePitchfork and farmLoopEnabled() end, 1.5)
            if hay then
                local id = hay:GetAttribute("HayId")
                if id and not needleHasPriority() then pcall(function() PitchforkDig:FireServer(id) end) end
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ToolInterval) or 0.5)
        if not IN_GAME then break end
        if State.AutoDeployDrone and farmLoopEnabled() and owns("DroneOwned") then
            if not LocalPlayer:GetAttribute("DroneDeployed") then
                pcall(function() DeployDrone:FireServer() end)
            end
        end
    end
end)

do
    local HEAT_FULL = 1.0
    local HEAT_EMPTY = 0.001
    local HEAT_STALLED_SECONDS = 4.0
    local COOLDOWN_SAFETY = 0.5
    local RUNTIME_FALLBACK_EXTRA = 1.0
    local held = false
    local ownsInputLock = false
    local mouseX, mouseY = 0, 0
    local wasEnabled = false
    local coolingPending = false
    local readyAt = 0
    local cycle = 0
    local lastStallWarning = -math.huge
    local HOTBAR_KEYS = {
        Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
        Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
        Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
    }

    local function getUpgradeLevel(name)
        local raw = tonumber(LocalPlayer:GetAttribute("HayUpgrade" .. name))
        return math.max(0, math.floor(raw or 0))
    end

    local function getVacuumTimings()
        local runtimeLevel = getUpgradeLevel("VacuumRuntime")
        local coolingLevel = getUpgradeLevel("VacuumCooling")
        local runtimeSeconds = 30 + 3 * runtimeLevel
        local coolingSeconds = coolingLevel == 0 and 13 or math.max(7, 12 - coolingLevel)
        return runtimeSeconds, coolingSeconds, runtimeLevel, coolingLevel
    end

    local forceVacuumReselect=false
    local function readHeat()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local hud = playerGui and playerGui:FindFirstChild("HUD")
        local overheat = hud and hud:FindFirstChild("Overheat")
        local fill = overheat and overheat:FindFirstChild("Fill")
        local replicated=LocalPlayer:GetAttribute("VacuumHeat")
        if type(replicated)=="number" and replicated==replicated and replicated>=0 and replicated<=1 then
            return replicated,fill and fill:IsA("GuiObject") and fill or nil
        end
        if not fill or not fill:IsA("GuiObject") then return nil, nil end
        local value = fill.Size.Y.Scale
        if type(value) ~= "number" or value ~= value or value < -0.05 or value > 1.05 then
            return nil, nil
        end
        return math.clamp(value, 0, 1), fill
    end

    local function mousePoint()
        local camera = Workspace.CurrentCamera
        if not camera then return nil end
        local screen = camera.ViewportSize
        if screen.X <= 0 or screen.Y <= 0 then return nil end
        return screen.X / 2, screen.Y / 2
    end

    local function releaseVacuum()
        if held then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 0)
            end)
            held = false
        end
        if ownsInputLock then
            autoUiMouseBusy = false
            ownsInputLock = false
        end
        vacuumSuctionActive = false
    end

    local vacuumFocus=watchVacuumFocus(function()
        local interrupted=held
        releaseVacuum()
        if interrupted then
            local _,cooling=getVacuumTimings()
            coolingPending=true
            readyAt=math.max(readyAt,os.clock()+cooling+COOLDOWN_SAFETY)
        end
    end)
    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        vacuumFocus.Stop()
        releaseVacuum()
        if previousCleanup then pcall(previousCleanup) end
    end

    local function mustReleaseForPriority()
        return Unloaded or not IN_GAME or afkOrbitTelemetry.RecoveryPending or not vacuumRequested() or not Window.Closed
            or earlyIntroPending or introSkipPending or needleHasPriority() or roundEndingVisible() or needlePickupActive
            or LocalPlayer:GetAttribute("NeedleInputLocked") == true
            or getHRP() == nil or Workspace.CurrentCamera == nil
    end

    local function canVacuum()
        return vacuumFocus.Ready() and not mustReleaseForPriority()
            and (not afkVacuumOrbitEnabled() or afkVacuumTargetReady)
    end

    local function equipVacuum()
        if forceVacuumReselect then
            if not canVacuum() then return false end
            local x,y=mousePoint()
            if not x then return false end
            VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0)
            local humanoid=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:UnequipTools() end
            local downOK=pcall(function() VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.One,false,game) end)
            task.wait(0.05)
            local upOK=pcall(function() VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.One,false,game) end)
            if not downOK or not upOK then return false end
            task.wait(0.15)
            if not canVacuum() then return false end
            forceVacuumReselect=false
        end
        local character = LocalPlayer.Character
        if not character then return false end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local vacuumTool = nil
        for _, container in ipairs({character, backpack}) do
            if container then
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("Tool") and obj.Name:lower():find("vacuum", 1, true) then
                        vacuumTool = obj
                        break
                    end
                end
            end
            if vacuumTool then break end
        end
        if vacuumTool and vacuumTool.Parent == character then return true end

        local slot = math.clamp(math.floor(tonumber(State.VacuumHotbarSlot) or 5), 1, 9)
        local key = HOTBAR_KEYS[slot]
        local downOK, downErr = pcall(function()
            VirtualInputManager:SendKeyEvent(true, key, false, game)
        end)
        task.wait(0.07)
        local upOK, upErr = pcall(function()
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)
        if not downOK or not upOK then
            warn("[Vacuum] Hotbar slot " .. tostring(slot) .. " input failed: " .. tostring(downOK and upErr or downErr))
            return false
        end
        if not canVacuum() then return false end
        task.wait(0.20)
        if not canVacuum() then return false end

        if vacuumTool and vacuumTool.Parent == backpack then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return false end
            local ok = pcall(function() humanoid:EquipTool(vacuumTool) end)
            if not ok then return false end
            task.wait(0.08)
        end
        return canVacuum()
    end

    task.spawn(function()
        while not Unloaded do
            task.wait(0.06)
            if not IN_GAME then break end
            if not vacuumRequested() then
                releaseVacuum()
                wasEnabled = false
            else
                local runtime, cooling, runtimeLevel, coolingLevel = getVacuumTimings()
                local heat, heatFill = readHeat()
                if not wasEnabled then
                    wasEnabled = true

                    if heat == nil then
                        readyAt = os.clock() + cooling + COOLDOWN_SAFETY
                    end
                    print(string.format("[Vacuum] Heat HUD %s; Runtime L%d %.0fs / Cooling L%d %.0fs (fallback timings)",
                        heat ~= nil and "found (live control)" or "missing (timed fallback)",
                        runtimeLevel, runtime, coolingLevel, cooling))
                end

                if heat and heat >= HEAT_FULL then
                    if not coolingPending then readyAt = os.clock() + cooling + COOLDOWN_SAFETY end
                    coolingPending = true
                end
                if coolingPending then
                    if afkOrbitTelemetry.VacuumStatus then afkOrbitTelemetry.VacuumStatus:SetDesc("Cooling; waiting for replicated ready state or empty heat") end
                    releaseVacuum()
                    if heat ~= nil then
                        if heat <= HEAT_EMPTY or (LocalPlayer:GetAttribute("VacuumState")=="Ready" and LocalPlayer:GetAttribute("VacuumOverheated")~=true) then
                            coolingPending = false
                            readyAt = 0
                            print("[Vacuum] Heat returned to 0%; ready to resume suction")
                        end
                    elseif os.clock() >= readyAt then

                        coolingPending = false
                        print("[Vacuum] Heat HUD missing; fallback cooldown completed")
                    end
                elseif os.clock() >= readyAt and canVacuum() and not autoUiMouseBusy then

                    if heat ~= nil and heat > HEAT_EMPTY then
                        task.wait(0.15)
                        local laterHeat = readHeat()
                        if laterHeat and laterHeat < heat - 0.001 then
                            coolingPending = true
                            print("[Vacuum] Existing cooldown detected; waiting for heat to reach 0%")
                        end
                    end
                    if not coolingPending and canVacuum() and not autoUiMouseBusy then
                        local focusGeneration=vacuumFocus.Generation()
                        cycle += 1
                        vacuumSuctionActive = true
                        autoUiMouseBusy = true
                        ownsInputLock = true
                        local didHold, reachedFull, hadLiveHeat = false, false, false
                        local sizeConnection = nil
                        local success, err = xpcall(function()
                            if not canVacuum() or not equipVacuum() then return end
                            if not canVacuum() then return end
                            runtime, cooling, runtimeLevel, coolingLevel = getVacuumTimings()
                            local x, y = mousePoint()
                            if not x then return end
                            mouseX, mouseY = x, y

                            local startHeat, activeFill = readHeat()
                            hadLiveHeat = startHeat ~= nil
                            if startHeat and startHeat >= HEAT_FULL then
                                reachedFull = true
                                return
                            end
                            if activeFill then
                                local previousValue = startHeat
                                sizeConnection = activeFill:GetPropertyChangedSignal("Size"):Connect(function()
                                    local current = readHeat()
                                    if current==nil then return end

                                    if current >= HEAT_FULL or (previousValue and previousValue >= 0.95 and current < previousValue - 0.15) then
                                        reachedFull = true
                                        releaseVacuum()
                                    end
                                    previousValue = current
                                end)
                            end
                            if not vacuumFocus.Ready() or focusGeneration~=vacuumFocus.Generation() then return end
                            -- Reconcile stale engine input before every new hold, including in background.
                            pcall(function() VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0) end)
                            task.wait(0.05)
                            if not canVacuum() or focusGeneration~=vacuumFocus.Generation() then return end
                            local pressed = pcall(function()
                                VirtualInputManager:SendMouseMoveEvent(x, y, game)
                                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                            end)
                            if not pressed then return end
                            held = true
                            if afkOrbitTelemetry.VacuumStatus then afkOrbitTelemetry.VacuumStatus:SetDesc("Holding vacuum; monitoring heat progress") end
                            if focusGeneration~=vacuumFocus.Generation() then releaseVacuum(); return end
                            didHold = true
                            print(string.format("[Vacuum] Cycle %d: holding Mouse1 to 100%% heat (Runtime L%d)", cycle, runtimeLevel))

                            local started = os.clock()
                            local lastHeat = startHeat
                            local lastRisingAt = started
                            local lastRisingHeat=startHeat

                            local fallbackDeadline = started + runtime + RUNTIME_FALLBACK_EXTRA
                            while held and not reachedFull and not mustReleaseForPriority() do
                                local current, newFill = readHeat()
                                if current ~= nil then
                                    hadLiveHeat = true
                                    if current >= HEAT_FULL
                                        or (lastHeat and lastHeat >= 0.95 and current < lastHeat - 0.15) then
                                        reachedFull = true
                                        break
                                    end
                                    if lastRisingHeat == nil or current > lastRisingHeat + 0.002 then
                                        lastRisingAt = os.clock();lastRisingHeat=current
                                    end
                                    lastHeat = current

                                    if os.clock() - lastRisingAt > HEAT_STALLED_SECONDS then
                                        forceVacuumReselect=true
                                        if afkOrbitTelemetry.VacuumStatus then afkOrbitTelemetry.VacuumStatus:SetDesc("Stall detected; releasing input and reselecting vacuum") end
                                        if os.clock() - lastStallWarning > 30 then
                                            lastStallWarning = os.clock()
                                            warn("[Vacuum] Heat stalled; releasing stale VIM hold and retrying a fresh press")
                                        end
                                        break
                                    end
                                elseif os.clock() >= fallbackDeadline then
                                    reachedFull = true
                                    break
                                end
                                task.wait(0.04)
                            end
                        end, function(e) return tostring(e) end)
                        if sizeConnection then sizeConnection:Disconnect() end
                        releaseVacuum()
                        if not success then warn("[Vacuum] Controller error: " .. tostring(err)) end
                        if reachedFull then
                            coolingPending = true
                            readyAt = os.clock() + cooling + COOLDOWN_SAFETY
                            if hadLiveHeat then
                                print(string.format("[Vacuum] Reached 100%% heat; Mouse1 released. Waiting for bar to reach 0%% (Cooling L%d)", coolingLevel))
                            else
                                print(string.format("[Vacuum] No heat HUD; timed fallback cooldown %.2fs", cooling + COOLDOWN_SAFETY))
                            end
                        elseif didHold then

                            readyAt = math.max(readyAt, os.clock() + 0.3)
                            print("[Vacuum] Suction interrupted below 100%; will resume from current heat")
                        else
                            readyAt = os.clock() + 1.0
                        end
                    end
                end
            end
        end
        releaseVacuum()
    end)
end

-- Bounded tracing runs only while a needle pickup is active.
local needleTraceLoadedAt=os.clock()
local needleTraceSequence=0
local needleTraceLastSuccess
local needleTraceFailedTarget
local needleTraceBaselineLoaded=false
local function beginNeedleTrace(needle,character,root,camera,started)
    if not needleTraceBaselineLoaded then
        needleTraceBaselineLoaded=true
        needleTraceLastSuccess=_G.__BEYY_NEEDLE_LAST_SUCCESS
        if not needleTraceLastSuccess and type(readfile)=="function" then
            local ok,previous=pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile("BeyyHub/needle_success_trace.json"))
            end)
            if ok and type(previous)=="table" and previous.Schema==1 and previous.Success==true and previous.PlaceId==game.PlaceId then needleTraceLastSuccess=previous end
        end
    end
    needleTraceSequence+=1
    local report={Schema=1,Attempt=needleTraceSequence,Time=os.time(),SessionUptime=os.clock()-needleTraceLoadedAt,PlaceId=game.PlaceId,JobId=game.JobId,
        Events={},Snapshots={},DroppedEvents=0}
    local connections={}
    local stopped=false
    local lastObserved={}
    local originalParent=needle.Parent
    local originalServer=Workspace:FindFirstChild("NeedleObjectiveServer")
    local mouse
    pcall(function() mouse=LocalPlayer:GetMouse() end)
    local function path(object)
        if not object then return "nil" end
        local ok,value=pcall(object.GetFullName,object)
        return ok and value or tostring(object)
    end
    local function vector(v)
        local result={X=v.X,Y=v.Y}
        if typeof(v)=="Vector3" then result.Z=v.Z end
        return result
    end
    local function event(kind,data)
        if stopped then return end
        local observationKey,observationValue
        if kind=="CameraType" or kind=="CameraSubject" then observationKey=kind;observationValue=data.Value
        elseif kind=="PlayerAttribute" then observationKey=kind..tostring(data.Name);observationValue=data.Value end
        if observationKey then
            if lastObserved[observationKey]==observationValue then return end
            lastObserved[observationKey]=observationValue
        end
        if #report.Events>=128 then report.DroppedEvents+=1;return end
        report.Events[#report.Events+1]={At=os.clock()-started,Kind=kind,Data=data}
    end
    local function watch(signal,kind,describe)
        local ok,connection=pcall(function()
            return signal:Connect(function(...)
                local args={...}
                local captured,data=pcall(describe,table.unpack(args))
                event(kind,captured and data or {CaptureError=tostring(data)})
            end)
        end)
        if ok then connections[#connections+1]=connection end
    end
    local function mouseState()
        return {LeftPressed=UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
            Behavior=tostring(UserInputService.MouseBehavior),Position=vector(UserInputService:GetMouseLocation()),
            GameMouseTarget=mouse and path(mouse.Target) or "unavailable"}
    end
    local function snapshot(stage)
        if stopped or #report.Snapshots>=24 then return end
        local ok,data=pcall(function()
            local tools={}
            for _,item in ipairs(character:GetChildren()) do if item:IsA("Tool") then tools[#tools+1]=item.Name end end
            local viewport=camera.ViewportSize/2
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={character}
            local ray=camera:ViewportPointToRay(viewport.X,viewport.Y)
            local hit=Workspace:Raycast(ray.Origin,ray.Direction*50,params)
            local inset=GuiService:GetGuiInset()
            return {Stage=stage,Mouse=mouseState(),Tools=tools,MenuClosed=Window.Closed,UIOwnsMouse=autoUiMouseBusy==true,
                Unloaded=Unloaded,PickupOwnsMouse=needlePickupActive==true,OrbitEnabled=afkVacuumOrbitEnabled(),CharacterSame=LocalPlayer.Character==character,CharacterLive=character.Parent~=nil,RootLive=root.Parent~=nil,
                ObjectiveLive=needle.Parent~=nil,ObjectiveParentSame=needle.Parent==originalParent,
                ObjectiveServerSame=Workspace:FindFirstChild("NeedleObjectiveServer")==originalServer,
                Target=path(needle),TargetPosition=vector(needle.Position),Distance=(root.Position-needle.Position).Magnitude,
                TargetHayId=resolveNeedleHayId(needle),Hidden=needle:GetAttribute("HIDDEN"),HiddenWithin=needle:GetAttribute("HIDDEN_WITHIN"),
                CameraSame=Workspace.CurrentCamera==camera,CameraType=tostring(camera.CameraType),CameraSubject=path(camera.CameraSubject),
                CameraPosition=vector(camera.CFrame.Position),CameraLook=vector(camera.CFrame.LookVector),
                CenterRayHit=hit and path(hit.Instance) or "none",GuiInset=vector(inset),
                VacuumActive=LocalPlayer:GetAttribute("VacuumActive"),VacuumState=LocalPlayer:GetAttribute("VacuumState"),NeedleEquippedSlot=LocalPlayer:GetAttribute("NeedleEquippedSlot"),NeedleOwned=LocalPlayer:GetAttribute("NeedleOwned"),NeedleInputLocked=LocalPlayer:GetAttribute("NeedleInputLocked"),
                CutsceneActive=LocalPlayer:GetAttribute("CutsceneActive"),HoveredHayId=LocalPlayer:GetAttribute("HoveredHayId")}
        end)
        report.Snapshots[#report.Snapshots+1]={At=os.clock()-started,Data=ok and data or {Stage=stage,CaptureError=tostring(data)}}
    end
    -- Signal callbacks are observation only; they never change input or gameplay state.
    watch(UserInputService.InputBegan,"InputBegan",function(input,processed)
        return {Type=tostring(input.UserInputType),Key=tostring(input.KeyCode),GameProcessed=processed}
    end)
    watch(UserInputService.InputEnded,"InputEnded",function(input,processed)
        return {Type=tostring(input.UserInputType),Key=tostring(input.KeyCode),GameProcessed=processed}
    end)
    watch(UserInputService.WindowFocused,"Focus",function() return {Focused=true} end)
    watch(UserInputService.WindowFocusReleased,"Focus",function() return {Focused=false} end)
    watch(UserInputService:GetPropertyChangedSignal("MouseBehavior"),"MouseBehavior",function() return mouseState() end)
    watch(Workspace:GetPropertyChangedSignal("CurrentCamera"),"CurrentCamera",function() return {Same=Workspace.CurrentCamera==camera} end)
    watch(camera:GetPropertyChangedSignal("CameraType"),"CameraType",function() return {Value=tostring(camera.CameraType)} end)
    watch(camera:GetPropertyChangedSignal("CameraSubject"),"CameraSubject",function() return {Value=path(camera.CameraSubject)} end)
    watch(character.ChildAdded,"CharacterChildAdded",function(item) return {Path=path(item),Class=item.ClassName,Tool=item:IsA("Tool")} end)
    watch(character.ChildRemoved,"CharacterChildRemoved",function(item) return {Path=path(item),Class=item.ClassName,Tool=item:IsA("Tool")} end)
    watch(LocalPlayer.CharacterAdded,"CharacterAdded",function(item) return {Same=item==character} end)
    watch(needle.AncestryChanged,"ObjectiveAncestry",function(_,parent) return {Parent=path(parent),Same=parent==originalParent} end)
    for _,attribute in ipairs({"NeedleOwned","NeedleInputLocked","CutsceneActive","VacuumActive","HandHoldEnabled","PitchforkHoldEnabled"}) do
        watch(LocalPlayer:GetAttributeChangedSignal(attribute),"PlayerAttribute",function() return {Name=attribute,Value=tostring(LocalPlayer:GetAttribute(attribute))} end)
    end
    local lastCameraEvent=-math.huge
    local function checkCamera(expected)
        if not expected or stopped or os.clock()-lastCameraEvent<0.1 then return end
        local ok,changed=pcall(function()
            return Workspace.CurrentCamera~=camera or camera.CameraType~=Enum.CameraType.Scriptable
                or (camera.CFrame.Position-expected.Position).Magnitude>0.1
                or camera.CFrame.LookVector:Dot(expected.LookVector)<0.999
        end)
        if ok and changed then lastCameraEvent=os.clock();event("CameraChangedBeforeAim",{Position=vector(camera.CFrame.Position),Type=tostring(camera.CameraType)}) end
    end
    local function finish(success,reason,clicks)
        if stopped then return end
        snapshot("after-cleanup")
        report.Success=success;report.Reason=reason;report.Clicks=clicks;report.Duration=os.clock()-started
        stopped=true
        for _,connection in ipairs(connections) do pcall(connection.Disconnect,connection) end
        task.defer(function()
            local ok,err=pcall(function()
                local history=_G.__BEYY_NEEDLE_TRACE_HISTORY or {}
                history[#history+1]=report
                if #history>12 then table.remove(history,1) end
                _G.__BEYY_NEEDLE_TRACE_HISTORY=history
                if success then needleTraceLastSuccess=report;_G.__BEYY_NEEDLE_LAST_SUCCESS=report end
                local payload=success and report or {Failure=report,LastSuccess=needleTraceLastSuccess}
                local json=game:GetService("HttpService"):JSONEncode(payload)
                local filename="BeyyHub/needle_"..(success and "success" or (needleTraceFailedTarget==needle and "retry" or "failure")).."_trace.json"
                if success then needleTraceFailedTarget=nil else needleTraceFailedTarget=needle end
                local saved=false
                if type(writefile)=="function" then saved=pcall(writefile,filename,json) end
                if not success then
                    _G.__BEYY_NEEDLE_FAILURE_TRACE=json
                    warn(string.format("[Needle Trace] Attempt %d failed (%d clicks); %s. Trace %s",report.Attempt,clicks,tostring(reason),saved and filename or "available in _G.__BEYY_NEEDLE_FAILURE_TRACE"))
                end
            end)
            if not ok then warn("[Needle Trace] Save failed: "..tostring(err)) end
        end)
    end
    snapshot("start")
    return {Event=event,Snapshot=snapshot,CheckCamera=checkCamera,Finish=finish}
end

do
    local SETTINGS = { HeightAboveNeedle = 2.5, HorizontalOffsetStuds = 2.0, MaxClicks = 8, MousePressSeconds = 0.10, OwnershipWaitSeconds = 0.10, RetryDelay = 0.6,
        FilterRadiusPixels = 50, FilterNeedleRadiusStuds = 8, FilterMaxParts = 400 }
    local busy = false
    local lastAttempt = 0
    local trackedNeedle = nil
    local confirmedNeedlePart, confirmedNeedleId = nil, nil
    local activeCleanup = nil
    local renderName = "BeyyV103_00NeedleAimHover_" .. tostring(LocalPlayer.UserId)
    local lastPrerequisiteWarnAt = -math.huge
    local function reportPrerequisite(reason)
        if os.clock() - lastPrerequisiteWarnAt >= 30 then
            lastPrerequisiteWarnAt = os.clock()
            warn("[Needle] Pickup waiting: " .. reason .. " (retrying automatically; warnings limited to once every 30s)")
        end
    end
    local function owned() return LocalPlayer:GetAttribute("NeedleOwned") == true end
    local function tryPickup(needle)
        if busy or Unloaded or roundEndingVisible() or not State.AutoPickupNeedle or not Window.Closed or owned() or not needle or not needle.Parent then return false end
        busy = true
        needlePickupActive = true
        local started = os.clock()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        local needleId = resolveNeedleHayId(needle)
        if not char or not char.Parent or not root or not root.Parent then
            reportPrerequisite("character or HumanoidRootPart unavailable")
            busy = false
            needlePickupActive = false
            return false
        end
        if not cam then
            reportPrerequisite("Workspace.CurrentCamera unavailable")
            busy = false
            needlePickupActive = false
            return false
        end
        local physicalFallback = type(needleId) ~= "number"
        setNeedlePickupStatus(physicalFallback and "Attempting normal mouse pickup; no numeric HayId found" or ("Picking up needle ID "..tostring(needleId)))
        local trace=beginNeedleTrace(needle,char,root,cam,started)
        local initialPivot = char:GetPivot()
        local originalHover = LocalPlayer:GetAttribute("HoveredHayId")
        local previousPickupCameraType, previousPickupCameraSubject, previousPickupCameraCFrame
        local pickupCameraCaptured = false
        local mouseDown, bound, cleaned, success = false, false, false, false
        local observedOwnership = false
        local clicks = 0
        local filteredParts = {}
        local queryStats = { filtered = 0 }
        local failureReason = "No NeedleOwned confirmation"
        local function restoreQueryFilter()
            for part, previous in pairs(filteredParts) do
                local ok = pcall(function()
                    if part.Parent then
                        part.CanQuery = previous.query
                        part.CanCollide = previous.collide
                    end
                end)
                filteredParts[part] = nil
            end
        end
        local function applyQueryFilter()
            local activeCamera = Workspace.CurrentCamera
            if not activeCamera or not needle.Parent then return end
            local screenSize = activeCamera.ViewportSize
            if screenSize.Y <= 0 then return end
            local middle = screenSize / 2
            local projectedNeedle = activeCamera:WorldToViewportPoint(needle.Position)
            local focalLength = screenSize.Y / (2 * math.tan(math.rad(activeCamera.FieldOfView / 2)))

            for pass = 1, 2 do
                if queryStats.filtered >= SETTINGS.FilterMaxParts then break end
                for _, folderName in ipairs({"HaystackClient", "HaystackCollision"}) do
                    local folder = Workspace:FindFirstChild(folderName)
                    if folder then
                        for _, part in budgetedFolderChildren(folder,function() return not Unloaded and State.AutoPickupNeedle and needle.Parent~=nil end,true) do
                            if queryStats.filtered >= SETTINGS.FilterMaxParts then break end
                            if Unloaded or not State.AutoPickupNeedle or observedOwnership then return end
                            if part:IsA("BasePart") and part ~= needle
                                and part:GetAttribute("IsNeedleObjective") ~= true
                                and part.CanQuery and not filteredParts[part] then
                                local nearNeedle = (part.Position - needle.Position).Magnitude
                                    <= SETTINGS.FilterNeedleRadiusStuds + math.min(part.Size.Magnitude * 0.5, 4)
                                local qualifies = (pass == 1 and nearNeedle)
                                if pass == 2 and not nearNeedle then
                                    local screen = activeCamera:WorldToViewportPoint(part.Position)
                                    if screen.Z > 0 and screen.Z < 45 then
                                        local radius = (part.Size.Magnitude * 0.5) * focalLength / screen.Z
                                        local distanceFromClick = (Vector2.new(screen.X, screen.Y) - middle).Magnitude
                                        local distanceFromNeedle = (Vector2.new(screen.X, screen.Y)
                                            - Vector2.new(projectedNeedle.X, projectedNeedle.Y)).Magnitude
                                        qualifies = distanceFromClick <= SETTINGS.FilterRadiusPixels + radius
                                            or (projectedNeedle.Z > 0 and distanceFromNeedle <= SETTINGS.FilterRadiusPixels + radius)
                                    end
                                end
                                if qualifies then
                                    local originalQuery, originalCollide = part.CanQuery, part.CanCollide
                                    local ok = pcall(function()
                                        if part.CanCollide then part.CanCollide = false end
                                        part.CanQuery = false
                                    end)
                                    if ok and not part.CanQuery then
                                        filteredParts[part] = { query = originalQuery, collide = originalCollide }
                                        queryStats.filtered += 1
                                    else
                                        pcall(function()
                                            part.CanQuery = originalQuery
                                            part.CanCollide = originalCollide
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local ownershipConnection
        local function captureOwnership()
            if not observedOwnership and owned() then
                observedOwnership = true
            end
        end
        ownershipConnection = LocalPlayer:GetAttributeChangedSignal("NeedleOwned"):Connect(captureOwnership)
        captureOwnership()
        local function releaseMouse()
            if not mouseDown then return end
            local center = cam.ViewportSize / 2
            pcall(function() VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0) end)
            trace.Event("ReleaseRequested",{Click=clicks})
            mouseDown = false
        end
        local function waitForConfirmation(seconds)
            local deadline = os.clock() + seconds
            while not Unloaded and State.AutoPickupNeedle and os.clock() < deadline do
                captureOwnership()
                if observedOwnership then return true end
                task.wait(0.025)
            end
            captureOwnership()
            return observedOwnership
        end
        local function cleanup()
            if cleaned then return end
            cleaned = true
            captureOwnership()
            success=success or observedOwnership
            trace.Event("CleanupStarted",{})
            trace.Snapshot("before-cleanup")
            releaseMouse()
            if bound then
                pcall(function() RunService:UnbindFromRenderStep(renderName) end)
                bound = false
            end
            if pickupCameraCaptured and cam.Parent then
                pcall(function()

                    local restoreType = afkFarmModeActive() and Enum.CameraType.Custom
                        or previousPickupCameraType or Enum.CameraType.Custom
                    cam.CameraType = restoreType
                    if previousPickupCameraSubject and previousPickupCameraSubject.Parent then
                        cam.CameraSubject = previousPickupCameraSubject
                    else
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid then cam.CameraSubject = humanoid end
                    end
                    if restoreType == Enum.CameraType.Scriptable and previousPickupCameraCFrame then
                        cam.CFrame = previousPickupCameraCFrame
                    end
                end)
            end
            if ownershipConnection then
                ownershipConnection:Disconnect()
                ownershipConnection = nil
            end
            restoreQueryFilter()
            captureOwnership()
            success = success or observedOwnership
            pcall(function()
                if not physicalFallback and LocalPlayer:GetAttribute("HoveredHayId") == needleId then
                    LocalPlayer:SetAttribute("HoveredHayId", originalHover)
                end
            end)
            if success then
                confirmedNeedlePart, confirmedNeedleId = needle, needleId
            elseif char.Parent then
                pcall(function() char:PivotTo(initialPivot) end)
            end
            if physicalFallback and not success then recordNeedleDiagnostic(needle) end
            setNeedlePickupStatus(success and "Needle collected; waiting for turn-in" or ("Pickup failed: "..tostring(failureReason)))
            local elapsed = os.clock() - started
            if success then
                print(string.format("[Needle] Picked up HayId=%s in %.2fs (%d clicks)",
                    tostring(needleId), elapsed, clicks))
            else
                warn(string.format("[Needle] Pickup failed HayId=%s: %s (%d clicks)",
                    tostring(needleId), tostring(failureReason), clicks))
            end
            trace.Finish(success,success and "NeedleOwned confirmed" or failureReason,clicks)
            activeCleanup = nil
            busy = false
            needlePickupActive = false
            lastAttempt = os.clock()
        end
        activeCleanup = cleanup
        local ok, err = xpcall(function()

            if afkFarmModeActive() then enterNeedleCamera() end
            previousPickupCameraType = cam.CameraType
            previousPickupCameraSubject = cam.CameraSubject
            previousPickupCameraCFrame = cam.CFrame
            pickupCameraCaptured = true
            local inputDeadline = os.clock() + 0.8
            while autoUiMouseBusy and os.clock() < inputDeadline and not Unloaded do task.wait(0.01) end
            if autoUiMouseBusy then failureReason = "UI click still owns mouse"; return end
            if Unloaded or not State.AutoPickupNeedle then failureReason = "Pickup cancelled before teleport"; return end
            local rootToPivot = root.CFrame:ToObjectSpace(char:GetPivot())

            local cameraForward = cam.CFrame.LookVector
            local horizontalForward = Vector3.new(cameraForward.X, 0, cameraForward.Z)
            if horizontalForward.Magnitude < 0.05 then
                local rootForward = root.CFrame.LookVector
                horizontalForward = Vector3.new(rootForward.X, 0, rootForward.Z)
            end
            if horizontalForward.Magnitude < 0.05 then
                horizontalForward = Vector3.new(0, 0, -1)
            end
            horizontalForward = horizontalForward.Unit
            local pickupHorizontalOffset=physicalFallback and 0.75 or SETTINGS.HorizontalOffsetStuds
            local pickupHeight=physicalFallback and 2.0 or SETTINGS.HeightAboveNeedle
            local targetRootPosition = needle.Position - horizontalForward * pickupHorizontalOffset
                + Vector3.new(0, pickupHeight, 0)
            local intendedDistance = (targetRootPosition - needle.Position).Magnitude
            local correctionLimit = intendedDistance + 0.35
            local retryLimit = intendedDistance + 0.80
            local function placeNearNeedle()

                local lookTarget = Vector3.new(needle.Position.X, targetRootPosition.Y, needle.Position.Z)
                local targetRoot = CFrame.lookAt(targetRootPosition, lookTarget)
                char:PivotTo(targetRoot * rootToPivot)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end

            local cameraPosition = targetRootPosition - horizontalForward * 3.5
                + Vector3.new(0, 3.5, 0)
            local expectedPickupCamera
            local function aimAtNeedle()
                if Unloaded or not needle.Parent or observedOwnership or roundEndingVisible() then return end
                if Workspace.CurrentCamera ~= cam then return end
                trace.CheckCamera(expectedPickupCamera)
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.lookAt(cameraPosition, needle.Position, Vector3.yAxis)
                expectedPickupCamera=cam.CFrame
            end
            local function selectHandForNeedle()
                if Unloaded or not State.AutoPickupNeedle or not Window.Closed then return false,"Hand selection cancelled" end
                local center=cam.ViewportSize/2
                local releaseOK,releaseError=pcall(function() VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0) end)
                if not releaseOK then return false,"Could not release vacuum input: "..tostring(releaseError) end
                local humanoid=char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:UnequipTools() end
                trace.Event("HandSelectionRequested",{Slot=1})
                local downOK,downError=pcall(function() VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.One,false,game) end)
                task.wait(0.05)
                -- Always pair the release, including cancellation while waiting.
                local upOK,upError=pcall(function() VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.One,false,game) end)
                if not downOK or not upOK then return false,"Hand hotbar input failed: "..tostring(downOK and upError or downError) end
                task.wait(0.15)
                local deadline=os.clock()+0.5
                while not Unloaded and State.AutoPickupNeedle and Window.Closed and LocalPlayer:GetAttribute("VacuumActive")==true and os.clock()<deadline do task.wait(0.025) end
                if Unloaded or not State.AutoPickupNeedle or not Window.Closed then return false,"Hand selection cancelled" end
                trace.Snapshot("after-hand-selection")
                if LocalPlayer:GetAttribute("VacuumActive")==true then return false,"Vacuum still active after selecting hand slot 1" end
                return true
            end
            if physicalFallback then
                local handReady,handReason=selectHandForNeedle()
                if not handReady then failureReason=handReason;return end
            end
            placeNearNeedle()
            trace.Snapshot("after-positioning")
            captureOwnership()
            if observedOwnership then success = true; return end
            local function forceHover()
                if not Unloaded and State.AutoPickupNeedle and needle.Parent and not observedOwnership then
                    aimAtNeedle()
                    if not physicalFallback and LocalPlayer:GetAttribute("HoveredHayId") ~= needleId then
                        LocalPlayer:SetAttribute("HoveredHayId", needleId)
                    end
                end
            end
            if not physicalFallback then LocalPlayer:SetAttribute("HoveredHayId", needleId) end
            aimAtNeedle()
            RunService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value + 30, forceHover)
            bound = true
            RunService.RenderStepped:Wait()
            if not physicalFallback then applyQueryFilter() end

            RunService.RenderStepped:Wait()
            for i = 1, SETTINGS.MaxClicks do
                captureOwnership()
                if observedOwnership then success = true; break end
                if Unloaded or not State.AutoPickupNeedle or not Window.Closed or roundEndingVisible() then failureReason = "Pickup cancelled at round end"; break end
                if not needle.Parent then failureReason = "Needle disappeared before confirmation"; break end
                if not char.Parent or not root.Parent then failureReason = "Character disappeared"; break end
                local distance = (root.Position - needle.Position).Magnitude
                if distance > correctionLimit then
                    placeNearNeedle()
                    distance = (root.Position - needle.Position).Magnitude
                end
                if distance > retryLimit then
                    failureReason = string.format("Root drifted beyond diagonal target (%.2f studs; target %.2f)", distance, intendedDistance)
                    break
                end
                forceHover()

                local center = cam.ViewportSize / 2
                pcall(function() VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game) end)
                RunService.RenderStepped:Wait()
                forceHover()
                local hoverMatches = physicalFallback or LocalPlayer:GetAttribute("HoveredHayId") == needleId
                if physicalFallback then
                    local ray=cam:ViewportPointToRay(center.X,center.Y)
                    local params=RaycastParams.new()
                    params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances={char}
                    local hit=Workspace:Raycast(ray.Origin,ray.Direction*50,params)
                    local needleModel=needle.Parent
                    local hitNeedle=hit and (hit.Instance==needle or (needleModel and needleModel:IsA("Model") and hit.Instance:IsDescendantOf(needleModel) and hit.Instance:GetAttribute("IsNeedleObjective")==true))
                    if not hitNeedle then
                        failureReason="Physical click ray blocked by "..(hit and hit.Instance:GetFullName() or "no target")
                        break
                    end
                end
                local projectedNeedle, onScreen = cam:WorldToViewportPoint(needle.Position)
                local screenOffset = onScreen and (Vector2.new(projectedNeedle.X, projectedNeedle.Y) - center).Magnitude or -1
                if not hoverMatches then failureReason = "HoveredHayId did not stick"; break end
                if not onScreen or screenOffset > 15 then
                    failureReason = "Needle camera did not centre the target"
                    break
                end
                if physicalFallback then
                    trace.Event("FreshReleaseRequested",{Click=i})
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
                    RunService.RenderStepped:Wait()
                    if Unloaded or not State.AutoPickupNeedle or not Window.Closed then failureReason="Pickup cancelled before fresh click"; break end
                end
                trace.Snapshot("before-press-"..tostring(i))
                trace.Event("PressRequested",{Click=i,OwnedMouseDown=mouseDown,PhysicalFallback=physicalFallback})
                local pressed, pressErr = pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                end)
                if not pressed then failureReason = "VIM press failed: " .. tostring(pressErr); break end
                trace.Event("PressResult",{OK=pressed,Error=pressErr and tostring(pressErr) or nil})
                clicks += 1
                mouseDown = true
                task.wait(SETTINGS.MousePressSeconds)
                releaseMouse()
                trace.Snapshot("after-release-"..tostring(i))
                if waitForConfirmation(SETTINGS.OwnershipWaitSeconds) then success = true; break end
                if i == 4 and not physicalFallback then applyQueryFilter() end
            end
            captureOwnership()
            success = success or observedOwnership
        end, function(e) return tostring(e) end)
        if not ok then failureReason = "Runtime error: " .. tostring(err) end
        cleanup()
        return success
    end
    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        if previousCleanup then pcall(previousCleanup) end
        if activeCleanup then pcall(activeCleanup) end
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    end
    task.spawn(function()
        while not Unloaded do
            task.wait(0.05)
            if not IN_GAME or roundEndingVisible() or not State.AutoPickupNeedle or owned() then
                trackedNeedle = nil
            else
                if not trackedNeedle or not trackedNeedle.Parent
                    or trackedNeedle:GetAttribute("HIDDEN_WITHIN") ~= nil
                    or trackedNeedle:GetAttribute("IsNeedleObjective") ~= true
                    then
                    trackedNeedle = findExposedNeedlePart()
                end
                if confirmedNeedleId~=nil and trackedNeedle and trackedNeedle == confirmedNeedlePart
                    and resolveNeedleHayId(trackedNeedle) == confirmedNeedleId then
                    continue
                end
                if trackedNeedle and not busy and (os.clock() - lastAttempt) >= (resolveNeedleHayId(trackedNeedle) and SETTINGS.RetryDelay or 5) then
                    lastAttempt = os.clock()
                    local target = trackedNeedle
                    task.spawn(function() tryPickup(target) end)
                end
            end
        end
    end)
end

local lastNeedleHandIn = 0
local needleHandInConnection = RunService.Heartbeat:Connect(function()
    if Unloaded or not IN_GAME then return end
    if not State.AutoHandInNeedle then return end
    if LocalPlayer:GetAttribute("NeedleOwned") ~= true then return end
    if os.clock() - lastNeedleHandIn < 0.12 then return end
    lastNeedleHandIn = os.clock()
    if needlePickupActive or roundEndingVisible() then return end
    local farmer = Workspace:FindFirstChild("NPC") and Workspace.NPC:FindFirstChild("Farmer_NPC")
    local hrp = getHRP()
    if not farmer or not hrp then return end
    local target = farmer:GetPivot().Position
    if (hrp.Position - target).Magnitude > 15 then
        hrp.CFrame = farmer:GetPivot() * CFrame.new(0, 0, 4)
    end
    pcall(function() NeedleHandIn:FireServer() end)
end)
local previousHandInCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    needleHandInConnection:Disconnect()
    if previousHandInCleanup then pcall(previousHandInCleanup) end
end


task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.BuyInterval) or 1)
        if not IN_GAME then break end
        if State.AutoBuyTools and not vacuumUpgradePriority.Reserve() then
            local sel = State.BuyToolsList or {}
            local list = {}
            if type(sel) == "table" then
                for k, v in pairs(sel) do
                    if type(k) == "number" then
                        if type(v) == "string" then table.insert(list, v) end
                    elseif v then table.insert(list, k) end
                end
            end
            for _, name in ipairs(list) do
                if vacuumUpgradePriority.Reserve() then break end
                if name == "Pitchfork" and not owns("PitchforkOwned") then
                    pcall(function() BuyShopItem:FireServer("Pitchfork") end)
                elseif name == "TNT" and not owns("TntOwned") then
                    pcall(function() BuyShopItem:FireServer("Tnt") end)
                elseif name == "Drone" and not owns("DroneOwned") then
                    pcall(function() BuyShopItem:FireServer("Drone") end)
                elseif name == "Infinite Bag" and not owns("InfiniteBagOwned") then
                    pcall(function() BuyShopItem:FireServer("InfiniteBag") end)
                elseif name == "Capacity Bag" and GameConfig then
                    local st = tonumber(LocalPlayer:GetAttribute("HayUpgradeCapacity")) or 1
                    local track = GameConfig.UPGRADE_TRACKS["Capacity"]
                    if track and st < #track.Levels then
                        local cost = track.Levels[st + 1].Cost or 0
                        if getCash() >= cost then pcall(function() BuyUpgrade:FireServer("Capacity") end) end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.PermInterval) or 1)
        if not IN_GAME then break end
        if State.UpgBagSize then tryBuyPermanent("ExtraHoldAmount") end
        if State.UpgExtraTake then tryBuyPermanent("ExtraTakeAmount") end
        if State.UpgGemValue then tryBuyPermanent("GemValue") end
        if State.UpgHayValue then tryBuyPermanent("ExtraHayValuePercentage") end
    end
end)

do
    local upgrades=createAutoUpgradeRuntime({
        State=State,Player=LocalPlayer,Cash=getCash,
        Folder=function() NeedleHaystack=ReplicatedStorage:FindFirstChild("NeedleHaystack");return NeedleHaystack end,
        OnConfig=function(config) GameConfig=config end,
        Status=function(text) if afkOrbitTelemetry.UpgradeStatus then afkOrbitTelemetry.UpgradeStatus:SetDesc(text) end end,
    })
    task.spawn(function()
        while not Unloaded do
            if IN_GAME then upgrades.Tick() end
            task.wait(0.25)
        end
    end)
end
task.spawn(function()
    while not Unloaded do
        task.wait(300)
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping); hum.Jump = true end
        end)
    end
end)

pcall(function()
    task.defer(function()
        if not Unloaded then pcall(function() CollectingTab:Select() end) end

    end)
end)

print("[Needle] Loaded v103.00")

task.spawn(function()
    local teleport=game:GetService("TeleportService")
    local active=true
    local pending=false
    local pendingSince=0
    local retryAt=0
    local timerIncreasing=false
    local lastTimer
    local cachedTimer
    local searchAt=0
    local clock=_G.__BEYY_ROUND_TIMEOUT_CLOCK
    if type(clock)~="table" or clock.JobId~=game.JobId or clock.PlaceId~=game.PlaceId then
        clock={JobId=game.JobId,PlaceId=game.PlaceId};_G.__BEYY_ROUND_TIMEOUT_CLOCK=clock
    end
    local function status(text)
        if afkOrbitTelemetry.TimeoutStatus then afkOrbitTelemetry.TimeoutStatus:SetDesc(text) end
    end
    local function parseTimer(text)
        if type(text)~="string" then return nil end
        local h,m,s=text:match("^%s*(%d+):(%d%d):(%d%d)%s*$")
        if h and tonumber(m)<60 and tonumber(s)<60 then return tonumber(h)*3600+tonumber(m)*60+tonumber(s) end
        m,s=text:match("^%s*(%d+):(%d%d)%s*$")
        if not m then m,s=text:match("^[Tt]ime%s*:?%s*(%d+):(%d%d)%s*$") end
        if m and tonumber(s)<60 then return tonumber(m)*60+tonumber(s) end
        return nil
    end
    local function visibleTimer(obj)
        local current=obj
        local named=false
        while current and current~=LocalPlayer:FindFirstChildOfClass("PlayerGui") do
            local name=current.Name:lower()
            if name:find("beyynative",1,true) or name:find("ending",1,true) or name:find("results",1,true) or name:find("puzzle",1,true) then return false end
            if name:find("timer",1,true) or name=="time" then named=true end
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current=current.Parent
        end
        local camera=Workspace.CurrentCamera
        local bottomRight=camera and obj:IsA("GuiObject") and obj.AbsolutePosition.X>=camera.ViewportSize.X*0.65 and obj.AbsolutePosition.Y>=camera.ViewportSize.Y*0.65
        return named or bottomRight
    end
    local function readTimer()
        if cachedTimer and cachedTimer.Parent and visibleTimer(cachedTimer) then
            local value=parseTimer(cachedTimer.Text)
            if value then return value end
        end
        cachedTimer=nil
        if os.clock()<searchAt then return nil end
        searchAt=os.clock()+5
        local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        local found
        for _,obj in ipairs(pg:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and parseTimer(obj.Text) and visibleTimer(obj) then
                if found then return nil end -- Ambiguous timers use the elapsed-time fallback.
                found=obj
            end
        end
        cachedTimer=found
        return found and parseTimer(found.Text) or nil
    end
    local function ensureReload()
        if _G.__BEYY_TELEPORT_RELOAD_JOB==game.JobId then return true end
        local env=_G
        if type(getgenv)=="function" then local ok,value=pcall(getgenv);if ok and type(value)=="table" then env=value end end
        local queue=queue_on_teleport or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
        if type(queue)~="function" then return false,"teleport reload is unsupported" end
        local ok,err=pcall(queue,[==[loadstring(game:HttpGet("https://raw.githubusercontent.com/sceneton/script/main/loader.lua?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))()]==])
        if ok then _G.__BEYY_TELEPORT_RELOAD_JOB=game.JobId end
        return ok,tostring(err)
    end
    local failed=teleport.TeleportInitFailed:Connect(function(player,result,message,placeId)
        if active and pending and player==LocalPlayer and placeId==BEYY_PLACE_IDS.Lobby then
            pending=false;afkOrbitTelemetry.RecoveryPending=false;retryAt=os.clock()+15
            status("Teleport failed; retrying in 15s: "..tostring(message))
        end
    end)
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        active=false;failed:Disconnect();afkOrbitTelemetry.RecoveryPending=false
        if previous then pcall(previous) end
    end
    while active and not Unloaded do
        task.wait(1)
        if not active or Unloaded then break end
        if LocalPlayer:GetAttribute("IntroCutsceneFinished")==true and not clock.Started then clock.Started=os.clock() end
        local timer=readTimer()
        if timer and lastTimer then
            if timer>lastTimer then timerIncreasing=true
            elseif timer<lastTimer then
                if timerIncreasing and timer<lastTimer-10 then clock.Started=os.clock();retryAt=0 end
                timerIncreasing=false
            end
        end
        if timer then lastTimer=timer end
        if timer and timerIncreasing then clock.Started=os.clock()-timer else timer=nil end
        local elapsed=timer or (clock.Started and os.clock()-clock.Started)
        if pending then
            if os.clock()-pendingSince>=30 then
                pending=false;afkOrbitTelemetry.RecoveryPending=false;retryAt=os.clock()+15
                status("Teleport has not completed; retrying in 15s")
            end
        elseif not State.AutoRoundFailsafe then status("Disabled")
        elseif not elapsed then status("Waiting for round timer or intro completion")
        elseif os.clock()<retryAt then -- Keep the failure reason visible during retry cooldown.
        elseif elapsed<=300 then
            status(string.format("%s: %d:%02d / 5:00",timer and "Game timer" or "Elapsed since intro",math.floor(elapsed/60),math.floor(elapsed%60)))
        else
            local ready,reason=ensureReload()
            if not ready then status("Cannot restart automatically: "..tostring(reason));retryAt=os.clock()+15
            else
                safeWrite(CACHE_FOLDER.."/autofarmwins_shared.txt","true")
                pending=true;pendingSince=os.clock();afkOrbitTelemetry.RecoveryPending=true
                status("Round exceeded 5 minutes; returning to lobby")
                local ok,err=pcall(function()
                    teleport:Teleport(BEYY_PLACE_IDS.Lobby,LocalPlayer,{BeyyHubTimeoutRecovery=true,AutoFarmWins=true,Created=os.time()})
                end)
                if not ok then pending=false;afkOrbitTelemetry.RecoveryPending=false;retryAt=os.clock()+15;status("Teleport error; retrying in 15s: "..tostring(err)) end
            end
        end
    end
end)



