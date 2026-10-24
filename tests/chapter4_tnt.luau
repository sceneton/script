-- Source-extracted controller/recorder tests; no Roblox execution.
local now,timers,spawned,warnings=0,{},{},{}
local os={clock=function()return now end,time=function()return 123 end}
local _G={}
local function warn(message)table.insert(warnings,message)end
local task={spawn=function(fn)table.insert(spawned,fn)end}
function task.wait(dt)
    local finish=now+(dt or 0.016)
    while true do
        local nextTimer
        for _,t in ipairs(timers)do if not t.done and t.at<=finish and (not nextTimer or t.at<nextTimer.at)then nextTimer=t end end
        if not nextTimer then break end
        now=nextTimer.at;nextTimer.done=true;nextTimer.fn()
    end
    now=finish
end
local function later(dt,fn)table.insert(timers,{at=now+dt,fn=fn})end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={fn=fn,connected=true};function c:Disconnect()self.connected=false end
        table.insert(self.listeners,c);return c
    end
    function s:Fire(...)for _,c in ipairs(self.listeners)do if c.connected then c.fn(...)end end end
    return s
end
local function trace(on)
    local d={events={},statuses={},on=on}
    function d.Enabled()return d.on end
    function d.Record(kind,build)
        if not d.on then return end
        table.insert(d.events,{Kind=kind,At=now,Data=type(build)=="function"and build()or build})
    end
    function d.Status(_,text)if d.on then table.insert(d.statuses,text)end end
    function d.find(kind)for i=#d.events,1,-1 do if d.events[i].Kind==kind then return d.events[i]end end end
    return d
end
-- INSERT_GATE
-- INSERT_STEP
local function close(a,b)assert(math.abs(a-b)<0.00001,tostring(a).." ~= "..tostring(b))end
local function setup(config)
    config=config or {};now=0;timers={};spawned={};warnings={};_G={}
    local d=trace(config.diagnostics~=false)
    local replies=signal();local sent={}
    local remote={Name="TntAction",OnClientEvent=replies,IsA=function(_,name)return name=="RemoteEvent"end}
    function remote:FireServer(action,...)
        table.insert(sent,{action=action,at=now,args=table.pack(...)})
        if action=="light"then
            if config.sendError then error("mock light failure")end
            if config.reply~=false then later(config.ackDelay or 0.2,function()replies:Fire(config.denied and "denied"or "lit",config.denied or 2.9)end)end
        elseif config.throwError then error("mock throw failure")end
    end
    local cooldown=config.cooldown or 5
    local available=true
    local gate=createTntRetryGate(function()return available and remote or nil end,function()return cooldown end,
        function()return config.lightTime or 0.48 end,d)
    return {gate=gate,diag=d,sent=sent,replies=replies,remote=remote,
        setCooldown=function(v)cooldown=v end,removeRemote=function()available=false end}
end
local passed=0
local function test(name,fn)fn();passed+=1;print("PASS "..name)end
test("acknowledgement and required lighting wait are timed separately",function()
    local e=setup();assert(not e.gate.Light());task.wait(1.5);assert(e.gate.Light());assert(e.gate.Throw("origin","velocity"))
    close(e.sent[1].at,1.5);close(e.sent[2].at,2.18)
    close(e.diag.find("Gate:LightingAcknowledged").Data.AcknowledgementSeconds,0.2)
    close(e.diag.find("Gate:ThrowRequest").Data.SinceAcknowledgementSeconds,0.48)
    assert(e.diag.find("Gate:ThrowRequest").Data.Sent)
end)
test("diagnostics on and off produce identical requests and timing",function()
    local a=setup();task.wait(1.5);a.gate.Light();a.gate.Throw("origin","velocity");local enabledSent=a.sent
    local b=setup({diagnostics=false});task.wait(1.5);b.gate.Light();b.gate.Throw("origin","velocity")
    assert(#b.diag.events==0 and #b.diag.statuses==0 and #enabledSent==#b.sent)
    for i,x in ipairs(enabledSent)do assert(x.action==b.sent[i].action);close(x.at,b.sent[i].at);assert(x.args.n==b.sent[i].args.n)end
end)
test("missing acknowledgement reports timeout and retains cooldown reservation",function()
    local e=setup({reply=false});task.wait(1.5);assert(not e.gate.Light())
    assert(e.diag.find("Gate:AcknowledgementTimeout"));assert(not e.gate.Ready());close(e.gate.Remaining(),6.55-now)
    assert(not e.gate.Throw());assert(#e.sent==1)
end)
test("denial is logged and server retry deadline wins",function()
    local e=setup({denied=3});task.wait(1.5);assert(not e.gate.Light());e.setCooldown(0.5)
    close(e.gate.Remaining(),4.75-now);assert(e.diag.find("Gate:Denied").Data.ServerRemaining==3)
end)
test("cooldown upgrades shorten prediction without snapshot side effects",function()
    local e=setup();task.wait(1.5);assert(e.gate.Light());e.setCooldown(2)
    local a=e.gate.DiagnosticSnapshot();local b=e.gate.DiagnosticSnapshot()
    close(a.PredictedReadyAt,3.75);close(a.ReservedRetryAt,b.ReservedRetryAt);close(a.ReservedRetryAt,6.75)
    close(e.gate.Remaining(),3.75-now)
end)
test("local send failure reports failure without claiming acceptance",function()
    local e=setup({sendError=true});task.wait(1.5);assert(not e.gate.Light());assert(e.diag.find("Gate:LightSendFailed"));close(e.gate.Remaining(),1)
end)
test("local throw failure is reported and no duplicate throw is sent",function()
    local e=setup({throwError=true});task.wait(1.5);assert(e.gate.Light());assert(not e.gate.Throw())
    assert(e.diag.find("Gate:ThrowRequest").Data.Sent==false);assert(not e.gate.Throw());assert(#e.sent==2)
end)
test("late acknowledgement is marked unmatched",function()
    local e=setup({reply=false});task.wait(1.5);e.gate.Light();e.replies:Fire("lit",2.9)
    assert(e.diag.find("Gate:ServerReply").Data.MatchedWaiting==false);assert(not e.gate.Throw())
end)
test("unload disconnects reply capture and prevents throwing",function()
    local e=setup();task.wait(1.5);assert(e.gate.Light());e.gate.Stop();local n=#e.diag.events
    e.replies:Fire("lit",2.9);assert(#e.diag.events==n);assert(not e.gate.Throw());assert(#e.sent==1)
end)
test("broken diagnostic callbacks cannot interrupt gate behavior",function()
    local e=setup();e.diag.Record=function()error("diagnostic error")end;e.diag.Status=e.diag.Record
    task.wait(1.5);assert(e.gate.Light());assert(e.gate.Throw());assert(#e.sent==2)
end)
test("invalid cooldown is visible as the existing 20-second fallback",function()
    local e=setup();e.setCooldown("invalid");local s=e.gate.DiagnosticSnapshot()
    assert(s.CooldownAttribute=="invalid"and s.EffectiveCooldown==20)
end)

local function makeStep(e,config)
    config=config or {}
    local root={Parent=true};local target={Name="hay"};local aims=0;local blocked
    local step=createHayTntStep({Gate=e.gate,Diagnostics=e.diag,Root=function()return root end,
        BlockReason=function()return blocked end,Allowed=function()return not blocked end,
        Aim=function(_,allowed,preferred)
            aims+=1;assert(allowed())
            task.wait(preferred and (config.refresh or 0)or (config.search or 0))
            if config.cancelAfterSearch then blocked="Paused for candle action"end
            if config.errorOnce and aims==1 then error("mock search error")end
            if config.noTarget or (preferred and config.noRefresh)then return nil end
            if preferred then assert(preferred==target)end
            return "from","velocity",preferred and config.changedTarget and {Name="other hay"}or target
        end})
    return step,function(reason)blocked=reason end,function()return aims end
end
test("slow initial search is measured independently of acknowledgement and lighting",function()
    local e=setup();local step=makeStep(e,{search=2.4});task.wait(1.7);step.Tick()
    local c=e.diag.find("AttemptFinished").Data
    close(c.ReadyOverdueSeconds,0.2);close(c.SearchSeconds,2.4);close(c.LightCallSeconds,0.68);close(c.RefreshSeconds,0)
    close(c.TotalAfterPredictedReadySeconds,3.28);assert(c.ThrowSent and #e.sent==2)
end)
test("slow refresh and replacement target are captured",function()
    local e=setup();local step=makeStep(e,{refresh=0.9,changedTarget=true});task.wait(1.5);step.Tick()
    local c=e.diag.find("AttemptFinished").Data;close(c.RefreshSeconds,0.9);assert(c.TargetChanged and c.ThrowSent)
end)
test("refresh that exceeds fuse reports a rejected throw",function()
    local e=setup();local step=makeStep(e,{refresh=3});task.wait(1.5);step.Tick()
    assert(e.diag.find("AttemptFinished").Data.ThrowSent==false and #e.sent==1)
    assert(e.diag.find("Gate:ThrowRejectedLocally"))
end)
test("no target sends no light and repeated failures are sampled",function()
    local e=setup();local step=makeStep(e,{noTarget=true});task.wait(1.5)
    for _=1,10 do step.Tick();task.wait(0.1)end
    local n=0;for _,event in ipairs(e.diag.events)do if event.Kind=="AttemptFinished"then n+=1 end end
    assert(n==1 and #e.sent==0)
end)
test("candle blocker is visible without searching or sending",function()
    local e=setup();local step,block,aims=makeStep(e);block("Paused for candle action");task.wait(1.5);step.Tick()
    assert(aims()==0 and #e.sent==0 and e.diag.statuses[#e.diag.statuses]=="Paused for candle action")
end)
test("cancellation during scan prevents light request",function()
    local e=setup();local step=makeStep(e,{cancelAfterSearch=true});task.wait(1.5);step.Tick()
    assert(#e.sent==0 and e.diag.find("AttemptFinished").Data.Stage=="Cancelled after target search")
end)
test("missing refreshed trajectory does not throw",function()
    local e=setup();local step=makeStep(e,{noRefresh=true});task.wait(1.5);step.Tick()
    assert(#e.sent==1 and e.diag.find("AttemptFinished").Data.Stage=="No valid trajectory after lighting")
end)
test("worker error is reported and subsequent iteration can recover",function()
    local e=setup();local step=makeStep(e,{errorOnce=true});task.wait(1.5);step.Tick()
    assert(e.diag.find("WorkerError")and #warnings==1);step.Tick();assert(#e.sent==2)
end)
test("diagnostics disabled leaves no captured cycle",function()
    local e=setup({diagnostics=false});local step=makeStep(e,{search=2.4});task.wait(1.5);step.Tick()
    assert(#e.sent==2 and #e.diag.events==0 and step.Snapshot()==nil)
end)

local CACHE_FOLDER,__BEYY_MODULE="BeyyHub","Chapter4"
local payload,copies,writes=nil,0,{}
local function typeof(v)return type(v)end
local function setclipboard(_)copies+=1 end
local game={PlaceId=102537610748607,JobId="mock",GetService=function(_,name)
    assert(name=="HttpService");return {JSONEncode=function(_,value)payload=value;return "encoded JSON"end}
end}
-- INSERT_RECORDER
test("recorder defaults off, bounds history, and exports only on explicit clipboard request",function()
    now=0;timers={};spawned={};_G={};payload=nil;copies=0;writes={}
    local toggle,buttons
    buttons={}
    local tab={Paragraph=function()return {SetDesc=function()end}end,
        Toggle=function(_,args)toggle=args;return args end,
        Button=function(_,args)buttons[args.Title]=args.Callback end}
    local player={Character=nil,AttributeChanged=signal(),OnTeleport=signal(),GetAttribute=function()return nil end}
    local d=createFeatureDiagnostics({Tab=tab,Registry={},Title="Auto TNT Diagnostics",Key="AutoTntDiagnostics",
        File="chapter4_auto_tnt_diagnostics",Player=player,Alive=function()return true end,Menu=function()return true end,
        Write=function(path,json)table.insert(writes,{path=path,json=json});return true end})
    assert(toggle.Value==false and not d.Enabled())
    d.Record("Disabled",function()error("Disabled diagnostics evaluated data")end);assert(payload==nil)
    toggle.Callback(true);assert(d.Enabled()and #spawned==1)
    for i=1,300 do d.Record("Timing",{Index=i})end
    toggle.Callback(false)
    assert(copies==0 and #writes==1);assert(payload.Capacity==256 and #payload.Events==256 and payload.DroppedEvents==45)
    assert(payload.Events[1].Sequence==46 and payload.Events[256].Sequence==301)
    assert(writes[1].path=="BeyyHub/chapter4_auto_tnt_diagnostics.json")
    buttons["Export Auto TNT Diagnostics"]();assert(copies==1)
    d.Stop();assert(not d.Enabled())
    for _,c in ipairs(player.AttributeChanged.listeners)do assert(not c.connected)end
    for _,c in ipairs(player.OnTeleport.listeners)do assert(not c.connected)end
end)
print(string.format("%d TNT diagnostic tests passed",passed))
