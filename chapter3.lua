-- beyy v103.00 | Chapter3 module | PlaceId 82626725163709
local __BEYY_MODULE = "Chapter3"
local __BEYY_SCRIPT_VERSION = "103.00"
if game.PlaceId ~= 82626725163709 then
    warn("[BeyyHub] Refusing to load Chapter3 module in another place")
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

-- Native, reversible cosmetic graphics reduction. No external code or object destruction.
local function installMinimalGraphics(tab,registry)
    local world=game:GetService("Workspace")
    local lighting=game:GetService("Lighting")
    local players=game:GetService("Players")
    local enabled,alive,generation=false,true,0
    local originals=setmetatable({},{__mode="k"})
    local connections={}
    local function set(object,key,value)
        local ok,old=pcall(function()return object[key]end)
        if not ok or old==value then return end
        local saved=originals[object]
        if not saved then saved={};originals[object]=saved end
        if saved[key]==nil then saved[key]={Value=old}end
        pcall(function()object[key]=value end)
    end
    local function characterObject(object)
        for _,player in ipairs(players:GetPlayers())do
            local character=player.Character
            if character and (object==character or object:IsDescendantOf(character))then return true end
        end
        local parent=object
        while parent and parent~=world and parent~=lighting do
            if parent:IsA("Model")and parent:FindFirstChildOfClass("Humanoid")then return true end
            parent=parent.Parent
        end
        return false
    end
    local function apply(object)
        if not enabled or not alive or characterObject(object)then return end
        if object:IsA("BasePart")then
            set(object,"Material",Enum.Material.Plastic)
            set(object,"Reflectance",0)
            set(object,"CastShadow",false)
            if object:IsA("MeshPart")then
                set(object,"RenderFidelity",Enum.RenderFidelity.Performance)
                set(object,"TextureID","")
            end
        elseif object:IsA("Decal")or object:IsA("Texture")then
            set(object,"Transparency",1)
        elseif object:IsA("SpecialMesh")then
            set(object,"TextureId","")
        elseif object:IsA("ParticleEmitter")or object:IsA("Trail")or object:IsA("Beam")
            or object:IsA("Smoke")or object:IsA("Fire")or object:IsA("Sparkles")
            or object:IsA("PostEffect")or object:IsA("Light")then
            set(object,"Enabled",false)
        elseif object:IsA("Explosion")then
            set(object,"Visible",false)
        end
    end
    local function restore()
        for object,properties in pairs(originals)do
            for key,saved in pairs(properties)do pcall(function()object[key]=saved.Value end)end
        end
        table.clear(originals)
    end
    local function disconnect()
        for _,connection in ipairs(connections)do connection:Disconnect()end
        table.clear(connections)
    end
    local function toggle(on)
        if not alive or enabled==(on==true)then return end
        enabled=on==true;generation+=1
        disconnect()
        if not enabled then restore();return end
        set(lighting,"GlobalShadows",false)
        local terrain=world:FindFirstChildOfClass("Terrain")
        if terrain then
            set(terrain,"WaterWaveSize",0);set(terrain,"WaterWaveSpeed",0)
            set(terrain,"WaterReflectance",0);set(terrain,"WaterTransparency",1)
        end
        pcall(function()
            local settings=UserSettings():GetService("UserGameSettings")
            set(settings,"SavedQualityLevel",Enum.SavedQualitySetting.QualityLevel1)
        end)
        local token=generation
        -- Subscribe before scanning so streamed/new effects are included.
        for _,root in ipairs({world,lighting})do
            connections[#connections+1]=root.DescendantAdded:Connect(function(object)
                task.defer(function()
                    if token==generation and alive and enabled and object.Parent then pcall(apply,object)end
                end)
            end)
        end
        task.spawn(function()
            local started=os.clock()
            for _,root in ipairs({world,lighting})do
                for index,object in ipairs(root:GetDescendants())do
                    if not alive or not enabled or token~=generation then return end
                    pcall(apply,object)
                    if index%64==0 and os.clock()-started>=0.002 then task.wait();started=os.clock()end
                end
            end
        end)
    end
    registry.MinimalGraphics=tab:Toggle({Title="Minimal Graphics",Value=false,
        Desc="Reduce world textures, shadows and effects. Turn off to restore; characters and UI stay intact.",Callback=toggle})
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        if alive then
            alive=false;enabled=false;generation+=1;disconnect();restore()
        end
        if previous then pcall(previous)end
    end
end

local function installUniversalWinsRecorder(tab, registry, isRunning)
    local env=type(getgenv)=='function' and getgenv()or _G
    if env.BeyyWinsRecorder then env.BeyyWinsRecorder.Stop()end
    local httpService=game:GetService('HttpService')
    local winsStorage=game:GetService('ReplicatedStorage')
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
    state.StatsGeneration=tonumber(state.StatsGeneration)or 0
    local function validSeconds(value)
        return type(value)=='number'and value>0 and value<math.huge
    end
    local roundTimes={}
    local function rememberRound(id,seconds)
        if not validSeconds(seconds)or type(id)~='string'or id==''then return end
        if id==state.RoundIgnoreJob then return end
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
        local rs=winsStorage
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
            RoundAverageSeconds=average,RoundSampleCount=count,StatsGeneration=state.StatsGeneration}
        state.Pending[#state.Pending+1]=entry
        save()
        if type(appendfile)=='function'then pcall(function()appendfile(storage..'/wins_history_'..tostring(player.UserId)..'.jsonl',httpService:JSONEncode(entry)..'\n')end)end
        setStatus('Recorded +'..tostring(gain)..' win(s); total '..tostring(total))
    end
    tab:Button({Title='Reset Webhook Wins/hr & Average',Callback=function()
        if not alive or not isRunning()then return end
        -- Stage any saved-win increase first; pending reports retain their old stats.
        pcall(sample)
        local completed=completion~=nil
        for _,round in ipairs(roundTimes)do if round.Id==game.JobId then completed=true;break end end
        local ok,ownedCompletion=pcall(function()return player:GetAttribute('NeedleRoundComplete')end)
        if completed or (ok and ownedCompletion==true)then state.RoundIgnoreJob=game.JobId end
        state.SessionWins=0
        state.Started=os.time()
        state.StatsGeneration+=1
        table.clear(roundTimes)
        completion=nil
        if save()then setStatus('Webhook stats reset: 0 tracked wins; 0/100 timed rounds')
        else setStatus('Webhook stats reset for this run; could not save the reset')end
    end})
    local function formatRoundTime(seconds)
        local whole=math.floor(seconds+0.5)
        return string.format('%d:%02d',whole//60,whole%60)
    end
    local function payload(entry)
        -- Completion can arrive just after the saved-win update. Fill in its
        -- timing before delivery, and keep averages fixed for later retries.
        if (entry.StatsGeneration or 0)==state.StatsGeneration and entry.JobId==game.JobId
            and completion and os.clock()-completion.At<10 then
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
-- Shared discovery for AutoSkip and camera bypass; no input or game-state writes.
local function createSkipCandidateIndex(getGui)
    local api={}
    local pg,alive,dirty,nextRecovery=nil,true,true,0
    local objects,buttons,markedText,connections={},{},{},{}
    local function marked(text)return type(text)=="string"and text:lower():find("skip",1,true)~=nil end
    local function clear()
        for _,entry in pairs(objects)do for _,connection in ipairs(entry.Connections)do connection:Disconnect()end end
        for _,connection in ipairs(connections)do connection:Disconnect()end
        table.clear(objects);table.clear(buttons);table.clear(markedText);table.clear(connections)
        dirty=true;pg=nil
    end
    local function add(object)
        if objects[object]then return end
        local entry={Object=object,Connections={},NameMarked=marked(object.Name)}
        objects[object]=entry
        if object:IsA("GuiButton")then buttons[#buttons+1]=entry end
        local function nameChanged()
            local current=marked(object.Name)
            if current~=entry.NameMarked then entry.NameMarked=current;dirty=true end
        end
        entry.Connections[#entry.Connections+1]=object:GetPropertyChangedSignal("Name"):Connect(nameChanged)
        entry.Connections[#entry.Connections+1]=object.AncestryChanged:Connect(function()dirty=true end)
        if object:IsA("TextLabel")or object:IsA("TextButton")then
            local function textChanged()
                local current=marked(object.Text)
                if current~=entry.TextMarked then entry.TextMarked=current;markedText[object]=current or nil;dirty=true end
            end
            textChanged()
            entry.Connections[#entry.Connections+1]=object:GetPropertyChangedSignal("Text"):Connect(textChanged)
        end
        dirty=true
    end
    local function remove(object)
        local entry=objects[object]
        if not entry then return end
        for _,connection in ipairs(entry.Connections)do connection:Disconnect()end
        objects[object]=nil;markedText[object]=nil;dirty=true
    end
    local function scan()
        if not pg then return end
        for _,object in ipairs(pg:GetDescendants())do add(object)end
        for object in pairs(objects)do if not object:IsDescendantOf(pg)then remove(object)end end
        nextRecovery=os.clock()+4
    end
    local function refresh()
        if not alive then return end
        local current=getGui()
        if current~=pg then
            clear();pg=current
            if pg then
                connections[1]=pg.DescendantAdded:Connect(add)
                connections[2]=pg.DescendantRemoving:Connect(remove)
                scan()
            end
        end
        if not pg or not dirty then return end
        dirty=false
        local compact={}
        for _,entry in ipairs(buttons)do
            local object=entry.Object
            if objects[object]==entry and object:IsDescendantOf(pg)then
                compact[#compact+1]=entry
                entry.Direct=entry.NameMarked or entry.TextMarked or false
                entry.Context=entry.Direct
                local ancestor,hops=object.Parent,0
                while ancestor and ancestor~=pg and hops<5 do
                    local parentEntry=objects[ancestor]
                    if parentEntry and parentEntry.NameMarked then entry.Context=true end
                    ancestor=ancestor.Parent;hops+=1
                end
            end
        end
        buttons=compact
        for object in pairs(markedText)do
            local ancestor=object.Parent
            local nearest=true
            while ancestor and ancestor~=pg do
                local entry=objects[ancestor]
                if entry and ancestor:IsA("GuiButton")then
                    entry.Context=true
                    if nearest and object:IsA("TextLabel")then entry.Direct=true end
                    nearest=false
                end
                ancestor=ancestor.Parent
            end
        end
    end
    local function visible(object)
        local parent=object
        while parent and parent~=pg do
            if parent:IsA("GuiObject")and not parent.Visible then return false end
            if parent:IsA("ScreenGui")and not parent.Enabled then return false end
            parent=parent.Parent
        end
        return parent==pg
    end
    function api.Contains(object,context)
        refresh()
        local entry=objects[object]
        return alive and pg~=nil and entry~=nil and object:IsDescendantOf(pg)
            and (context and entry.Context or (not context and entry.Direct))and visible(object)or false
    end
    function api.Find(context,predicate)
        refresh()
        if not alive or not pg then return nil end
        for attempt=1,2 do
            for _,entry in ipairs(buttons)do
                local object=entry.Object
                if (context and entry.Context or (not context and entry.Direct))and visible(object)
                    and (not predicate or predicate(object))then return object end
            end
            if attempt==1 and os.clock()>=nextRecovery then scan();refresh()else break end
        end
    end
    function api.Stop()alive=false;clear()end
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()api.Stop();if previous then previous()end end
    return api
end

-- Idle waits wake on toggles/state changes, with a one-second recovery timer.
-- Active intervals and purchase-confirmation deadlines are supplied by callers.
local function createWorkerWake(player)
    local api={}
    local alive=true
    local waiters,connections={},{}
    local cashFolder,cashValue,cashConnections=nil,nil,{}
    local function finish(token,cancelTimer)
        if token.Done then return end
        token.Done=true;waiters[token]=nil
        if cancelTimer and token.Timer then pcall(task.cancel,token.Timer)end
        task.defer(token.Thread)
    end
    function api.Wake(key)
        for token in pairs(waiters)do
            if key==nil or token.Key==key or(key=="upgrades"and token.Key=="upgrades-cash")then finish(token,true)end
        end
    end
    local function syncCash()
        local folder=player:FindFirstChild("leaderstats")
        local value=folder and folder:FindFirstChild("Cash")
        if folder==cashFolder and value==cashValue then return end
        for _,connection in ipairs(cashConnections)do connection:Disconnect()end
        table.clear(cashConnections);cashFolder,cashValue=folder,value
        if folder then
            cashConnections[#cashConnections+1]=folder.ChildAdded:Connect(function()syncCash();api.Wake("upgrades-cash")end)
            cashConnections[#cashConnections+1]=folder.ChildRemoved:Connect(function()syncCash();api.Wake("upgrades-cash")end)
        end
        if value then cashConnections[#cashConnections+1]=value:GetPropertyChangedSignal("Value"):Connect(function()api.Wake("upgrades-cash")end)end
    end
    connections[1]=player.AttributeChanged:Connect(function(name)
        if name:sub(1,10)=="HayUpgrade"or name=="UpgradeCostMultiplier"or name=="PitchforkUpgradeCostMultiplier"then api.Wake("upgrades")end
    end)
    connections[2]=player.ChildAdded:Connect(function(child)if child.Name=="leaderstats"then syncCash();api.Wake("upgrades")end end)
    connections[3]=player.ChildRemoved:Connect(function(child)if child==cashFolder then syncCash();api.Wake("upgrades")end end)
    function api.Wait(interval,idle,key)
        if not alive then return end
        if not idle then task.wait(interval);return end
        if key=="upgrades"or key=="upgrades-cash"then syncCash()end
        local token={Thread=coroutine.running(),Key=key}
        waiters[token]=true
        token.Timer=task.delay(1,function()finish(token,false)end)
        coroutine.yield()
    end
    function api.Stop()
        if not alive then return end
        alive=false
        for _,connection in ipairs(connections)do connection:Disconnect()end
        for _,connection in ipairs(cashConnections)do connection:Disconnect()end
        for token in pairs(waiters)do finish(token,true)end
        table.clear(connections);table.clear(cashConnections)
        cashFolder,cashValue=nil,nil
    end
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()api.Stop();if previous then previous()end end
    return api
end

-- Optional bounded local feature traces. Observers never send input or gameplay requests.
local function createFeatureDiagnostics(options)
    local api={Probe=nil,Remote=nil}
    local enabled,alive,pumping=false,true,false
    local ring,head,count,total,dropped={},1,0,0,0
    local dirty,nextSave,lastState=false,0,nil
    local errors,lastStatus=0,"No observation yet"
    local counters,statuses,connections={},{},{}
    local feedback,feedbackConnection=nil,nil
    local nextOtherFeedback=0
    local path=CACHE_FOLDER.."/"..options.File..".json"
    local http=game:GetService("HttpService")
    local function value(item,depth,seen)
        local kind=typeof(item)
        if kind=="nil"or kind=="boolean"or kind=="string"then return kind=="string"and item:sub(1,1000)or item end
        if kind=="number"then return item==item and math.abs(item)<math.huge and item or tostring(item)end
        if kind=="Vector3"then return {X=item.X,Y=item.Y,Z=item.Z}end
        if kind=="CFrame"then return value(item.Position)end
        if kind=="Instance"then return {Name=item.Name,Class=item.ClassName}end
        if kind~="table"then return tostring(item)end
        depth=depth or 0;seen=seen or {}
        if depth>=5 or seen[item]then return "<bounded>"end
        seen[item]=true
        local output,n={},0
        for key,child in pairs(item)do
            n+=1;if n>40 then break end
            if type(key)=="number"or type(key)=="string"then output[key]=value(child,depth+1,seen)end
        end
        seen[item]=nil;return output
    end
    function api.Enabled()return alive and enabled and options.Alive()end
    function api.Record(kind,build)
        if not api.Enabled()then return end
        local ok,data=pcall(function()return value(type(build)=="function"and build()or build or {})end)
        if not ok then errors+=1;return end
        total+=1;counters[kind]=(counters[kind]or 0)+1
        local event={Sequence=total,At=os.clock(),Kind=kind,Data=data}
        if count<256 then ring[(head+count-1)%256+1]=event;count+=1
        else ring[head]=event;head=head%256+1;dropped+=1 end
        dirty=true
    end
    function api.Status(stage,message)
        if not api.Enabled()then return end
        if statuses[stage]==message then return end
        statuses[stage]=message;lastStatus=stage..": "..tostring(message)
        api.Record("Status",{Stage=stage,Message=message})
    end
    function api.Snapshot()
        local ok,current=pcall(function()
            local character=options.Player.Character
            local root=character and character:FindFirstChild("HumanoidRootPart")
            local flags={}
            for _,key in ipairs({"NeedleOwned","HasCarKey","CarryingUfoPart","NeedleInputLocked","CutsceneActive","HintViewerOpen",
                "BossHeld","BossRagdolled","BossRagdollRecovering","BossKnockdownCamera","BossStunnedUntil",
                "PumpkinSnared","PumpkinGrabbed","PumpkinPulled","BossEquippedSlot","VacuumHeat","VacuumActive"})do flags[key]=options.Player:GetAttribute(key)end
            return value({MenuClosed=options.Menu(),RootPresent=root~=nil,RootAnchored=root and root.Anchored,
                Position=root and root.Position,Player=flags,Feature=api.Probe and api.Probe()or {}})
        end)
        if not ok then errors+=1;return {SnapshotError=tostring(current)}end
        return current
    end
    local status=options.Tab:Paragraph({Title=options.Title.." Status",Desc="Off; no diagnostic capture"})
    local function export(manual)
        local events={};for i=1,count do events[i]=ring[(head+i-2)%256+1]end
        local ok,json=pcall(function()return http:JSONEncode({Schema=1,Module=__BEYY_MODULE,Feature=options.Title,
            PlaceId=game.PlaceId,JobId=game.JobId,ExportedAt=os.time(),Enabled=api.Enabled(),Capacity=256,
            TotalEvents=total,DroppedEvents=dropped,DiagnosticErrors=errors,Counters=counters,Events=events,
            Current=api.Snapshot(),Interpretation="Requests are attempts. Observed feedback is not automatically credited to this automation."})end)
        if not ok then errors+=1;return end
        local written,result=pcall(options.Write,path,json)
        if written and result then dirty=false end
        if manual and type(setclipboard)=="function"then pcall(setclipboard,json)end
    end
    function api.Export()export(true)end
    local function disconnect()
        for _,connection in ipairs(connections)do connection:Disconnect()end
        table.clear(connections)
        if feedbackConnection then feedbackConnection:Disconnect()end
        feedback,feedbackConnection=nil,nil
    end
    local function syncRemote()
        local remote=api.Remote and api.Remote()
        if remote==feedback then return end
        if feedbackConnection then feedbackConnection:Disconnect()end
        feedback,feedbackConnection=remote,nil
        if remote and remote:IsA("RemoteEvent")then
            feedbackConnection=remote.OnClientEvent:Connect(function(...)
                local args=table.pack(...)
                local argumentCount=args.n;args.n=nil
                if args[1]=="Hit"and args[2]~=options.Player.UserId then
                    if os.clock()<nextOtherFeedback then counters.SuppressedOtherFeedback=(counters.SuppressedOtherFeedback or 0)+1;return end
                    nextOtherFeedback=os.clock()+1
                end
                api.Record("ObservedServerFeedback",function()return {ArgumentCount=argumentCount,Arguments=args,Attribution="Observed only; inspect sender/tool/grade before attributing a hit"}end)
            end)
        end
    end
    local function pump()
        if pumping then return end
        pumping=true
        task.spawn(function()
            while api.Enabled()do
                local ok=pcall(function()
                    syncRemote()
                    local current=api.Snapshot()
                    local key=http:JSONEncode(current.Feature or {})
                    if key~=lastState then lastState=key;api.Record("StateChanged",current)end
                    if dirty and os.clock()>=nextSave then nextSave=os.clock()+5;export(false)end
                    status:SetDesc("Capturing | "..count.."/256 events | "..dropped.." overwritten | "..lastStatus)
                end)
                if not ok then errors+=1 end
                task.wait(0.5)
            end
            pumping=false
        end)
    end
    options.Registry[options.Key]=options.Tab:Toggle({Title=options.Title,Value=false,Callback=function(on)
        if not alive then return end
        enabled=on==true
        if enabled then
            disconnect();lastState=nil;table.clear(statuses);nextSave=os.clock()+5
            connections[1]=options.Player.AttributeChanged:Connect(function(key)
                if key:find("Boss",1,true)or key:find("Needle",1,true)or key=="HasCarKey"or key=="CarryingUfoPart"or key=="CutsceneActive"then
                    api.Record("PlayerAttribute",function()return {Attribute=key,Value=options.Player:GetAttribute(key)}end)
                end
            end)
            if options.Player.OnTeleport then
                connections[#connections+1]=options.Player.OnTeleport:Connect(function(state)
                    api.Record("TeleportObserved",{State=tostring(state)})
                    if dirty then export(false)end
                end)
            end
            api.Record("DiagnosticsEnabled",api.Snapshot);pump()
        else disconnect();if dirty then export(false)end;status:SetDesc("Off | "..count.." recorded events")end
    end})
    options.Tab:Button({Title="Export "..options.Title,Callback=api.Export})
    function api.Stop()
        if not alive then return end
        disconnect();if dirty then export(false)end
        alive=false;enabled=false;api.Probe=nil;api.Remote=nil
    end
    local previous=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()api.Stop();if previous then previous()end end
    return api
end

local function installTntObservation(diagnostics, probe)
    local retry,block,lastBlock,lastSample,lastAim=nil,nil,nil,0,nil
    local function snapshot()
        if not block then return nil end
        return {Reason=block.Reason,ObservedAt=block.ObservedAt,PredictedReadyAt=block.ReadyAt,
            BlockedAfterCooldownSeconds=os.clock()-block.ObservedAt,Active=true}
    end
    function diagnostics.BindGate(value)retry=value end
    function diagnostics.MeasureAim(stage,fn,...)
        local started=os.clock()
        diagnostics.Status("TNT",stage)
        local result=table.pack(pcall(fn,...))
        if not result[1]then diagnostics.Record("WorkerError",{Stage=stage,Error=tostring(result[2])});error(result[2],0)end
        lastAim={Stage=stage,Seconds=os.clock()-started,TargetFound=result[2]~=nil,Target=result[4],At=os.clock()}
        diagnostics.Record("TargetTiming",lastAim)
        return table.unpack(result,2,result.n)
    end
    diagnostics.Probe=function()
        local data=probe()
        local state=retry and retry.DiagnosticSnapshot()or nil
        data.Gate=state
        local now=os.clock()
        local readyAt=state and state.PredictedReadyAt
        local reason=data.BlockReason
        if not reason and lastAim and not lastAim.TargetFound then reason="Waiting for reachable hay / valid throw trajectory"end
        data.BlockReason=reason;data.LastTargetTiming=lastAim
        local overdue=type(readyAt)=="number"and now>=readyAt
        if not diagnostics.Enabled()then block=nil;lastBlock=nil;lastAim=nil
        else
            if block and (not reason or not overdue or reason~=block.Reason or readyAt~=block.ReadyAt)then
                local ended=snapshot();ended.Active=false;ended.EndedAt=now
                ended.EndReason=not reason and "Block cleared"or not overdue and "Cooldown prediction moved"or "Block reason changed"
                lastBlock=ended;diagnostics.Record("CooldownBlockEnded",ended);block=nil
            end
            if reason and overdue then
                if not block then
                    block={Reason=reason,ObservedAt=now,ReadyAt=readyAt};lastSample=now
                    diagnostics.Record("CooldownBlockStarted",snapshot())
                elseif now-lastSample>=1 then lastSample=now;diagnostics.Record("CooldownBlockOngoing",snapshot())end
            end
        end
        data.CooldownBlocks={Current=snapshot(),LastCompleted=lastBlock}
        data.Observation="Block durations start at first enabled sample after predicted cooldown; sampled every 0.5 seconds"
        return data
    end
end

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
    local slots, positions, freeSlots, connections = {}, {}, {}, table.create(2)
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
    local function compactSlots()
        local live = slotCount - #freeSlots
        if #freeSlots < 64 or #freeSlots <= live / 2 then return end
        local dense, newPositions = table.create(live), {}
        for index = 1, slotCount do
            local object = slots[index]
            if object then dense[#dense+1] = object; newPositions[object] = #dense end
        end
        slots, positions, freeSlots, slotCount = dense, newPositions, {}, #dense
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
        compactSlots()
        local scanSlots, scanSlotCount = slots, slotCount
        local index=1
        while index<=scanSlotCount do
            if not alive or folder~=scanFolder or not scanFolder.Parent then return nil end
            local obj=scanSlots[index]
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
-- Shared hay membership and spatial candidates; snapshots stay immutable across yields.
local haySearch = (function()
    local current, ready, alive = nil, false, true
    local records, cells, moving, connections = {}, {}, {}, {}
    local serial, revision, snapshotRevision, snapshot = 0, 0, -1, nil
    local orderSlots = {}
    local holes = 0
    local CELL = 16
    local function cellKey(position)
        return math.floor(position.X / CELL)..":"..math.floor(position.Z / CELL)
    end
    local function detach(record)
        local bucket = record.Cell and cells[record.Cell]
        if bucket then
            bucket[record] = nil
            if next(bucket) == nil then cells[record.Cell] = nil end
        end
        record.Cell = nil
    end
    local function move(record)
        -- Physics movement need not emit Position signals. Scan unanchored parts live.
        if record.Object.Anchored == false then
            detach(record); moving[record] = true; return
        end
        moving[record] = nil
        local key = cellKey(record.Object.Position)
        if key == record.Cell then return end
        detach(record)
        local bucket = cells[key]
        if not bucket then bucket = {}; cells[key] = bucket end
        bucket[record] = true; record.Cell = key
    end
    local function compactOrder()
        local dense = {}
        for _, record in ipairs(orderSlots) do
            if record then
                dense[#dense + 1] = record; record.Slot = #dense
            end
        end
        orderSlots, holes = dense, 0
    end
    local function remove(object)
        local record = records[object]
        if not record then return end
        records[object] = nil; detach(record); moving[record] = nil
        if record.Connection then record.Connection:Disconnect() end
        if record.AnchoredConnection then record.AnchoredConnection:Disconnect() end
        orderSlots[record.Slot] = false; holes += 1
        record.Object, record.Connection, record.AnchoredConnection = nil, nil, nil
        while #orderSlots > 0 and orderSlots[#orderSlots] == false do
            orderSlots[#orderSlots] = nil; holes -= 1
        end
        if holes >= 64 and holes > (#orderSlots - holes) / 2 then compactOrder() end
        revision += 1; snapshot = nil
    end
    local function clear()
        ready = false
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
        for _, record in pairs(records) do
            if record.Connection then record.Connection:Disconnect() end
            if record.AnchoredConnection then record.AnchoredConnection:Disconnect() end
        end
        records, cells, moving = {}, {}, {}
        orderSlots, holes = {}, 0
        snapshot, snapshotRevision, serial = nil, -1, 0
        revision += 1
    end
    local function add(object)
        if records[object] or object.Parent ~= current then return end
        serial += 1
        local record = {Object = object, Order = serial, Slot = #orderSlots + 1}
        records[object] = record
        orderSlots[#orderSlots + 1] = record
        if object:IsA("BasePart") then
            move(record)
            record.Connection = object:GetPropertyChangedSignal("Position"):Connect(function()
                if records[object] == record and object.Parent == current then move(record) end
            end)
            record.AnchoredConnection = object:GetPropertyChangedSignal("Anchored"):Connect(function()
                if records[object] == record and object.Parent == current then move(record) end
            end)
        end
        revision += 1; snapshot = nil
    end
    local function watch(folder)
        if not alive then return false end
        if not folder or not folder.Parent then
            if current then clear(); current = nil end
            return false
        end
        if current == folder then return ready end
        clear(); current = folder
        if not folder then return false end
        local watched = folder
        connections[1] = folder.ChildAdded:Connect(add)
        connections[2] = folder.ChildRemoved:Connect(remove)
        connections[3] = folder.AncestryChanged:Connect(function()
            if current == watched and not watched.Parent then clear(); current = nil end
        end)
        local started = os.clock()
        for index, object in ipairs(folder:GetChildren()) do
            if not alive or current ~= watched then return false end
            add(object)
            if index % 64 == 0 and os.clock() - started >= 0.001 then
                task.wait(); started = os.clock()
            end
        end
        if not alive or current ~= watched or not watched.Parent then return false end
        ready = true
        return true
    end
    local api = {}
    function api.Snapshot(folder)
        if not watch(folder) then return nil end
        if snapshot and snapshotRevision == revision then return snapshot end
        if holes > 0 then compactOrder() end
        local result = table.create(#orderSlots)
        for index, record in ipairs(orderSlots) do result[index] = record.Object end
        snapshot, snapshotRevision = result, revision
        return result
    end
    function api.Nearby(folder, center, radius, height)
        if not watch(folder) then return nil end
        -- Large or unusual upgrade values fall back to the original exact caller filter.
        if type(radius) ~= "number" or radius ~= radius or radius < 0 or radius == math.huge then
            return api.Snapshot(folder)
        end
        local minX, maxX = math.floor((center.X-radius)/CELL), math.floor((center.X+radius)/CELL)
        local minZ, maxZ = math.floor((center.Z-radius)/CELL), math.floor((center.Z+radius)/CELL)
        if (maxX-minX+1)*(maxZ-minZ+1) > 256 then return api.Snapshot(folder) end
        local ordered = {}
        local function include(record)
            local object = record.Object
            if object.Parent ~= folder then return end
            local p = object.Position
            local dx, dz = p.X - center.X, p.Z - center.Z
            if dx * dx + dz * dz <= radius * radius and math.abs(p.Y - center.Y) <= height then
                ordered[#ordered + 1] = record
            end
        end
        for x = minX, maxX do
            for z = minZ, maxZ do
                local bucket = cells[x..":"..z]
                if bucket then
                    for record in pairs(bucket) do
                        include(record)
                    end
                end
            end
        end
        for record in pairs(moving) do include(record) end
        table.sort(ordered, function(a, b) return a.Order < b.Order end)
        local result = table.create(#ordered)
        for index, record in ipairs(ordered) do result[index] = record.Object end
        return result
    end
    function api.Stop()
        alive = false; clear(); current = nil
    end
    local previous = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        api.Stop()
        if previous then pcall(previous) end
    end
    return api
end)()

local function budgetedFolderChildren(folder,isAllowed,descendants,nearCenter,nearRadius)
    local children
    if not descendants and folder.Name == "HaystackClient" then
        if nearCenter then children = haySearch.Nearby(folder,nearCenter,nearRadius,nearRadius)
        else children = haySearch.Snapshot(folder) end
    end
    children = children or (descendants and folder:GetDescendants() or folder:GetChildren())
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

local function aimHayTnt(world,config,root,isAllowed,preferred)
    if not root or not root.Parent or not isAllowed() then return nil end
    local folder=world:FindFirstChild("HaystackClient")
    if not folder then return nil end
    local function valid(part)
        if not part or part.Parent~=folder or not part:IsA("BasePart") or part:GetAttribute("HayId")==nil then return false end
        local delta=part.Position-root.Position
        return delta.X*delta.X+delta.Z*delta.Z>9
    end
    local hay=valid(preferred) and preferred or nil
    if not hay then
        local best=math.huge
        local position=root.Position
        for _,part in budgetedFolderChildren(folder,isAllowed) do
            if valid(part) then
                local delta=part.Position-position
                local score=delta:Dot(delta)
                if score<best then best=score;hay=part end
            end
        end
    end
    -- The scan may yield. Use the current character and target positions afterward.
    if not root.Parent or not isAllowed() or not valid(hay) then return nil end
    local target=hay.Position
    local origin=root.Position+Vector3.new(0,1.5,0)
    local toward=target-origin
    local planar=Vector3.new(toward.X,0,toward.Z)
    if planar.Magnitude<=3 then return nil end
    -- Put the projectile outside the avatar, on the side facing the hay.
    origin+=planar.Unit*2.5
    local displacement=target-origin
    if displacement.Magnitude<0.1 then return nil end
    local minSpeed=tonumber(config and config.TNT_MIN_THROW_SPEED)
    local maxSpeed=tonumber(config and config.TNT_MAX_THROW_SPEED)
    local fuse=tonumber(config and config.TNT_FUSE_TIME) or 2.9
    if not minSpeed or not maxSpeed or minSpeed<0 or maxSpeed<minSpeed then return nil end
    local up=math.abs(displacement.Unit:Dot(Vector3.yAxis))>0.97 and Vector3.zAxis or Vector3.yAxis
    local from=CFrame.lookAt(origin,target,up)
    -- Earliest feasible trajectory within the game's configured throw-speed limits.
    for index=4,60 do
        local flight=index*0.025
        if flight>=fuse-0.15 then break end
        local velocity=displacement/flight+Vector3.new(0,world.Gravity*flight*0.5,0)
        local speed=velocity.Magnitude
        if speed>=minSpeed and speed<=maxSpeed then return from,velocity,hay,flight end
    end
    return nil
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
    local idle,waitKey=true,"upgrades"
    local tracks = {
        {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
        {"UpgVacRuntime","VacuumRuntime"},
        {"UpgTntPower","TntPower"},{"UpgTntLuck","TntLuck"},
        {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
        {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
        {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
        {"UpgTntCooldown","TntCooldown"},
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
        idle,waitKey=true,"upgrades"
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
            idle=false
            if level(pending.Name)~=pending.Level or not options.State[pending.Flag] then pending=nil
            elseif os.clock()<pending.Until then status("Waiting for "..pending.Name.." purchase confirmation"); return
            else
                status("Server did not confirm "..pending.Name.."; retrying")
                pending=nil
            end
        end
        local cash=tonumber(options.Cash()) or 0
        local selected, available, vacuum, power, earlyTnt, lateTnt=0,{},nil,nil,nil,nil
        for _,entry in ipairs(tracks) do
            if options.State[entry[1]] then
                selected+=1
                local track=config.UPGRADE_TRACKS[entry[2]]
                local current=level(entry[2])
                local nextLevel=track and track.Levels and track.Levels[current+1]
                local price=nextLevel and cost(entry[2],nextLevel)
                if price then
                    local target={Flag=entry[1],Name=entry[2],Level=current,Cost=price}
                    if entry[2]=="TntCooldown" then
                        -- Tracks start at L1: two purchases reach L3.
                        if current<3 then earlyTnt=target else lateTnt=target end
                    else
                        available[#available+1]=target
                    end
                    if entry[2]=="VacuumPower" then power=target end
                    if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                end
            end
        end
        if selected==0 then status("No cash upgrades enabled"); return end
        if #available==0 and not earlyTnt and not lateTnt then status("Selected cash upgrades are maxed or unavailable"); return end
        local target
        if earlyTnt then
            if cash<earlyTnt.Cost then waitKey="upgrades-cash";status(string.format("Saving for TntCooldown: $%.2f / $%.2f",cash,earlyTnt.Cost)); return end
            target=earlyTnt
        elseif power then
            if cash<power.Cost then waitKey="upgrades-cash";status(string.format("Saving for VacuumPower: $%.2f / $%.2f",cash,power.Cost)); return end
            target=power
        elseif vacuum and cash>=vacuum.Cost*0.75 then
            if cash<vacuum.Cost then waitKey="upgrades-cash";status(string.format("Saving for %s: $%.2f / $%.2f",vacuum.Name,cash,vacuum.Cost)); return end
            target=vacuum
        else
            for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
            -- Remaining TNT speed levels wait until all other enabled tracks finish.
            if #available==0 and lateTnt and cash>=lateTnt.Cost then target=lateTnt end
        end
        if not target then
            waitKey="upgrades-cash"
            local cheapest=available[1] or lateTnt
            for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
            status(string.format("Waiting for cash: $%.2f / $%.2f (%s)",cash,cheapest.Cost,cheapest.Name)); return
        end
        idle=false
        remote:FireServer(target.Name)
        pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Until=os.clock()+0.25}
        status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
    end
    return {IsIdle=function()return idle end,WaitKey=function()return waitKey end,Tick=function()
        local ok,err=pcall(tick)
        if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
    end}
end


local function createTntRetryGate(getRemote, getCooldown, getLightTime, diagnostics)
    local startupReadyAt=os.clock()+1.5 -- One-time startup delay; never wait on a lit fuse.
    local lastLitAt
    local remote, connection
    local alive, nextLightAt, phase, expiresAt, throwReadyAt = true, 0, nil, 0, 0
    local requestId,requestAt,ackAt=0,nil,nil
    local function record(kind,build)
        if diagnostics then pcall(diagnostics.Record,"Gate:"..kind,build)end
    end
    local function status(message)
        if diagnostics then pcall(diagnostics.Status,"TNT",message)end
    end
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
            remote=current; phase=nil; nextLightAt=0; lastLitAt=nil
            record("RemoteBound",function()return {Remote=current.Name}end)
            connection=remote.OnClientEvent:Connect(function(action,value)
                local now=os.clock()
                local waiting=phase=="waiting"
                record("ServerReply",function()return {Action=action,Value=value,RequestId=requestId,
                    MatchedWaiting=waiting,ReplySeconds=waiting and requestAt and now-requestAt or nil,Phase=phase}end)
                if action=="denied" then
                    local remaining=tonumber(value)
                    if not remaining or remaining~=remaining or remaining<0 or remaining==math.huge then remaining=1 end
                    lastLitAt=nil -- A server denial overrides predicted upgrade savings.
                    nextLightAt=now+remaining+0.05
                    phase=nil
                    record("Denied",function()return {RequestId=requestId,ServerRemaining=remaining,RetryAt=nextLightAt}end)
                    status("Server denied TNT; waiting for retry deadline")
                elseif action=="lit" then
                    lastLitAt=now
                    nextLightAt=now+cooldown()+0.05
                    if phase=="waiting" then
                        ackAt=now
                        phase="lit"
                        local fuse=tonumber(value)
                        expiresAt=now+((fuse and fuse>0 and fuse<math.huge) and fuse or 2.9)
                        local duration=tonumber(getLightTime and getLightTime())
                        if not duration or duration~=duration or duration<0 or duration==math.huge then duration=0.48 end
                        throwReadyAt=now+duration
                        record("LightingAcknowledged",function()return {RequestId=requestId,AcknowledgementSeconds=requestAt and now-requestAt,
                            CooldownSeconds=cooldown(),LightingSeconds=duration,ThrowReadyAt=throwReadyAt,FuseExpiresAt=expiresAt}end)
                        status("Lighting acknowledged; waiting for lighting duration")
                    end
                end
            end)
        end
        return true
    end
    local gate={}
    local function deadline()
        -- An upgrade can shorten the cooldown after a light request was acknowledged.
        if lastLitAt then nextLightAt=math.min(nextLightAt,lastLitAt+cooldown()+0.05) end
        return math.max(startupReadyAt,nextLightAt)
    end
    function gate.Remaining() return math.max(0,deadline()-os.clock()) end
    -- Snapshot is observational: do not advance or shorten the retry deadline here.
    function gate.DiagnosticSnapshot()
        local predicted=lastLitAt and math.min(nextLightAt,lastLitAt+cooldown()+0.05)or nextLightAt
        return {Phase=phase or "idle",RequestId=requestId,RequestAt=requestAt,AcknowledgedAt=ackAt,
            PredictedReadyAt=math.max(startupReadyAt,predicted),StartupReadyAt=startupReadyAt,
            ReservedRetryAt=nextLightAt,ThrowReadyAt=throwReadyAt,FuseExpiresAt=expiresAt,
            CooldownAttribute=getCooldown(),EffectiveCooldown=cooldown(),ConfiguredLightTime=getLightTime and getLightTime(),
            Clock="Client os.clock; cooldown is a prediction, not the game's displayed timer"}
    end
    function gate.Ready() return bind() and os.clock()>=deadline() end
    function gate.WaitInterval()
        local remaining=gate.Remaining()
        return remaining>0 and math.clamp(remaining,0.03,0.25) or 0.1
    end
    function gate.Light()
        if not gate.Ready() then return false end
        lastLitAt=nil -- Lost acknowledgements retain their reserved retry deadline.
        phase="waiting"
        requestId+=1;requestAt=os.clock();ackAt=nil
        nextLightAt=os.clock()+cooldown()+0.05 -- Lost acknowledgements must not cause rapid retries.
        record("LightRequest",gate.DiagnosticSnapshot)
        status("Waiting for server lighting acknowledgement")
        local ok=pcall(remote.FireServer,remote,"light")
        if not ok then
            phase=nil;nextLightAt=os.clock()+1
            record("LightSendFailed",gate.DiagnosticSnapshot);status("Light request failed locally")
            return false
        end
        local deadline=os.clock()+2
        while alive and phase=="waiting" and os.clock()<deadline do task.wait(0.03) end
        if not alive or phase~="lit" then
            record(phase=="waiting"and "AcknowledgementTimeout"or "LightingAborted",gate.DiagnosticSnapshot)
            phase=nil;return false
        end
        -- A lighting acknowledgement starts the fuse; it is not permission to throw yet.
        local remaining=throwReadyAt-os.clock()
        if remaining>0 then task.wait(remaining) end
        record("LightingWaitFinished",function()return {RequestId=requestId,Ready=alive and phase=="lit"and os.clock()<expiresAt,
            SinceAcknowledgementSeconds=ackAt and os.clock()-ackAt,ThrowReadyAt=throwReadyAt,FuseRemaining=expiresAt-os.clock()}end)
        return alive and phase=="lit" and os.clock()<expiresAt
    end
    function gate.Throw(...)
        if not alive or phase~="lit" or os.clock()<throwReadyAt or os.clock()>=expiresAt then
            record("ThrowRejectedLocally",gate.DiagnosticSnapshot);return false
        end
        phase=nil -- Exactly one throw for a confirmed lighting request.
        local ok,result=pcall(remote.FireServer,remote,"throw",...)
        record("ThrowRequest",function()return {RequestId=requestId,Sent=ok,Error=not ok and tostring(result)or nil,
            SinceLightRequestSeconds=requestAt and os.clock()-requestAt,SinceAcknowledgementSeconds=ackAt and os.clock()-ackAt,
            LightingDeadlineOverrunSeconds=os.clock()-throwReadyAt,FuseRemaining=expiresAt-os.clock(),
            Interpretation="Sent means local FireServer succeeded, not server acceptance or a hit"}end)
        status(ok and "Throw request sent"or "Throw request failed locally")
        return ok,result
    end
    function gate.Stop()
        record("Stopped",gate.DiagnosticSnapshot)
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

-- Instrument the existing hay TNT sequence without changing its waits or targeting.

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
    -- Runtime efficiency pass: private caches only.
    local UI = {}
    local players = game:GetService("Players")
    local newInstance = Instance.new
    local input = game:GetService("UserInputService")
    local run = game:GetService("RunService")
    local http = game:GetService("HttpService")
    local colors = {bg=Color3.fromRGB(20,22,27), row=Color3.fromRGB(32,35,42), text=Color3.fromRGB(231,234,240), accent=Color3.fromRGB(58,104,153)}
    local function node(class, parent, props)
        local obj = newInstance(class)
        if props then for k,v in pairs(props) do obj[k]=v end end
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
        local parent=players.LocalPlayer:WaitForChild("PlayerGui")
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

    local DiagnosticsTab = hubWindow:Tab({ Title = "Diagnostics", Icon = "activity" })
    local Registry = {}
    local sharedSkipIndex=createSkipCandidateIndex(function()return game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")end)
local workerWake=createWorkerWake(game:GetService("Players").LocalPlayer)

    local overviewTab = hubWindow:Tab({ Title = "Overview & Settings", Icon = "house" })
    installAntiIdle(overviewTab, Registry, function() return not hubUnloaded end)
    installMinimalGraphics(overviewTab, Registry)
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

    local bossToolsBusy = function() return false end
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
        AutoSolveRanchPuzzles=true, AutoGrabAttachUfoParts=false,
        AutoBossFight=false, AutoBossBodyHits=true, AutoBossGrabEscape=true, AutoBossFinish=true, BossDiagnostics=false,
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
    local bossFunctionsDiagnostics=createFeatureDiagnostics({Tab=DiagnosticsTab,Registry=Registry,Title="Boss Function Diagnostics",Key="BossFunctionDiagnostics",File="chapter3_boss_functions_diagnostics",Player=LocalPlayer,Alive=function()return not hubUnloaded end,Menu=function()return hubWindow.Closed end,Write=safeWrite})

    local needleTab = farmingSection:Tab({ Title = "Needle", Icon = "search" })
    local inventorySection = hubWindow:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
    local shopTab = inventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
    local upgradesTab = inventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
    local function farmToggle(tab, key, title, desc)
        local element = tab:Toggle({
            Title=title, Desc=desc, Value=sharedFarmState[key],
            Callback=function(enabled)
                sharedFarmState[key] = enabled == true
                workerWake.Wake(key:sub(1,3)=="Upg"and "upgrades"or key)
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
    local tntDiagnostics=createFeatureDiagnostics({Tab=DiagnosticsTab,Registry=Registry,Title="Auto TNT Diagnostics",
        Key="AutoTntDiagnostics",File="chapter3_auto_tnt_diagnostics",Player=LocalPlayer,
        Alive=function()return not hubUnloaded end,Menu=function()return hubWindow.Closed end,Write=safeWrite})
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
            or sharedFarmPuzzleBusy()
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
    local function exposedNeedle()
        local folder=Workspace:FindFirstChild("NeedleObjectiveServer")
        folder=folder and folder:FindFirstChild("Needle")
        if not folder then indexedObjectives(nil); return nil end
        for _,item in ipairs(indexedObjectives(folder)) do
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
                                for _,other in budgetedFolderChildren(folder,function() return not hubUnloaded and (sharedFarmState.AutoPickHay or sharedFarmState.AutoFindNeedle) end,false,hay.Position,radius+1) do
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
    local tntRetry=createTntRetryGate(function() return farmRemote("TntAction") end,function() return LocalPlayer:GetAttribute("TntCooldown") end,function() return sharedGameConfig and sharedGameConfig.TNT_LIGHT_TIME end,tntDiagnostics)
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            if (sharedFarmState.AutoUsePitchfork or sharedFarmState.AutoDeployDrone)
                and needleFolder and not farmBlocked() and not needlePriority() and not bossToolsBusy() then
                if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                    local _,id=selectPitchforkHay(function() return not hubUnloaded and sharedFarmState.AutoUsePitchfork and not farmBlocked() and not needlePriority() and not bossToolsBusy() end)
                    if id then sendFarmRemote("PitchforkDig",id) end
                end
                if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                    and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                    sendFarmRemote("DeployDrone")
                end

            end
        end
    end)
    installTntObservation(tntDiagnostics,function()
        local reason
        if not sharedFarmState.AutoUseTNT then reason="Auto TNT disabled"
        elseif not needleFolder then reason="Waiting for NeedleHaystack"
        elseif farmBlocked()then
            reason=LocalPlayer:GetAttribute("CutsceneActive")==true and "Paused for cutscene"or LocalPlayer:GetAttribute("NeedleInputLocked")==true and "Paused for input lock"or "Farming blocked"
        elseif needlePriority()then reason="Paused for needle action"
    elseif bossToolsBusy()then reason="Paused for boss tools"
        elseif LocalPlayer:GetAttribute("TntOwned")~=true then reason="Waiting for TNT ownership"
        elseif not farmRemote("TntAction")then reason="Waiting for TNT remote"
        elseif not farmRoot()then reason="Waiting for character"end
        return {AutoUseTNT=sharedFarmState.AutoUseTNT,Owned=LocalPlayer:GetAttribute("TntOwned"),
            BlockReason=reason,RemoteAvailable=farmRemote("TntAction")~=nil,HayFolderPresent=Workspace:FindFirstChild("HaystackClient")~=nil}
    end)
    tntDiagnostics.BindGate(tntRetry)
    spawnChapterWorker(function()
        while not hubUnloaded do
            task.wait(tntRetry.WaitInterval())
            if needleFolder and not farmBlocked() and not needlePriority() and not bossToolsBusy() then
                if sharedFarmState.AutoUseTNT and LocalPlayer:GetAttribute("TntOwned")==true and tntRetry.Ready() then
                    if sharedFarmState.AutoUseTNT and not farmBlocked() and not needlePriority() then
                        local root=farmRoot()
                        local function allowed()
                            return not hubUnloaded and sharedFarmState.AutoUseTNT and not farmBlocked() and not needlePriority() and not bossToolsBusy()
                        end
                        local from,velocity,hay=tntDiagnostics.MeasureAim("Target search",aimHayTnt,Workspace,sharedGameConfig,root,allowed)
                        if from and root and root.Parent and root==farmRoot() and allowed() and tntRetry.Light() then
                            from,velocity=tntDiagnostics.MeasureAim("Target refresh",aimHayTnt,Workspace,sharedGameConfig,root,allowed,hay)
                            if from and root.Parent and root==farmRoot() and allowed() then
                                tntRetry.Throw(from,velocity)
                            end
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
            workerWake.Wait(0.08,not sharedFarmState.AutoUseVacuum and not vacuumHeld,"AutoUseVacuum")
            if hubUnloaded then break end
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
    spawnChapterWorker(function()
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
                workerWake.Wait(0.25,upgrades.IsIdle(),upgrades.WaitKey())
            end
        end)
    end


    -- Chapter 3 options adapted from BeyyTU/needlehub chapter3.lua
    -- Reference blob: 1e4025b9bd9d261effa6b45334038d532c08c4ed
    local function installRanchOptions()
        local ranchUfoStatusText="Starting UFO automation"
        local ranchUfoStatusLabel
        local ranchUfoDiagnostic=function() return {} end
        -- Ranch GUI solver. The three GUI layouts and interactive controls
        -- were obtained from the live read-only Ranch JSON captures.
        -- Server-side puzzle remote arguments are NOT known. Normal solving
        -- uses real GUI dragging, not speculative remote requests.
        local ranchPuzzleNames = {
            "UfoWireMinigame", "UfoVentMinigame", "UfoAlignMinigame"
        }
        local ranchPuzzleInputBusy = false
        local ranchUfoBusy = false
        local ranchMouseHeld = false
        local ranchLastPuzzleGui = nil
        local ranchSession = nil
        local ranchAttempts = 0
        local ranchNextAttemptAt = 0
        local ranchInstantProbeActive = false

        local function ranchActivePuzzle()
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if not pg then return nil, nil end
            for _, name in ipairs(ranchPuzzleNames) do
                local gui = pg:FindFirstChild(name)
                if gui and gui:IsA("ScreenGui") and gui.Enabled then
                    local panel = gui:FindFirstChild("Panel")
                    if panel and panel:IsA("GuiObject") and panel.Visible then
                        return name, gui
                    end
                end
            end
            return nil, nil
        end
        local function ranchPuzzleAlive(gui)
            return gui ~= nil and gui.Parent ~= nil
                and gui:IsA("ScreenGui") and gui.Enabled == true
                and gui:FindFirstChild("Panel") ~= nil
        end
        sharedFarmPuzzleBusy = function()
            return ranchUfoBusy or ranchPuzzleInputBusy or ranchInstantProbeActive
                or ranchActivePuzzle() ~= nil
        end

        local function ranchPoint(element)
            local pos, size = element.AbsolutePosition, element.AbsoluteSize
            return Vector2.new(pos.X + size.X*0.5, pos.Y + size.Y*0.5)
        end
        local function ranchMouseMove(point)
            VirtualInputManager:SendMouseMoveEvent(math.floor(point.X+0.5),
                math.floor(point.Y+0.5), game)
        end
        local function ranchMouseButton(point, down)
            VirtualInputManager:SendMouseButtonEvent(math.floor(point.X+0.5),
                math.floor(point.Y+0.5), 0, down, game, 0)
        end
        local function ranchReleaseMouse()
            if not ranchMouseHeld then return end
            ranchMouseHeld = false
            local point = UserInputService:GetMouseLocation()
            pcall(function() ranchMouseButton(point, false) end)
        end
        -- Validated in standalone Ranch GUI pilot v6 (frame input for wire/align)
        -- and Vent Teleport pilot v2 (0.29 clip-height jump with GUI inset).
        -- This block is ONLY called by the existing AutoSolveRanchPuzzles loop.
        local function ranchGuiActive(gui)
            if not ranchPuzzleAlive(gui) then return false end
            local panel=gui:FindFirstChild("Panel")
            return panel and panel:IsA("GuiObject") and panel.Visible
        end
        local function ranchCanSolve(gui)
            return not hubUnloaded and sharedFarmState.AutoSolveRanchPuzzles
                and hubWindow.Closed and not ranchInstantProbeActive
                and not ranchUfoBusy and not needleBusy
                and LocalPlayer:GetAttribute("CutsceneActive")~=true
                and LocalPlayer:GetAttribute("NeedleInputLocked")~=true
                and ranchGuiActive(gui)
        end
        local function ranchWaitClosed(gui,seconds)
            local deadline=os.clock()+seconds
            while ranchGuiActive(gui) and os.clock()<deadline do
                if not ranchCanSolve(gui) then return false end
                task.wait(0.06)
            end
            return not ranchGuiActive(gui)
        end
        local function ranchGuiInsetY()
            local ok,top=pcall(function() return GuiService:GetGuiInset() end)
            return ok and top.Y or 0
        end
        local function ranchInsidePanel(panel,point)
            local p,s=panel.AbsolutePosition,panel.AbsoluteSize
            return point.X>=p.X-8 and point.X<=p.X+s.X+8
                and point.Y>=p.Y-8 and point.Y<=p.Y+s.Y+8
        end
        -- Every mouse hold has a corresponding release, even if input is
        -- interrupted by closing the hub, disabling the toggle or an error.
        -- mode="frame" is the tested wire/align gesture. mode="jump" is the
        -- tested Vent gesture, with ONE intermediate-free mouse move.
        -- mode="timed" preserves the proven GUI input as a fallback.
        local function ranchGuiDrag(gui,origin,goal,insetY,profile)
            if not ranchCanSolve(gui) then return false end
            local offset=Vector2.new(0,insetY or 0)
            local first,last=origin+offset,goal+offset
            local began=false
            local ok,err=pcall(function()
                ranchMouseMove(first)
                RunService.RenderStepped:Wait()
                if not ranchCanSolve(gui) then return end
                ranchMouseButton(first,true)
                began=true
                ranchMouseHeld=true
                if ranchSession and ranchSession.gui==gui then
                    ranchSession.drags+=1
                end
                RunService.RenderStepped:Wait()
                if profile.mode=="frame" then
                    if ranchCanSolve(gui) then
                        ranchMouseMove(first:Lerp(last,0.55))
                        RunService.RenderStepped:Wait()
                    end
                    if ranchCanSolve(gui) then
                        ranchMouseMove(last)
                        RunService.RenderStepped:Wait()
                    end
                elseif profile.mode=="jump" then
                    if ranchCanSolve(gui) then
                        ranchMouseMove(last)
                        RunService.RenderStepped:Wait()
                    end
                else
                    local steps=profile.steps or 20
                    local duration=profile.duration or 0.32
                    for i=1,steps do
                        if not ranchCanSolve(gui) then break end
                        ranchMouseMove(first:Lerp(last,i/steps))
                        task.wait(duration/steps)
                    end
                    if ranchCanSolve(gui) then
                        ranchMouseMove(last)
                        task.wait(profile.hold or 0.09)
                    end
                end
            end)
            if began then
                pcall(function() ranchMouseButton(last,false) end)
                ranchMouseHeld=false
            end
            if not ok then
                warn("[Ranch Puzzles] Mouse input error: "..tostring(err))
            end
            return ok and began
        end

        local ranchAlignProfiles={
            {mode="frame",window=1.33}, -- successful v6
            {mode="timed",duration=0.26,steps=15,hold=0.045,window=1.55},
            {mode="timed",duration=0.42,steps=22,hold=0.09,window=1.70},
        }
        local function ranchSolveLaser(gui,insetY,attempt)
            local panel=gui:FindFirstChild("Panel")
            local arrow=panel and panel:FindFirstChild("Arrow")
            local track=panel and panel:FindFirstChild("Track")
            if not arrow or not track or not arrow:IsA("GuiObject") then
                return false,"Laser Arrow/Track missing"
            end
            local cy=tonumber(track:GetAttribute("CenterY"))
            if not cy then return false,"Laser CenterY attribute missing" end
            local tpos,tsize=track.AbsolutePosition,track.AbsoluteSize
            local before=ranchPoint(arrow)
            local target=Vector2.new(math.clamp(before.X,tpos.X+4,
                tpos.X+tsize.X-4),tpos.Y+cy*tsize.Y)
            for index,profile in ipairs(ranchAlignProfiles) do
                if not ranchCanSolve(gui) then
                    return not ranchGuiActive(gui),"Laser input interrupted"
                end
                local start=ranchPoint(arrow)
                print(string.format(
                    "[Ranch Puzzles] ALIGN profile=%d mode=%s inset=%d targetY=%.1f",
                    index,profile.mode,insetY,target.Y))
                if not ranchGuiDrag(gui,start,target,insetY,profile) then
                    return false,"Laser GUI drag failed"
                end
                if ranchWaitClosed(gui,profile.window) then
                    return true,"Laser solved using "..profile.mode.." input"
                end
            end
            return false,"Laser still open after verified GUI profiles"
        end

        local ranchWireProfiles={
            {mode="frame",settle=0.075}, -- successful v6
            {mode="timed",duration=0.23,steps=14,hold=0.045,settle=0.12},
            {mode="timed",duration=0.38,steps=22,hold=0.09,settle=0.20},
        }
        local function ranchSolveWires(gui,insetY,attempt)
            local panel=gui:FindFirstChild("Panel")
            local left=panel and panel:FindFirstChild("Left")
            local right=panel and panel:FindFirstChild("Right")
            local lines=panel and panel:FindFirstChild("Lines")
            if not left or not right or not lines then
                return false,"Wire Left/Right/Lines missing"
            end
            local pairs={}
            for _,wire in ipairs(left:GetChildren()) do
                local color=wire:GetAttribute("Wire")
                local tip=wire:FindFirstChild("Tip")
                if type(color)=="string" and tip and tip:IsA("GuiObject") then
                    for _,other in ipairs(right:GetChildren()) do
                        if other:GetAttribute("Wire")==color then
                            local matching=other:FindFirstChild("Tip")
                            if matching and matching:IsA("GuiObject") then
                                pairs[#pairs+1]={color=color,source=tip,target=matching}
                                break
                            end
                        end
                    end
                end
            end
            if #pairs~=4 then
                return false,"Expected four wire pairs; got "..#pairs
            end
            table.sort(pairs,function(x,y)
                return x.source.AbsolutePosition.Y<y.source.AbsolutePosition.Y
            end)
            local completeCount=#pairs+1 -- one native Lines child is a template
            local last=#lines:GetChildren()
            local connected=0
            for _,pair in ipairs(pairs) do
                if not ranchGuiActive(gui) then return true,"Wire GUI closed" end
                if not ranchCanSolve(gui) then return false,"Wire input interrupted" end
                if #lines:GetChildren()>=completeCount then break end
                local registered=false
                for index,profile in ipairs(ranchWireProfiles) do
                    if not ranchCanSolve(gui) then
                        return not ranchGuiActive(gui),"Wire input interrupted"
                    end
                    -- Exact matching Tip centers: no extra 45-94px overshoot.
                    local from,to=ranchPoint(pair.source),ranchPoint(pair.target)
                    if not ranchGuiDrag(gui,from,to,insetY,profile) then
                        return false,"Wire drag failed: "..pair.color
                    end
                    task.wait(profile.settle)
                    if not ranchGuiActive(gui) then
                        return true,"Wire GUI closed after "..pair.color
                    end
                    local count=#lines:GetChildren()
                    if count>last then
                        connected+=count-last
                        last=count
                        registered=true
                        print("[Ranch Puzzles] WIRE "..pair.color..
                            " connected; profile="..index.." lines="..count)
                        break
                    end
                end
                if not registered and #lines:GetChildren()<completeCount then
                    return false,"Wire "..pair.color.." did not connect after three profiles"
                end
            end
            if #lines:GetChildren()>=completeCount then
                if ranchWaitClosed(gui,1.45) then
                    return true,"All four wires connected and GUI closed"
                end
                return true,"All four wires connected; waiting for native finish"
            end
            return false,"Wires incomplete; lines="..#lines:GetChildren()
        end

        local ranchVentProfiles={
            {label="PREFERRED-JUMP",fraction=0.29,mode="jump"},
            {label="EXTENDED-JUMP",fraction=0.34,mode="jump"},
            {label="PROVEN-DRAG",fraction=0.34,mode="timed",
                duration=0.32,steps=20,hold=0.09},
        }
        local function ranchVentCount(clip)
            local counter=clip:FindFirstChild("Counter")
            local text=counter and counter:IsA("TextLabel") and counter.Text or ""
            return tonumber(text:match("^(%d+)")),text
        end
        local function ranchVentSnapshot(strands)
            local sample={}
            for _,obj in ipairs(strands:GetChildren()) do
                if obj:IsA("GuiObject") then
                    local grab=obj:FindFirstChild("Grab")
                    if grab and grab:IsA("GuiObject") then
                        sample[obj]={position=ranchPoint(grab),
                            visible=obj.Visible,grabVisible=grab.Visible}
                    end
                end
            end
            return sample
        end
        local function ranchVentCandidates(strands,pulled)
            local list={}
            for obj,state in pairs(ranchVentSnapshot(strands)) do
                if state.visible and state.grabVisible and not pulled[obj] then
                    local grab=obj:FindFirstChild("Grab")
                    if grab then list[#list+1]={strand=obj,grab=grab} end
                end
            end
            table.sort(list,function(x,y)
                if x.strand.ZIndex==y.strand.ZIndex then
                    return x.strand.Name>y.strand.Name
                end
                return x.strand.ZIndex>y.strand.ZIndex
            end)
            return list
        end
        local function ranchVentTarget(panel,clip,from,fraction)
            local d=clip.AbsoluteSize.Y*fraction
            local p,s=panel.AbsolutePosition,panel.AbsoluteSize
            local margin=8
            local options={
                Vector2.new(math.clamp(from.X+d,p.X+margin,p.X+s.X-margin),from.Y),
                Vector2.new(math.clamp(from.X-d,p.X+margin,p.X+s.X-margin),from.Y),
                Vector2.new(from.X,math.clamp(from.Y+d,p.Y+margin,p.Y+s.Y-margin)),
                Vector2.new(from.X,math.clamp(from.Y-d,p.Y+margin,p.Y+s.Y-margin)),
            }
            local target,distance=options[1],-1
            for _,option in ipairs(options) do
                local n=(option-from).Magnitude
                if n>distance then target,distance=option,n end
            end
            return target,distance/math.max(1,clip.AbsoluteSize.Y)
        end
        local function ranchSolveVent(gui,insetY,attempt)
            local panel=gui:FindFirstChild("Panel")
            local clip=panel and panel:FindFirstChild("Clip")
            local strands=clip and clip:FindFirstChild("Strands")
            if not clip or not strands then
                return false,"Vent Clip/Strands missing"
            end
            local initial=select(1,ranchVentCount(clip))
            if not initial then return false,"Vent counter unreadable" end
            local pulled,visits={},{}
            local progress,failures=0,0
            local opened=os.clock()
            for trial=1,math.max(initial*3,45) do
                if not ranchGuiActive(gui) then return true,"Vent GUI closed" end
                if not ranchCanSolve(gui) then return false,"Vent input interrupted" end
                if os.clock()-opened>=27 then
                    return false,"Vent safety window elapsed, progress="..progress
                end
                local before=select(1,ranchVentCount(clip))
                if before and before<=0 then
                    print("[Ranch Puzzles] VENT all "..initial..
                        " strands removed in "..string.format("%.2f",os.clock()-opened).."s")
                    return true,"Vent counter reached zero"
                end
                local selected,least=nil,math.huge
                for _,candidate in ipairs(ranchVentCandidates(strands,pulled)) do
                    local point=ranchPoint(candidate.grab)
                    local n=visits[candidate.strand] or 0
                    if ranchInsidePanel(panel,point)
                        and n<#ranchVentProfiles and n<least then
                        selected,least=candidate,n
                        if n==0 then break end
                    end
                end
                if not selected then
                    return false,"No eligible Vent strand; remaining="..tostring(before)
                end
                local piece=selected.strand
                local profileIndex=(visits[piece] or 0)+1
                visits[piece]=profileIndex
                local profile=ranchVentProfiles[profileIndex]
                local from=ranchPoint(selected.grab)
                local goal,pull=ranchVentTarget(panel,clip,from,profile.fraction)
                if pull<=0.205 then
                    visits[piece]=#ranchVentProfiles
                else
                    local prior=ranchVentSnapshot(strands)
                    if not ranchGuiDrag(gui,from,goal,insetY,profile) then
                        return false,"Vent "..piece.Name.." input failed"
                    end
                    local after=select(1,ranchVentCount(clip))
                    local deadline=os.clock()+0.22
                    while ranchGuiActive(gui) and
                        (not after or not before or after>=before)
                        and os.clock()<deadline do
                        if not ranchCanSolve(gui) then break end
                        task.wait(0.015)
                        after=select(1,ranchVentCount(clip))
                    end
                    if after and before and after<before then
                        progress+=before-after
                        -- Overlapping hitboxes can intercept the pointer;
                        -- identify the real pulled strand by movement instead
                        -- of assuming it was the candidate we clicked.
                        local now=ranchVentSnapshot(strands)
                        for obj,old in pairs(prior) do
                            if not pulled[obj] then
                                local newer=now[obj]
                                local shift=newer and
                                    (newer.position-old.position).Magnitude or 0
                                local hidden=old.visible and
                                    (not newer or not newer.visible)
                                if shift>85 or hidden then pulled[obj]=true end
                            end
                        end
                        print("[Ranch Puzzles] VENT "..profile.label..
                            " progress="..progress.."/"..initial)
                        task.wait(0.025)
                    else
                        failures+=1
                        print("[Ranch Puzzles] VENT "..profile.label..
                            " missed "..piece.Name.."; retrying alternate strand")
                        task.wait(0.21)
                        if not ranchInsidePanel(panel,ranchPoint(selected.grab)) then
                            visits[piece]=#ranchVentProfiles
                        end
                    end
                end
            end
            return false,"Vent attempt limit, progress="..progress..
                " misses="..failures
        end

        local ranchSolvers={
            UfoWireMinigame=ranchSolveWires,
            UfoVentMinigame=ranchSolveVent,
            UfoAlignMinigame=ranchSolveLaser,
        }
        task.spawn(function()
            while not hubUnloaded do
                task.wait(0.18)
                local name,gui=ranchActivePuzzle()
                if ranchSession and gui~=ranchSession.gui then
                    local past=ranchSession
                    local elapsed=os.clock()-past.openedAt
                    print(string.format(
                        "[Ranch Puzzles] %s closed after %.1fs | autoAttempts=%d | GUI drags=%d | instantRequests=%d | autoAtOpen=%s; closure alone does not prove server completion",
                        past.name,elapsed,past.autoAttempts,past.drags,
                        past.instantRequests,tostring(past.autoEnabledAtOpen)))
                    if past.autoAttempts==0 and past.drags==0 then
                        print("[Ranch Puzzles] No automatic GUI dragging occurred in this session; possible built-in idle completion or manual input")
                    end
                    ranchSession=nil
                end
                if not gui then
                    ranchLastPuzzleGui=nil
                    ranchAttempts=0
                    ranchNextAttemptAt=0
                elseif gui~=ranchLastPuzzleGui then
                    ranchLastPuzzleGui=gui
                    ranchAttempts=0
                    ranchNextAttemptAt=0
                    ranchSession={
                        gui=gui,name=name,openedAt=os.clock(),
                        autoEnabledAtOpen=sharedFarmState.AutoSolveRanchPuzzles,
                        autoAttempts=0,drags=0,instantRequests=0
                    }
                    print("[Ranch Puzzles] Opened "..name
                        .." | AutoSolve="..tostring(sharedFarmState.AutoSolveRanchPuzzles))
                end
                if gui and sharedFarmState.AutoSolveRanchPuzzles
                    and hubWindow.Closed and not ranchPuzzleInputBusy
                    and not ranchUfoBusy and not needleBusy
                    and LocalPlayer:GetAttribute("CutsceneActive")~=true
                    and LocalPlayer:GetAttribute("NeedleInputLocked")~=true
                    and not ranchInstantProbeActive
                    and ranchAttempts<3 and os.clock()>=ranchNextAttemptAt then
                    ranchAttempts+=1
                    ranchNextAttemptAt=os.clock()+8
                    ranchPuzzleInputBusy=true
                    releaseSharedVacuum()
                    if ranchSession and ranchSession.gui==gui then
                        ranchSession.autoAttempts+=1
                    end
                    local solver=ranchSolvers[name]
                    local attempt=ranchAttempts
                    task.spawn(function()
                        -- All three verified solvers need the correct inset immediately.
                        local insetY=ranchGuiInsetY()
                        print(string.format("[Ranch Puzzles] %s GUI solve attempt %d (inset=%d)",
                            name,attempt,insetY))
                        local ok,submitted,details=pcall(solver,gui,insetY,attempt)
                        ranchReleaseMouse()
                        ranchPuzzleInputBusy=false
                        if not ok then
                            warn("[Ranch Puzzles] Solver failed: "..tostring(submitted))
                        else
                            print("[Ranch Puzzles] "..tostring(details))
                            if not submitted then
                                warn("[Ranch Puzzles] Puzzle still needs manual action: "..tostring(details))
                            end
                        end
                        task.wait(0.65)
                        if not ranchPuzzleAlive(gui) then
                            print("[Ranch Puzzles] "..name.." GUI closed after solve; verify puzzle progression")
                        elseif attempt>=3 then
                            warn("[Ranch Puzzles] "..name.." still open after three drag attempts; stopped automatic retries")
                        end
                    end)
                end
            end
            ranchReleaseMouse()
        end)

        local function ranchInstantCompletionProbe()
            if hubUnloaded or ranchInstantProbeActive or ranchPuzzleInputBusy or ranchUfoBusy or needleBusy then
                warn("[Ranch Puzzles] Input already busy; instant test skipped")
                return
            end
            local name,gui=ranchActivePuzzle()
            if not name or not gui then
                warn("[Ranch Puzzles] Open a wire, vent or laser GUI before testing instant completion")
                return
            end
            local folder=ReplicatedStorage:FindFirstChild("UfoCrash")
            local remotes=folder and folder:FindFirstChild("Remotes")
            local remote=remotes and remotes:FindFirstChild("PuzzleDone")
            if not remote or not remote:IsA("RemoteEvent") then
                warn("[Ranch Puzzles] PuzzleDone RemoteEvent not available")
                return
            end
            ranchInstantProbeActive=true
            releaseSharedVacuum()
            pcall(function() hubWindow:Close() end)
            task.spawn(function()
                task.wait(0.2)
                if not ranchPuzzleAlive(gui) or hubUnloaded then
                    ranchInstantProbeActive=false
                    warn("[Ranch Puzzles] Instant test aborted: puzzle closed or module unloaded")
                    return
                end
                -- Exactly ONE no-argument request. The diagnostic only
                -- identifies the remote, not its expected payload. This
                -- test cannot prove whether other payloads are accepted.
                local ok,err=pcall(function() remote:FireServer() end)
                if ranchSession and ranchSession.gui==gui and ok then
                    ranchSession.instantRequests+=1
                end
                print(string.format("[Ranch Puzzles] Instant test: %s PuzzleDone() sent=%s",
                    name,tostring(ok)))
                if not ok then warn("[Ranch Puzzles] Instant test error: "..tostring(err)) end
                task.wait(2.0)
                local closed=not ranchPuzzleAlive(gui)
                if closed then
                    warn("[Ranch Puzzles] Instant test: GUI CLOSED after PuzzleDone(); promising but server puzzle completion is NOT proven. Verify UFO progression.")
                else
                    warn("[Ranch Puzzles] Instant test: GUI STILL OPEN after PuzzleDone(); no-argument completion not confirmed (other payloads remain unknown).")
                end
                ranchInstantProbeActive=false
            end)
        end

        -- Ranch UFO-part objective, independent of the hay/needle remotes.
        -- Diagnostics show UfoSplitted piece flags (Revealed, Returned,
        -- HeldBy), CarryingUfoPart on LocalPlayer, and PartsReturned on the
        -- UFO model. Only these replicated state changes confirm progress.
        -- Isolate UFO automation helpers into their own Luau function scope.
        -- Chapter 3's shared module already has many local variables; keeping
        -- these helpers in the enclosing block risks the compiler's 200-local
        -- limit even though each pickup helper is independently small.
        local function runRanchUfoAutomation()
        local ranchUfoNextActionAt = 0
        local ranchUfoFailedUntil = {}
        local ranchUfoFailureCount = {}
        local ufoDiagnostics
        local ranchUfoLastNotice = -math.huge
        local function ranchUfoNotice(message, warning)
            if ufoDiagnostics then ufoDiagnostics.Status(warning and "Warning"or "UFO",message)end
            if warning and os.clock()-ranchUfoLastNotice < 6 then return end
            if warning then
                ranchUfoLastNotice=os.clock()
                warn("[Ranch UFO] "..tostring(message))
            else
                print("[Ranch UFO] "..tostring(message))
            end
        end
        local function ranchUfoModel()
            local model=Workspace:FindFirstChild("UfoSplitted")
            return model and model:IsA("Model") and model or nil
        end
        local function ranchUfoReturned(model)
            return model and tonumber(model:GetAttribute("PartsReturned")) or 0
        end
        local function ranchUfoModelPiece(model,name)
            if not model or type(name)~="string" then return nil end
            local p=model:FindFirstChild(name,true)
            return p and p:IsA("BasePart") and p or nil
        end
        local observedUfoModel,observedUfoParts=nil,{}
        local observedUfoConnections={}
        local function clearUfoObservationIndex()
            for _,connection in ipairs(observedUfoConnections)do connection:Disconnect()end
            table.clear(observedUfoConnections);table.clear(observedUfoParts);observedUfoModel=nil
        end
        local function ranchUfoObservedParts(model)
            if model~=observedUfoModel then
                clearUfoObservationIndex();observedUfoModel=model
                if model then
                    local function add(part)if part:IsA("BasePart")then observedUfoParts[#observedUfoParts+1]=part end end
                    local function remove(part)
                        local index=table.find(observedUfoParts,part)
                        if index then table.remove(observedUfoParts,index)end
                    end
                    observedUfoConnections[1]=model.DescendantAdded:Connect(add)
                    observedUfoConnections[2]=model.DescendantRemoving:Connect(remove)
                    for _,part in ipairs(model:GetDescendants())do add(part)end
                end
            end
            return observedUfoParts
        end
        local previousUfoObservationCleanup=_G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP=function()
            clearUfoObservationIndex()
            if previousUfoObservationCleanup then previousUfoObservationCleanup()end
        end

        local function ranchUfoCarried()
            local name=LocalPlayer:GetAttribute("CarryingUfoPart")
            if type(name)=="string" and #name>0 then return name end
            -- Replication can deliver HeldBy before CarryingUfoPart. Do not
            -- misclassify a completed pickup as a failed pickup.
            local model=Workspace:FindFirstChild("UfoSplitted")
            if model then
                for _,p in ipairs(ranchUfoObservedParts(model)) do
                    if p:IsA("BasePart") and p:GetAttribute("Returned")~=true then
                        local held=p:GetAttribute("HeldBy")
                        if held==LocalPlayer.UserId or held==tostring(LocalPlayer.UserId) then
                            return p.Name
                        end
                    end
                end
            end
            return nil
        end
        local function ranchUfoUnheld(piece)
            local holder=piece:GetAttribute("HeldBy")
            return holder==nil
        end
        local function ranchUfoExposedPart(model)
            if not model then return nil end
            local root=farmRoot()
            local best,score=nil,math.huge
            -- The true revealed UFO pieces live in UfoSplitted; Scatter
            -- proxies are NOT the collectible objects.
            for _,piece in ipairs(model:GetDescendants()) do
                if piece:IsA("BasePart") and
                    piece:GetAttribute("UfoPiece")==true
                    and piece:GetAttribute("Revealed")==true
                    and piece:GetAttribute("Returned")~=true
                    and ranchUfoUnheld(piece) then
                    local distance=root and (root.Position-piece.Position).Magnitude or 0
                    local untilAt=ranchUfoFailedUntil[piece.Name] or 0
                    if os.clock()>=untilAt and distance<score then
                        best,score=piece,distance
                    end
                end
            end
            return best
        end
        local function ranchUfoMainPart(model)
            local main=model and model:FindFirstChild("Main")
            if not main then return nil end
            if main:IsA("BasePart") then return main end
            -- Prefer the click-detector surface if one exists. The previous
            -- largest-part heuristic could aim at an inert decorative hull.
            for _,desc in ipairs(main:GetDescendants()) do
                if desc:IsA("ClickDetector") and desc.Parent
                    and desc.Parent:IsA("BasePart") then
                    return desc.Parent
                end
            end
            if main:IsA("Model") and main.PrimaryPart then return main.PrimaryPart end
            local best,volume=nil,0
            for _,part in ipairs(main:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency<1 then
                    local v=part.Size.X*part.Size.Y*part.Size.Z
                    if v>volume then best,volume=part,v end
                end
            end
            return best or main:FindFirstChildWhichIsA("BasePart",true)
        end
        local function ranchUfoRemote(name,...)
            local folder=ReplicatedStorage:FindFirstChild("UfoCrash")
            local remotes=folder and folder:FindFirstChild("Remotes")
            local remote=remotes and remotes:FindFirstChild(name)
            if not remote or not remote:IsA("RemoteEvent") then return false end
            local args=table.pack(...)
            local ok,err=pcall(function()
                remote:FireServer(table.unpack(args,1,args.n))
            end)
            if not ok then ranchUfoNotice(name.." failed: "..tostring(err),true) end
            return ok -- Local send only; never interpreted as server acceptance.
        end
        local function ranchUfoBlockReason(ignoreMenu)
            if bossToolsBusy() then return "Boss workflow active" end
            if hubUnloaded then return "Hub unloaded" end
            if not sharedFarmState.AutoGrabAttachUfoParts then return "Auto Grab & Attach UFO Parts is OFF" end
            if not hubWindow.Closed and not ignoreMenu then return "Close the menu to allow UFO movement" end
            if needleBusy or needlePriority() then return "Waiting for needle pickup / turn-in" end
            if ranchInstantProbeActive then return "Waiting for instant puzzle test" end
            if ranchPuzzleInputBusy then return "Waiting for puzzle input" end
            local puzzle=ranchActivePuzzle()
            if puzzle then return "Waiting for puzzle: "..puzzle end
            for _,flag in ipairs({"NeedleInputLocked","CutsceneActive","HintViewerOpen"}) do
                if LocalPlayer:GetAttribute(flag)==true then return "Waiting for "..flag end
            end
            if not farmRoot() then return "Waiting for character root" end
            if not Workspace.CurrentCamera then return "Waiting for camera" end
            return nil
        end
        local function ranchUfoSafeToMove()
            return ranchUfoBlockReason()==nil
        end
        ranchUfoDiagnostic=function()
            local model=ranchUfoModel()
            local data={status=ranchUfoStatusText,blocker=ranchUfoBlockReason(true),menuOpen=not hubWindow.Closed,
                module=__BEYY_MODULE,placeId=game.PlaceId,jobId=game.JobId,
                modelFound=model~=nil,carrying=ranchUfoCarried(),
                partsReturned=ranchUfoReturned(model),pieces={}}
            if model then
                data.modelAttributes=model:GetAttributes()
                local root=farmRoot()
                for _,piece in ipairs(model:GetDescendants()) do
                    if piece:IsA("BasePart") then
                        data.pieces[#data.pieces+1]={path=piece:GetFullName(),
                            attributes=piece:GetAttributes(),unheld=ranchUfoUnheld(piece),
                            distance=root and (root.Position-piece.Position).Magnitude or nil,
                            retryIn=math.max(0,(ranchUfoFailedUntil[piece.Name] or 0)-os.clock())}
                    end
                end
            end
            return data
        end
        -- One live observation per decision tick, reused by status and action selection.
        -- No observation crosses a yield; pickup/attach routines retain live checks.
        local function ranchUfoObserve()
            local model=ranchUfoModel()
            local observed={Model=model,Carrying=nil,Piece=nil,Revealed=0,Held=0,Returned=0}
            local carried=LocalPlayer:GetAttribute("CarryingUfoPart")
            if type(carried)=="string"and #carried>0 then observed.Carrying=carried end
            if not model then return observed end
            local root=farmRoot()
            local best=math.huge
            local now=os.clock()
            for _,piece in ipairs(ranchUfoObservedParts(model))do
                if piece:IsA("BasePart")then
                    local revealed=piece:GetAttribute("Revealed")==true
                    local returned=piece:GetAttribute("Returned")==true
                    local held=piece:GetAttribute("HeldBy")
                    if not observed.Carrying and not returned and (held==LocalPlayer.UserId or held==tostring(LocalPlayer.UserId))then observed.Carrying=piece.Name end
                    if revealed then
                        observed.Revealed+=1
                        if held~=nil then observed.Held+=1 end
                        if returned then observed.Returned+=1 end
                    end
                    if piece:GetAttribute("UfoPiece")==true and revealed and not returned and held==nil
                        and now>=(ranchUfoFailedUntil[piece.Name]or 0)then
                        local distance=root and (root.Position-piece.Position).Magnitude or 0
                        if distance<best then observed.Piece=piece;best=distance end
                    end
                end
            end
            return observed
        end

        local function ranchUfoUpdateStatus(observed)
            local reason=ranchUfoBlockReason(true)
            if reason then ranchUfoStatusText=reason
            elseif ranchUfoBusy then return
            else
                observed=observed or ranchUfoObserve()
                local model=observed.Model
                if not model then ranchUfoStatusText="Waiting for Workspace.UfoSplitted model"
                elseif model:GetAttribute("Repaired")==true or ranchUfoReturned(model)>=(tonumber(model:GetAttribute("PartsTotal")) or 7) then
                    ranchUfoStatusText="UFO repaired / all parts returned"
                elseif observed.Carrying then ranchUfoStatusText="Carrying "..observed.Carrying.."; attachment pending"
                elseif os.clock()<ranchUfoNextActionAt then ranchUfoStatusText="Waiting for retry cooldown"
                elseif observed.Piece then ranchUfoStatusText="Ready: "..observed.Piece.Name
                else
                    local revealed,held,returned=observed.Revealed,observed.Held,observed.Returned
                    ranchUfoStatusText=string.format("No eligible UFO part: revealed=%d, held=%d, returned=%d",revealed,held,returned)
                end
            end
            if ufoDiagnostics then ufoDiagnostics.Status("Worker",ranchUfoStatusText)end
            return observed
        end
        local function ranchUfoWaitFor(check,timeout)
            local deadline=os.clock()+timeout
            repeat
                if check() then return true end
                if not ranchUfoSafeToMove() then return false end
                task.wait(0.04)
            until os.clock()>=deadline
            return check()
        end

        -- Click from several CAMERA and ROOT angles. The old routine used
        -- a fixed diagonal position and blindly clicked screen center, even
        -- if a hay bale or decorative UFO part obscured the actual target.
        -- UFO pickups use VIEWPORT pixel coordinates, exactly as the
        -- working Chapter 1/2 needle pickup routines do. WorldToScreenPoint
        -- adds the GUI inset and can miss small exposed UFO parts. Attachment
        -- retains its already-working cursor targeting, unchanged.
        local function ranchUfoPickupEligible(piece)
            local model=ranchUfoModel()
            return model and piece and piece:IsDescendantOf(model)and piece:GetAttribute("UfoPiece")==true
                and piece:GetAttribute("Revealed")==true and piece:GetAttribute("Returned")~=true and piece:GetAttribute("HeldBy")==nil
        end
        local function ranchUfoWorldClick(target,root,camera,check,stage)
            if not target or not target.Parent or not root or not camera then
                return false,"missing target/root/camera"
            end
            if check() then return true,"already confirmed" end
            local character=LocalPlayer.Character
            local center=target.Position
            local relative=root.Position-center
            local base=math.atan2(relative.Z,relative.X)
            local angles={0,math.pi/3,-math.pi/3,2*math.pi/3,
                -2*math.pi/3,math.pi}
            local attempts,occluded=0,0
            local lookHeight=stage=="attach" and 1.8 or 1.0
            for index,rotation in ipairs(angles) do
                if check() then return true,"confirmed between angles" end
                if not ranchUfoSafeToMove()or(stage=="pickup"and not ranchUfoPickupEligible(target))or not target.Parent
                    or not root.Parent or camera~=Workspace.CurrentCamera then
                    return false,"interrupted"
                end
                local theta=base+rotation
                local direction=Vector3.new(math.cos(theta),0,math.sin(theta))
                local reach=stage=="attach" and 3.1 or 2.35
                local stand=center+direction*reach+Vector3.new(0,1.15,0)
                local aim=center
                local cameraReach=math.max(reach+0.8,
                    math.min(9.5,target.Size.Magnitude*0.50+1.3))
                -- Try elevated camera views on the later angles as well:
                -- an exposed piece can still sit behind a tall hay clump
                -- when viewed from every horizontal side.
                local height=index>=4
                    and (stage=="attach" and 3.1 or 3.5) or lookHeight
                local camPos=center+direction*cameraReach+
                    Vector3.new(0,height,0)
                -- Keep avatar upright; avoid placing the root directly into
                -- the part. Angles are relative to the avatar's initial side.
                root.CFrame=CFrame.lookAt(stand,
                    Vector3.new(center.X,stand.Y,center.Z))
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                camera.CameraType=Enum.CameraType.Scriptable
                camera.CFrame=CFrame.lookAt(camPos,aim)
                -- The server validates proximity against replicated player
                -- position. One render frame was too short for this to settle:
                -- do not click until the moved root has had network time.
                task.wait(0.12)
                if check() then return true,"confirmed after approach" end
                if not ranchUfoSafeToMove()or(stage=="pickup"and not ranchUfoPickupEligible(target))then return false,"interrupted" end
                local rootError=(root.Position-stand).Magnitude
                if rootError>5 then
                    print(string.format(
                        "[Ranch UFO] %s %s angle=%d root moved %.1f studs away from requested position; click may fail proximity validation",
                        tostring(stage),target.Name,index,rootError))
                end
                camera.CFrame=CFrame.lookAt(camPos,aim)
                local screen,visible
                if stage=="pickup" then
                    screen,visible=camera:WorldToScreenPoint(aim)
                else
                    screen,visible=camera:WorldToScreenPoint(aim)
                end
                local params=RaycastParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                if character then params.FilterDescendantsInstances={character} end
                params.IgnoreWater=true
                local ray=Workspace:Raycast(camPos,(aim-camPos)*1.05,params)
                local hit=ray and ray.Instance
                local clear=not hit or hit==target
                    or (stage=="attach" and target.Parent and
                        hit:IsDescendantOf(target.Parent))
                if not clear then
                    occluded+=1
                    print(string.format("[Ranch UFO] %s %s angle=%d obstructed by %s",
                        tostring(stage),target.Name,index,hit:GetFullName()))
                elseif visible then
                    local pos=Vector2.new(screen.X,screen.Y)
                    if stage~="pickup" then
                        -- Preserved attachment input from the previously
                        -- working release; do NOT modify its click semantics.
                        local down=false
                        local sent,err=pcall(function()
                            VirtualInputManager:SendMouseMoveEvent(
                                math.floor(pos.X+0.5),math.floor(pos.Y+0.5),game)
                            RunService.RenderStepped:Wait()
                            if not ranchUfoSafeToMove()or(stage=="pickup"and not ranchUfoPickupEligible(target))then return end
                            VirtualInputManager:SendMouseButtonEvent(
                                math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                0,true,game,0)
                            down=true
                            task.wait(0.06)
                        end)
                        if down then
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(
                                    math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                    0,false,game,0)
                            end)
                        end
                        if not sent then
                            ranchUfoNotice("World click error: "..tostring(err),true)
                        end
                        if down then
                            attempts+=1
                            if ranchUfoWaitFor(check,0.33) then
                                print(string.format(
                                    "[Ranch UFO] %s %s confirmed via angle=%d clicks=%d",
                                    tostring(stage),target.Name,index,attempts))
                                return true,"click confirmed"
                            end
                        end
                    else
                        -- Chapter 1/2 pickup method: viewport center,
                        -- stable Scriptable camera and short repeated clicks.
                        local atCenter=(pos-(camera.ViewportSize*0.5+Vector2.new(0,ranchGuiInsetY()))).Magnitude
                        if atCenter>18 then
                            print(string.format(
                                "[Ranch UFO] pickup %s angle=%d off-center %.1fpx",
                                target.Name,index,atCenter))
                        else
                            for pressIndex=1,2 do
                                if check() then return true,"confirmed before re-click" end
                                if not ranchUfoSafeToMove()or(stage=="pickup"and not ranchUfoPickupEligible(target))then
                                    return false,"interrupted"
                                end
                                camera.CameraType=Enum.CameraType.Scriptable
                                camera.CFrame=CFrame.lookAt(camPos,aim)
                                local down=false
                                local sent,err=pcall(function()
                                    VirtualInputManager:SendMouseMoveEvent(
                                        math.floor(pos.X+0.5),math.floor(pos.Y+0.5),game)
                                    RunService.RenderStepped:Wait()
                                    if not ranchUfoSafeToMove()or(stage=="pickup"and not ranchUfoPickupEligible(target))then return end
                                    camera.CameraType=Enum.CameraType.Scriptable
                                    camera.CFrame=CFrame.lookAt(camPos,aim)
                                    VirtualInputManager:SendMouseButtonEvent(
                                        math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                        0,true,game,0)
                                    down=true
                                    task.wait(0.085)
                                end)
                                if down then
                                    pcall(function()
                                        VirtualInputManager:SendMouseButtonEvent(
                                            math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                            0,false,game,0)
                                    end)
                                end
                                if not sent then
                                    ranchUfoNotice("Pickup click failed: "..tostring(err),true)
                                end
                                if down then
                                    attempts+=1
                                    if ranchUfoWaitFor(check,0.14) then
                                        print(string.format(
                                            "[Ranch UFO] pickup %s confirmed angle=%d click=%d viewport=(%.0f,%.0f)",
                                            target.Name,index,attempts,pos.X,pos.Y))
                                        return true,"click confirmed"
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.04)
            end
            ranchUfoNotice(string.format(
                "%s %s no state confirmation across %d angles (clicks=%d, occluded=%d)",
                tostring(stage),target.Name,#angles,attempts,occluded),true)
            return check(),"unconfirmed after angle sweep"
        end
        -- UfoPartsClient sends the part Instance for TAKE and no args for RETURN.
        -- Approach first; successful delivery alone never confirms progress.
        local function ranchUfoApproachRequest(target,root,check,remoteName,argument)
            if check() then return true end
            if remoteName=="PickUpPart"and not ranchUfoPickupEligible(target)then return false end
            if not target or not root or not root.Parent or not ranchUfoSafeToMove() then return false end
            local model=ranchUfoModel()
            local center=remoteName=="ReturnPart" and model and model:GetPivot().Position or target.Position
            local offset=root.Position-center
            local horizontal=Vector3.new(offset.X,0,offset.Z)
            local direction=horizontal.Magnitude>0.01 and horizontal.Unit or Vector3.new(1,0,0)
            local stand=center+direction*3+Vector3.new(0,1.15,0)
            root.CFrame=CFrame.lookAt(stand,Vector3.new(center.X,stand.Y,center.Z))
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
            task.wait(0.15)
            if check() then return true end
            if remoteName=="PickUpPart"and not ranchUfoPickupEligible(target)then return false end
            if not ranchUfoSafeToMove() or not target.Parent or not root.Parent then return false end
            -- Match the client proximity checks using the actual position after moving.
            if remoteName=="ReturnPart" then center=model:GetPivot().Position else center=target.Position end
            local maxDistance=remoteName=="ReturnPart" and 30 or 14
            if (root.Position-center).Magnitude>maxDistance then return false end
            local sent
            if ufoDiagnostics then ufoDiagnostics.Record("InteractionRequest",function()return {Action=remoteName,Target=target,Distance=(root.Position-center).Magnitude,Carrying=ranchUfoCarried(),Returned=ranchUfoReturned(model)}end)end
            if remoteName=="ReturnPart" then sent=ranchUfoRemote("ReturnPart")
            else sent=ranchUfoRemote("PickUpPart",argument) end
            if sent and ranchUfoWaitFor(check,0.85) then return true end
            return check()
        end
        local function ranchUfoPickup(part,root,camera)
            local name=part.Name
            local function received()
                return ranchUfoCarried()==name
                    or part:GetAttribute("HeldBy")==LocalPlayer.UserId
                    or part:GetAttribute("HeldBy")==tostring(LocalPlayer.UserId)
            end
            if received() then return true end
            if ranchUfoApproachRequest(part,root,received,"PickUpPart",part) then return true end
            if not ranchUfoSafeToMove()or not ranchUfoPickupEligible(part)then return false end
            -- Chapter 2's reliable key pickup disables nearby hay queries
            -- and collisions JUST during targeting. A revealed UFO piece
            -- can overlap the same hay. Restore everything without exception
            -- before returning so normal farming remains unaffected.
            local filtered={}
            local filteredCount=0
            local function suppressHayBlockers()
                for _,folderName in ipairs({"HaystackClient","HaystackCollision"}) do
                    local folder=Workspace:FindFirstChild(folderName)
                    if folder then
                        for _,obj in ipairs(folder:GetDescendants()) do
                            if filteredCount>=48 then break end
                            if obj:IsA("BasePart") and obj~=part
                                and obj:GetAttribute("IsNeedleObjective")~=true
                                and (obj.CanQuery or obj.CanCollide)
                                and (obj.Position-part.Position).Magnitude <=
                                    7+math.min(obj.Size.Magnitude*0.5,4) then
                                local wasQuery,wasCollide=obj.CanQuery,obj.CanCollide
                                local ok=pcall(function()
                                    obj.CanCollide=false
                                    obj.CanQuery=false
                                end)
                                if ok then
                                    filtered[obj]={query=wasQuery,collide=wasCollide}
                                    filteredCount+=1
                                else
                                    pcall(function()
                                        obj.CanQuery=wasQuery
                                        obj.CanCollide=wasCollide
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            local function restoreHayBlockers()
                for obj,was in pairs(filtered) do
                    if obj.Parent then
                        pcall(function()
                            obj.CanQuery=was.query
                            obj.CanCollide=was.collide
                        end)
                    end
                end
                table.clear(filtered)
            end
            local clickDetector=part:FindFirstChildWhichIsA("ClickDetector",true)
            ranchUfoNotice(string.format(
                "Revealed part %s: query=%s detector=%s (screen aim fallback after client pickup request)",
                name,tostring(part.CanQuery),
                tostring(clickDetector and clickDetector:GetFullName() or "none")))
            local callOK,clicked,why=xpcall(function()
                suppressHayBlockers()
                if filteredCount>0 then
                    print("[Ranch UFO] Filtered "..filteredCount..
                        " nearby hay blockers for pickup of "..name)
                end
                return ranchUfoWorldClick(part,root,camera,received,"pickup")
            end,function(err) return tostring(err) end)
            restoreHayBlockers()
            if not callOK then
                ranchUfoNotice("Pickup camera failed: "..tostring(clicked),true)
                return received()
            end
            if clicked or received() then return true end
            if why=="interrupted" then return false end
            -- Only one existing remote fallback; delivery is NOT treated as
            -- successful unless the replicated carrying state confirms it.
            if ranchUfoSafeToMove()and ranchUfoPickupEligible(part)then
                local sent=ranchUfoRemote("PickUpPart",part)
                if sent and ranchUfoWaitFor(received,0.65) then return true end
            end
            return received()
        end
        local function ranchUfoAttach(model,root,camera)
            local carrying=ranchUfoCarried()
            if not carrying then return false end
            local before=ranchUfoReturned(model)
            local piece=ranchUfoModelPiece(model,carrying)
            local function attached()
                return ranchUfoReturned(model)>before
                    or (piece and piece:GetAttribute("Returned")==true)
            end
            local main=ranchUfoMainPart(model)
            if not main then
                ranchUfoNotice("UFO Main attach surface not found",true)
                return false
            end
            if ranchUfoApproachRequest(main,root,attached,"ReturnPart") then return true end
            if not ranchUfoSafeToMove() then return false end
            ranchUfoNotice("Carrying "..carrying.."; attaching from alternate angles")
            local clicked,why=ranchUfoWorldClick(main,root,camera,attached,"attach")
            if clicked then return true end
            if why=="interrupted" then return false end
            -- No FireServer call is regarded as a confirmed attachment.
            if ranchUfoSafeToMove() then
                local sent=ranchUfoRemote("ReturnPart")
                if sent and ranchUfoWaitFor(attached,0.75) then return true end
            end
            return attached()
        end
        task.spawn(function()
            local lastStatus
            while not hubUnloaded do
                workerWake.Wait(0.10,not sharedFarmState.AutoGrabAttachUfoParts,"AutoGrabAttachUfoParts")
                if hubUnloaded then break end
                local tickOK,tickError=pcall(function()
                local observed=ranchUfoUpdateStatus()
                if observed and sharedFarmState.AutoGrabAttachUfoParts and not ranchUfoBusy
                    and os.clock()>=ranchUfoNextActionAt and ranchUfoSafeToMove() then
                    local model=observed.Model
                    if model and model:GetAttribute("Repaired")~=true
                        and ranchUfoReturned(model) <
                            (tonumber(model:GetAttribute("PartsTotal")) or 7) then
                        local carrying=observed.Carrying
                        local piece=not carrying and observed.Piece or nil
                        if carrying or piece then
                            ranchUfoBusy=true
                            ranchUfoStatusText=carrying and ("Attaching "..carrying) or ("Picking up "..piece.Name)
                            releaseSharedVacuum()
                            local root=farmRoot()
                            local camera=Workspace.CurrentCamera
                            local originalRoot=root and root.CFrame
                            local originalCamType=camera and camera.CameraType
                            local originalCamSubject=camera and camera.CameraSubject
                            local originalCamCF=camera and camera.CFrame
                            local attached=false
                            local pickedUp=false
                            local label=carrying or (piece and piece.Name) or "unknown"
                            local ok,err=xpcall(function()
                                if not root or not camera then return end
                                if carrying then
                                    attached=ranchUfoAttach(model,root,camera)
                                elseif piece then
                                    pickedUp=ranchUfoPickup(piece,root,camera)
                                    if pickedUp and ranchUfoSafeToMove() then
                                        -- Keep camera/root in-place while
                                        -- attaching so the server sees a
                                        -- contiguous carried-part sequence.
                                        attached=ranchUfoAttach(model,root,camera)
                                    end
                                end
                            end,function(e) return tostring(e) end)
                            if camera and camera.Parent then
                                pcall(function()
                                    camera.CameraSubject=originalCamSubject
                                    camera.CameraType=originalCamType
                                    camera.CFrame=originalCamCF
                                end)
                            end
                            if root and root.Parent and originalRoot then
                                pcall(function()
                                    root.CFrame=originalRoot
                                    root.AssemblyLinearVelocity=Vector3.zero
                                    root.AssemblyAngularVelocity=Vector3.zero
                                end)
                            end
                            ranchUfoBusy=false
                            if not ok then
                                ranchUfoNotice("Pickup/attach error: "..tostring(err),true)
                            end
                            local stillCarrying=ranchUfoCarried()
                            if attached then
                                if ufoDiagnostics then ufoDiagnostics.Record("AttachmentConfirmed",function()return {Part=label,PartsReturned=ranchUfoReturned(model)}end)end
                                ranchUfoFailureCount[label]=nil
                                ranchUfoFailedUntil[label]=nil
                                ranchUfoNotice(string.format(
                                    "UFO piece %s ATTACHED (PartsReturned=%d)",
                                    label,ranchUfoReturned(model)))
                                ranchUfoNextActionAt=os.clock()+0.60
                            elseif stillCarrying or pickedUp then
                                -- Pickup succeeded: do NOT mark as a failure
                                -- or apply the per-part pickup cooldown.
                                ranchUfoFailureCount[label]=nil
                                ranchUfoFailedUntil[label]=nil
                                ranchUfoNextActionAt=os.clock()+0.35
                                ranchUfoNotice(label..
                                    " PICKED UP; attachment pending (held="..
                                    tostring(stillCarrying)..")")
                            elseif not ranchUfoSafeToMove() then
                                -- Cutscene, puzzle opening, toggle OFF, or
                                -- user opening the menu is not a pickup fail.
                                ranchUfoNextActionAt=os.clock()+0.40
                            else
                                local failures=(ranchUfoFailureCount[label] or 0)+1
                                ranchUfoFailureCount[label]=failures
                                local cooldown=math.min(12,2*failures)
                                ranchUfoFailedUntil[label]=os.clock()+cooldown
                                ranchUfoNextActionAt=os.clock()+math.min(2,cooldown)
                                ranchUfoNotice(string.format(
                                    "%s pickup still unconfirmed (attempt=%d, retry=%ds, carried=%s, returned=%d)",
                                    label,failures,cooldown,tostring(stillCarrying),
                                    ranchUfoReturned(model)),true)
                            end
                        end
                    end
                end
                end)
                if not tickOK then
                    ranchUfoStatusText="UFO worker error: "..tostring(tickError)
                    ranchUfoNotice(ranchUfoStatusText,true)
                    task.wait(1)
                end
                local display=ranchUfoStatusText..(hubWindow.Closed and "" or " (menu paused)")
                if ranchUfoStatusLabel and display~=lastStatus then
                    lastStatus=display
                    pcall(function() ranchUfoStatusLabel:SetDesc(display) end)
                end
            end
        end)

        end
        runRanchUfoAutomation()

        local tab=hubWindow:Tab({Title="Chapter 3 / Ranch",Icon="construction"})
        tab:Section({Title="UFO part collection"})
        local createdUfoDiagnostics=createFeatureDiagnostics({Tab=DiagnosticsTab,Registry=Registry,Title="UFO Collection Diagnostics",Key="UfoCollectionDiagnostics",File="chapter3_ufo_diagnostics",Player=LocalPlayer,Alive=function()return not hubUnloaded end,Menu=function()return hubWindow.Closed end,Write=safeWrite})
        ufoDiagnostics=createdUfoDiagnostics
        ufoDiagnostics.Probe=function()return ranchUfoDiagnostic()end
        farmToggle(tab,"AutoGrabAttachUfoParts","Auto Grab & Attach UFO Parts",
            "Automatically picks up revealed UFO pieces, approaches the UFO and attaches them. Confirms ownership and PartsReturned; starts OFF for testing.")
        ranchUfoStatusLabel=tab:Paragraph({Title="UFO Pickup / Attach Status",Desc=ranchUfoStatusText})
        DiagnosticsTab:Button({Title="Export UFO Pickup Diagnostics",Callback=function()
            local ok,err=pcall(function()
                local data=ranchUfoDiagnostic()
                local json=httpService:JSONEncode(data)
                local path=CACHE_FOLDER.."/ufo_pickup_diagnostic.json"
                safeWrite(path,json)
                if type(setclipboard)=="function" then pcall(setclipboard,json) end
                print("[Ranch UFO] "..ranchUfoStatusText.." | diagnostic: "..path)
            end)
            if not ok then warn("[Ranch UFO] Diagnostic failed: "..tostring(err)) end
        end})
        tab:Section({Title="UFO puzzle automation"})
        farmToggle(tab,"AutoSolveRanchPuzzles","Auto Solve Ranch Puzzles",
            "Auto-drag matching wires, remove vent hay, and align laser when puzzle opens. OFF lets you test whether the game completes idle puzzles on its own.")
        tab:Button({
            Title="Test Instant Puzzle Completion (once)",
            Callback=ranchInstantCompletionProbe,
        })
        tab:Paragraph({
            Title="Ranch Puzzle Status",
            Desc="Use Auto Solve OFF and leave a puzzle untouched to measure built-in idle completion. Console logs time open, automated drags and instant probes. PuzzleDone() without arguments was not confirmed by tests.",
        })
        tab:Button({
            Title="Inspect Ranch puzzle and boss objects",
            Callback=function()
                local names={}
                for _, root in ipairs({Workspace,ReplicatedStorage}) do
                    for _, obj in ipairs(root:GetChildren()) do
                        if obj.Name:lower():find("puzzle",1,true)
                            or obj.Name:lower():find("boss",1,true)
                            or obj.Name:lower():find("ranch",1,true)
                            or obj.Name:lower():find("combat",1,true) then
                            names[#names+1]=root.Name.."."..obj.Name.." ("..obj.ClassName..")"
                        end
                    end
                end
                print("[BeyyHub Ranch] Discovery roots: "..(#names>0 and table.concat(names," | ") or "none found; run detailed Ranch dump"))
            end,
        })

        local previousRanchCleanup=_G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP=function()
            if previousRanchCleanup then pcall(previousRanchCleanup) end
            ranchReleaseMouse()
        end
    end
    installRanchOptions()
-- Owns TNT during boss combat; existing hay TNT runs outside the encounter.
local function createBossHeadTnt(options)
    local player,world=options.Player,options.World
    local pending,nextLightAt,lastStatus=nil,0,nil
    local connectedRemote,connection
    local function status(message)
        if message~=lastStatus then lastStatus=message; options.Status(message) end
    end
    local function locked()
        for _,flag in ipairs({"CutsceneActive","NeedleInputLocked","BossHeld","BossRagdolled","BossRagdollRecovering","BossKnockdownCamera"}) do
            if player:GetAttribute(flag)==true then return true end
        end
        return world:GetServerTimeNow()<(tonumber(player:GetAttribute("BossStunnedUntil")) or 0)
    end
    local function ready(boss)
        return options.Enabled() and not locked() and boss and boss:GetAttribute("BossWeakPoint")=="Head"
            and boss:GetAttribute("BossWeakPointDizzy")==true and boss:GetAttribute("BossVulnerable")==true
            and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0
    end
    local function windowEnd(boss)
        return tonumber(boss and boss:GetAttribute("BossStunEndsAt"))
    end
    local function bind(remote)
        if remote==connectedRemote then return end
        if connection then connection:Disconnect() end
        connectedRemote=remote; connection=nil
        if remote then
            connection=remote.OnClientEvent:Connect(function(kind,payload)
                local now=world:GetServerTimeNow()
                if kind=="lit" and pending and pending.stage=="lighting" then
                    pending.stage="lit"; pending.litAt=now
                    nextLightAt=now+pending.cooldown
                    status("Lit; preparing vulnerable-head throw")
                    options.Record("tnt_lit",{at=now,slot=player:GetAttribute("BossEquippedSlot")})
                elseif kind=="denied" and pending then
                    pending=nil; nextLightAt=math.max(nextLightAt,now+math.max(0.5,tonumber(payload) or 1))
                    status("Server denied TNT; waiting for retry")
                    options.Record("tnt_denied",{retry=payload})
                end
            end)
        end
    end
    local function trajectory(origin,target,minSpeed,maxSpeed,gravity)
        local delta=target-origin
        -- Earliest feasible ballistic path within the replicated throw-speed limits.
        for index=3,24 do
            local flight=index*0.025
            local velocity=delta/flight+Vector3.new(0,gravity*flight*0.5,0)
            if velocity.Magnitude>=minSpeed and velocity.Magnitude<=maxSpeed then return velocity,flight end
        end
    end
    local controller={}
    function controller.Tick()
        local remote=options.Remote()
        bind(remote)
        if not remote then status("Waiting for TNT remote"); return end
        local now=world:GetServerTimeNow()
        local boss=options.Boss()
        if pending and pending.boss~=boss then pending=nil end
        if pending then
            if pending.stage=="lighting" then
                if now-pending.requestAt>2 then
                    pending=nil; status("Lighting response timeout; waiting for cooldown")
                end
                return
            end
            if now>=pending.litAt+pending.fuse then pending=nil; status("Fuse elapsed; waiting for next window"); return end
            if not ready(boss) then status("Lit TNT: head window unavailable; throw withheld"); return end
            if now<pending.litAt+pending.lightTime then return end
            local head=player.Character and player.Character:FindFirstChild("Head")
            local root=boss:FindFirstChild("RootPart")
            local bone=root and root:FindFirstChild("Head",true)
            if not head or not bone or not bone:IsA("Bone") then status("Waiting for head geometry"); return end
            local origin=head.CFrame*CFrame.new(0.8,-0.8,-1.5)
            local target=bone.TransformedWorldCFrame.Position
            local velocity,flight=trajectory(origin.Position,target,pending.minSpeed,pending.maxSpeed,world.Gravity)
            if not velocity then status("Head outside feasible TNT trajectory"); return end
            local ends=windowEnd(boss)
            -- Reserve time for both impact and explosion, plus replication margin.
            local explosionAt=pending.litAt+pending.fuse
            if not ends or math.max(now+flight,explosionAt)+0.2>=ends then status("Window too short; throw withheld"); return end
            if now+flight>=explosionAt-0.1 then status("Fuse too short for head impact; throw withheld"); return end
            local ok,err=pcall(function() remote:FireServer("throw",origin,velocity) end)
            options.Record("tnt_throw",{sent=ok,error=not ok and tostring(err) or nil,flight=flight,
                fuseRemaining=explosionAt-now,windowRemaining=ends-now,slot=player:GetAttribute("BossEquippedSlot")})
            pending=nil
            status(ok and "Thrown at vulnerable head; awaiting hit feedback" or "TNT throw error")
            return
        end
        if not options.Enabled() then status("Boss TNT disabled / menu open"); return end
        if player:GetAttribute("TntOwned")~=true then status("TNT not owned"); return end
        if now<nextLightAt then status("Waiting for TNT cooldown"); return end
        if not ready(boss) then status("Waiting for vulnerable head"); return end
        local cfg=options.Config()
        local fuse=tonumber(options.BossConfig.TntFuse) or (cfg and tonumber(cfg.TNT_FUSE_TIME))
        local light=cfg and tonumber(cfg.TNT_LIGHT_TIME)
        local minSpeed=cfg and tonumber(cfg.TNT_MIN_THROW_SPEED)
        local maxSpeed=cfg and tonumber(cfg.TNT_MAX_THROW_SPEED)
        if not fuse or fuse<=0 or not light or light<0 or not minSpeed or not maxSpeed or maxSpeed<minSpeed then
            status("Waiting for replicated TNT timing / speed config"); return
        end
        local ends=windowEnd(boss)
        if not ends or now+fuse+0.4>=ends then status("Head window too short to light TNT"); return end
        local head=player.Character and player.Character:FindFirstChild("Head")
        local body=boss:FindFirstChild("RootPart")
        local bone=body and body:FindFirstChild("Head",true)
        if not head or not bone or not bone:IsA("Bone") then return end
        local origin=head.CFrame*CFrame.new(0.8,-0.8,-1.5)
        if not trajectory(origin.Position,bone.TransformedWorldCFrame.Position,minSpeed,maxSpeed,world.Gravity) then
            status("Head outside feasible TNT trajectory"); return
        end
        local cooldown=math.max(0.5,tonumber(player:GetAttribute("TntCooldown")) or tonumber(options.BossConfig.TntCooldown) or 10)
        pending={stage="lighting",boss=boss,requestAt=now,fuse=fuse,lightTime=light,minSpeed=minSpeed,maxSpeed=maxSpeed,cooldown=cooldown}
        -- Reserve cooldown even if a reply is lost; never spam light while awaiting acknowledgement.
        nextLightAt=now+cooldown
        local ok,err=pcall(function() remote:FireServer("light") end)
        options.Record("tnt_light",{sent=ok,error=not ok and tostring(err) or nil,slot=player:GetAttribute("BossEquippedSlot")})
        if not ok then pending=nil end
        status(ok and "Lighting TNT; awaiting server acknowledgement" or "TNT light error")
    end
    function controller.Stop()
        pending=nil
        if connection then connection:Disconnect(); connection=nil end
    end
    return controller
end

    local function installChapter3Boss()
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Input=game:GetService("VirtualInputManager")
local player=Players.LocalPlayer
if not player then return end
if type(_G.__BEYY_WEAK_TEST_STOP)=="function" then pcall(_G.__BEYY_WEAK_TEST_STOP) end
local tab=hubWindow:Tab({Title="Chapter 3 Boss",Icon="swords"})
farmToggle(tab,"AutoBossFight","Auto Boss Fight")
farmToggle(tab,"AutoBossBodyHits","Body Hits Between Weak Points")
farmToggle(tab,"AutoBossGrabEscape","Auto Grab Escape")
farmToggle(tab,"AutoBossFinish","Auto Key Pickup & Finish")
farmToggle(DiagnosticsTab,"BossDiagnostics","Boss Diagnostics")
local statusLabel=tab:Paragraph({Title="Boss Status",Desc="Auto Boss Fight is OFF"})
local tntLabel=tab:Paragraph({Title="Boss TNT Status",Desc="Waiting for vulnerable head"})
local vacuumLabel=tab:Paragraph({Title="Boss Vacuum Status",Desc="Waiting for boss"})
local roundLabel=tab:Paragraph({Title="Round End Status",Desc="Waiting for completion"})
local active=true
local connections,bones={},{}
local currentBoss
local nextSend=0
local started=os.clock()
local trace={version=1,integrated=true,events={},vacuumSamples={},roundEndEvents={},attempts=0,bodyAttempts=0,weakAttempts=0,
    grabInputs=0,confirmedHits=0,reportedDamage=0}
local lastStatus
local lastRangeNotice=-math.huge
local grabSession
local nextVacuumSample=0
local vacuumLastHeat,vacuumProgressAt,vacuumState
local finishedEncounter=false
local observedBoss
local observedEncounter
local postFight=false
local postFightDeadline=0
local nextKeyAttempt=0
local keyInputHeld
local walkingHumanoid
local monitoringFinish=false
local finishMonitorDeadline=0
local roundWatched={}
local nextRoundSave=0
local config={PitchforkRange=13,PitchforkCooldown=0.85}
local fight=RS:FindFirstChild("BossFight")
local configModule=fight and fight:FindFirstChild("Config")
if configModule then local ok,result=pcall(require,configModule); if ok and type(result)=="table" then config=result end end
local function log(message,details)
    bossFunctionsDiagnostics.Status("Boss",message)
    if details then bossFunctionsDiagnostics.Record("BossFunction",function()return {Message=message,Details=details}end)end
    if message==lastStatus and not details then return end
    lastStatus=message
    pcall(function() statusLabel:SetDesc(message) end)
    if sharedFarmState.BossDiagnostics then print("[Boss] "..message) end
    if #trace.events<2048 then
        trace.events[#trace.events+1]={at=os.clock()-started,status=message,details=details}
    else trace.droppedEvents=(trace.droppedEvents or 0)+1 end
end
local function saveTrace(force)
    if not force and not sharedFarmState.BossDiagnostics then return end
    if type(writefile)=="function" then
        pcall(function()
            if type(makefolder)=="function" then pcall(makefolder,"BeyyHub") end
            writefile("BeyyHub/chapter3_boss_integrated.json",Http:JSONEncode(trace))
        end)
    end
end
local function encodeRoundValue(value,depth,seen)
    depth=depth or 0; seen=seen or {}
    local kind=typeof(value)
    if kind=="nil" or kind=="boolean" then return value end
    if kind=="number" then return value==value and math.abs(value)<math.huge and value or tostring(value) end
    if kind=="string" then return value:sub(1,1000) end
    if kind=="Instance" then return {path=value:GetFullName(),class=value.ClassName} end
    if kind=="Vector3" then return {x=value.X,y=value.Y,z=value.Z} end
    if kind=="table" then
        if depth>=4 or seen[value] then return "[bounded table]" end
        seen[value]=true
        local result,count={},0
        for key,item in pairs(value) do
            count+=1; if count>40 then result.__truncated=true; break end
            result[tostring(key)]=encodeRoundValue(item,depth+1,seen)
        end
        seen[value]=nil; return result
    end
    return tostring(value)
end
local function recordRound(kind,path,payload)
    if not active then return end
    local row={at=os.clock()-started,serverTime=WS:GetServerTimeNow(),kind=kind,path=path,payload=encodeRoundValue(payload)}
    if #trace.roundEndEvents<128 then trace.roundEndEvents[#trace.roundEndEvents+1]=row
    else trace.droppedRoundEvents=(trace.droppedRoundEvents or 0)+1 end
    pcall(function() roundLabel:SetDesc(kind..": "..path) end)
    if sharedFarmState.BossDiagnostics then print("[Round Monitor] "..kind..": "..path) end
    saveTrace()
end
local function monitorAttribute(obj,name)
    local entry=roundWatched[obj]
    if not entry then entry={}; roundWatched[obj]=entry end
    if entry[name] then return end
    entry[name]=true
    recordRound("attribute_initial",obj:GetFullName().."."..name,obj:GetAttribute(name))
    connections[#connections+1]=obj:GetAttributeChangedSignal(name):Connect(function()
        recordRound("attribute_changed",obj:GetFullName().."."..name,obj:GetAttribute(name))
    end)
end
local function monitorRemote(remote)
    if not remote or roundWatched[remote] or not remote:IsA("RemoteEvent") then return end
    roundWatched[remote]=true
    recordRound("listener_ready",remote:GetFullName(),nil)
    connections[#connections+1]=remote.OnClientEvent:Connect(function(...)
        recordRound("server_event",remote:GetFullName(),table.pack(...))
    end)
end
local function refreshRoundMonitors()
    monitorAttribute(player,"NeedleRoundComplete")
    local folder=RS:FindFirstChild("NeedleHaystack")
    if folder then
        monitorRemote(folder:FindFirstChild("NeedleRoundCompleted"))
        monitorAttribute(folder,"RoundFinishedElapsed")
        monitorAttribute(folder,"RoundStartedAt")
    end
    local finish=RS:FindFirstChild("TruckFinish")
    if finish then
        for _,name in ipairs({"Cutscene","Blocked","Skip"}) do monitorRemote(finish:FindFirstChild(name)) end
    end
end
local bossTnt
local function stop()
    if bossTnt then bossTnt.Stop() end
    if not active then return end
    active=false
    trace.duration=os.clock()-started
    if walkingHumanoid then
        pcall(function()
            local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            walkingHumanoid:Move(Vector3.zero,false)
            if root then walkingHumanoid:MoveTo(root.Position) end
        end)
        walkingHumanoid=nil
    end
    if keyInputHeld then pcall(function() Input:SendKeyEvent(false,keyInputHeld,false,game) end); keyInputHeld=nil end
    for _,connection in ipairs(connections) do connection:Disconnect() end
    log("Stopped")
    saveTrace(true)
end
_G.__BEYY_C3_BOSS_STOP=stop
local previousBossCleanup=_G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP=function()
    stop()
    if previousBossCleanup then pcall(previousBossCleanup) end
end
DiagnosticsTab:Button({Title="Export Boss Diagnostics",Callback=function()
    saveTrace(true)
    if type(setclipboard)=="function" then pcall(function() setclipboard(Http:JSONEncode(trace)) end) end
end})
bossToolsBusy=function()
    if not active or not sharedFarmState.AutoBossFight then return false end
    if postFight then return true end
    local model=WS:FindFirstChild("HayGolem_Rig")
    local state=model and model:GetAttribute("BossState")
    return state~=nil and state~="" and state~="Sleeping" and state~="Unavailable" and state~="Returning"
end
local function beginKeyPickup()
    if postFight or finishedEncounter then return end
    if not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossFinish then return end
    postFight=true; postFightDeadline=os.clock()+60
    log("Boss defeated; waiting to collect neck key",{kind="key_start"})
end
local feedback=fight and fight:FindFirstChild("Feedback")
if feedback and feedback:IsA("RemoteEvent") then
    connections[#connections+1]=feedback.OnClientEvent:Connect(function(kind,userId,amount,position,tool,grade)
        if kind=="Hit" and userId==player.UserId and tool=="TNT" then
            log("Server TNT hit: "..tostring(amount).." ("..tostring(grade or "Normal")..")",
                {kind="tnt_hit",amount=amount,grade=grade or "Normal",bossEquippedSlot=player:GetAttribute("BossEquippedSlot")})
        elseif kind=="Hit" and userId==player.UserId and tool=="Pitchfork" then
            trace.confirmedHits+=1
            trace.reportedDamage+=tonumber(amount) or 0
            log("Server pitchfork hit: "..tostring(amount).." ("..tostring(grade or "Normal")..")",
                {kind="hit",amount=amount,grade=grade or "Normal",bossEquippedSlot=player:GetAttribute("BossEquippedSlot")})
        elseif kind=="GrabPrompts" and type(userId)=="table" and type(userId.prompts)=="table" then
            grabSession={id=userId.id,prompts=userId.prompts,good=tonumber(userId.good) or 0.3,
                needed=tonumber(userId.needed) or 3,sent={},successes=0}
            log("Grab prompts received",{kind="grab_prompts",id=grabSession.id,needed=grabSession.needed})
        elseif kind=="AttackFX" and type(amount)=="table" then
            if grabSession and amount.id==grabSession.id then
                if userId=="GrabProgress" and amount.userId==player.UserId then
                    grabSession.successes=tonumber(amount.successes) or grabSession.successes
                    log("Server grab progress: "..tostring(amount.grade),
                        {kind="grab_progress",index=amount.index,grade=amount.grade,successes=grabSession.successes,misses=amount.misses})
                elseif userId=="Cancel" or ((userId=="GrabRelease" or userId=="GrabHurl") and amount.userId==player.UserId) then
                    log("Grab ended: "..tostring(amount.reason or userId),{kind="grab_end",reason=amount.reason or userId})
                    grabSession=nil
                end
            end
        elseif kind=="BossEvent" and userId=="Defeated" then beginKeyPickup() end
    end)
end
connections[#connections+1]=player.OnTeleport:Connect(stop)
bossTnt=createBossHeadTnt({
    Player=player,World=WS,BossConfig=config,
    Enabled=function() return active and not hubUnloaded and sharedFarmState.AutoBossFight
        and sharedFarmState.AutoUseTNT and hubWindow.Closed and not postFight and not monitoringFinish end,
    Boss=function() return WS:FindFirstChild("HayGolem_Rig") end,
    Remote=function() local folder=RS:FindFirstChild("NeedleHaystack"); local remote=folder and folder:FindFirstChild("TntAction"); return remote and remote:IsA("RemoteEvent") and remote or nil end,
    Config=function() return sharedGameConfig end,
    Status=function(message) bossFunctionsDiagnostics.Status("TNT",message);pcall(function() tntLabel:SetDesc(message) end) end,
    Record=function(kind,details) details.kind=kind; log(kind,details) end,
})
bossFunctionsDiagnostics.Probe=function()
    local rig=WS:FindFirstChild("HayGolem_Rig")
    return {Fight=sharedFarmState.AutoBossFight,BodyHits=sharedFarmState.AutoBossBodyHits,GrabEscape=sharedFarmState.AutoBossGrabEscape,Finish=sharedFarmState.AutoBossFinish,TNT=sharedFarmState.AutoUseTNT,Vacuum=sharedFarmState.AutoUseVacuum,PostFight=postFight,FinishMonitoring=monitoringFinish,EncounterFinished=finishedEncounter,GrabSession=grabSession and {Needed=grabSession.needed,Successes=grabSession.successes},Boss=rig and rig:GetAttributes(),Counters={Requests=trace.attempts,GrabInputs=trace.grabInputs,ConfirmedFeedback=trace.confirmedHits,ReportedDamage=trace.reportedDamage},Status=lastStatus}
end
local function tickGrab()
    if not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossGrabEscape or not hubWindow.Closed then return end
    local session=grabSession
    if not session or session.successes>=session.needed then return end
    if player:GetAttribute("BossHeld")~=true then return end
    local boss=WS:FindFirstChild("HayGolem_Rig")
    if not boss or boss:GetAttribute("GrabVictim")~=player.UserId then return end
    local remote=fight and fight:FindFirstChild("GrabInput")
    if not remote or not remote:IsA("RemoteEvent") then return end
    local now=WS:GetServerTimeNow()
    for index,prompt in ipairs(session.prompts) do
        if not session.sent[index] then
            local perfectAt=tonumber(prompt.perfectAt)
            local shownAt=tonumber(prompt.shownAt)
            if not perfectAt or not shownAt or type(prompt.key)~="string" then session.sent[index]="invalid"
            elseif now>perfectAt+session.good then session.sent[index]="expired"
            elseif now>=shownAt and now>=perfectAt then
                session.sent[index]=true
                local ok,err=pcall(function() remote:FireServer(session.id,index,prompt.key,now) end)
                if ok then trace.grabInputs+=1 end
                log(ok and "Sent timed grab response: "..prompt.key or "Grab request error: "..tostring(err),
                    {kind="grab_input",index=index,key=prompt.key,offset=now-perfectAt,sent=ok})
                return
            else return end
        end
    end
end
local function sampleVacuum()
    local now=WS:GetServerTimeNow()
    if now<nextVacuumSample then return end
    nextVacuumSample=now+0.25
    local heat=tonumber(player:GetAttribute("VacuumHeat"))
    local activeVacuum=player:GetAttribute("VacuumActive")
    local overheated=player:GetAttribute("VacuumOverheated")
    local slot=player:GetAttribute("BossEquippedSlot")
    local boss=WS:FindFirstChild("HayGolem_Rig")
    local state="unknown"
    local locked=player:GetAttribute("BossHeld")==true or player:GetAttribute("BossRagdolled")==true
        or player:GetAttribute("BossKnockdownCamera")==true or player:GetAttribute("CutsceneActive")==true
        or player:GetAttribute("NeedleInputLocked")==true or now<(tonumber(player:GetAttribute("BossStunnedUntil")) or 0)
    if slot~=5 then state="not equipped"
    elseif locked then state="combat input locked"
    elseif overheated==true then state="overheated"
    elseif activeVacuum==false then state="inactive"
    elseif activeVacuum==true and heat then
        state="active"
        if not vacuumLastHeat or not vacuumProgressAt or math.abs(heat-vacuumLastHeat)>=0.002 then
            vacuumLastHeat=heat; vacuumProgressAt=now
        elseif now-vacuumProgressAt>=4 then state="suspected frozen heat" end
    end
    if state~="active" and state~="suspected frozen heat" then vacuumLastHeat=nil; vacuumProgressAt=nil end
    if #trace.vacuumSamples<400 then
        trace.vacuumSamples[#trace.vacuumSamples+1]={at=os.clock()-started,state=state,heat=heat,
            active=activeVacuum,overheated=overheated,slot=slot,bossHealth=boss and boss:GetAttribute("BossHealth"),
            vacuumState=player:GetAttribute("VacuumState")}
    end
    if state~=vacuumState then
        vacuumState=state
        pcall(function() vacuumLabel:SetDesc(state..(heat and string.format(" | heat %.0f%%",heat*100) or "")) end)
        log("Vacuum monitor: "..state,{kind="vacuum_state",state=state,heat=heat})
    end
end
local function tick()
    if not sharedFarmState.AutoBossFight or not hubWindow.Closed then return end
    local boss=WS:FindFirstChild("HayGolem_Rig")
    if boss~=currentBoss then currentBoss=boss; table.clear(bones) end
    if not boss then log("Waiting for boss"); return end
    if postFight then return end
    if boss:GetAttribute("BossState")=="Defeated" then beginKeyPickup(); return end
    local state=boss:GetAttribute("BossState")
    for _,excluded in ipairs({"Intro","Sleeping","Rising","Falling","Returning","Unavailable"}) do
        if state==excluded then log("Waiting: boss "..state); return end
    end
    local name=boss:GetAttribute("BossWeakPoint")
    local now=WS:GetServerTimeNow()
    local ends=tonumber(boss:GetAttribute("BossWeakPointEndsAt"))
    local dizzy=boss:GetAttribute("BossWeakPointDizzy")==true
    local weak=type(name)=="string" and name~="" and (not ends or now<ends or dizzy)
    if not weak and not sharedFarmState.AutoBossBodyHits then return end
    if not weak then name="Chest" end
    for _,flag in ipairs({"NeedleInputLocked","CutsceneActive","BossRagdolled","BossRagdollRecovering","BossKnockdownCamera","BossHeld"}) do
        if player:GetAttribute(flag)==true then log("Waiting: "..flag); return end
    end
    if now<(tonumber(player:GetAttribute("BossStunnedUntil")) or 0) then log("Waiting for stun to end"); return end
    if now<nextSend then return end
    local head=player.Character and player.Character:FindFirstChild("Head")
    local body=boss:FindFirstChild("RootPart")
    if not head or not body then log("Waiting for character / boss root"); return end
    local bone=bones[name]
    if not bone or not bone:IsDescendantOf(body) then
        bone=body:FindFirstChild(name,true)
        if (not bone or not bone:IsA("Bone")) and not weak then
            name="Pelvis"; bone=body:FindFirstChild(name,true)
        end
        if not bone or not bone:IsA("Bone") then log("Missing target bone: "..name); return end
        bones[name]=bone
    end
    local target=bone.TransformedWorldCFrame.Position
    local direction=target-head.Position
    local range=math.clamp(tonumber(player:GetAttribute("PitchforkReach")) or tonumber(config.PitchforkRange) or 13,tonumber(config.PitchforkRange) or 13,24)
    if direction.Magnitude>range then
        if os.clock()-lastRangeNotice>=1 then
            lastRangeNotice=os.clock()
            log(string.format("Move closer to %s: %.1f studs (limit %.1f)",name,direction.Magnitude,range))
        end
        return
    end
    if direction.Magnitude<0.01 then return end
    local folder=RS:FindFirstChild("NeedleHaystack")
    local remote=folder and folder:FindFirstChild("PitchforkDig")
    if not remote or not remote:IsA("RemoteEvent") then log("Waiting for PitchforkDig remote"); return end
    local ok,err=pcall(function() remote:FireServer("Boss",head.Position,direction.Unit) end)
    nextSend=now+math.max(0.1,tonumber(player:GetAttribute("PitchforkCooldown")) or tonumber(config.PitchforkCooldown) or 0.85)
    if ok then
        trace.attempts+=1
        if weak then trace.weakAttempts+=1 else trace.bodyAttempts+=1 end
        log("Sent cooldown-paced attempt at "..name.."; waiting for server hit feedback",
            {kind="attempt",target=name,targetType=weak and "weak" or "body",bossState=state,dizzy=dizzy,distance=direction.Magnitude,
             cooldown=nextSend-now,bossEquippedSlot=player:GetAttribute("BossEquippedSlot"),
             needleEquippedSlot=player:GetAttribute("NeedleEquippedSlot"),bossHealth=boss:GetAttribute("BossHealth")})
    else log("Request error: "..tostring(err)) end
end
local function walkPigCircle(center,character,root)
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if not humanoid then log("Circle skipped: Humanoid unavailable"); return false end
    local function movementDetails(target)
        local state="unknown"
        pcall(function() state=humanoid:GetState().Name end)
        local direction=humanoid.MoveDirection
        return {position={x=root.Position.X,y=root.Position.Y,z=root.Position.Z},
            target=target and {x=target.X,y=target.Y,z=target.Z} or nil,
            walkSpeed=humanoid.WalkSpeed,health=humanoid.Health,anchored=root.Anchored,
            humanoidState=state,sit=humanoid.Sit,platformStand=humanoid.PlatformStand,
            moveDirection=direction and {x=direction.X,y=direction.Y,z=direction.Z} or nil,
            cutsceneActive=player:GetAttribute("CutsceneActive"),inputLocked=player:GetAttribute("NeedleInputLocked"),
            bossHeld=player:GetAttribute("BossHeld"),ragdolled=player:GetAttribute("BossRagdolled"),
            knockdownCamera=player:GetAttribute("BossKnockdownCamera")}
    end
    walkingHumanoid=humanoid
    log("Walking one 360-degree circle with a 3-stud radius",{kind="circle_start",radius=3,movement=movementDetails()})
    local deadline=os.clock()+20
    -- MoveTo can finish within roughly one stud; use longer chords so the
    -- arrival tolerance does not immediately consume successive waypoints.
    for index=0,12 do
        if not active or not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossFinish or not hubWindow.Closed or player.Character~=character or not root.Parent or humanoid.Health<=0 then return false end
        local angle=index*math.pi*2/12
        local target=center+Vector3.new(math.cos(angle)*3,0,math.sin(angle)*3)
        humanoid:MoveTo(target)
        local legDeadline=math.min(deadline,os.clock()+3)
        local arrived=false
        repeat
            if not active or not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossFinish or not hubWindow.Closed or player.Character~=character or not root.Parent or humanoid.Health<=0 then return false end
            local offset=root.Position-target
            arrived=Vector3.new(offset.X,0,offset.Z).Magnitude<=1
            if arrived then break end
            task.wait(0.05)
        until os.clock()>=legDeadline
        if not arrived then log("Circle interrupted: walking path blocked or timed out",
            {kind="circle_failed",waypoint=index,movement=movementDetails(target)}); return false end
    end
    trace.pigCircleCompleted=true
    log("Completed 3-stud-radius circle",{kind="circle_complete",radius=3,laps=1})
    return true
end
local function tickKeyPickup()
    if not postFight or not active then return end
    if not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossFinish or not hubWindow.Closed then return end
    if os.clock()>=postFightDeadline then log("Key pickup timeout; teleport skipped"); finishedEncounter=true; postFight=false; saveTrace(true); return end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root then log("Waiting for character to collect key"); return end
    if player:GetAttribute("HasCarKey")==true then
        local destination=Vector3.new(-658.85,3.76,285.29)
        root.CFrame=CFrame.new(destination)
        root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
        trace.keyConfirmed=true; trace.teleportedToPig=true
        log("HasCarKey confirmed; teleported to pig coordinates",{kind="key_complete",destination={x=-658.85,y=3.76,z=285.29}})
        walkPigCircle(destination,character,root)
        if not active then return end
        if walkingHumanoid then
            pcall(function() walkingHumanoid:Move(Vector3.zero,false); walkingHumanoid:MoveTo(root.Position) end)
            walkingHumanoid=nil
        end
        finishedEncounter=true
        monitoringFinish=true; finishMonitorDeadline=os.clock()+60
        log("Round-end monitors remain active for 60 seconds",{kind="finish_monitor_start"})
        saveTrace(); return
    end
    if player:GetAttribute("CutsceneActive")==true or player:GetAttribute("NeedleInputLocked")==true
        or player:GetAttribute("BossHeld")==true or player:GetAttribute("BossRagdolled")==true then
        log("Waiting for post-fight input lock to clear"); return
    end
    if os.clock()<nextKeyAttempt then return end
    local boss=WS:FindFirstChild("HayGolem_Rig")
    local body=boss and boss:FindFirstChild("HayGolem_Body")
    local key=body and body:FindFirstChild("CarKey")
    local prompt=key and key:FindFirstChild("TakeKeyPrompt")
    if not key or not key:IsA("BasePart") or not prompt or not prompt:IsA("ProximityPrompt") then
        log("Waiting for neck key / TakeKeyPrompt"); return
    end
    if not prompt.Enabled then log("Waiting for neck key prompt to enable"); return end
    nextKeyAttempt=os.clock()+1.5
    local reach=math.min(3,math.max(0.5,prompt.MaxActivationDistance*0.5))
    local offset=root.Position-key.Position
    local horizontal=Vector3.new(offset.X,0,offset.Z)
    local direction=horizontal.Magnitude>0.01 and horizontal.Unit or Vector3.new(1,0,0)
    local stand=key.Position+direction*reach
    root.CFrame=CFrame.lookAt(stand,key.Position)
    root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
    task.wait(0.2)
    if not active or not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossFinish or not hubWindow.Closed or root~= (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then return end
    if player:GetAttribute("HasCarKey")==true then return end
    if not key.Parent or not prompt.Parent or not prompt.Enabled or (root.Position-key.Position).Magnitude>prompt.MaxActivationDistance then return end
    local ok,err=pcall(function()
        if type(fireproximityprompt)=="function" then fireproximityprompt(prompt)
        else
            keyInputHeld=prompt.KeyboardKeyCode
            Input:SendKeyEvent(true,keyInputHeld,false,game)
            task.wait(math.max(0,prompt.HoldDuration)+0.1)
        end
    end)
    if keyInputHeld then pcall(function() Input:SendKeyEvent(false,keyInputHeld,false,game) end); keyInputHeld=nil end
    log(ok and "Activated neck key prompt; waiting for HasCarKey" or "Key prompt error: "..tostring(err),
        {kind="key_attempt",sent=ok})
end
log("Auto Boss Fight is OFF")
task.spawn(function()
    local ok,err=pcall(function()
        while active and not hubUnloaded do
            local model=WS:FindFirstChild("HayGolem_Rig")
            local encounter=model and model:GetAttribute("Encounter")
            if model and (model~=observedBoss or observedEncounter~=encounter) then
                observedBoss=model; observedEncounter=encounter
                finishedEncounter=false; postFight=false; monitoringFinish=false; grabSession=nil
            end
            refreshRoundMonitors()
            bossTnt.Tick()
            if not sharedFarmState.AutoBossFight then
                log("Auto Boss Fight is OFF")
                if walkingHumanoid then
                    pcall(function() walkingHumanoid:Move(Vector3.zero,false) end)
                    walkingHumanoid=nil
                end
                task.wait(0.5)
                continue
            end
            if monitoringFinish then
                if os.clock()>=finishMonitorDeadline then log("Round-end monitor window finished"); monitoringFinish=false; postFight=false; postFightDeadline=0; task.wait(0.5) end
            elseif postFight then tickKeyPickup()
            else tickGrab(); if bossToolsBusy() then sampleVacuum() end; tick() end
            if os.clock()>=nextRoundSave then nextRoundSave=os.clock()+5; saveTrace() end
            task.wait(0.05)
        end
    end)
    if not ok then log("Test error: "..tostring(err)) end
    stop()
end)

    end
    installChapter3Boss()



    do
        local overview = overviewTab
-- Unskippable controller adapted from BeyyTU/needlehub chapter3.lua.
-- Reference blob: 35506fd60881344cadf11d99a4562d4b8fd20907; private runtime caches retained.
-- Optional read-only cutscene trace: bounded history, local exports, no gameplay actions.
local function createCutsceneDiagnostics(options)
    local api={Probe=nil,LastDecision="No controller observation yet"}
    local enabled,alive,pumping=false,true,false
    local ring,head,count,sequence,dropped={},1,0,0,0
    local dirty,nextSave,lastMismatch=false,0,-math.huge
    local expectedCamera,expectedFrame,lastWrite=nil,nil,nil
    local errors,lastDecisionKey=0,nil
    local lastCameraError=-math.huge
    local path=CACHE_FOLDER.."/"..tostring(__BEYY_MODULE):lower().."_cutscene_diagnostics.json"
    local function value(item,depth,seen)
        local kind=typeof(item)
        if kind=="nil"or kind=="boolean"then return item end
        if kind=="number"then return item==item and math.abs(item)<math.huge and item or tostring(item)end
        if kind=="string"then return item:sub(1,768)end
        if kind=="Vector3"then return {X=item.X,Y=item.Y,Z=item.Z}end
        if kind=="Instance"then return {Name=item.Name,Class=item.ClassName}end
        if kind~="table"then return "<"..kind..">"end
        depth=depth or 0;seen=seen or {}
        if depth>=5 or seen[item]then return "<bounded>"end
        seen[item]=true
        local result,total={},0
        for key,child in pairs(item)do
            total+=1;if total>40 then break end
            if type(key)=="string"or type(key)=="number"then result[key]=value(child,depth+1,seen)end
        end
        seen[item]=nil;return result
    end
    function api.Enabled()return alive and enabled and options.Alive()end
    function api.Record(kind,build)
        if not api.Enabled()then return end
        if kind=="CameraWriteError"then
            if os.clock()-lastCameraError<1 then return end
            lastCameraError=os.clock()
        end
        local ok,data=pcall(function()return value(type(build)=="function"and build()or build or {})end)
        if not ok then errors+=1;data={DiagnosticError=tostring(data):sub(1,512)}end
        sequence+=1
        local event={Sequence=sequence,At=os.clock(),Kind=kind,Data=data}
        if count<256 then ring[(head+count-1)%256+1]=event;count+=1
        else ring[head]=event;head=head%256+1;dropped+=1 end
        dirty=true
    end
    function api.Decision(build)
        if not api.Enabled()then return end
        local ok,data=pcall(build)
        if not ok then api.Record("DiagnosticError",{Error=tostring(data)});return end
        local key=tostring(data.Reason)..":"..tostring(data.Scene)..":"..tostring(data.Active)
        api.LastDecision=tostring(data.Reason)
        if key~=lastDecisionKey then lastDecisionKey=key;api.Record("Decision",data)end
    end
    function api.ClearCamera()expectedCamera,expectedFrame,lastWrite=nil,nil,nil end
    function api.CameraWritten(camera,frame)
        if api.Enabled()then expectedCamera,expectedFrame,lastWrite=camera,frame,os.clock()end
    end
    function api.Snapshot()
        local events={}
        for index=1,count do events[index]=ring[(head+index-2)%256+1]end
        local ok,current=pcall(function()
            return value({Base=options.Base(),Controller=api.Probe and api.Probe()or {Installed=false},
                LastCameraWriteAt=lastWrite,LastDecision=api.LastDecision})
        end)
        return {Schema=1,Module=__BEYY_MODULE,PlaceId=game.PlaceId,JobId=game.JobId,UserId=options.Player.UserId,
            ExportedAt=os.time(),Enabled=api.Enabled(),TotalEvents=sequence,DroppedEvents=dropped,
            DiagnosticErrors=errors,Capacity=256,Current=ok and current or {DiagnosticError=tostring(current):sub(1,512)},Events=events}
    end
    local status=options.Tab:Paragraph({Title="Cutscene Diagnostics Status",Desc="Off; no diagnostic capture"})
    local function export(manual)
        local ok,json=pcall(function()return options.Http:JSONEncode(api.Snapshot())end)
        if not ok then return false,"JSON encoding failed"end
        local wrote,saved=pcall(options.Write,path,json);saved=wrote and saved==true
        local copied=false
        if manual and type(setclipboard)=="function"then copied=pcall(setclipboard,json)end
        if saved then dirty=false end
        return saved or copied,(saved and ("Saved "..path)or "Could not save locally")..(copied and "; copied JSON to clipboard"or "")
    end
    function api.Export()
        local ok,message=export(true);status:SetDesc(message);return ok,message
    end
    function api.Tick()
        if not api.Enabled()then return end
        if expectedFrame and os.clock()-lastMismatch>=2 then
            local ok,mismatch=pcall(function()
                local camera=options.World.CurrentCamera
                if not camera then return {Reason="No current camera"}end
                local distance=(camera.CFrame.Position-expectedFrame.Position).Magnitude
                local dot=camera.CFrame.LookVector:Dot(expectedFrame.LookVector)
                if camera~=expectedCamera or camera.CameraType~=Enum.CameraType.Scriptable or distance>0.1 or dot<0.999 then
                    return {CameraChanged=camera~=expectedCamera,CameraType=tostring(camera.CameraType),PositionDelta=distance,LookDot=dot,
                        Note="Observed after last bypass write; may be another camera owner, not necessarily an error"}
                end
            end)
            if ok and mismatch then lastMismatch=os.clock();api.Record("CameraMismatch",mismatch)end
        end
        if dirty and os.clock()>=nextSave then nextSave=os.clock()+5;export(false)end
        status:SetDesc("Capturing | "..count.."/256 events | "..dropped.." overwritten | "..api.LastDecision)
    end
    local function pump()
        if pumping then return end;pumping=true
        task.spawn(function()
            while api.Enabled()do pcall(api.Tick);task.wait(0.5)end
            pumping=false
        end)
    end
    options.Registry.CutsceneDiagnostics=options.Tab:Toggle({Title="Unskippable Cutscene Diagnostics",Value=false,
        Callback=function(state)
            enabled=state==true
            if enabled then
                nextSave=os.clock()+5;lastDecisionKey=nil
                api.Record("DiagnosticsEnabled",function()return {Current=options.Base()}end)
                pump()
            else
                api.ClearCamera()
                if dirty then export(false)end
                status:SetDesc("Off; "..count.." recent events retained")
            end
        end})
    options.Tab:Button({Title="Export Cutscene Diagnostics",Callback=api.Export})
    function api.Stop()
        if dirty then export(false)end
        alive=false;enabled=false;api.Probe=nil;api.ClearCamera()
    end
    return api
end

local cutsceneDiagnostics=createCutsceneDiagnostics({
    Player=LocalPlayer,World=Workspace,Http=game:GetService("HttpService"),Tab=DiagnosticsTab,Registry=Registry,
    Alive=function()return not hubUnloaded end,Write=safeWrite,
    Base=function()
        local character=LocalPlayer.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local camera=Workspace.CurrentCamera
        return {BypassToggle=Registry.CutsceneBypass and Registry.CutsceneBypass.Value or false,MenuClosed=hubWindow.Closed,
            IntroFinished=LocalPlayer:GetAttribute("IntroCutsceneFinished"),CutsceneActive=LocalPlayer:GetAttribute("CutsceneActive"),
            Chapter2ReleaseActive=LocalPlayer:GetAttribute("Chapter2ReleaseActive"),NeedleOwned=LocalPlayer:GetAttribute("NeedleOwned"),
            NeedleInputLocked=LocalPlayer:GetAttribute("NeedleInputLocked"),RootPresent=root~=nil,RootAnchored=root and root.Anchored,
            Position=root and root.Position,WalkSpeed=humanoid and humanoid.WalkSpeed,JumpPower=humanoid and humanoid.JumpPower,
            PlatformStand=humanoid and humanoid.PlatformStand,Sit=humanoid and humanoid.Sit,
            CameraType=camera and tostring(camera.CameraType),CameraPosition=camera and camera.CFrame.Position,
            MouseBehavior=tostring(UserInputService.MouseBehavior)}
    end,
})
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
    if cutsceneBypassStop then return true end
    cutsceneDiagnostics.Record("ControllerStarting")
    local ok, result = pcall(function()

        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local workspace = Workspace
        local sin, cos, abs = math.sin, math.cos, math.abs
        local upAxis = Vector3.yAxis
        local cameraRaycastParams, cameraRaycastCharacter
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
        local lastSkipFallbackScan = 0
        local lastRenderTime = os.clock()

        local function log(s)
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
                    result = CFrame.lookAt(eye, eye + vec * 8, upAxis)
                    focus = eye + vec * 8
                    hideHeadForFirstPerson()
                else
                    local target = rt.Position + Vector3.new(0, 1.6, 0)
                    local desired = target - vec * distance
                    local params = cameraRaycastParams
                    if not params then
                        params = RaycastParams.new()
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        params.RespectCanCollide = true
                        cameraRaycastParams = params
                    end
                    if cameraRaycastCharacter ~= char then
                        params.FilterDescendantsInstances = char and {char} or {}
                        cameraRaycastCharacter = char
                    end
                    local hit = workspace:Raycast(target, desired - target, params)
                    if hit then
                        local hitDistance = (hit.Position - target).Magnitude
                        desired = target - vec * math.max(0.35, math.min(distance, hitDistance - 0.40))
                    end
                    result = CFrame.lookAt(desired, target, upAxis)
                    focus = target
                end
                cam.CameraType = Enum.CameraType.Scriptable
                local hum = humanoid()
                if hum then cam.CameraSubject = hum end
                cam.CFrame = result
                cutsceneDiagnostics.CameraWritten(cam,result)
                cam.Focus = CFrame.new(focus)
            end)
            inCameraWrite = false
            if not safe then cutsceneDiagnostics.Record("CameraWriteError",function()return {Error=tostring(err)}end)end
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
                    local before = hudNormal[gui]
                    if not before or before.enabled ~= gui.Enabled or before.order ~= gui.DisplayOrder then
                        hudNormal[gui] = { enabled = gui.Enabled, order = gui.DisplayOrder }
                    end
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
        -- Candidate discovery happens once per overlay, then follows GUI membership.
        local finalVisualIndex = {Gui = nil, Connections = {}, Screens = {}, Candidates = {}}
        local function clearFinalVisualIndex()
            for _, connection in ipairs(finalVisualIndex.Connections) do connection:Disconnect() end
            for _, entry in pairs(finalVisualIndex.Screens) do
                for _, connection in ipairs(entry.Connections) do connection:Disconnect() end
            end
            finalVisualIndex.Gui = nil
            table.clear(finalVisualIndex.Connections)
            table.clear(finalVisualIndex.Screens)
            table.clear(finalVisualIndex.Candidates)
        end
        local function watchFinalVisualGui(pg)
            if finalVisualIndex.Gui == pg then return end
            clearFinalVisualIndex(); finalVisualIndex.Gui = pg
            local function addScreen(gui)
                if not gui:IsA("ScreenGui") or finalVisualIndex.Screens[gui] then return end
                local entry = {Connections = {}, Objects = {}, Watching = false}
                finalVisualIndex.Screens[gui] = entry
                local function add(object)
                    local keys
                    if object:IsA("GuiObject") then
                        keys = {"BackgroundTransparency"}
                        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                            keys[#keys+1] = "TextTransparency"; keys[#keys+1] = "TextStrokeTransparency"
                        elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                            keys[#keys+1] = "ImageTransparency"
                        end
                    elseif object:IsA("UIStroke") then keys = {"Transparency"} end
                    if keys then
                        entry.Objects[object] = true; finalVisualIndex.Candidates[object] = keys
                    end
                end
                local function remove(object)
                    entry.Objects[object] = nil; finalVisualIndex.Candidates[object] = nil
                end
                local function refresh()
                    local matching = isFinalOverlay(gui)
                    if matching == entry.Watching then return end
                    entry.Watching = matching
                    if entry.Added then entry.Added:Disconnect(); entry.Removed:Disconnect() end
                    entry.Added, entry.Removed = nil, nil
                    for object in pairs(entry.Objects) do remove(object) end
                    if matching then
                        entry.Added = gui.DescendantAdded:Connect(add)
                        entry.Removed = gui.DescendantRemoving:Connect(remove)
                        for _, object in ipairs(gui:GetDescendants()) do add(object) end
                    end
                end
                entry.Connections[1] = gui:GetPropertyChangedSignal("Name"):Connect(refresh)
                -- These wrappers also disconnect the current membership connections.
                entry.Connections[2] = {Disconnect = function()
                    if entry.Added then entry.Added:Disconnect(); entry.Removed:Disconnect() end
                end}
                refresh()
            end
            local function removeScreen(gui)
                local entry = finalVisualIndex.Screens[gui]
                if not entry then return end
                for _, connection in ipairs(entry.Connections) do connection:Disconnect() end
                for object in pairs(entry.Objects) do finalVisualIndex.Candidates[object] = nil end
                finalVisualIndex.Screens[gui] = nil
            end
            finalVisualIndex.Connections[1] = pg.ChildAdded:Connect(addScreen)
            finalVisualIndex.Connections[2] = pg.ChildRemoved:Connect(removeScreen)
            for _, gui in ipairs(pg:GetChildren()) do addScreen(gui) end
        end
        local function hideFinalCutsceneVisuals()
            if not finalVisualsEnabled or not scene then return end
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then clearFinalVisualIndex(); return end
            watchFinalVisualGui(pg)
            for object, keys in pairs(finalVisualIndex.Candidates) do
                if object.Parent and object:IsDescendantOf(pg) then
                    for _, key in ipairs(keys) do maskFinalProperty(object, key) end
                end
            end
        end

        local function restoreFinalCutsceneVisuals()
            clearFinalVisualIndex()
            for inst, props in pairs(finalVisualBefore) do
                if inst.Parent then
                    for key, original in pairs(props) do
                        pcall(function() inst[key] = original end)
                    end
                end
                finalVisualBefore[inst] = nil
            end
        end

        local function skipButtonOnScreen()
            lastEndingSkipVisible=sharedSkipIndex.Find(false)~=nil
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
            cutsceneDiagnostics.Record("CameraRestore")
            cutsceneDiagnostics.ClearCamera()
            cameraRaycastParams, cameraRaycastCharacter = nil, nil
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
            cutsceneDiagnostics.Decision(function()
                local reason
                if not enabled then reason="Controller disabled"
                elseif shouldYieldCutsceneBypass() then reason="Menu/results/automation priority; see current state"
                elseif player:GetAttribute("IntroCutsceneFinished")==false then reason="Intro unfinished"
                elseif introConfirmedAt and now-introConfirmedAt<INTRO_SETTLE_SECONDS then reason="Intro settling"
                elseif yieldingToEnding then reason="Visible Skip/ending UI owns the camera"
                elseif current then reason="Bypassing "..current
                elseif now<recoveryEnd then reason="Recovery grace"
                else reason="No eligible unskippable scene flag"end
                return {Reason=reason,Scene=current,Active=active,RecoveryRemaining=math.max(0,recoveryEnd-now)}
            end)
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

        cutsceneDiagnostics.Probe=function()
            return {Installed=true,Alive=alive,Enabled=enabled,Active=active,Scene=scene,YieldingToEnding=yieldingToEnding,
                SkipVisible=lastEndingSkipVisible,PriorityYield=shouldYieldCutsceneBypass(),
                RecoveryRemaining=math.max(0,recoveryEnd-os.clock()),FirstPerson=cameraFirstPerson,
                CameraWriteError=cameraErrorWarned,PuzzleOrCandleBusy=sharedFarmPuzzleBusy()}
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
            cameraRaycastParams, cameraRaycastCharacter = nil, nil
            controls, lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil, nil
            task.delay(0.4, function() if alive and not active then rememberGameplay() end end)
        end))

        local function handleCameraInput()
            if not alive or not enabled or not active or not yaw then return end
            pcall(function()
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                end
            end)
            local ok, md = pcall(function() return UserInputService:GetMouseDelta() end)
            if ok and md then
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
            cutsceneDiagnostics.Record("ControllerStopped",cutsceneDiagnostics.Probe)
            cutsceneDiagnostics.Probe=nil
            cutsceneDiagnostics.ClearCamera()
            local wasActive = active
            alive, enabled, active = false, false, false
            cameraRaycastParams, cameraRaycastCharacter = nil, nil
            pcall(function() RunService:UnbindFromRenderStep(renderId) end)
            unwatchLeverCamera()
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
                task.wait((active or scene) and 0.1 or 0.35)
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
        cutsceneDiagnostics.Record("ControllerError",function()return {Error=tostring(result)}end)
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
    cutsceneDiagnostics.Stop()
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
            if hubUnloaded or not startupConfig then return end
            local ok, loaded, err = pcall(function() return buildConfig(startupConfig):Load() end)
            local success = ok and loaded ~= false and loaded ~= nil
            Notify("Config", success and ("Auto-loaded: " .. startupConfig)
                or ("Auto-load failed: " .. tostring(ok and err or loaded)), 3, success and "check" or "x")
        end)
    else
        SettingsTab:Paragraph({ Title = "Configs unavailable", Desc = "Saving configs requires filesystem support in your environment." })
    end
    end

    print("[BeyyHub] v103.00 " .. BEYY_CHAPTER .. " module loaded (RightControl to open)")
end


