local function createBossWeakpointPitchfork(options)
    local player,world=options.Player,options.World
    local active,nextSend,boss,root=true,0,nil,nil
    local bones,lastStatus={},nil
    local excluded={Sleeping=true,Intro=true,Rising=true,Falling=true,Returning=true,Unavailable=true,Defeated=true}
    local controller={}
    local function status(text)
        if text~=lastStatus then lastStatus=text;options.Status(text)end
    end
    function controller.IsEngaged()
        if not active or not options.Enabled()then return false end
        local rig=world:FindFirstChild("PumpkinGolem_Rig")
        local state=rig and rig:GetAttribute("BossState")
        return rig~=nil and type(state)=="string" and state~="" and not excluded[state]
            and rig:GetAttribute("BossHidden")~=true and (tonumber(rig:GetAttribute("BossHealth"))or 0)>0
    end
    function controller.Stop()active=false;table.clear(bones)end
    function controller.Tick()
        if not active then return end
        if not options.Enabled()then status("Disabled");return end
        if not controller.IsEngaged()then status("Waiting for active boss");return end
        if options.Blocked()then status("Paused for menu, cutscene or candle action");return end
        local rig=world:FindFirstChild("PumpkinGolem_Rig")
        local body=rig:FindFirstChild("RootPart")
        if rig~=boss or body~=root then boss,root=rig,body;table.clear(bones);nextSend=0 end
        local now=world:GetServerTimeNow()
        for _,flag in ipairs({"BossHeld","BossRagdolled","BossRagdollRecovering","BossKnockdownCamera"})do
            if player:GetAttribute(flag)==true then status("Waiting: "..flag);return end
        end
        if now<(tonumber(player:GetAttribute("BossStunnedUntil"))or 0)then status("Waiting for stun to end");return end
        if player:GetAttribute("PitchforkOwned")~=true then status("Waiting for pitchfork ownership");return end
        local name=rig:GetAttribute("BossWeakPoint")
        local ends=tonumber(rig:GetAttribute("BossWeakPointEndsAt"))
        local dizzy=rig:GetAttribute("BossWeakPointDizzy")==true
        if type(name)~="string" or name=="" or (ends and now>=ends and not dizzy)then status("Waiting for weak point");return end
        if name=="Head" and rig:GetAttribute("BossHeadless")==true then status("Waiting for attached weak point");return end
        local character=player.Character
        local head=character and character:FindFirstChild("Head")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not head or not humanoid or humanoid.Health<=0 or not body then status("Waiting for character or boss body");return end
        local bone=bones[name]
        if not bone or not bone:IsDescendantOf(body)then
            bone=body:FindFirstChild(name,true)
            if not bone or not bone:IsA("Bone")then status("Waiting for weak-point bone: "..name);return end
            bones[name]=bone
        end
        local direction=bone.TransformedWorldCFrame.Position-head.Position
        local range=math.clamp(tonumber(player:GetAttribute("PitchforkReach"))or 13,13,24)
        if direction.Magnitude>range then status(string.format("Move closer to %s (%.1f / %.1f studs)",name,direction.Magnitude,range));return end
        if direction.Magnitude<0.01 then return end
        if now<nextSend then return end
        local remote=options.Remote()
        if not remote then status("Waiting for PitchforkDig remote");return end
        local ok=pcall(remote.FireServer,remote,"Boss",head.Position,direction.Unit)
        nextSend=now+math.max(0.1,tonumber(player:GetAttribute("PitchforkCooldown"))or 0.85)
        status(ok and ("Targeting "..name.."; hit confirmation handled by server")or "Pitchfork request failed; retry pending")
    end
    return controller
end

-- Standalone Chapter 4 pitchfork diagnostics. Uses the same targeting helper as the hub.
if game.PlaceId~=102537610748607 then warn("[C4 Pitchfork Test] Run inside Chapter 4.");return end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
if not player then return end
local env=type(getgenv)=="function" and getgenv()or _G
if type(env.BeyyC4PitchforkTest)=="table" and type(env.BeyyC4PitchforkTest.Stop)=="function"then pcall(env.BeyyC4PitchforkTest.Stop)end
local active,enabled=true,true
local started=os.clock()
local connections={}
local SAVE_PATH="BeyyHub/chapter4_weakpoint_pitchfork_test.json"
local trace={version=1,placeId=game.PlaceId,jobId=game.JobId,startedUtc=os.time(),events={},samples={},
    attempts=0,requestsSent=0,confirmedPitchforkHits=0,reportedDamage=0,grades={},droppedEvents=0,droppedSamples=0}
local lastStatus,lastPrinted="Starting",nil
local controller,gui,label,counts,toggle
local watchedBoss,feedbackConnection,watchedFeedback
local lastAttempt,nextSample,nextSave= nil,0,0
local flags={"PitchforkOwned","PitchforkReach","PitchforkCooldown","PitchforkPhase","PitchforkHoldEnabled",
    "BossEquippedSlot","NeedleEquippedSlot","BossHeld","BossRagdolled","BossRagdollRecovering",
    "BossKnockdownCamera","BossStunnedUntil","NeedleInputLocked","CutsceneActive","HintViewerOpen",
    "CarryingCandle","VacuumActive","VacuumHeat"}
local function encode(value,depth,seen)
    depth=depth or 0;seen=seen or {}
    local kind=typeof(value)
    if kind=="nil"or kind=="boolean"then return value end
    if kind=="number"then return value==value and math.abs(value)<math.huge and value or tostring(value)end
    if kind=="string"then return value:sub(1,1500)end
    if kind=="Vector3"then return {x=value.X,y=value.Y,z=value.Z}end
    if kind=="CFrame"then return {position=encode(value.Position)}end
    if kind=="Instance"then return {path=value:GetFullName(),class=value.ClassName}end
    if kind=="table"then
        if depth>=5 or seen[value]then return "[bounded]"end
        seen[value]=true;local out,count={},0
        for k,v in pairs(value)do count+=1;if count>70 then out.__truncated=true;break end;out[tostring(k)]=encode(v,depth+1,seen)end
        seen[value]=nil;return out
    end
    return tostring(value)
end
local function record(kind,data)
    if #trace.events>=2000 then table.remove(trace.events,1);trace.droppedEvents+=1 end
    trace.events[#trace.events+1]={at=os.clock()-started,serverTime=WS:GetServerTimeNow(),kind=kind,data=encode(data)}
end
local function updateUI()
    if label then label.Text=lastStatus end
    if counts then counts.Text=string.format("Requests %d | Server hits %d | Damage %.0f",trace.requestsSent,trace.confirmedPitchforkHits,trace.reportedDamage)end
    if toggle then toggle.Text=enabled and "Pause attacks"or "Resume attacks"end
end
local function status(text)
    lastStatus=text
    if text~=lastPrinted then
        lastPrinted=text;record("gate_or_status",text)
        -- Keep distance updates visible without repeatedly printing every polling tick.
        if not text:find("Move closer",1,true)then print("[C4 Pitchfork Test] "..text)end
    end
    updateUI()
end
local function snapshot()
    local boss=WS:FindFirstChild("PumpkinGolem_Rig")
    local root=boss and boss:FindFirstChild("RootPart")
    local name=boss and boss:GetAttribute("BossWeakPoint")
    local bone=root and type(name)=="string"and root:FindFirstChild(name,true)
    local character=player.Character
    local head=character and character:FindFirstChild("Head")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local attributes={}
    for _,key in ipairs(flags)do attributes[key]=player:GetAttribute(key)end
    local target=bone and bone:IsA("Bone")and bone.TransformedWorldCFrame.Position
    return {status=lastStatus,enabled=enabled,boss=boss and boss:GetAttributes(),bossPath=boss and boss:GetFullName(),
        player=attributes,health=humanoid and humanoid.Health,origin=head and head.Position,
        target=target,bonePath=bone and bone:GetFullName(),boneClass=bone and bone.ClassName,
        boneWorldPosition=bone and bone:IsA("Bone")and bone.WorldPosition,
        distance=target and head and (target-head.Position).Magnitude,
        reach=math.clamp(tonumber(player:GetAttribute("PitchforkReach"))or 13,13,24),
        cooldown=math.max(0.1,tonumber(player:GetAttribute("PitchforkCooldown"))or 0.85)}
end
local function save()
    trace.duration=os.clock()-started;trace.lastStatus=lastStatus
    if type(writefile)~="function"then return false,"Executor writefile unavailable; trace remains in BeyyC4PitchforkTest.Trace"end
    local ok,err=pcall(function()
        if type(makefolder)=="function"then pcall(makefolder,"BeyyHub")end
        writefile(SAVE_PATH,Http:JSONEncode(trace))
    end)
    return ok,ok and SAVE_PATH or tostring(err)
end
local function stop()
    if not active then return end
    active=false;enabled=false
    if controller then controller.Stop()end
    for _,connection in ipairs(connections)do connection:Disconnect()end
    if feedbackConnection then feedbackConnection:Disconnect()end
    record("stopped",snapshot())
    local ok,path=save()
    if gui then gui:Destroy()end
    print("[C4 Pitchfork Test] Stopped. "..(ok and "Saved "or "Save unavailable: ")..path)
end
local function watchFeedback()
    local fight=RS:FindFirstChild("BossFight")
    local remote=fight and fight:FindFirstChild("Feedback")
    if remote==watchedFeedback then return end
    if feedbackConnection then feedbackConnection:Disconnect();feedbackConnection=nil end
    watchedFeedback=remote
    if not remote or not remote:IsA("RemoteEvent")then record("feedback_missing",{});return end
    record("feedback_listener",remote)
    feedbackConnection=remote.OnClientEvent:Connect(function(kind,userId,amount,position,tool,grade,...)
        if kind=="Hit"then
            record("server_hit",{kind=kind,userId=userId,amount=amount,position=position,tool=tool,grade=grade,
                latestOwnRequest=lastAttempt and lastAttempt.id,secondsSinceRequest=lastAttempt and os.clock()-lastAttempt.at,
                ownPlayer=userId==player.UserId,extra=table.pack(...)})
            if userId==player.UserId and tool=="Pitchfork"then
                trace.confirmedPitchforkHits+=1;trace.reportedDamage+=tonumber(amount)or 0
                local key=tostring(grade or "Normal");trace.grades[key]=(trace.grades[key]or 0)+1
                print(string.format("[C4 Pitchfork Test] SERVER HIT: %s damage | grade=%s | %.2fs since latest request",tostring(amount),key,lastAttempt and os.clock()-lastAttempt.at or -1))
                updateUI()
            end
        else
            -- Capture only combat-related feedback; avoid large cosmetic traffic.
            if kind~="AttackFX"and kind~="Sound"then record("server_feedback",{kind,userId,amount,position,tool,grade,...})end
        end
    end)
end
local proxy={}
function proxy:FireServer(kind,origin,direction)
    local folder=RS:FindFirstChild("NeedleHaystack")
    local remote=folder and folder:FindFirstChild("PitchforkDig")
    assert(remote and remote:IsA("RemoteEvent"),"PitchforkDig disappeared")
    trace.attempts+=1
    local sample=snapshot()
    local rayResult
    if sample.target then
        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={player.Character,WS:FindFirstChild("PumpkinGolem_Rig")}
        params.RespectCanCollide=true
        local hit=WS:Raycast(origin,sample.target-origin,params)
        if hit then rayResult={object=hit.Instance,position=hit.Position,distance=hit.Distance}end
    end
    local attempt={id=trace.attempts,snapshot=sample,request={kind=kind,origin=origin,direction=direction},obstruction=rayResult}
    record("attempt",attempt)
    local ok,err=pcall(remote.FireServer,remote,kind,origin,direction)
    if not ok then record("request_error",{id=attempt.id,error=tostring(err)});error(err)end
    trace.requestsSent+=1;lastAttempt={id=trace.attempts,at=os.clock()}
    record("request_dispatched",{id=lastAttempt.id})
    print(string.format("[C4 Pitchfork Test] Request #%d target=%s distance=%.2f reach=%.2f obstruction=%s",lastAttempt.id,tostring(sample.boss and sample.boss.BossWeakPoint),sample.distance or -1,sample.reach,rayResult and rayResult.object:GetFullName()or "none"))
    task.delay(1.5,function()
        if active then record("attempt_followup",{id=attempt.id,snapshot=snapshot(),totalServerHits=trace.confirmedPitchforkHits})end
    end)
end
controller=createBossWeakpointPitchfork({Player=player,World=WS,
    Enabled=function()return active and enabled end,
    Blocked=function()return player:GetAttribute("NeedleInputLocked")==true or player:GetAttribute("CutsceneActive")==true
        or player:GetAttribute("HintViewerOpen")==true or player:GetAttribute("CarryingCandle")~=nil
        or (player.PlayerGui:FindFirstChild("CandleMatchMinigame")and player.PlayerGui.CandleMatchMinigame.Enabled)end,
    Remote=function()
        local folder=RS:FindFirstChild("NeedleHaystack");local remote=folder and folder:FindFirstChild("PitchforkDig")
        return remote and remote:IsA("RemoteEvent")and proxy or nil
    end,Status=status})
env.BeyyC4PitchforkTest={Stop=stop,Save=save,Trace=trace,SetEnabled=function(value)enabled=value==true;record("attack_toggle",enabled);updateUI()end}
do
    gui=Instance.new("ScreenGui");gui.Name="BeyyC4PitchforkDiagnostic";gui.ResetOnSpawn=false;gui.DisplayOrder=1000
    gui.Parent=player:WaitForChild("PlayerGui")
    local panel=Instance.new("Frame");panel.Size=UDim2.fromOffset(430,160);panel.Position=UDim2.new(0.5,-215,0,100)
    panel.BackgroundColor3=Color3.fromRGB(25,25,29);panel.Parent=gui
    local title=Instance.new("TextLabel");title.Size=UDim2.new(1,0,0,30);title.Text="Chapter 4 — Pitchfork Test";title.Active=true;title.Parent=panel
    label=Instance.new("TextLabel");label.Position=UDim2.fromOffset(10,35);label.Size=UDim2.new(1,-20,0,45);label.TextWrapped=true;label.Parent=panel
    counts=Instance.new("TextLabel");counts.Position=UDim2.fromOffset(10,80);counts.Size=UDim2.new(1,-20,0,25);counts.Parent=panel
    for _,item in ipairs({title,label,counts})do item.BackgroundTransparency=1;item.TextColor3=Color3.fromRGB(235,235,240);item.TextSize=15;item.Font=Enum.Font.Code end
    local function button(text,x,fn)
        local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(130,32);b.Position=UDim2.fromOffset(x,118);b.Text=text
        b.BackgroundColor3=Color3.fromRGB(60,60,70);b.TextColor3=Color3.new(1,1,1);b.TextSize=14;b.Parent=panel
        connections[#connections+1]=b.Activated:Connect(fn);return b
    end
    toggle=button("Pause attacks",10,function()env.BeyyC4PitchforkTest.SetEnabled(not enabled)end)
    button("Save report",150,function()local ok,path=save();print("[C4 Pitchfork Test] "..(ok and "Saved "or "Save failed: ")..path)end)
    button("Stop",290,stop)
    local dragging,dragStart,startPosition=false,nil,nil
    connections[#connections+1]=title.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;dragStart=input.Position;startPosition=panel.Position end
    end)
    connections[#connections+1]=UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
            local delta=input.Position-dragStart;panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
        end
    end)
    connections[#connections+1]=UIS.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end
record("start",snapshot());updateUI()
print("[C4 Pitchfork Test] Started. Disable the hub's boss/hay pitchfork toggles for isolated results. Pause attacks to record manual pitchfork hits. Report: "..SAVE_PATH)
task.spawn(function()
    local lastError,nextErrorLog=nil,0
    while active do
        local ok,err=pcall(function()
            watchFeedback()
            controller.Tick()
            if os.clock()>=nextSample then
                nextSample=os.clock()+0.5
                local boss=WS:FindFirstChild("PumpkinGolem_Rig")
                if boss~=watchedBoss then
                    watchedBoss=boss
                    local bones={}
                    if boss then for _,obj in ipairs(boss:GetDescendants())do if obj:IsA("Bone")then bones[#bones+1]={name=obj.Name,path=obj:GetFullName()}end end end
                    record("boss_discovered",{boss=boss,bones=bones})
                end
                if #trace.samples>=600 then table.remove(trace.samples,1);trace.droppedSamples+=1 end
                trace.samples[#trace.samples+1]={at=os.clock()-started,data=encode(snapshot())}
            end
            if os.clock()>=nextSave then nextSave=os.clock()+10;save()end
        end)
        if not ok and (tostring(err)~=lastError or os.clock()>=nextErrorLog)then
            lastError=tostring(err);nextErrorLog=os.clock()+5;record("runtime_error",lastError)
            warn("[C4 Pitchfork Test] "..lastError);save()
        end
        task.wait(0.1)
    end
end)
