-- beyy v103.00 | Chapter2 module | PlaceId 83445806734780
local __BEYY_MODULE = "Chapter2"
local __BEYY_SCRIPT_VERSION = "103.00"
if game.PlaceId ~= 83445806734780 then
    warn("[BeyyHub] Refusing to load Chapter2 module in another place")
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

local function installUniversalWinsRecorder(tab, registry, isRunning)
    local env=type(getgenv)=='function' and getgenv()or _G
    if env.BeyyWinsRecorder then env.BeyyWinsRecorder.Stop()end
    local httpService=game:GetService('HttpService')
    local player=game:GetService('Players').LocalPlayer
    local storage='BeyyHub'
    local settingsPath=storage..'/wins_webhook.json'
    local statePath=storage..'/wins_recorder_'..tostring(player.UserId)..'.json'
    local alive=true
    local dataClient,dataModule,nextResolve=nil,nil,0
    local connections={}
    local function readJson(path)
        if type(readfile)~='function'then return nil end
        local ok,value=pcall(function()return httpService:JSONDecode(readfile(path))end)
        return ok and type(value)=='table'and value or nil
    end
    local function writeJson(path,value)
        if type(writefile)~='function'then return false end
        if type(makefolder)=='function'then pcall(makefolder,storage)end
        return pcall(function()writefile(path,httpService:JSONEncode(value))end)
    end
    local settings=readJson(settingsPath)or {Enabled=true,Url=''}
    settings.Enabled=settings.Enabled~=false
    local function validUrl(url)
        return type(url)=='string'and url:match('^https://discord%.com/api/webhooks/%d+/[%w_%-]+$')~=nil
    end
    if not validUrl(settings.Url)then settings.Url=''end
    local state=readJson(statePath)or {}
    state.Pending=type(state.Pending)=='table'and state.Pending or {}
    state.SessionWins=tonumber(state.SessionWins)or 0
    state.Started=tonumber(state.Started)or os.time()
    local function validSeconds(value)
        return type(value)=='number'and value>0 and value<math.huge
    end
    local roundTimes={}
    local function rememberRound(id,seconds)
        if not validSeconds(seconds)or type(id)~='string'or id==''then return end
        for _,round in ipairs(roundTimes)do if round.Id==id then return end end
        roundTimes[#roundTimes+1]={Id=id,Seconds=seconds}
        if #roundTimes>100 then table.remove(roundTimes,1)end
    end
    if type(state.RoundTimes)=='table'then
        for _,round in ipairs(state.RoundTimes)do
            if type(round)=='table'then rememberRound(round.Id,round.Seconds)end
        end
    elseif type(readfile)=='function'then
        -- Reuse previously recorded round times when upgrading an existing recorder.
        pcall(function()
            local history=readfile(storage..'/wins_history_'..tostring(player.UserId)..'.jsonl')
            for line in history:gmatch('[^\r\n]+')do
                local ok,entry=pcall(httpService.JSONDecode,httpService,line)
                if ok and type(entry)=='table'then rememberRound(entry.JobId,entry.RoundSeconds)end
            end
        end)
    end
    state.RoundTimes=roundTimes
    local function roundAverage()
        local total=0
        for _,round in ipairs(roundTimes)do total+=round.Seconds end
        return #roundTimes>0 and total/#roundTimes or nil,#roundTimes
    end
    local status=tab:Paragraph({Title='Wins Recorder Status',Desc='Waiting for saved wins'})
    local function setStatus(text)if alive then status:SetDesc(text)end end
    local function save()return writeJson(statePath,state)end
    registry.WinsRecorderEnabled=tab:Toggle({Title='Discord Win Reports',Value=settings.Enabled,
        Callback=function(value)
            settings.Enabled=value==true;writeJson(settingsPath,settings)
            setStatus(settings.Enabled and 'Enabled; waiting for wins / pending reports'or 'Discord reporting paused')
        end})
    tab:Input({Title='Wins Webhook URL',Value='',Placeholder='Paste webhook URL to replace the saved one',Callback=function(value)
        if type(value)~='string'or value==''then return end
        value=value:match('^%s*(.-)%s*$')
        if not validUrl(value)then setStatus('Invalid Discord webhook URL');return end
        settings.Url=value;writeJson(settingsPath,settings);setStatus('Webhook configured locally')
    end})
    local chapters={[77108422251420]='Lobby',[108628039999641]='Chapter 1',[83445806734780]='Chapter 2',
        [82626725163709]='Chapter 3',[102537610748607]='Chapter 4'}
    local chapter=chapters[game.PlaceId]or __BEYY_MODULE or ('Place '..tostring(game.PlaceId))
    local completion
    local completionConnection,completionRemote
    local function sample()
        if not alive or not isRunning()then return end
        local rs=game:GetService('ReplicatedStorage')
        local folder=rs:FindFirstChild('NeedleHaystack')
        local remote=folder and folder:FindFirstChild('NeedleRoundCompleted')
        if remote~=completionRemote then
            if completionConnection then completionConnection:Disconnect();completionConnection=nil end
            completionRemote=remote
            if remote and remote:IsA('RemoteEvent')then
                completionConnection=remote.OnClientEvent:Connect(function(_,_,_,seconds)
                    completion={At=os.clock(),Seconds=tonumber(seconds)}
                    rememberRound(game.JobId,completion.Seconds)
                    save()
                    task.defer(sample)
                end)
            end
        end
        if not dataClient and os.clock()>=nextResolve then
            nextResolve=os.clock()+5
            local shared=rs:FindFirstChild('Shared');local services=shared and shared:FindFirstChild('Services')
            dataModule=services and services:FindFirstChild('Data')
            if dataModule then local ok,value=pcall(require,dataModule);if ok and type(value)=='table'then dataClient=value.client end end
        end
        if not dataClient or dataClient.Wins==nil then setStatus('Waiting for saved-win data');return end
        local ok,total=pcall(function()return dataClient.Wins()end)
        if not ok or type(total)~='number'or total<0 or total~=total or total==math.huge or total%1~=0 then return end
        if type(state.LastWins)~='number'then
            state.LastWins=total;save()
            setStatus('Tracking '..tostring(total)..' saved wins'..(settings.Url==''and '; configure webhook'or ''))
            return
        end
        if total==state.LastWins then return end
        if total<state.LastWins then state.LastWins=total;save();setStatus('Saved wins decreased; baseline updated');return end
        local before=state.LastWins
        local gain=total-before
        state.LastWins=total;state.SessionWins+=gain
        local seconds=folder and tonumber(folder:GetAttribute('RoundFinishedElapsed'))
        if not seconds and completion and os.clock()-completion.At<10 then seconds=completion.Seconds end
        -- A multi-win increase is still only one observed round, never N copies.
        rememberRound(game.JobId,seconds)
        local average,count=roundAverage()
        local entry={Id=tostring(player.UserId)..':'..tostring(total),Username=player.Name,UserId=player.UserId,
            Chapter=chapter,PlaceId=game.PlaceId,JobId=game.JobId,Before=before,Total=total,Gain=gain,
            SessionWins=state.SessionWins,SessionStarted=state.Started,Observed=os.time(),RoundSeconds=seconds,
            RoundAverageSeconds=average,RoundSampleCount=count}
        state.Pending[#state.Pending+1]=entry
        save()
        if type(appendfile)=='function'then pcall(function()appendfile(storage..'/wins_history_'..tostring(player.UserId)..'.jsonl',httpService:JSONEncode(entry)..'\n')end)end
        setStatus('Recorded +'..tostring(gain)..' win(s); total '..tostring(total))
    end
    local function formatRoundTime(seconds)
        local whole=math.floor(seconds+0.5)
        return string.format('%d:%02d',whole//60,whole%60)
    end
    local function payload(entry)
        -- Completion can arrive just after the saved-win update. Fill in its
        -- timing before delivery, and keep averages fixed for later retries.
        if entry.JobId==game.JobId and completion and os.clock()-completion.At<10 then
            if validSeconds(completion.Seconds)then entry.RoundSeconds=completion.Seconds end
            entry.RoundAverageSeconds,entry.RoundSampleCount=roundAverage()
        end
        local elapsed=math.max(1,entry.Observed-entry.SessionStarted)
        local fields={
            {name='Account',value=entry.Username..' ('..tostring(entry.UserId)..')',inline=true},
            {name='Chapter',value=entry.Chapter,inline=true},
            {name='Wins gained',value='+'..tostring(entry.Gain),inline=true},
            {name='Saved wins',value=tostring(entry.Before)..' → '..tostring(entry.Total),inline=true},
            {name='Tracked wins',value=tostring(entry.SessionWins),inline=true},
            {name='Wins / hour',value=string.format('%.1f',entry.SessionWins*3600/elapsed),inline=true},
        }
        if entry.RoundSeconds and entry.RoundSeconds>=0 then fields[#fields+1]={name='Round time',value=formatRoundTime(entry.RoundSeconds),inline=true}end
        fields[#fields+1]={name='Average round time (last 100)',inline=true,
            value=validSeconds(entry.RoundAverageSeconds)and string.format('%s (%d/100 rounds)',formatRoundTime(entry.RoundAverageSeconds),entry.RoundSampleCount or 0)
                or 'No timed rounds recorded yet (0/100)'}
        return {username='BeyyHub Wins',allowed_mentions={parse={}},embeds={{title='Win recorded',color=5763719,
            fields=fields,footer={text='Record '..entry.Id..' | Place '..tostring(entry.PlaceId)},
            timestamp=os.date('!%Y-%m-%dT%H:%M:%SZ',entry.Observed)}}}
    end
    local sending=false
    local retryAt=0
    local function deliver()
        if not alive or sending or not settings.Enabled or not validUrl(settings.Url)or #state.Pending==0 or os.clock()<retryAt then return end
        local send=type(request)=='function'and request or type(http_request)=='function'and http_request
            or type(syn)=='table'and syn.request or type(http)=='table'and http.request
        if type(send)~='function'then setStatus('HTTP request API unavailable; reports saved locally');return end
        sending=true
        local entry=state.Pending[1]
        local url=settings.Url
        task.spawn(function()
            local ok,response=pcall(function()return send({Url=url..'?wait=true',Method='POST',Headers={['Content-Type']='application/json'},Body=httpService:JSONEncode(payload(entry))})end)
            local code=ok and type(response)=='table'and tonumber(response.StatusCode or response.Status)or nil
            if code and code>=200 and code<300 then
                if state.Pending[1]==entry then table.remove(state.Pending,1)end
                state.LastSent=entry.Id;save();setStatus('Sent +'..tostring(entry.Gain)..' win(s); total '..tostring(entry.Total))
                retryAt=os.clock()+1
            else
                local delay=30
                if code==429 then
                    local decodedOk,body=pcall(function()return httpService:JSONDecode(response.Body or '{}')end)
                    delay=decodedOk and type(body)=='table'and tonumber(body.retry_after)or 5
                    delay=math.max(1,math.min(delay or 5,3600))
                elseif code==401 or code==403 or code==404 then delay=300 end
                retryAt=os.clock()+delay
                -- Never print response bodies/errors: they can contain the secret URL.
                setStatus('Webhook '..(code and ('HTTP '..tostring(code))or 'request failed')..'; queued for retry')
            end
            sending=false
        end)
    end
    local function stop()
        if not alive then return end
        pcall(sample);alive=false
        if completionConnection then completionConnection:Disconnect()end
        for _,connection in ipairs(connections)do connection:Disconnect()end
        save()
    end
    env.BeyyWinsRecorder={Stop=stop,Sample=sample,State=state,Configured=settings.Url~=''}
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()stop();if previous then previous()end end
    connections[#connections+1]=player.OnTeleport:Connect(function(teleportState)
        if teleportState==Enum.TeleportState.Started then stop()end
    end)
    task.spawn(function()
        while alive and isRunning()do
            local ok=pcall(sample)
            if not ok then setStatus('Saved-win read failed; retrying')end
            deliver();task.wait(.5)
        end
        stop()
    end)
    return env.BeyyWinsRecorder
end

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

local selectPitchforkHay, stopPitchforkSelector = createPitchforkSelector(true, false)
-- Start intro input before constructing the menu or waiting for gameplay assets.
local earlyIntroRunning = true
local earlyIntroPending = false
local earlyIntroGui, earlyIntroConnection
local earlyIntroButtons = setmetatable({}, {__mode="k"})
local function stopEarlyIntro()
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
        local selected, available, vacuum, power=0,{},nil,nil
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
                    if entry[2]=="VacuumPower" then power=target end
                    if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                end
            end
        end
        if selected==0 then status("No cash upgrades enabled"); return end
        if #available==0 then status("Selected cash upgrades are maxed or unavailable"); return end
        local target
        if power then
            if cash<power.Cost then status(string.format("Saving for VacuumPower: $%.2f / $%.2f",cash,power.Cost)); return end
            target=power
        elseif vacuum and cash>=vacuum.Cost*0.75 then
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
        for _,entry in ipairs({{Flag="UpgVacPower",Name="VacuumPower"},{Flag="UpgVacCooling",Name="VacuumCooling"}}) do
            if state[entry.Flag] then
                local track=tracks[entry.Name]
                local level=getLevel(entry.Name)
                local nextLevel=track and track.Levels and track.Levels[level+1]
                local cost=nextLevel and tonumber(nextLevel.Cost or 0)
                if cost then cost=math.round(cost*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)*100)/100 end
                if cost and cost>=0 and cost<math.huge then
                    return {Name=entry.Name,Level=level,Cost=cost}
                end
            end
        end
        return nil
    end
    local function awaiting()
        if pending and (getLevel(pending.Name)~=pending.Level or os.clock()>=pending.Until) then pending=nil end
        return pending~=nil
    end
    local priority={}
    function priority.Reserve()
        if awaiting() then return true end
        local target=nextVacuum()
        return target~=nil and (target.Name=="VacuumPower" or (tonumber(getCash()) or 0)>=target.Cost*0.75)
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

local function chapter2AutoPuzzleReady(player,workspace,skipPending)
    if player:GetAttribute("IntroCutsceneFinished")~=true then return false,"Waiting for intro skip confirmation" end
    if skipPending or player:GetAttribute("CutsceneActive")==true then return false,"Waiting for intro cutscene to close" end
    if player:GetAttribute("NeedleInputLocked")==true then return false,"Waiting for intro input lock to clear" end
    local character=player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false,"Waiting for character" end
    if not workspace.CurrentCamera then return false,"Waiting for camera" end
    local puzzles=workspace:FindFirstChild("Puzzles")
    local puzzle=puzzles and puzzles:FindFirstChild("LeverPuzzle")
    local levers=puzzle and puzzle:FindFirstChild("Levers")
    if not levers then return false,"Waiting for lever puzzle" end
    for i=1,3 do if not levers:FindFirstChild("Lever"..i) then return false,"Waiting for Lever "..i end end
    return true
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
    local hubNativeUI
    local hubRestoreAction = nil
    local hubCursorCleanup = nil
    _G.__BEYY_HUB_CLEANUP = function()
        hubUnloaded = true
        if hubRestoreAction then pcall(hubRestoreAction) end
        if hubCursorCleanup then pcall(hubCursorCleanup) end
        if hubWindow then pcall(function() hubWindow:Destroy() end) end
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
    hubNativeUI = createNativeUI()
    hubWindow = hubNativeUI:CreateWindow({
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
        hubCursorCleanup = function() hubWindow:Close() end
    end

    local chapter2ConfigReady=false
    local Registry = {}
    local overviewTab = hubWindow:Tab({ Title = "Overview & Settings", Icon = "house" })
    installAntiIdle(overviewTab, Registry, function() return not hubUnloaded end)
    installUniversalWinsRecorder(overviewTab, Registry, function() return not hubUnloaded end)
    overviewTab:Section({ Title = "Detected chapter" })
    overviewTab:Paragraph({
        Title = BEYY_CHAPTER .. " (Place ID " .. tostring(game.PlaceId) .. ")",
        Desc = "Farming and Inventory are available in every chapter. Right Ctrl opens or closes the menu.",
    })
    overviewTab:Section({ Title = "Shared menu" })
    Registry.MenuKeybind = overviewTab:Keybind({
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
    local pickupStatus = needleTab:Paragraph({ Title="Key / Needle Pickup Status", Desc="Waiting for the next pickup scan." })
    local lastPickupStatus
    local function setPickupStatus(message)
        if message == lastPickupStatus then return end
        lastPickupStatus = message
        pcall(function() pickupStatus:SetDesc(message) end)
    end
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

    local upgradeStatus=upgradesTab:Paragraph({Title="Auto Upgrade Status",Desc="Waiting for upgrade check"})
    local function spawnChapterWorker(fn)
        if BEYY_CHAPTER ~= "Lobby" then task.spawn(fn) end
    end
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
    local farmRemoteCache = {}
    local function farmRemote(name)
        local folder=ReplicatedStorage:FindFirstChild("NeedleHaystack")
        local cached=farmRemoteCache[name]
        if folder and cached and cached.Parent==folder and cached.Name==name then return cached end
        local result=folder and folder:FindFirstChild(name)
        farmRemoteCache[name]=result and result:IsA("RemoteEvent") and result or nil
        return result and result:IsA("RemoteEvent") and result or nil
    end
    local function sendFarmRemote(name,...)
        local remote=farmRemote(name)
        if not remote then return false end
        return pcall(remote.FireServer,remote,...)
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
local indexedPreferred, stopPreferredIndex = createObjectiveIndex()
local previousPreferredCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    stopPreferredIndex()
    if previousPreferredCleanup then pcall(previousPreferredCleanup) end
end
    local function exposedNeedle()
        local server=Workspace:FindFirstChild("NeedleObjectiveServer")
        if not server then indexedObjectives(nil); indexedPreferred(nil); return nil,"Target search: Workspace.NeedleObjectiveServer is missing (not replicated or a different objective layout)" end
        local keyPart=server:FindFirstChild("Key")
        local preferred=keyPart or server:FindFirstChild("Needle")
        if not preferred then indexedPreferred(nil) end
        local seen={}
        local parts,marked,hidden,invalid=0,0,0,0
        local samples={}
        local function inspect(item)
            if seen[item] then return nil end
            seen[item]=true
            if not item:IsA("BasePart") then return nil end
            parts+=1
            local marker=item:GetAttribute("IsNeedleObjective")
            local hiding=item:GetAttribute("HIDDEN_WITHIN")
            local id=item:GetAttribute("HayId")
            if #samples<3 then
                table.insert(samples,item.Name..": marker="..tostring(marker)..", hidden="..tostring(hiding)..", HayId="..tostring(id).." ("..type(id)..")")
            end
            -- The confirmed Chapter 2 Key part need not carry Chapter 1's marker.
            if marker==true or item==keyPart then
                marked+=1
                if hiding~=nil then hidden+=1
                elseif type(id)~="number" then invalid+=1
                else return item end
            end
        end
        -- Prefer the confirmed direct Key part and inspect the root itself.
        if preferred then
            local found=inspect(preferred)
            if found then return found end
            for _,item in ipairs(indexedPreferred(preferred)) do
                found=inspect(item)
                if found then return found end
            end
        end
        -- Keep the same attribute requirements, but allow marked objectives elsewhere in this container.
        for _,item in ipairs(indexedObjectives(server)) do
            local found=inspect(item)
            if found then return found end
        end
        return nil,string.format("Target search: %d parts, %d objective markers, %d hidden, %d missing/nonnumeric IDs. %s",
            parts,marked,hidden,invalid,table.concat(samples," | "))
    end
    local needleBusy=false
    local function needlePriority()
        if needleBusy then return true end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then
            return sharedFarmState.AutoHandInNeedle or sharedFarmState.AutoPickupNeedle
        end
        return sharedFarmState.AutoPickupNeedle and exposedNeedle()~=nil
    end
    local collectSelectors={}
    local previousCollectCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        for _,entry in pairs(collectSelectors) do entry.Stop() end
        if previousCollectCleanup then previousCollectCleanup() end
    end
    local function closestInFolder(folderName,idName,limit)
        local key=folderName..":"..idName
        local entry=collectSelectors[key]
        if not entry then
            local selectTarget,stop=createPitchforkSelector(true,false,{FolderName=folderName,IdName=idName,Range=limit,ObjectId=idName=="Dropped"})
            entry={Select=selectTarget,Stop=stop};collectSelectors[key]=entry
        end
        return entry.Select(function() return not hubUnloaded and not farmBlocked() and not needlePriority() end)
    end
    local function bagFull()
        return (tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0)
            >= (tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25)
    end
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(math.max(0.1,tonumber(sharedFarmState.CollectInterval) or 0.5))
            if (sharedFarmState.AutoPickHay or sharedFarmState.AutoFindNeedle or sharedFarmState.AutoCollectDroppedHay or sharedFarmState.AutoCollectGems)
                and needleFolder and not farmBlocked() and not needlePriority() then
                if (sharedFarmState.AutoPickHay or (sharedFarmState.AutoFindNeedle and not exposedNeedle())) and not bagFull() then
                    local hay,id=closestInFolder("HaystackClient","HayId",30)
                    if id and (sharedFarmState.AutoPickHay or sharedFarmState.AutoFindNeedle) and not farmBlocked() and not needlePriority() then
                        local nearby={}
                        local radius=tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                        if radius>0 and hay then
                            local folder=Workspace:FindFirstChild("HaystackClient")
                            if folder then
                                for _,other in budgetedFolderChildren(folder,function() return not hubUnloaded and (sharedFarmState.AutoPickHay or sharedFarmState.AutoFindNeedle) end) do
                                    if other~=hay and other:IsA("BasePart")
                                        and other:GetAttribute("HayId")
                                        and (other.Position-hay.Position).Magnitude<=radius+1 then
                                        nearby[#nearby+1]=other:GetAttribute("HayId")
                                        if #nearby>=6 then break end
                                    end
                                end
                            end
                        end
                        if hay and hay.Parent and (sharedFarmState.AutoPickHay or sharedFarmState.AutoFindNeedle) and not farmBlocked() and not needlePriority() then sendFarmRemote("PickHay",id,nearby) end
                    end
                end
                if sharedFarmState.AutoCollectDroppedHay and not bagFull() then
                    local _,d=closestInFolder("DroppedHay","Dropped",28)
                    if d and sharedFarmState.AutoCollectDroppedHay and not farmBlocked() and not needlePriority() then sendFarmRemote("PickDroppedHay",d) end
                end
                if sharedFarmState.AutoCollectGems then
                    local _,id=closestInFolder("GemsClient","GemId",35)
                    if id and sharedFarmState.AutoCollectGems and not farmBlocked() and not needlePriority() then sendFarmRemote("CollectGem",id) end
                end
            end
        end
    end)
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(1)
            if sharedFarmState.AutoSellHay and needleFolder and not farmBlocked() and not needlePriority() then
                local held=tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0
                local threshold=tonumber(sharedFarmState.SellThreshold) or 25
                if held>0 and ((sharedFarmState.SellOnlyIfFull and bagFull())
                    or (not sharedFarmState.SellOnlyIfFull and held>=threshold)) then
                    sendFarmRemote("SellHay")
                end
            end
        end
    end)
    do
    local tntRetry=createTntRetryGate(function() return farmRemote("TntAction") end,function() return LocalPlayer:GetAttribute("TntCooldown") end)
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            if (sharedFarmState.AutoUsePitchfork or sharedFarmState.AutoDeployDrone or sharedFarmState.AutoUseTNT)
                and needleFolder and not farmBlocked() and not needlePriority() then
                if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                    local _,id=selectPitchforkHay(function() return not hubUnloaded and sharedFarmState.AutoUsePitchfork and not farmBlocked() and not needlePriority() end)
                    if id then sendFarmRemote("PitchforkDig",id) end
                end
                if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                    and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                    sendFarmRemote("DeployDrone")
                end
                if sharedFarmState.AutoUseTNT and LocalPlayer:GetAttribute("TntOwned")==true and tntRetry.Light() then
                    if sharedFarmState.AutoUseTNT and not farmBlocked() and not needlePriority() then
                        local camera=Workspace.CurrentCamera
                        if camera then
                            tntRetry.Throw(camera.CFrame,
                                camera.CFrame.LookVector*40+Vector3.new(0,8,0))
                        end
                    end
                end
            end
        end
    end)
    end
    local vacuumWatchdog=createVacuumHeatWatchdog()
    local lastVacuumRecoveryWarning=-math.huge
    local forceVacuumReselect=false
    local vacuumHeld=false
    local vacuumPoint=Vector2.zero
    local vacuumStart=0
    local vacuumCooldown=0
    local vacuumCooling=false
    local function releaseSharedVacuum()
        vacuumWatchdog.Stop()
        if vacuumHeld then
            vacuumHeld=false
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
            end)
        end
    end
    local vacuumFocus=watchVacuumFocus(function()
        local interrupted=vacuumHeld
        releaseSharedVacuum()
        if interrupted then
            local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local hud=pg and pg:FindFirstChild("HUD")
            local heat=hud and hud:FindFirstChild("Overheat")
            local fill=heat and heat:FindFirstChild("Fill")
            if fill and fill:IsA("GuiObject") then
                vacuumCooling=fill.Size.Y.Scale>0.001
            else
                vacuumCooling=false
                vacuumCooldown=math.max(vacuumCooldown,os.clock()+13.5)
            end
        end
    end)
    local oldCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        vacuumFocus.Stop()
        releaseSharedVacuum()
        if oldCleanup then pcall(oldCleanup) end
    end
    spawnChapterWorker(function()
        local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
            Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
            Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
        while not hubUnloaded do
            task.wait(0.08)
            local active=vacuumFocus.Ready() and needleFolder and BEYY_CHAPTER~="Lobby" and sharedFarmState.AutoUseVacuum
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
                    local replicated=LocalPlayer:GetAttribute("VacuumHeat")
                    if type(replicated)=="number" and replicated==replicated and replicated>=0 and replicated<=1 then level=replicated end
                    local recovery=vacuumHeld and vacuumWatchdog.Check(level)
                    if level and level>=0.999 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    elseif vacuumCooling and (not level or level>0.001) and not (LocalPlayer:GetAttribute("VacuumState")=="Ready" and LocalPlayer:GetAttribute("VacuumOverheated")~=true) then
                        releaseSharedVacuum()
                    elseif recovery then
                        if recovery=="stalled" then forceVacuumReselect=true end
                        releaseSharedVacuum()
                        vacuumCooling=recovery=="cooling" and level~=nil and level>0.001
                        vacuumCooldown=math.max(vacuumCooldown,os.clock()+0.25)
                        if recovery=="stalled" and os.clock()-lastVacuumRecoveryWarning>=10 then
                            lastVacuumRecoveryWarning=os.clock()
                            warn("[Vacuum] Heat stalled; stale VIM hold released; fresh press pending")
                        end
                    elseif not vacuumHeld then
                        vacuumCooling=false
                        local focusGeneration=vacuumFocus.Generation()
                        if forceVacuumReselect then
                            pcall(function() VirtualInputManager:SendMouseButtonEvent(point.X,point.Y,0,false,game,0) end)
                            pcall(function() VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.One,false,game) end)
                            task.wait(0.05)
                            pcall(function() VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.One,false,game) end)
                            task.wait(0.15)
                            if hubUnloaded or not sharedFarmState.AutoUseVacuum or farmBlocked() or not hubWindow.Closed or needlePriority() then continue end
                            forceVacuumReselect=false
                        end
                        local equipped=false
                        local character=LocalPlayer.Character
                        if character then
                            for _,tool in ipairs(character:GetChildren()) do
                                if tool:IsA("Tool") and tool.Name:lower():find("vacuum",1,true) then equipped=true;break end
                            end
                        end
                        local slot=math.clamp(math.floor(tonumber(sharedFarmState.VacuumHotbarSlot) or 5),1,9)
                        local key=hotbar[slot]
                        if not equipped then
                        pcall(function() VirtualInputManager:SendKeyEvent(true,key,false,game) end)
                        task.wait(0.05)
                        pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
                        task.wait(0.15)
                        end
                        if vacuumFocus.Ready() and focusGeneration==vacuumFocus.Generation() and not farmBlocked() and hubWindow.Closed and not needlePriority() then
                            vacuumPoint=point
                            pcall(function() VirtualInputManager:SendMouseButtonEvent(point.X,point.Y,0,false,game,0) end)
                            task.wait(0.05)
                            if vacuumFocus.Ready() and focusGeneration==vacuumFocus.Generation() and sharedFarmState.AutoUseVacuum
                                and not farmBlocked() and hubWindow.Closed and not needlePriority() then
                            local pressed=pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
                            end)
                            if pressed then
                                vacuumHeld=true; vacuumStart=os.clock()
                                vacuumWatchdog.Start(level)
                                if focusGeneration~=vacuumFocus.Generation() then releaseSharedVacuum() end
                            end
                            end
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
    spawnChapterWorker(function()
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
    local function pickupBlockReason()
        if hubUnloaded then return "Hub unloaded" end
        if not sharedFarmState.AutoPickupNeedle then return "Auto pickup is off" end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then return "Key / needle collected" end
        if not needleFolder then return "Waiting for NeedleHaystack to replicate" end
        if sharedFarmPuzzleBusy() then return "Waiting for puzzle automation to release control" end
        if LocalPlayer:GetAttribute("CutsceneActive")==true then return "Waiting for CutsceneActive to clear (visual bypass does not clear this flag)" end
        if LocalPlayer:GetAttribute("NeedleInputLocked")==true then return "Waiting for NeedleInputLocked to clear" end
        if LocalPlayer:GetAttribute("HintViewerOpen")==true then return "Close the hint viewer to pick up the key" end
        if needleBusy then return "Pickup in progress" end
        return nil
    end
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.NeedleInterval) or 1))
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local blocked = pickupBlockReason()
            if blocked then
                setPickupStatus(blocked)
            else
                local needle,targetReason=exposedNeedle()
                local root=farmRoot()
                local camera=Workspace.CurrentCamera
                if not needle then
                    setPickupStatus(targetReason or "No eligible objective found")
                elseif not root or not camera then
                    setPickupStatus("Waiting for the character and camera")
                else
                    needleBusy=true
                    releaseSharedVacuum()
                    local previousRoot=root.CFrame
                    local previousCameraType=camera.CameraType
                    local previousCameraCF=camera.CFrame
                    local previousHover=LocalPlayer:GetAttribute("HoveredHayId")
                    local renderName="BeyySharedNeedleAim_"..tostring(LocalPlayer.UserId)
                    local bound=false
                    local mouseDown=false
                    local moved=false
                    local cameraCaptured=false
                    local collected=false
                    local ownershipConnection
                    local filteredParts={}
                    local function captureOwnership()
                        collected=collected or LocalPlayer:GetAttribute("NeedleOwned")==true
                        return collected
                    end
                    local function filterNearbyHay()
                        -- Match Chapter 1's local click-obstruction workaround, with full restoration.
                        local count=0
                        for _,folderName in ipairs({"HaystackClient","HaystackCollision"}) do
                            local folder=Workspace:FindFirstChild(folderName)
                            if folder then
                                for _,part in budgetedFolderChildren(folder,function() return not hubUnloaded and sharedFarmState.AutoPickupNeedle and needle.Parent~=nil end,true) do
                                    if count>=400 then break end
                                    if part:IsA("BasePart") and part~=needle
                                        and part:GetAttribute("IsNeedleObjective")~=true
                                        and not filteredParts[part] and part.CanQuery
                                        and (part.Position-needle.Position).Magnitude<=8+math.min(part.Size.Magnitude*0.5,4) then
                                        local saved={query=part.CanQuery,collide=part.CanCollide}
                                        filteredParts[part]=saved
                                        pcall(function() part.CanCollide=false; part.CanQuery=false end)
                                        count+=1
                                    end
                                end
                            end
                        end
                    end
                    local cleaned=false
                    local function clear()
                        if cleaned then return end
                        cleaned=true
                        captureOwnership()
                        if mouseDown then
                            mouseDown=false
                            local center=camera.ViewportSize/2
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            end)
                        end
                        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
                        if cameraCaptured and camera then
                            pcall(function()
                                camera.CameraType=previousCameraType
                                camera.CFrame=previousCameraCF
                            end)
                        end
                        if ownershipConnection then ownershipConnection:Disconnect() end
                        for part,saved in pairs(filteredParts) do
                            pcall(function()
                                if part.Parent then part.CanCollide=saved.collide; part.CanQuery=saved.query end
                            end)
                        end
                        -- Keep a confirmed pickup beside the objective for the hand-in routine.
                        if moved and not collected and root and root.Parent then pcall(function() root.CFrame=previousRoot end) end
                        pcall(function() LocalPlayer:SetAttribute("HoveredHayId",previousHover) end)
                        needleBusy=false
                    end
                    local ok,err=xpcall(function()
                        ownershipConnection=LocalPlayer:GetAttributeChangedSignal("NeedleOwned"):Connect(captureOwnership)
                        -- Puzzle automation may reopen the hub. Hide it before sending gameplay clicks.
                        if hubWindow.Closed~=true then
                            setPickupStatus("Closing the menu for key pickup")
                            hubWindow:Close()
                        end
                        local menuDeadline=os.clock()+1
                        repeat
                            RunService.RenderStepped:Wait()
                        until hubWindow.Closed==true or hubUnloaded or os.clock()>=menuDeadline
                        if hubWindow.Closed~=true then error("Menu did not close; pickup will retry") end
                        -- Give the cutscene controller time to release its camera before capturing it.
                        task.wait(0.15)
                        if hubUnloaded or farmBlocked() or not sharedFarmState.AutoPickupNeedle
                            or not needle.Parent or not root.Parent then return end
                        if Workspace.CurrentCamera~=camera then error("Camera changed; pickup will retry") end
                        previousCameraType=camera.CameraType
                        previousCameraCF=camera.CFrame
                        cameraCaptured=true
                        setPickupStatus("Teleporting beside the key / needle")
                        local id=needle:GetAttribute("HayId")
                        local character=LocalPlayer.Character
                        if not character or not character.Parent then return end
                        local rootToPivot=root.CFrame:ToObjectSpace(character:GetPivot())
                        local look=camera.CFrame.LookVector
                        local forward=Vector3.new(look.X,0,look.Z)
                        if forward.Magnitude<0.05 then forward=Vector3.new(0,0,-1) end
                        forward=forward.Unit
                        local spot=needle.Position-forward*2+Vector3.new(0,2.5,0)
                        local function placeNearObjective()
                            local facing=Vector3.new(needle.Position.X,spot.Y,needle.Position.Z)
                            character:PivotTo(CFrame.lookAt(spot,facing)*rootToPivot)
                            moved=true
                            root.AssemblyLinearVelocity=Vector3.zero
                            root.AssemblyAngularVelocity=Vector3.zero
                        end
                        local cameraSpot=spot-forward*3.5+Vector3.new(0,3.5,0)
                        local function aim()
                            if hubUnloaded or collected or not needle.Parent or Workspace.CurrentCamera~=camera then return end
                            camera.CameraType=Enum.CameraType.Scriptable
                            camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                            LocalPlayer:SetAttribute("HoveredHayId",id)
                        end
                        placeNearObjective()
                        aim()
                        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+30,function()
                            aim()
                        end)
                        bound=true
                        RunService.RenderStepped:Wait()
                        filterNearbyHay()
                        RunService.RenderStepped:Wait()
                        setPickupStatus("Clicking the objective; waiting for ownership confirmation")
                        for attempt=1,12 do
                            if captureOwnership() then break end
                            if hubUnloaded or farmBlocked() or not sharedFarmState.AutoPickupNeedle
                                or not needle.Parent or not root.Parent or not character.Parent then break end
                            if Workspace.CurrentCamera~=camera then error("Camera replaced during pickup; retrying") end
                            if (root.Position-spot).Magnitude>0.75 then placeNearObjective() end
                            aim()
                            local center=camera.ViewportSize/2
                            VirtualInputManager:SendMouseMoveEvent(center.X,center.Y,game)
                            RunService.RenderStepped:Wait()
                            aim()
                            local projected,onScreen=camera:WorldToViewportPoint(needle.Position)
                            if not onScreen or (Vector2.new(projected.X,projected.Y)-center).Magnitude>15 then
                                error("Objective is not centred under the mouse; retrying")
                            end
                            if LocalPlayer:GetAttribute("HoveredHayId")~=id then error("Objective hover was lost; retrying") end
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,true,game,0)
                            mouseDown=true
                            task.wait(0.1)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            mouseDown=false
                            local deadline=os.clock()+0.4
                            repeat
                                if captureOwnership() then break end
                                task.wait(0.025)
                            until hubUnloaded or not sharedFarmState.AutoPickupNeedle or os.clock()>=deadline
                            if attempt==4 or attempt==8 then filterNearbyHay() end
                        end
                    end,function(e) return tostring(e) end)
                    clear()
                    if not ok then
                        setPickupStatus("Pickup error: "..tostring(err))
                        warn("[BeyyHub] Chapter 2 key pickup: "..tostring(err))
                    elseif collected then
                        setPickupStatus("Key / needle collected")
                    else
                        setPickupStatus("Pickup not confirmed; retrying on the next scan")
                    end
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
    local vacuumUpgradePriority=createVacuumUpgradePriority(sharedFarmState,function() return sharedGameConfig end,cash,
        function(name) return tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1 end,
        function(name) return sendFarmRemote("BuyUpgrade",name) end)
    local function tryTrack(name)
        if not sharedGameConfig then return end
        if name=="VacuumPower" or name=="VacuumCooling" then vacuumUpgradePriority.Purchase(); return end
        if vacuumUpgradePriority.Reserve() then return end
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
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.BuyInterval) or 1))
            if needleFolder and sharedFarmState.AutoBuyTools and BEYY_CHAPTER~="Lobby" and not vacuumUpgradePriority.Reserve() then
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
                    if vacuumUpgradePriority.Reserve() then break end
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
    spawnChapterWorker(function()
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
    do
        local upgrades=createAutoUpgradeRuntime({
            State=sharedFarmState,Player=LocalPlayer,Cash=cash,
            Folder=function() needleFolder=ReplicatedStorage:FindFirstChild("NeedleHaystack");return needleFolder end,
            OnConfig=function(config) sharedGameConfig=config end,
            Status=function(text) upgradeStatus:SetDesc(text) end,
        })
        spawnChapterWorker(function()
            while not hubUnloaded do
                upgrades.Tick()
                task.wait(0.25)
            end
        end)
    end


        local puzzleTab = hubWindow:Tab({ Title = "Puzzles", Icon = "puzzle" })
        local function countVisibleColourGems(folder)
            local count, total = 0, 0
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") and child.Name == "Shard" then
                    total += 1
                    for _, obj in ipairs(child:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Transparency < 0.98
                            and obj.LocalTransparencyModifier < 0.98 then
                            count += 1
                            break
                        end
                    end
                end
            end
            return count, total
        end
        local function readVisibleColourCounts(puzzle)
            local counts, summaries = {}, {}
            local firstProblem
            for index, name in ipairs({ "Red", "Purple", "Green" }) do
                local folder = puzzle:FindFirstChild(name .. "Gems")
                if not folder then return nil, nil, name .. "Gems folder missing" end
                local visible, slots = countVisibleColourGems(folder)
                counts[index] = visible
                summaries[index] = string.format("%s: %d visible / %d slots", name, visible, slots)
                if visible == 0 and not firstProblem then
                    firstProblem = name .. " has 0 visible Shards"
                end
            end
            if firstProblem then return nil, summaries, firstProblem end
            return counts, summaries
        end
        local puzzleControllerBusy = false
        local colourRunning = false
        local colourCancel = false
        local COLOUR_RENDER_BIND = "BeyyV103_00ColourAim_" .. tostring(LocalPlayer.UserId)

        local COLOUR_CAMERA_SETTLE = 0.12
        local COLOUR_MOUSE_SETTLE = 0.0125
        local COLOUR_CLICK_HOLD = 0.05
        local COLOUR_CLICK_GAP = 0.07
        local COLOUR_BETWEEN_PEDESTALS = 0.06
        local function colourStatus(_message)
        end
        local function readColourPuzzle()
            local puzzles = Workspace:FindFirstChild("Puzzles")
            local puzzle = puzzles and puzzles:FindFirstChild("ColorPuzzle")
            if not puzzle then return nil, nil, "ColorPuzzle not found" end
            local base = puzzle:FindFirstChild("Folder")
            if not base then return nil, nil, "ColorPuzzle.Folder (pedestals) not found" end
            local counts, summaries, problem = readVisibleColourCounts(puzzle)
            if not counts then
                return nil, nil, problem
            end
            local pedestals = {}
            for index = 1, 3 do
                if counts[index] < 1 or counts[index] > 5 then
                    return nil, nil, string.format("Gem count %d outside expected 1-5 for pedestal %d; not clicking", counts[index], index)
                end
                local pedestal = base:FindFirstChild("Pedestal" .. tostring(index))
                if not pedestal or not pedestal:IsA("Model") then
                    return nil, nil, "Pedestal" .. index .. " model missing"
                end
                pedestals[index] = pedestal
            end

            if counts[1] == 5 and counts[2] == 5 and counts[3] == 5 then
                return nil, nil, "All 15 slot models appear visible; cannot verify the gem counts"
            end
            return counts, pedestals
        end
        local function clickPartForPedestal(pedestal)
            local parts = {}
            for _, item in ipairs(pedestal:GetDescendants()) do
                if item:IsA("ClickDetector") and item.Parent and item.Parent:IsA("BasePart") then
                    return item.Parent, "ClickDetector"
                end
                if item:IsA("BasePart") and item.CanQuery then
                    parts[#parts + 1] = item
                end
            end
            local names = { "click", "hitbox", "button", "top", "main", "pad", "pedestal" }
            for _, name in ipairs(names) do
                for _, item in ipairs(parts) do
                    if item.Name:lower():find(name, 1, true) then return item, name end
                end
            end
            return parts[1], parts[1] and "first queryable part" or "no queryable BasePart"
        end
        local function pedestalView(pedestal, target, character)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { character }
            rayParams.IgnoreWater = true
            local forward = Vector3.new(target.CFrame.LookVector.X, 0, target.CFrame.LookVector.Z)
            if forward.Magnitude < 0.05 then forward = Vector3.new(0, 0, 1) end
            forward = forward.Unit
            local side = Vector3.new(-forward.Z, 0, forward.X)
            local directions = {
                forward, -forward, side, -side,
                (forward + side).Unit, (forward - side).Unit,
                (-forward + side).Unit, (-forward - side).Unit,
            }
            local best, bestScore = nil, -1
            for _, radius in ipairs({ 3.5, 4.5, 5.5, 7 }) do
                for _, vertical in ipairs({ 1.5, 0.5, 2.5, -0.3 }) do
                    for _, dir in ipairs(directions) do
                        local cameraAt = target.Position + dir * radius + Vector3.new(0, vertical, 0)
                        local ray = target.Position - cameraAt
                        local hit = Workspace:Raycast(cameraAt, ray.Unit * (ray.Magnitude + 0.25), rayParams)
                        local score = hit and (hit.Instance == target and 3
                            or (hit.Instance:IsDescendantOf(pedestal) and 2 or 0)) or 0
                        if score > bestScore then
                            bestScore = score
                            best = { cameraAt = cameraAt, lookAt = target.Position, score = score }
                        end
                        if score == 3 then return best, rayParams end
                    end
                end
            end
            return best, rayParams
        end
        local function runColourPuzzle()
            if hubUnloaded or colourRunning then return end
            if puzzleControllerBusy then colourStatus("Another puzzle controller is active; wait for it to finish") return end
            colourRunning = true
            puzzleControllerBusy = true
            colourCancel = false
            local cam = Workspace.CurrentCamera
            local previousPivot, previousCFrame, previousType, previousSubject
            local colourCompletedAllClicks = false

            local colourServerCompleted = false
            local colourStateSeen = false
            local puzzleRemotes = ReplicatedStorage:FindFirstChild("Puzzles")
            local colourStateRemote = puzzleRemotes and puzzleRemotes:FindFirstChild("PuzzleState")
            local colourSolvedRemote = puzzleRemotes and puzzleRemotes:FindFirstChild("PuzzleSolved")
            local colourStateConnection, colourSolvedConnection
            if colourStateRemote and colourStateRemote:IsA("RemoteEvent") then
                colourStateConnection = colourStateRemote.OnClientEvent:Connect(function(snapshot)
                    local entry = type(snapshot) == "table" and snapshot.ColorPuzzle
                    if type(entry) == "table" then
                        colourStateSeen = true
                        if entry.completed == true or entry.solved == true then
                            colourServerCompleted = true
                        end
                    end
                end)
            end
            if colourSolvedRemote and colourSolvedRemote:IsA("RemoteEvent") then
                colourSolvedConnection = colourSolvedRemote.OnClientEvent:Connect(function(puzzleName)
                    if puzzleName == "ColorPuzzle" then
                        colourServerCompleted = true
                    elseif type(puzzleName) == "table" and
                        (puzzleName.puzzle == "ColorPuzzle" or puzzleName.puzzleName == "ColorPuzzle") then
                        colourServerCompleted = true
                    end
                end)
            end
            local function colourWorldSolved()
                local puzzles = Workspace:FindFirstChild("Puzzles")
                local colour = puzzles and puzzles:FindFirstChild("ColorPuzzle")
                return colour ~= nil and (colour:GetAttribute("Solved") == true or colour:GetAttribute("Completed") == true)
            end
            local mouseDown = false
            local lastClick = Vector2.new(0, 0)
            local previousMouse = UserInputService:GetMouseLocation()
            local previousMouseBehavior = UserInputService.MouseBehavior
            local reopenMenu = hubWindow and hubWindow.Closed == false
            local function releaseMouse()
                if mouseDown then
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(lastClick.X, lastClick.Y, 0, false, game, 0)
                    end)
                    mouseDown = false
                end
            end
            local function restore()
                releaseMouse()
                pcall(function() RunService:UnbindFromRenderStep(COLOUR_RENDER_BIND) end)
                pcall(function() UserInputService.MouseBehavior = previousMouseBehavior end)
                local character = LocalPlayer.Character
                if previousPivot and character and character.Parent then
                    pcall(function() character:PivotTo(previousPivot) end)
                end
                if cam and cam.Parent then
                    pcall(function()
                        if previousType then cam.CameraType = previousType end
                        if previousSubject then cam.CameraSubject = previousSubject end
                        if previousCFrame then cam.CFrame = previousCFrame end
                    end)
                end
                pcall(function()
                    VirtualInputManager:SendMouseMoveEvent(previousMouse.X, previousMouse.Y, game)
                end)
                hubRestoreAction = nil
            end
            hubRestoreAction = restore
            local ok, err = xpcall(function()
                local counts, pedestals, problem = readColourPuzzle()
                if not counts then colourStatus("Stopped: " .. tostring(problem)) return end
                colourStatus(string.format("Round gems: red=%d, purple=%d, green=%d", counts[1], counts[2], counts[3]))
                pcall(function() colourCountStatus:SetDesc(string.format("Red: %d | Purple: %d | Green: %d", counts[1], counts[2], counts[3])) end)
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not character or not root or not cam then
                    colourStatus("Character root or camera unavailable") return
                end

                if reopenMenu then
                    pcall(function() hubWindow:Close() end)
                    task.wait(0.12)
                end
                previousPivot = character:GetPivot()
                previousCFrame = cam.CFrame
                previousType = cam.CameraType
                previousSubject = cam.CameraSubject
                local rootToPivot = root.CFrame:ToObjectSpace(previousPivot)

                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                local total = 0
                for i, colour in ipairs({ "Red", "Purple", "Green" }) do
                    if hubUnloaded or colourCancel then break end
                    local pedestal = pedestals[i]
                    local target, reason = clickPartForPedestal(pedestal)
                    if not target then
                        colourStatus("Stopped: Pedestal" .. i .. " has " .. tostring(reason))
                        break
                    end
                    local view, rayParams = pedestalView(pedestal, target, character)
                    if not view or view.score < 2 then
                        colourStatus("Stopped: no clear sightline to Pedestal" .. i .. "; don't guess clicks")
                        break
                    end

                    local rootPosition = view.cameraAt - Vector3.new(0, 1.6, 0)
                    local horizontalLook = Vector3.new(target.Position.X, rootPosition.Y, target.Position.Z)
                    character:PivotTo(CFrame.lookAt(rootPosition, horizontalLook) * rootToPivot)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero

                    local lockedCamera = CFrame.lookAt(view.cameraAt, target.Position, Vector3.yAxis)
                    local function aim()
                        if hubUnloaded or colourCancel or Workspace.CurrentCamera ~= cam then return end
                        cam.CameraType = Enum.CameraType.Scriptable
                        cam.CFrame = lockedCamera
                        cam.Focus = CFrame.new(target.Position)
                        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                    end
                    pcall(function() RunService:UnbindFromRenderStep(COLOUR_RENDER_BIND) end)
                    RunService:BindToRenderStep(COLOUR_RENDER_BIND, Enum.RenderPriority.Last.Value + 30, aim)
                    aim()
                    task.wait(math.max(COLOUR_CAMERA_SETTLE, 0.30))
                    for _ = 1, 3 do
                        RunService.RenderStepped:Wait()
                        aim()
                    end
                    local center = cam.ViewportSize * 0.5
                    local sent = 0
                    for clickIndex = 1, counts[i] do
                        if hubUnloaded or colourCancel then break end
                        aim()
                        RunService.RenderStepped:Wait()
                        aim()
                        local hit = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 25, rayParams)
                        if not hit or not hit.Instance:IsDescendantOf(pedestal) then
                            colourStatus(string.format("Stopped at %s %d/%d: centre ray blocked by %s",
                                colour, clickIndex, counts[i], hit and hit.Instance:GetFullName() or "nothing"))
                            break
                        end
                        local moved, moveError = pcall(function()
                            VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game)
                        end)
                        if not moved then
                            colourStatus("Stopped: could not move cursor: " .. tostring(moveError))
                            break
                        end
                        RunService.RenderStepped:Wait()
                        task.wait(math.max(COLOUR_MOUSE_SETTLE, 0.03))
                        aim()

                        aim()
                        local down, pressError = pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                        end)
                        if not down then
                            colourStatus("Stopped: VIM Mouse1 press failed: " .. tostring(pressError))
                            break
                        end
                        mouseDown = true
                        lastClick = center
                        task.wait(COLOUR_CLICK_HOLD)
                        aim()
                        releaseMouse()
                        sent += 1
                        total += 1

                        task.wait(clickIndex < counts[i] and COLOUR_CLICK_GAP or 0.09)
                    end
                    pcall(function() RunService:UnbindFromRenderStep(COLOUR_RENDER_BIND) end)
                    colourStatus(string.format("%s pedestal: %d/%d clicks sent", colour, sent, counts[i]))
                    if sent < counts[i] then break end
                    task.wait(COLOUR_BETWEEN_PEDESTALS)
                end
                colourCompletedAllClicks = not hubUnloaded and not colourCancel
                    and total == counts[1] + counts[2] + counts[3]
                if colourCompletedAllClicks then

                    if colourStateRemote and colourStateRemote:IsA("RemoteEvent") then
                        pcall(function() colourStateRemote:FireServer() end)
                    end
                    colourStatus(string.format("All %d clicks sent; waiting 0.25s for Colour server confirmation...", total))
                    task.wait(0.25)
                    if colourServerCompleted or colourWorldSolved() then
                        colourStatus(string.format("CONFIRMED: ColorPuzzle completed after 0.25s (%d clicks sent).", total))
                    else
                        colourCompletedAllClicks = false
                        colourStatus(string.format(
                            "NOT CONFIRMED after 0.25s (%d clicks sent, state received=%s). Some pedestal clicks may not have registered; stopping before reporting success.",
                            total, tostring(colourStateSeen)))
                    end
                else
                    colourStatus(string.format("Incomplete: %d VIM clicks sent. Remaining stages will not run automatically.", total))
                end
            end, function(e) return tostring(e) end)
            restore()
            if colourStateConnection then colourStateConnection:Disconnect() end
            if colourSolvedConnection then colourSolvedConnection:Disconnect() end
            if not ok then colourStatus("ERROR: " .. tostring(err)) end
            colourRunning = false
            puzzleControllerBusy = false

            if reopenMenu and not hubUnloaded and hubWindow then
                pcall(function() hubWindow:Open() end)
            end
            return ok and colourCompletedAllClicks and not hubUnloaded and not colourCancel
        end
        local leverRunning = false
        local leverCancelled = false
        local LEVER_RENDER_BIND = "BeyyV103_00LeverAim_" .. tostring(LocalPlayer.UserId)

        local function status(_message)
        end
        local function leverFolder()
            local puzzles = Workspace:FindFirstChild("Puzzles")
            local puzzle = puzzles and puzzles:FindFirstChild("LeverPuzzle")
            return puzzle and puzzle:FindFirstChild("Levers")
        end
        local function clickPartForLever(lever)
            if not lever then return nil end

            for _, child in ipairs(lever:GetDescendants()) do
                if child:IsA("ClickDetector") and child.Parent and child.Parent:IsA("BasePart") then
                    return child.Parent
                end
            end
            local preferred
            local fallback
            for _, child in ipairs(lever:GetDescendants()) do
                if child:IsA("BasePart") then
                    fallback = fallback or child
                    if child.Name:lower():find("lever", 1, true) or child.Name:lower():find("handle", 1, true) then
                        preferred = preferred or child
                    end
                end
            end
            return preferred or fallback
        end

        local CAPTURED_LEVER_POSES = {
            [1] = {
                RootPosition = Vector3.new(-143.4634705, -17.7200069, -12.6431561),
                RootLook = Vector3.new(-0.2753348, 0, -0.9613484),
                CameraPosition = Vector3.new(-143.3726044, -15.9443932, -12.3258915),
                CameraLook = Vector3.new(-0.1817362, -0.7512290, -0.6345290),
                ClickPartName = "Main",
            },
            [2] = {
                RootPosition = Vector3.new(-80.9218597, -17.7200069, -51.0603104),
                RootLook = Vector3.new(0.7973347, 0, 0.6035374),
                CameraPosition = Vector3.new(-81.2457199, -16.0284252, -51.3054543),
                CameraLook = Vector3.new(0.6477203, -0.5831626, 0.4902855),
                ClickPartName = "Handle",
            },
            [3] = {
                RootPosition = Vector3.new(-92.9316330, -17.7200069, -10.6254930),
                RootLook = Vector3.new(-0.9357321, 0, -0.3527115),
                CameraPosition = Vector3.new(-92.4652405, -16.2803955, -10.4496927),
                CameraLook = Vector3.new(-0.9327921, -0.0792224, -0.3516004),
                ClickPartName = "Main",
            },
        }
        local function capturedLeverView(index, character)
            local pose = CAPTURED_LEVER_POSES[index]
            if not pose then return nil, nil end
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { character }
            rayParams.IgnoreWater = true
            return {
                RootCFrame = CFrame.lookAt(pose.RootPosition,
                    pose.RootPosition + pose.RootLook, Vector3.yAxis),
                CameraPosition = pose.CameraPosition,
                CameraCFrame = CFrame.lookAt(pose.CameraPosition,
                    pose.CameraPosition + pose.CameraLook, Vector3.yAxis),
                Captured = true,
            }, rayParams
        end

        local function findLeverView(lever, target, character)
            local forward = Vector3.new(target.CFrame.LookVector.X, 0, target.CFrame.LookVector.Z)
            if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, 1) end
            forward = forward.Unit
            local side = Vector3.new(-forward.Z, 0, forward.X)
            local directions = {
                forward, -forward, side, -side,
                (forward + side).Unit, (forward - side).Unit,
                (-forward + side).Unit, (-forward - side).Unit,
            }
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { character }
            rayParams.IgnoreWater = true
            local best, bestRank = nil, -1
            for _, radius in ipairs({ 3.5, 4.5, 5.5 }) do
                for _, direction in ipairs(directions) do
                    local cameraPosition = target.Position + direction * radius + Vector3.new(0, 1.75, 0)
                    local rayDirection = target.Position - cameraPosition
                    local hit = Workspace:Raycast(cameraPosition, rayDirection.Unit * (rayDirection.Magnitude + 0.12), rayParams)
                    local rank = 0
                    if hit and hit.Instance == target then
                        rank = 3
                    elseif hit and hit.Instance:IsDescendantOf(lever) then
                        rank = 2
                    elseif not hit then

                        rank = 1
                    end
                    if rank > bestRank then
                        bestRank = rank
                        best = {
                            Direction = direction,
                            CameraPosition = cameraPosition,
                            Hit = hit and hit.Instance or nil,
                            Rank = rank,
                        }
                    end
                    if rank == 3 then return best, rayParams end
                end
            end
            return best, rayParams
        end

        local function runLevers()
            if leverRunning or hubUnloaded then return end
            if puzzleControllerBusy then status("Another puzzle controller is active; wait for it to finish") return end
            puzzleControllerBusy = true
            leverRunning = true
            leverCancelled = false
            local leverPassClicks = 0
            local previousCharacterPivot, previousCameraCFrame, previousCameraType, previousCameraSubject
            local clickDown = false
            local clickPoint = Vector2.new(0, 0)
            local cam = Workspace.CurrentCamera
            local function releaseMouse()
                if clickDown then

                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(clickPoint.X, clickPoint.Y, 0, false, game, 0)
                    end)
                    clickDown = false
                end
            end
            local function restore()
                releaseMouse()
                pcall(function() RunService:UnbindFromRenderStep(LEVER_RENDER_BIND) end)
                local char = LocalPlayer.Character
                if char and char.Parent and previousCharacterPivot then
                    pcall(function() char:PivotTo(previousCharacterPivot) end)
                end
                if cam and cam.Parent then
                    pcall(function()
                        if previousCameraType then cam.CameraType = previousCameraType end
                        if previousCameraSubject then cam.CameraSubject = previousCameraSubject end
                        if previousCameraCFrame then cam.CFrame = previousCameraCFrame end
                    end)
                end
                hubRestoreAction = nil
            end
            hubRestoreAction = restore
            local ok, err = xpcall(function()
                local folder = leverFolder()
                if not folder then
                    status("Levers folder absent. Wait for Chapter 2 puzzle assets to load.")
                    return
                end
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not root or not cam then
                    status("Character root or camera unavailable; retry after spawning.")
                    return
                end
                previousCharacterPivot = character:GetPivot()
                previousCameraCFrame = cam.CFrame
                previousCameraType = cam.CameraType
                previousCameraSubject = cam.CameraSubject
                local rootToPivot = root.CFrame:ToObjectSpace(previousCharacterPivot)
                local attempted, missing, clear = 0, 0, 0
                for i = 1, 3 do
                    if hubUnloaded or leverCancelled then
                        status("Lever pass cancelled")
                        break
                    end
                    local lever = folder:FindFirstChild("Lever" .. tostring(i))
                    local pose = CAPTURED_LEVER_POSES[i]
                    local target = lever and pose and lever:FindFirstChild(pose.ClickPartName, true)
                    if target and not target:IsA("BasePart") then target = nil end
                    target = target or clickPartForLever(lever)
                    if not target then
                        missing += 1
                        status("Lever" .. i .. " has no replicated clickable BasePart; skipped")
                    else
                        local view, rayParams = capturedLeverView(i, character)
                        if not view then

                            view, rayParams = findLeverView(lever, target, character)
                        end
                        if not view then
                            missing += 1
                            status("Lever" .. i .. " camera view unavailable; skipped")
                        else
                            local targetPosition = target.Position
                            local newRoot
                            if view.RootCFrame then

                                newRoot = view.RootCFrame
                            else
                                local rootPosition = targetPosition + view.Direction * 2.5 + Vector3.new(0, 0.6, 0)
                                local gazeAt = Vector3.new(targetPosition.X, rootPosition.Y, targetPosition.Z)
                                newRoot = CFrame.lookAt(rootPosition, gazeAt, Vector3.yAxis)
                            end
                            character:PivotTo(newRoot * rootToPivot)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            local function aim()
                                if hubUnloaded or leverCancelled or not target.Parent or Workspace.CurrentCamera ~= cam then return end
                                cam.CameraType = Enum.CameraType.Scriptable

                                cam.CFrame = view.CameraCFrame or CFrame.lookAt(view.CameraPosition, target.Position, Vector3.yAxis)
                            end
                            pcall(function() RunService:UnbindFromRenderStep(LEVER_RENDER_BIND) end)
                            RunService:BindToRenderStep(LEVER_RENDER_BIND, Enum.RenderPriority.Last.Value + 30, aim)
                            aim()

                            task.wait(i == 3 and 0.22 or 0.12)
                            RunService.RenderStepped:Wait()
                            aim()
                            local center = cam.ViewportSize * 0.5

                            local hit = Workspace:Raycast(cam.CFrame.Position,
                                cam.CFrame.LookVector * 25, rayParams)
                            local hitName = hit and hit.Instance:GetFullName() or "none"
                            local directHit = hit and hit.Instance == target
                            local sameModel = hit and hit.Instance:IsDescendantOf(lever)
                            if directHit then clear += 1 end
                            if leverCancelled or hubUnloaded then
                                status("Lever pass cancelled")
                            elseif not sameModel then
                                warn("[AutoLever] Lever" .. i .. " centre ray missed lever (hit=" .. hitName .. "); skipping click")
                            else
                                local moveOK, moveError = pcall(function()
                                    VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game)
                                end)
                                RunService.RenderStepped:Wait()
                                task.wait(0.04)
                                if not moveOK then
                                    warn("[AutoLever] Mouse move failed: " .. tostring(moveError))
                                elseif not leverCancelled and not hubUnloaded and target.Parent then

                                    local watchPart = lever:FindFirstChild("Handle", true)
                                    if not (watchPart and watchPart:IsA("BasePart")) then watchPart = target end
                                    local before = watchPart.CFrame
                                    local pressed, pressError = pcall(function()
                                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                                    end)
                                    if pressed then
                                        clickDown = true
                                        clickPoint = center
                                        task.wait(0.10)
                                        releaseMouse()
                                        attempted += 1
                                        leverPassClicks = attempted

                                        local moved = false
                                        for _ = 1, 7 do
                                            if hubUnloaded or leverCancelled then break end
                                            local relative = before:ToObjectSpace(watchPart.CFrame)
                                            local _, angle = relative:ToAxisAngle()
                                            if (before.Position - watchPart.Position).Magnitude > 0.04
                                                or math.abs(math.deg(angle)) > 1.0 then
                                                moved = true
                                                break
                                            end
                                            task.wait(0.05)
                                        end

                                        if not leverCancelled and not hubUnloaded then
                                            if i == 1 then
                                                task.wait(0.10)
                                            elseif i == 3 then
                                                task.wait(0.30)
                                            end
                                        end
                                    else
                                        warn("[AutoLever] Lever" .. i .. " VIM click failed: " .. tostring(pressError))
                                    end
                                end
                            end
                            pcall(function() RunService:UnbindFromRenderStep(LEVER_RENDER_BIND) end)
                            task.wait(0.06)
                        end
                    end
                end
                if not leverCancelled and not hubUnloaded then
                    status(string.format("Pass complete: %d clicks sent, %d missing targets, %d direct part sightlines. Puzzle state unverified.",
                        attempted, missing, clear))
                end
            end, function(message) return tostring(message) end)
            restore()
            if not ok then status("ERROR: " .. tostring(err)) end
            leverRunning = false
            puzzleControllerBusy = false
            return ok and leverPassClicks == 3 and not hubUnloaded and not leverCancelled
        end

        local PICTURE_REQUEST_INTERVAL = 0.10
        local pictureRunning = false
        local pictureFinished = false
        local pictureSuccess = false
        local pictureCancelled = false
        local pictureAllowReposition = false
        local function pictureStatus(_message)
        end
        local function runPicturePuzzle()
            if pictureRunning then
                pictureStatus("Already running; not starting duplicate workers")
                return false
            end
            pictureRunning = true
            pictureFinished = false
            pictureSuccess = false
            local savedPivot = nil
            local pictureMovedPlayer = false
            local function cancelled()
                return hubUnloaded or pictureCancelled
            end
            local function pause(seconds)
                local stopAt = os.clock() + math.max(0, seconds)
                while os.clock() < stopAt do
                    if cancelled() then return false end
                    task.wait(math.min(0.05, math.max(0.01, stopAt - os.clock())))
                end
                return not cancelled()
            end
            local function main()
                local pf = Workspace:FindFirstChild("Puzzles")
                local room = pf and pf:FindFirstChild("PicturePuzzle")
                local puzzle = room and room:FindFirstChild("PicturePuzzle")
                local state = puzzle and puzzle:FindFirstChild("State")
                local board = puzzle and puzzle:FindFirstChild("BoardPart")
                local rf = ReplicatedStorage:FindFirstChild("Puzzles")
                local action = rf and rf:FindFirstChild("PuzzleAction")
                if not (puzzle and state and board and action and action:IsA("RemoteEvent")) then
                    pictureStatus("Cannot start: PicturePuzzle State/BoardPart or PuzzleAction missing")
                    return false
                end
                local values = {}
                for i = 1, 16 do
                    values[i] = state:FindFirstChild("Rotation" .. i)
                    if not (values[i] and values[i]:IsA("IntValue")) then
                        pictureStatus("Missing Rotation" .. i)
                        return false
                    end
                end
                local interactDistance = tonumber(puzzle:GetAttribute("MaxInteractDistance")) or 30
                pcall(function()
                    local config = require(rf:WaitForChild("PuzzleConfig"))
                    local entry = config and config.Puzzles and config.Puzzles.PicturePuzzle
                    if entry then
                        interactDistance = tonumber(entry.InteractDistance) or interactDistance
                    end
                end)
                local totalSent = 0
                local totalConfirmed = 0
                local totalNoAck = 0
                local pending = {}
                local retryAfter = {}
                local cursor = 0
                local nextSendAt = 0
                local noRangeLogged = false
                local maxUntil = os.clock() + 160

                local acknowledgementTimeout = 1.5
                local function closeEnough()
                    local c = LocalPlayer.Character
                    local root = c and c:FindFirstChild("HumanoidRootPart")
                    return root and (root.Position - board.Position).Magnitude <= interactDistance
                end
                local function checkSolved()
                    return puzzle:GetAttribute("Solved") == true
                end
                local function getNearBoardAfterOtherStages()
                    if pictureMovedPlayer then return false end
                    local character = LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if not root then return false end

                    savedPivot = character:GetPivot()
                    local spot = board.CFrame:PointToWorldSpace(Vector3.new(0, -2.5, -8))
                    local target = Vector3.new(board.Position.X, spot.Y, board.Position.Z)
                    local moved = pcall(function()
                        character:PivotTo(CFrame.lookAt(spot, target))
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end)
                    if moved then
                        pictureMovedPlayer = true
                        pictureStatus("Other puzzles finished; moved into picture interaction range to finish")
                        pause(0.45)
                    else
                        savedPivot = nil
                    end
                    return moved
                end
                local function readState()
                    local unfinished = 0
                    for i = 1, 16 do
                        local v = values[i].Value
                        if type(v) ~= "number" or v < 0 or v > 3 then
                            return nil, "Unexpected Rotation" .. i .. " value " .. tostring(v)
                        end
                        if v ~= 0 then unfinished += 1 end
                    end
                    return unfinished
                end
                local function updatePending(now)
                    for i, request in pairs(pending) do
                        local current = values[i].Value
                        if current ~= request.before then
                            totalConfirmed += 1
                            pending[i] = nil
                            retryAfter[i] = nil
                        elseif now - request.sentAt >= acknowledgementTimeout then

                            pending[i] = nil
                            retryAfter[i] = now + 0.55
                            totalNoAck += 1
                            pictureStatus(string.format("No acknowledgement for Tile%d (%.2fs); total no-acks %d",
                                i, acknowledgementTimeout, totalNoAck))
                        end
                    end
                end
                local function chooseTarget(now)

                    for offset = 1, 16 do
                        local i = ((cursor + offset - 1) % 16) + 1
                        if values[i].Value ~= 0 and not pending[i] and
                            (not retryAfter[i] or now >= retryAfter[i]) then
                            return i
                        end
                    end
                    return nil
                end
                pictureStatus(string.format("Starting: one remote every %.2fs | server-state acknowledgement per tile | %.1f stud range",
                    PICTURE_REQUEST_INTERVAL, interactDistance))
                local allZeroAt = nil
                while not cancelled() and os.clock() < maxUntil do
                    if checkSolved() then
                        pictureStatus(string.format("SOLVED=true | sent %d, confirmed %d, no-ack %d",
                            totalSent, totalConfirmed, totalNoAck))
                        return true
                    end
                    local now = os.clock()
                    updatePending(now)
                    local unfinished, reason = readState()
                    if unfinished == nil then
                        pictureStatus("Stopped: " .. tostring(reason))
                        return false
                    end
                    if unfinished == 0 then
                        allZeroAt = allZeroAt or now
                        if now - allZeroAt >= 4.0 then
                            pictureStatus("All rotations zero, but Solved=true not replicated")
                            return false
                        end
                        if not pause(0.04) then break end
                    elseif not closeEnough() then
                        allZeroAt = nil
                        if pictureAllowReposition then
                            getNearBoardAfterOtherStages()
                        elseif not noRangeLogged then
                            pictureStatus("Waiting for proximity while Number/Colour operate")
                            noRangeLogged = true
                        end
                        if not pause(0.12) then break end
                    else
                        allZeroAt = nil
                        noRangeLogged = false
                        if now >= nextSendAt then
                            local i = chooseTarget(now)
                            if i then
                                local before = values[i].Value
                                local ok, err = pcall(function()
                                    action:FireServer("PicturePuzzle", "Tile" .. i)
                                end)

                                if ok then
                                    pending[i] = {before = before, sentAt = os.clock()}
                                    totalSent += 1
                                    cursor = i
                                    nextSendAt = os.clock() + PICTURE_REQUEST_INTERVAL
                                else
                                    pictureStatus("Tile" .. i .. " FireServer failed: " .. tostring(err))
                                    retryAfter[i] = os.clock() + 0.55
                                end
                            end
                        end
                        if not pause(0.02) then break end
                    end
                end
                if not cancelled() then
                    pictureStatus(string.format("Timed out | sent %d, confirmed %d, no-ack %d",
                        totalSent, totalConfirmed, totalNoAck))
                end
                return false
            end
            local ok, outcome = xpcall(main, function(e) return tostring(e) end)
            if pictureMovedPlayer and savedPivot then
                local char = LocalPlayer.Character
                if char and char.Parent then
                    pcall(function() char:PivotTo(savedPivot) end)
                end
            end
            pictureSuccess = ok and outcome == true
            pictureFinished = true
            pictureRunning = false
            if not ok then pictureStatus("ERROR: " .. tostring(outcome)) end
            if pictureCancelled then pictureStatus("Cancelled") end
            return pictureSuccess
        end

        puzzleTab:Section({ Title = "Full Chapter 2 automation" })
        local allPuzzlesRunning = false
        sharedFarmPuzzleBusy = function() return allPuzzlesRunning or puzzleControllerBusy end
        local allPuzzlesCancel = false
        local autoSolveOnJoin=true
        local autoRunClaimed=false
        local autoStartWaiting=false
        local autoStartCancelled=false
        local allPuzzlesStage = "Idle"
        local allPuzzlesStatus=puzzleTab:Paragraph({Title="Auto Puzzle Status",Desc="Waiting for startup"})
        local function allStatus(message)
            allPuzzlesStage = message
            allPuzzlesStatus:SetDesc(message)
        end
        local isNumberStageCancelled = function()
            return hubUnloaded or allPuzzlesCancel
        end
        local function runNumberPuzzleInHub()
            local numberCode = [===[

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local PLACE_ID = 83445806734780

local REUSE_DISTANCE = 7.0
local TELEPORT_SETTLE = 0.23
local REUSE_SETTLE = 0.065
local RETRY_SETTLE = 0.53
local FIRST_FEEDBACK_WAIT = 1.00
local RETRY_FEEDBACK_WAIT = 1.55
local BETWEEN_POSTERS = 0.07
local KEYPAD_SETTLE = 0.40
local KEYPAD_RETRY_SETTLE = 0.70
local KEYPAD_FEEDBACK_WAIT = 2.20
local KEYPAD_RETRY_FEEDBACK_WAIT = 2.90
local PREFIX = "[NumberSolver] "

if not player then
    warn(PREFIX .. "LocalPlayer unavailable")
    return
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__BEYY_NUMBER_FINDER_CLOSE) == "function" then
    pcall(env.__BEYY_NUMBER_FINDER_CLOSE)
end

local connections = {}
local running, cancelled, closed = false, false, false
local pending, pendingSubmit, latestState, foundCode, foundIndex, correctPosterIndex
local runSerial = 0
local codeLength = 4
local config, numberConfig, actionRemote, feedbackRemote, stateRemote

local function safeString(value)
    if value == nil then return "nil" end
    return tostring(value):gsub("[\r\n]", " ")
end

local function log(message)
    if type(__beNumberStatus) == "function" then
        pcall(__beNumberStatus, safeString(message))
    end
end

local function getRoot()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return root and root:IsA("BasePart") and root or nil
end

local function getPosterFolder()
    local puzzles = workspace:FindFirstChild("Puzzles")
    local folder = puzzles and puzzles:FindFirstChild((numberConfig and numberConfig.Folder) or "NumberPuzzle")
    local path = (numberConfig and numberConfig.Posters) or "Posters"
    for piece in tostring(path):gmatch("[^/]+") do
        folder = folder and folder:FindFirstChild(piece)
    end
    return folder
end

local function getKeypad()
    local puzzles = workspace:FindFirstChild("Puzzles")
    local folder = puzzles and puzzles:FindFirstChild((numberConfig and numberConfig.Folder) or "NumberPuzzle")
    local path = (numberConfig and numberConfig.Keypad) or "Keypad"
    for piece in tostring(path):gmatch("[^/]+") do
        folder = folder and folder:FindFirstChild(piece)
    end
    return folder
end

local function puzzleCompleted()
    return latestState and latestState.completed == true or false
end

local function isTaken(index)
    local taken = latestState and latestState.taken
    return type(taken) == "table" and
        (taken[index] == true or taken[tostring(index)] == true) or false
end

local function availablePosters()
    local result, folder = {}, getPosterFolder()
    if not folder then return result end
    local attributeName = (config and config.PosterIndexAttribute) or "PosterIndex"
    local seen = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") then
            local index = child:GetAttribute(attributeName)
            if type(index) == "number" and index >= 1 and not seen[index] and not isTaken(index) then
                seen[index] = true
                result[#result + 1] = {index = index, part = child}
            end
        end
    end
    table.sort(result, function(a, b) return a.index < b.index end)
    return result
end

local function orderByNearest(posters, startPosition)
    local remaining, route, cursor = {}, {}, startPosition
    for _, item in ipairs(posters) do remaining[#remaining + 1] = item end
    while #remaining > 0 do
        local best, bestDistance = 1, math.huge
        for i, item in ipairs(remaining) do
            local distance = (item.part.Position - cursor).Magnitude
            if distance < bestDistance then
                best, bestDistance = i, distance
            end
        end
        local nextPoster = table.remove(remaining, best)
        route[#route + 1] = nextPoster
        cursor = nextPoster.part.Position
    end
    return route
end

local function validCode(value)
    return type(value) == "string" and #value == codeLength and value:match("^%d+$") ~= nil
end

local function readGuiCode()
    local pg = player:FindFirstChild("PlayerGui")
    local note = pg and pg:FindFirstChild("NumberPuzzleNote")
    local paper = note and note:FindFirstChild("Paper")
    local code = paper and paper:FindFirstChild("Code")
    if code and code:IsA("TextLabel") then return code.Text end
    return nil
end

local function registerCode(value, source, index)
    if not validCode(value) then return false end
    if foundCode ~= value then
        foundCode = value
        foundIndex = index or foundIndex
        log("CODE FOUND: " .. value .. " | via " .. safeString(source) ..
            " | poster=" .. safeString(foundIndex))
    end
    return true
end

local function readKnownCode(source)
    if validCode(foundCode) then return true end
    if latestState and registerCode(latestState.code, source .. " PuzzleState") then return true end
    return registerCode(readGuiCode(), source .. " GUI")
end

local function restorePosition(origin)
    local root = getRoot()
    if root and origin then
        local ok, err = pcall(function()
            root.CFrame = origin
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        log(ok and "Returned to original location" or ("Could not restore position: " .. safeString(err)))
    else
        log("Could not restore original location (character changed or root missing)")
    end
end

local function close()
    if closed then return end
    closed = true
    cancelled = true
    runSerial = runSerial + 1
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    if env.__BEYY_NUMBER_FINDER_CLOSE == close then
        env.__BEYY_NUMBER_FINDER_CLOSE = nil
    end
end

env.__BEYY_NUMBER_FINDER_CLOSE = close

local function waitForFeedback(target, seconds, serial)
    local started = os.clock()
    while os.clock() - started < seconds do
        if closed or cancelled or runSerial ~= serial then return "cancel" end
        if validCode(foundCode) then return "found" end
        if target.feedback then return "feedback" end
        if isTaken(target.index) then return "taken" end
        task.wait(0.025)
    end
    if readKnownCode("timeout") then return "found" end
    return "timeout"
end

local function teleportNear(poster)
    local root = getRoot()
    if not root or not poster or not poster.Parent then return false, "root/poster missing" end

    local destination = poster.Position + Vector3.new(0, 2.65, 0)
    local ok, err = pcall(function()
        root.CFrame = CFrame.new(destination) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not ok then return false, safeString(err) end
    return true, "moved"
end

local function moveToPosterIfNecessary(poster, maxDistance)
    local root = getRoot()
    local reuseLimit = math.min(REUSE_DISTANCE, maxDistance - 2.0)
    if root and reuseLimit > 0 and (root.Position - poster.Position).Magnitude <= reuseLimit then
        return true, "within range", false
    end
    local ok, reason = teleportNear(poster)
    return ok, reason, ok
end

local function teleportNearKeypad(keypad)
    local root = getRoot()
    if not root then return false, "HumanoidRootPart missing" end
    if not keypad or not keypad.Parent then return false, "keypad missing" end
    if not (keypad:IsA("Model") or keypad:IsA("BasePart")) then
        return false, "unexpected keypad class: " .. keypad.ClassName
    end
    local pivot = keypad:GetPivot()
    local destination = pivot.Position - pivot.LookVector * 4.0 + Vector3.new(0, 2.5, 0)
    local ok, err = pcall(function()
        root.CFrame = CFrame.new(destination) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not ok then return false, safeString(err) end
    return true, "moved"
end

local function submitDiscoveredCode(serial)
    if not validCode(foundCode) then
        log("KEYPAD STOP: no valid " .. tostring(codeLength) .. "-digit code")
        return false
    end
    if puzzleCompleted() then
        log("KEYPAD SKIPPED: NumberPuzzle already completed")
        return true
    end
    local keypad = getKeypad()
    if not keypad then
        log("KEYPAD STOP: Workspace.Puzzles.NumberPuzzle.Keypad unavailable (not streamed?)")
        return false
    end
    local range = (numberConfig and numberConfig.InteractDistance) or 10
    if type(range) ~= "number" or range <= 0 then range = 10 end
    log("CODE FOUND: " .. foundCode .. " | approaching keypad | max interaction range=" .. tostring(range))
    for attempt = 1, 2 do
        if cancelled or closed or serial ~= runSerial then
            log("KEYPAD CANCELLED before attempt " .. tostring(attempt))
            return false
        end
        if puzzleCompleted() then
            log("KEYPAD CONFIRMED: PuzzleState completed=true")
            return true
        end
        local moved, reason = teleportNearKeypad(keypad)
        if not moved then
            log("KEYPAD STOP: teleport failed: " .. safeString(reason))
            return false
        end
        task.wait(attempt == 1 and KEYPAD_SETTLE or KEYPAD_RETRY_SETTLE)
        if cancelled or closed or serial ~= runSerial then return false end
        local root = getRoot()
        local distance = root and (root.Position - keypad:GetPivot().Position).Magnitude or math.huge
        if distance >= range - 0.5 then
            log(string.format("KEYPAD STOP: too far from keypad (%.2f / %.2f studs)", distance, range))
            return false
        end

        local probe = {received = false, accepted = nil}
        pendingSubmit = probe
        log(string.format("KEYPAD SUBMIT attempt %d/2 | code=%s | distance=%.2f | FireServer", attempt, foundCode, distance))
        local fired, fireErr = pcall(function()
            actionRemote:FireServer("NumberPuzzle", "Submit", foundCode)
        end)
        if not fired then
            pendingSubmit = nil
            log("KEYPAD STOP: FireServer failed: " .. safeString(fireErr))
            return false
        end
        local started = os.clock()
        local timeout = attempt == 1 and KEYPAD_FEEDBACK_WAIT or KEYPAD_RETRY_FEEDBACK_WAIT
        local gotCompletion, gotFeedback, wasAccepted = false, false, false
        while os.clock() - started < timeout do
            if cancelled or closed or serial ~= runSerial then
                pendingSubmit = nil
                return false
            end
            if puzzleCompleted() then
                gotCompletion = true
                break
            end
            if probe.received then
                gotFeedback, wasAccepted = true, probe.accepted == true
                break
            end
            task.wait(0.03)
        end
        pendingSubmit = nil
        if gotCompletion then
            log("KEYPAD SUCCESS: PuzzleState confirms completed=true")
            return true
        end
        if gotFeedback then
            if wasAccepted then
                log("KEYPAD SUCCESS: server PuzzleFeedback Submit=true")

                for _ = 1, 12 do
                    if closed or cancelled or runSerial ~= serial or puzzleCompleted() then break end
                    task.wait(0.05)
                end
                if not puzzleCompleted() then
                    log("Submit accepted, but no completed state observed yet (feedback is authoritative)")
                end
                return true
            end
            log("KEYPAD REJECTED: server PuzzleFeedback Submit=false. Not retrying an explicit rejection")
            return false
        end
        log("KEYPAD TIMEOUT attempt " .. attempt .. ": no Submit feedback or completed state")
        if attempt == 1 then

            pcall(function() stateRemote:FireServer() end)
            task.wait(0.25)
            if puzzleCompleted() then
                log("KEYPAD SUCCESS: state refresh confirmed completed=true")
                return true
            end
            log("Retrying keypad once with a longer teleport settle")
        end
    end
    log("KEYPAD UNCONFIRMED: no response after two attempts; check keypad distance or server requirements")
    return false
end

local function runFinder()
    if running then log("Finder is already running"); return end
    if closed then return end
    if game.PlaceId ~= PLACE_ID then
        log("Wrong place: join Chapter 2 (PlaceId " .. tostring(PLACE_ID) .. ")")
        return
    end
    if not actionRemote or not feedbackRemote or not stateRemote then
        log("PuzzleAction/PuzzleFeedback/PuzzleState are missing")
        return
    end
    local startRoot = getRoot()
    if not startRoot then log("HumanoidRootPart missing; wait for character to spawn"); return end
    if puzzleCompleted() then
        log("NumberPuzzle already completed; nothing to solve")
        return
    end
    local existingCode = readKnownCode("startup")
    local candidates = {}
    if existingCode then
        log("Existing code detected; skipping poster search and going straight to the keypad")
    else
        local folder = getPosterFolder()
        if not folder then log("Poster folder missing; wait for puzzle to stream in"); return end
        candidates = availablePosters()
        if #candidates == 0 then log("No uncollected indexed poster parts remain"); return end
        candidates = orderByNearest(candidates, startRoot.Position)
    end

    local originalCFrame = startRoot.CFrame
    running, cancelled = true, false
    runSerial = runSerial + 1
    local serial = runSerial
    local range = (numberConfig and numberConfig.PosterDistance) or 10
    log("START FULL AUTO v1.2 | " .. tostring(#candidates) .. " posters | range=" .. safeString(range) ..
        " | code length=" .. tostring(codeLength) .. " | route=nearest | reuse <=" .. tostring(math.min(REUSE_DISTANCE, range - 2.0)) .. " studs")

    do
        local attempted, accepted, skipped = 0, 0, 0
        local teleports, reused = 0, 0
        local ok, err = pcall(function()
            for _, item in ipairs(candidates) do
                if cancelled or closed or runSerial ~= serial or readKnownCode("between posters") then break end
                if latestState and latestState.completed then
                    log("Puzzle already completed according to PuzzleState")
                    break
                end
                local index, poster = item.index, item.part
                if not poster or not poster.Parent or isTaken(index) then
                    log("Skipping index " .. tostring(index) .. " (gone/taken)")
                else
                    attempted = attempted + 1

                    local matched = false

                    for attempt = 1, 2 do
                        if cancelled or closed or runSerial ~= serial then break end
                        if not poster.Parent or isTaken(index) then break end
                        local moved, reason, didTeleport
                        if attempt == 1 then
                            moved, reason, didTeleport = moveToPosterIfNecessary(poster, range)
                        else

                            moved, reason = teleportNear(poster)
                            didTeleport = moved
                        end
                        if not moved then
                            log("Poster #" .. index .. " positioning failed: " .. reason)
                            break
                        end
                        if didTeleport then teleports = teleports + 1 else reused = reused + 1 end

                        task.wait(attempt == 1 and (didTeleport and TELEPORT_SETTLE or REUSE_SETTLE) or RETRY_SETTLE)
                        if cancelled or closed or runSerial ~= serial then break end
                        local root = getRoot()
                        local distance = root and (root.Position - poster.Position).Magnitude or math.huge
                        if distance > range - 0.75 then
                            log(string.format("Poster #%d still %.2f studs away; repositioning", index, distance))
                            teleportNear(poster)
                            task.wait(0.20)
                            root = getRoot()
                            distance = root and (root.Position - poster.Position).Magnitude or math.huge
                        end
                        if distance > range - 0.3 then
                            log("Skipping poster #" .. index .. ": cannot reach interaction range (" ..
                                string.format("%.2f", distance) .. " studs)")
                            break
                        end
                        local target = {index = index, feedback = false, correct = nil}
                        pending = target
                        local fired, fireError = pcall(function()
                            actionRemote:FireServer("NumberPuzzle", "Poster", index)
                        end)
                        if not fired then
                            log("PuzzleAction failed for #" .. index .. ": " .. safeString(fireError))
                            pending = nil
                            break
                        end
                        local outcome = waitForFeedback(target, attempt == 1 and FIRST_FEEDBACK_WAIT or RETRY_FEEDBACK_WAIT, serial)
                        pending = nil
                        if outcome == "feedback" or outcome == "taken" or outcome == "found" then
                            matched = true
                            accepted = accepted + 1

                            if target.correct == true and not validCode(foundCode) then
                                for waitIndex = 1, 10 do
                                    if cancelled or closed or runSerial ~= serial then break end
                                    if waitIndex == 3 then
                                        pcall(function() stateRemote:FireServer() end)
                                    end
                                    task.wait(0.20)
                                    if readKnownCode("correct feedback wait") then break end
                                end
                            end
                            break
                        elseif outcome == "cancel" then
                            break
                        else
                            log("No response for poster #" .. index ..
                                (attempt == 1 and "; retrying with longer settle" or "; skipping"))
                        end
                    end
                    if not matched and not validCode(foundCode) then skipped = skipped + 1 end
                    if validCode(foundCode) or correctPosterIndex then break end
                    task.wait(BETWEEN_POSTERS)
                end
            end
        end)
        if not ok then log("SCAN ERROR: " .. safeString(err)) end
        pending = nil
        local submitted = false
        if ok and not cancelled and not closed and runSerial == serial and validCode(foundCode) then
            local submitOK, submitResult = pcall(submitDiscoveredCode, serial)
            if submitOK then
                submitted = submitResult == true
            else
                log("KEYPAD ERROR: " .. safeString(submitResult))
            end
        end
        pendingSubmit = nil
        restorePosition(originalCFrame)
        running = false
        if submitted then
            log("FULL AUTO SUCCESS | code=" .. foundCode .. " | poster=" .. safeString(foundIndex) ..
                " | visited=" .. attempted .. " | processed=" .. accepted ..
                " | teleports=" .. teleports .. " | reused=" .. reused)
        elseif cancelled or closed then
            log("SOLVER CANCELLED | visited=" .. attempted .. " | processed=" .. accepted)
        elseif validCode(foundCode) then
            log("CODE FOUND BUT KEYPAD NOT CONFIRMED | code=" .. foundCode ..
                " | press START to retry keypad without searching notes")
        elseif correctPosterIndex then
            log("CORRECT POSTER FOUND (#" .. correctPosterIndex ..
                ") but its code was not exposed yet; examine PuzzleState / NumberPuzzleNote UI")
        else
            log("SCAN FINISHED WITHOUT CODE | visited=" .. attempted .. " | processed=" .. accepted ..
                " | no-confirmation=" .. skipped .. " | check logs; server may have denied some requests")
        end
        log("Movement summary: teleports=" .. teleports .. " | reused position=" .. reused)
        return submitted
    end
end

local puzzles = ReplicatedStorage:FindFirstChild("Puzzles") or ReplicatedStorage:WaitForChild("Puzzles", 10)
local configModule = puzzles and puzzles:FindFirstChild("PuzzleConfig")
if configModule and configModule:IsA("ModuleScript") then
    local ok, value = pcall(require, configModule)
    if ok and type(value) == "table" then
        config = value
        numberConfig = value.Puzzles and value.Puzzles.NumberPuzzle
        if numberConfig and type(numberConfig.CodeLength) == "number" then
            codeLength = numberConfig.CodeLength
        end
    else
        log("Runtime PuzzleConfig require failed: " .. safeString(value))
    end
end

actionRemote = puzzles and puzzles:FindFirstChild("PuzzleAction")
feedbackRemote = puzzles and puzzles:FindFirstChild("PuzzleFeedback")
stateRemote = puzzles and puzzles:FindFirstChild("PuzzleState")
if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
    connections[#connections + 1] = feedbackRemote.OnClientEvent:Connect(function(puzzle, action, index, correct, returnedCode)
        if closed or puzzle ~= "NumberPuzzle" then return end
        if action == "Submit" then
            if pendingSubmit then
                pendingSubmit.received = true
                pendingSubmit.accepted = (index == true)
                log("KEYPAD FEEDBACK | Submit=" .. safeString(index))
            else
                log("Unsolicited keypad Submit feedback=" .. safeString(index))
            end
            return
        end
        if action ~= "Poster" then return end
        local numericIndex = tonumber(index)
        if pending and numericIndex == pending.index then
            pending.feedback = true
            pending.correct = correct
            log("MATCHING FEEDBACK | poster=" .. safeString(index) ..
                " | correct=" .. safeString(correct) ..
                " | returnedCode=" .. (validCode(returnedCode) and returnedCode or "(none)"))
            if correct == true and not validCode(returnedCode) then
                log("Correct poster confirmed, but code not in feedback. Checking puzzle state/GUI")
            end
        end
        if correct == true then
            foundIndex = numericIndex or foundIndex
            correctPosterIndex = numericIndex or correctPosterIndex
        end
        if validCode(returnedCode) then
            registerCode(returnedCode, "PuzzleFeedback", numericIndex)
        end
    end)
else
    log("PuzzleFeedback RemoteEvent unavailable")
end
if stateRemote and stateRemote:IsA("RemoteEvent") then
    connections[#connections + 1] = stateRemote.OnClientEvent:Connect(function(payload)
        if closed or type(payload) ~= "table" or type(payload.NumberPuzzle) ~= "table" then return end
        latestState = payload.NumberPuzzle
        if not validCode(foundCode) then
            registerCode(latestState.code, "PuzzleState")
        end
    end)
else
    log("PuzzleState RemoteEvent unavailable")
end

log("Integrated full-auto number solver starting")
if stateRemote and stateRemote:IsA("RemoteEvent") then
    pcall(function() stateRemote:FireServer() end)
end
task.wait(0.18)
local watcherActive = true
task.spawn(function()
    while watcherActive do
        if type(__beCancelled) == "function" and __beCancelled() then
            cancelled = true
            break
        end
        task.wait(0.05)
    end
end)
local solved = false
local worked, result = xpcall(runFinder, function(err) return tostring(err) end)
watcherActive = false
if worked then
    solved = result == true
else
    log("INTEGRATED RUN ERROR: " .. tostring(result))
end
close()
return solved]===]
            local runner, compileErr = loadstring(
                "return function(__beNumberStatus, __beCancelled)\n" .. numberCode .. "\nend")
            if not runner then
                allStatus("Number solver compile failed: " .. tostring(compileErr))
                return false
            end
            local okFactory, entry = pcall(runner)
            if not okFactory or type(entry) ~= "function" then
                allStatus("Number solver initialization failed: " .. tostring(entry))
                return false
            end
            local ok, solved = pcall(entry, function(message)
                allStatus("Number: " .. tostring(message))
            end, isNumberStageCancelled)
            if not ok then
                allStatus("Number solver runtime error: " .. tostring(solved))
                return false
            end
            return solved == true
        end
        local function waitAll(seconds)
            local endAt = os.clock() + seconds
            while os.clock() < endAt do
                if isNumberStageCancelled() then return false end
                task.wait(0.06)
            end
            return not isNumberStageCancelled()
        end

        local function stopAllPuzzles()
            if not allPuzzlesRunning then
                autoStartCancelled=true
                allStatus("Automatic startup cancelled; manual solve remains available")
                return
            end
            allPuzzlesCancel = true
            leverCancelled = true
            colourCancel = true
            pictureCancelled = true
            allStatus("Stop requested; restoring controls and position")
        end
        local originalHubCleanup = _G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP = function()
            allPuzzlesCancel = true
            leverCancelled = true
            colourCancel = true
            pictureCancelled = true
            if originalHubCleanup then originalHubCleanup() end
        end
        local function waitForHubMenuClear()
            if not hubWindow then
                allStatus("Stopped: menu window unavailable; cannot safely aim at Lever 1")
                return false
            end
            local function windUIOverCrosshair()
                local camera = Workspace.CurrentCamera
                if not camera then return true end
                local centre = camera.ViewportSize * 0.5
                local inset = GuiService:GetGuiInset()
                local x, y = centre.X, centre.Y - inset.Y
                local guiRoots = { game:GetService("CoreGui") }
                local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if playerGui then guiRoots[#guiRoots + 1] = playerGui end
                for _, root in ipairs(guiRoots) do
                    if root then
                        local ok, objects = pcall(function()
                            return root:GetGuiObjectsAtPosition(x, y)
                        end)
                        if ok then
                            for _, gui in ipairs(objects) do
                                local ancestor = gui
                                while ancestor do
                                    if ancestor:IsA("ScreenGui") then
                                        local name = string.lower(ancestor.Name)
                                        if string.find(name, "windui", 1, true)
                                            or string.find(name, "beyy", 1, true) then
                                            return true
                                        end
                                        break
                                    end
                                    ancestor = ancestor.Parent
                                end
                            end
                        end
                    end
                end
                return false
            end
            if hubWindow.Closed ~= true then
                local ok, err = pcall(function() hubWindow:Close() end)
                if not ok then
                    allStatus("Stopped: could not close menu: " .. tostring(err))
                    return false
                end
            end
            local deadline = os.clock() + 4.0
            while not hubUnloaded and not allPuzzlesCancel and os.clock() < deadline do
                if hubWindow.Closed == true and not windUIOverCrosshair() then
                    RunService.RenderStepped:Wait()
                    RunService.RenderStepped:Wait()
                    if hubWindow.Closed == true and not windUIOverCrosshair() then
                        return true
                    end
                end
                RunService.RenderStepped:Wait()
            end
            if not hubUnloaded and not allPuzzlesCancel then
                allStatus("Stopped: menu not fully hidden after 4s; Lever 1 was not attempted")
            end
            return false
        end
        local function runAllPuzzles()
            if allPuzzlesRunning then allStatus("Already running"); return end
            if hubUnloaded or puzzleControllerBusy or leverRunning or colourRunning then
                allStatus("Cannot start while another puzzle controller is active")
                return
            end
            autoRunClaimed=true
            allPuzzlesRunning = true
            allPuzzlesCancel = false
            pictureCancelled = false
            pictureAllowReposition = false

            local reopenAfter = hubWindow and hubWindow.Closed == false
            local ok, err = xpcall(function()
                if not waitForHubMenuClear() then return end
                if isNumberStageCancelled() then return end
                allStatus("1/3: Activating the three levers...")
                if not runLevers() then
                    allStatus("Stopped: lever pass incomplete; check lever status")
                    return
                end
                if isNumberStageCancelled() then return end

                pictureFinished = false
                pictureSuccess = false
                pictureCancelled = false
                if not pictureRunning then
                    task.spawn(runPicturePuzzle)
                end

                local numberFinished = false
                local numberSolved = false
                task.spawn(function()
                    local worked, result = xpcall(runNumberPuzzleInHub, function(e)
                        return tostring(e)
                    end)
                    numberSolved = worked and result == true
                    if not worked then
                        allStatus("Early number worker error: " .. tostring(result))
                    end
                    numberFinished = true
                end)
                allStatus("2/3: Number + picture started during 6s post-lever cutscene...")
                if not waitAll(6.00) then return end
                if isNumberStageCancelled() then return end

                if not numberFinished then
                    allStatus("Cutscene wait done; Number scan still running (picture continues). Waiting before Colour...")
                end
                local numberJoinDeadline = os.clock() + 120
                while not numberFinished and not isNumberStageCancelled() and os.clock() < numberJoinDeadline do
                    task.wait(0.10)
                end
                if isNumberStageCancelled() then return end
                if not numberFinished then

                    allStatus("Stopped: Number worker exceeded 120s after cutscene; Colour not started to avoid teleport conflicts")
                    allPuzzlesCancel = true
                    pictureCancelled = true
                    return
                end
                if not numberSolved then
                    allStatus("Early Number attempt not confirmed; retrying once after cutscene before Colour...")
                    numberSolved = runNumberPuzzleInHub()
                    if isNumberStageCancelled() then return end
                end
                if not numberSolved then
                    allStatus("Number not confirmed after retry; proceeding to Colour (inspect NumberSolver logs)")
                end

                allStatus("3/3: Colour pedestals + picture rotations running together...")
                if not runColourPuzzle() then
                    pictureCancelled = true
                    allStatus("Stopped: colour pass incomplete; see Colour status")
                    return
                end
                if isNumberStageCancelled() then return end

                if not numberSolved then
                    allStatus("Number still incomplete; trying it once more after Colour unlock...")
                    numberSolved = runNumberPuzzleInHub()
                    if isNumberStageCancelled() then return end
                end

                pictureAllowReposition = true
                if not pictureFinished then
                    allStatus("Colour stage finished; waiting for picture rotation confirmations...")
                end
                local joinDeadline = os.clock() + 48
                while not pictureFinished and not isNumberStageCancelled() and os.clock() < joinDeadline do
                    task.wait(0.10)
                end
                if not pictureFinished then
                    pictureCancelled = true
                    allStatus("Picture solver timed out; see Auto Picture status")
                elseif numberSolved and pictureSuccess then
                    allStatus("Finished: Number and Picture server-confirmed; Colour VIM clicks sent.")
                elseif not isNumberStageCancelled() then
                    allStatus(string.format("Incomplete: Number=%s, Picture=%s. Check individual solver logs.",
                        tostring(numberSolved), tostring(pictureSuccess)))
                end
            end, function(e) return tostring(e) end)
            if not ok then
                pictureCancelled = true
                allStatus("ERROR: " .. tostring(err))
            end
            if allPuzzlesCancel or hubUnloaded then
                allStatus("Sequence cancelled")
            end
            allPuzzlesRunning = false
            if reopenAfter and not hubUnloaded and hubWindow then
                pcall(function() hubWindow:Open() end)
            end
        end
        local function queueAutoStart()
            if autoStartWaiting or autoRunClaimed or hubUnloaded then return end
            autoStartWaiting=true
            task.spawn(function()
                local deadline=os.clock()+120
                while not hubUnloaded and not autoRunClaimed and not autoStartCancelled and autoSolveOnJoin and os.clock()<deadline do
                    if not chapter2ConfigReady then
                        allStatus("Waiting for saved config before automatic startup")
                    else
                        local ready,reason=chapter2AutoPuzzleReady(LocalPlayer,Workspace,earlyIntroPending)
                        if ready and not allPuzzlesRunning and not puzzleControllerBusy and not leverRunning and not colourRunning then
                            allStatus("Intro confirmed; waiting 0.05s before the first lever")
                            task.wait(0.05)
                            local stillReady=chapter2AutoPuzzleReady(LocalPlayer,Workspace,earlyIntroPending)
                            if stillReady and not hubUnloaded and autoSolveOnJoin and not autoStartCancelled and not autoRunClaimed
                                and not allPuzzlesRunning and not puzzleControllerBusy and not leverRunning and not colourRunning then
                                autoStartWaiting=false
                                allStatus("Intro confirmed; starting full puzzle sequence")
                                runAllPuzzles()
                                return
                            end
                        end
                        if not ready then allStatus(reason) else allStatus("Waiting for active puzzle controller") end
                    end
                    task.wait(0.1)
                end
                autoStartWaiting=false
                if not hubUnloaded and not autoRunClaimed then
                    allStatus(not autoSolveOnJoin and "Automatic startup disabled" or (autoStartCancelled and "Automatic startup cancelled" or "Startup timed out; intro or assets not ready"))
                end
            end)
        end
        Registry.Chapter2AutoSolveOnJoin=puzzleTab:Toggle({
            Title="Auto Solve Puzzles on Join",Value=true,
            Callback=function(value)
                autoSolveOnJoin=value==true
                if autoSolveOnJoin then autoStartCancelled=false;queueAutoStart() end
            end,
        })
        queueAutoStart()
        puzzleTab:Button({
            Title = "Auto Solve Puzzles",
            Desc = "Levers, Number+Picture during 6s cutscene, then Colour+Picture; verify completion.",
            Callback = function()
                if not allPuzzlesRunning then task.spawn(runAllPuzzles) end
            end,
        })
        puzzleTab:Button({
            Title = "Stop Auto Solve Puzzles",
            Desc = "Cancel any remaining stages and restore movement/camera when safe.",
            Callback = stopAllPuzzles,
        })
        puzzleTab:Button({
            Title = "Auto Number Puzzle (only)",
            Desc = "Run the integrated note finder and four-digit keypad submission without levers or colour puzzle.",
            Callback = function()
                if allPuzzlesRunning or puzzleControllerBusy or hubUnloaded then
                    allStatus("Another puzzle controller is active")
                    return
                end
                task.spawn(function()
                    if allPuzzlesRunning then return end
                    allPuzzlesRunning, allPuzzlesCancel = true, false
                    allStatus("Number puzzle only: starting code finder...")
                    local ok, result = pcall(runNumberPuzzleInHub)
                    if not ok then
                        allStatus("Number-only ERROR: " .. tostring(result))
                    elseif result then
                        allStatus("Number-only: keypad submission confirmed")
                    elseif not isNumberStageCancelled() then
                        allStatus("Number-only: keypad not confirmed; inspect NumberSolver logs")
                    end
                    allPuzzlesRunning = false
                end)
            end,
        })

    do
        local overview = overviewTab
local function cutsceneResultsVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    return ending and ending:IsA("ScreenGui") and ending.Enabled == true
end
local function shouldYieldCutsceneBypass()
    return hubUnloaded or not hubWindow.Closed or needleBusy or sharedFarmPuzzleBusy() or cutsceneResultsVisible()
end
local function setCutsceneBypassActive(_) end
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
        local SettingsTab = overviewTab
        local ConfigManager = hubWindow.ConfigManager
        local function Header(tab, title) tab:Section({ Title = title }) end
        local function Notify(title, content, duration, icon)
            pcall(function() hubNativeUI:Notify({ Title=title, Content=content, Duration=duration or 3, Icon=icon }) end)
        end
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
            if hubUnloaded or not startupConfig then chapter2ConfigReady=true; return end
            local ok, loaded, err = pcall(function() return buildConfig(startupConfig):Load() end)
            local success = ok and loaded ~= false and loaded ~= nil
            Notify("Config", success and ("Auto-loaded: " .. startupConfig)
                or ("Auto-load failed: " .. tostring(ok and err or loaded)), 3, success and "check" or "x")
            chapter2ConfigReady=true
        end)
    else
        chapter2ConfigReady=true
        SettingsTab:Paragraph({ Title = "Configs unavailable", Desc = "Saving configs requires filesystem support in your environment." })
    end
    end

    print("[BeyyHub] v103.00 " .. BEYY_CHAPTER .. " module loaded (RightControl to open)")
end
