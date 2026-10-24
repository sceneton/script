-- Mocked execution of the production controller; no Roblox/executor required.
local now,heartbeat,delays,onWait=0,{}, {},nil
local os={clock=function()return now end}
local task={}
function task.wait(dt)
    now+=dt
    if onWait then onWait()end
    for _,c in ipairs(heartbeat)do if c.connected then c.fn()end end
    for _,d in ipairs(delays)do if not d.done and now>=d.at then d.done=true;d.fn()end end
end
function task.delay(dt,fn)table.insert(delays,{at=now+dt,fn=fn})end
local function signal()
    return {Connect=function(_,fn)
        local c={connected=true,fn=fn}
        function c:Disconnect()self.connected=false end
        table.insert(heartbeat,c);return c
    end}
end
local vmt={}
vmt.__index=function(v,k)if k=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end
local function vector(x,y,z)return setmetatable({X=x,Y=y,Z=z},vmt)end
vmt.__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vmt.__sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local Vector3={new=vector,zero=vector(0,0,0)}
local CFrame={lookAt=function(pos)return {Position=pos}end}
local Enum={KeyCode={Space="Space"}}
local services,workspace={},nil
local game={GetService=function(_,name)return services[name]end}
local function firesignal(event)event()end
local function warn(_)end
-- INSERT_CONTROLLER

local function object(name,attrs,children,class)
    local o={Name=name,attributes=attrs or {},children=children or {},Parent=true,class=class or "Model"}
    function o:GetAttribute(k)return self.attributes[k]end
    function o:FindFirstChild(k)return self.children[k]end
    function o:FindFirstChildOfClass(k)for _,c in pairs(self.children)do if c.class==k then return c end end end
    function o:GetChildren()local t={};for _,c in pairs(self.children)do table.insert(t,c)end;table.sort(t,function(a,b)return a.Name<b.Name end);return t end
    function o:IsA(k)return self.class==k end
    function o:GetPivot()return {Position=vector(0,0,0)}end
    return setmetatable(o,{__index=function(self,k)return self.children[k]end})
end
local function setup(config)
    config=config or {};now=0;heartbeat={};delays={};onWait=nil
    local root=object("HumanoidRootPart",nil,nil,"BasePart");root.Position=vector(0,0,0);root.Anchored=config.scene or false
    local character=object("Character",nil,{HumanoidRootPart=root})
    local gui=object("CandleMatchMinigame",nil,nil,"ScreenGui");gui.Enabled=false
    local pg=object("PlayerGui",nil,{CandleMatchMinigame=gui},"PlayerGui")
    local player=object("Player",{CutsceneActive=config.scene or false},{PlayerGui=pg});player.UserId=42;player.Character=character
    local altar=object("WhereToPlaceCandles",{CandlesFound=config.found or 0,CandlesLit=config.lit or 0,CandlesTotal=4})
    for i=1,4 do altar.children[tostring(i)]=object(tostring(i),{Lit=i<=(config.lit or 0)})end
    local candles=object("HayCandles")
    for i=1,(config.exposed or 4)do candles.children[tostring(i)]=object("Candle"..i,{HayCandle=true,Revealed=true})end
    workspace=object("World",nil,{WhereToPlaceCandles=altar,HayCandles=candles})
    local calls,records,keys={}, {},{}
    local enabled,menu,alive,blocked=true,true,true,false
    local remotes=object("Remotes")
    local env={player=player,root=root,altar=altar,gui=gui,candles=candles,calls=calls,records=records,keys=keys}
    local held
    for _,name in ipairs({"PickUpCandle","PlaceCandle","MatchDone"})do
        remotes.children[name]={FireServer=function(_,target)
            table.insert(calls,{name=name,target=target,time=now})
            if env.onRemote and env.onRemote(name,target)==false then return end
            if name=="PickUpCandle"then
                held=target;target.attributes.HeldBy=42;player.attributes.CarryingCandle=target.Name;altar.attributes.CandlesFound+=1
            elseif name=="PlaceCandle"then
                if root.Anchored then return end
                target.attributes.ReservedBy=42;player.attributes.CarryingCandle=nil
                if held then held.attributes.Placed=true end
                gui.Enabled=not player.attributes.CutsceneActive
            elseif name=="MatchDone"then
                if config.fallback then gui.Enabled=true;return end
                target.attributes.Lit=true;altar.attributes.CandlesLit+=1
                altar.attributes.AllLit=altar.attributes.CandlesLit>=4
            end
        end}
    end
    remotes.children.MatchPuzzle={OnClientEvent=function()gui.Enabled=false end}
    services.ReplicatedStorage=object("RS",nil,{CandleRitual=object("CandleRitual",nil,{Remotes=remotes})})
    services.RunService={Heartbeat=signal()}
    services.UserInputService={GetFocusedTextBox=function()return nil end}
    local options={Player=player,Alive=function()return alive end,Enabled=function()return enabled end,
        MenuClosed=function()return menu end,Blocked=function()return blocked end,
        PauseTools=function()assert(env.controller.IsBusy());env.paused=true end,
        Status=function(s)env.status=s end,Record=function(k,b)table.insert(records,{k=k,data=b and b()})end,
        Input={SendKeyEvent=function(_,down)
            table.insert(keys,down)
            if config.fallback and not down then
                for _,h in ipairs(altar:GetChildren())do if h:GetAttribute("ReservedBy")==42 and not h:GetAttribute("Lit")then
                    h.attributes.Lit=true;altar.attributes.CandlesLit+=1;gui.Enabled=false;break
                end end
            end
        end}}
    env.controller=createCandleAutomation(options)
    function env.disable()enabled=false end
    function env.openMenu()menu=false end
    function env.closeMenu()menu=true end
    function env.block()blocked=true end
    function env.count(name)local n=0;for _,c in ipairs(calls)do if c.name==name then n+=1 end end;return n end
    function env.activeConnections()local n=0;for _,c in ipairs(heartbeat)do if c.connected then n+=1 end end;return n end
    return env
end
local passed=0
local function test(name,fn)fn();passed+=1;print("PASS "..name)end
test("wait for all exposed candles",function()
    local e=setup({exposed=3});assert(not e.controller.Tick());assert(#e.calls==0)
end)
test("complete four candles in holder order",function()
    local e=setup()
    for i=1,4 do assert(e.controller.Tick(),tostring(e.status));assert(e.altar:GetAttribute("CandlesLit")==i,tostring(e.status));assert(e.calls[#e.calls].target.Name==tostring(i))end
    assert(e.count("PickUpCandle")==4 and e.count("PlaceCandle")==4 and e.count("MatchDone")==4)
    assert(e.paused and not e.gui.Enabled and not e.controller.IsBusy())
end)
test("existing carried candle resumes immediately",function()
    local e=setup({exposed=0,found=1});e.player.attributes.CarryingCandle="existing"
    assert(e.controller.Tick());assert(e.count("PickUpCandle")==0 and e.count("PlaceCandle")==1)
end)
test("reserved holder resumes without pickup or placement",function()
    local e=setup({exposed=0});e.altar.children["1"].attributes.ReservedBy=42
    assert(e.controller.Tick());assert(e.count("PickUpCandle")==0 and e.count("PlaceCandle")==0)
end)
test("teammate claim is deferred without remote spam",function()
    local e=setup()
    e.onRemote=function(name,target)if name=="PickUpCandle"then target.attributes.HeldBy=99;return false end end
    assert(not e.controller.Tick());assert(e.count("PickUpCandle")==1 and e.count("PlaceCandle")==0)
end)
test("local ownership waits for CarryingCandle replication",function()
    local e=setup();local pending
    e.onRemote=function(name,target)if name=="PickUpCandle"then target.attributes.HeldBy=42;pending=now;return false end end
    onWait=function()if pending and now-pending>=0.1 then e.player.attributes.CarryingCandle="replicated" end end
    assert(e.controller.Tick());assert(e.count("PickUpCandle")==1)
end)
test("teammate claim during approach cancels pickup",function()
    local e=setup();e.root.Position=vector(20,0,0)
    onWait=function()e.candles.children["1"].attributes.HeldBy=99 end
    assert(not e.controller.Tick());assert(e.count("PickUpCandle")==0 and e.count("PlaceCandle")==0)
end)
test("holder claimed during approach is revalidated before placement",function()
    local e=setup()
    e.onRemote=function(name)if name=="PickUpCandle"then e.root.Position=vector(20,0,0)end end
    onWait=function()e.altar.children["1"].attributes.ReservedBy=99;e.root.Position=vector(0,0,0)end
    assert(not e.controller.Tick());assert(e.count("PickUpCandle")==1 and e.count("PlaceCandle")==0)
end)
test("skeleton cutscene can finish last two candles",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2})
    assert(e.controller.Tick());assert(not e.root.Anchored and e.activeConnections()==1)
    assert(e.controller.Tick());assert(e.altar:GetAttribute("AllLit"));assert(e.root.Anchored and e.activeConnections()==0)
end)
test("failed cutscene placement waits for scene end",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2})
    e.onRemote=function(name)if name=="PlaceCandle"then return false end end
    assert(not e.controller.Tick());local n=#e.calls
    assert(e.root.Anchored and e.activeConnections()==0)
    e.controller.Tick();assert(#e.calls==n)
end)
test("hidden GUI lighting retries are throttled",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});e.altar.children["3"].attributes.ReservedBy=42
    e.onRemote=function(name)if name=="MatchDone"then return false end end
    assert(not e.controller.Tick());assert(e.count("MatchDone")==1)
    e.controller.Tick();assert(e.count("MatchDone")==1)
    task.wait(1.1);e.controller.Tick();assert(e.count("MatchDone")==2)
end)
test("fallback releases Space",function()
    local e=setup({fallback=true});assert(e.controller.Tick());assert(#e.keys==2 and e.keys[1] and not e.keys[2])
end)
test("menu cancellation releases held input",function()
    local e=setup({fallback=true})
    onWait=function()if #e.keys>0 and e.keys[#e.keys]then e.openMenu()end end
    assert(not e.controller.Tick());assert(#e.keys==2 and e.keys[2]==false);assert(not e.controller.IsBusy())
end)
test("menu pause restores owned anchor and disconnects heartbeat",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});assert(e.controller.Tick())
    e.openMenu();task.wait(0.025);assert(e.root.Anchored and e.activeConnections()==0)
end)
test("unload restores owned anchor and stops requests",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});assert(e.controller.Tick());e.controller.Stop()
    assert(e.root.Anchored and e.activeConnections()==0);local n=#e.calls;task.wait(6);e.controller.Tick();assert(#e.calls==n)
end)
test("anchor window expires after 5.5 seconds",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});assert(e.controller.Tick());task.wait(5.8)
    assert(e.root.Anchored and e.activeConnections()==0)
end)
test("disabling candle automation restores owned anchor",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});assert(e.controller.Tick());e.disable();task.wait(0.025)
    assert(e.root.Anchored and e.activeConnections()==0);local n=#e.calls;e.controller.Tick();assert(#e.calls==n)
end)
test("new input lock restores owned anchor",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});assert(e.controller.Tick());e.block();task.wait(0.025)
    assert(e.root.Anchored and e.activeConnections()==0)
end)
test("an initially free root is never reanchored",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});e.root.Anchored=false
    assert(e.controller.Tick());e.controller.Stop();assert(not e.root.Anchored and e.activeConnections()==0)
end)
test("respawn cancels active input without touching replacement root",function()
    local e=setup({fallback=true});local replacement=object("Character")
    onWait=function()if #e.keys>0 and e.keys[#e.keys]then e.player.Character=replacement end end
    assert(not e.controller.Tick());assert(e.keys[#e.keys]==false and not e.controller.IsBusy())
end)
test("old delayed cleanup cannot stop a new anchor window on the same root",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});assert(e.controller.Tick())
    e.openMenu();e.controller.Tick();e.closeMenu();task.wait(4)
    e.altar.attributes.CandlesLit=2;e.altar.attributes.CandlesFound=1
    e.altar.children["3"].attributes.Lit=false;e.altar.children["3"].attributes.ReservedBy=nil
    e.player.attributes.CarryingCandle="next-round"
    assert(e.controller.Tick());assert(not e.root.Anchored)
    task.wait(1);assert(not e.root.Anchored and e.activeConnections()==1)
end)
test("late match GUI closes after completed batch",function()
    local e=setup();for _=1,4 do assert(e.controller.Tick())end
    e.gui.Enabled=true;e.controller.Tick();assert(not e.gui.Enabled)
end)
test("unlit reserved match is preserved",function()
    local e=setup({scene=true,lit=2,found=2,exposed=2});e.altar.children["3"].attributes.ReservedBy=42
    e.onRemote=function(name)if name=="MatchDone"then return false end end
    e.controller.Tick();e.gui.Enabled=true;e.openMenu();e.controller.Tick();assert(e.gui.Enabled)
end)

local LocalPlayer,Workspace,hubUnloaded,BEYY_CHAPTER,chapter4Diagnostics
local function farmBlocked()
    return hubUnloaded or LocalPlayer:GetAttribute("NeedleInputLocked")==true
        or LocalPlayer:GetAttribute("CutsceneActive")==true or LocalPlayer:GetAttribute("HintViewerOpen")==true
end
-- INSERT_GATE
test("cutscene gate only permits remaining ritual during mid-ritual cutscene",function()
    local e=setup();LocalPlayer=e.player;Workspace=workspace;hubUnloaded=false;BEYY_CHAPTER="Chapter4"
    chapter4Diagnostics={Candles={Record=function()end}}
    assert(not candleBlocked())
    LocalPlayer.attributes.NeedleInputLocked=true;assert(candleBlocked())
    LocalPlayer.attributes.CutsceneActive=true;assert(candleBlocked())
    e.altar.attributes.CandlesLit=2;assert(not candleBlocked())
    LocalPlayer.attributes.HintViewerOpen=true;assert(candleBlocked());LocalPlayer.attributes.HintViewerOpen=nil
    local ending=object("NeedleEndingUI",nil,nil,"ScreenGui");ending.Enabled=true
    LocalPlayer.children.PlayerGui.children.NeedleEndingUI=ending;assert(candleBlocked());ending.Enabled=false
    e.altar.attributes.AllLit=true;assert(candleBlocked());e.altar.attributes.AllLit=nil
    hubUnloaded=true;assert(candleBlocked());hubUnloaded=false
    BEYY_CHAPTER="Chapter3";assert(candleBlocked())
end)
print(string.format("%d candle regression tests passed",passed))
