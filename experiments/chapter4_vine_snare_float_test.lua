-- Standalone Chapter 4 vine snare float experiment. No hub loader or combat remote calls.
if game.PlaceId~=102537610748607 then warn("[Snare Float Test] Run this in Chapter 4");return end

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
        local gui=node("ScreenGui",parent,{Name="BeyySnareFloatTest",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
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
        local bind="BeyySnareFloatCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
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

local function createVineSnareFloatController(d)
    local enabled,alive=false,true
    local pending,flight
    local api={}
    local function record(kind,data)d.Record(kind,data or {})end
    local function blocked()return d.Blocked()end
    local function release(reason,restore)
        pending=nil
        local previous=flight;flight=nil
        if not previous then return end
        local _,root=d.Character()
        local restored=false
        if restore and root==previous.Root and root.Parent and not blocked()
            and(root.Position-previous.Target.Position).Magnitude<25 then
            root.CFrame=previous.Start
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
            restored=true
        end
        record("FloatEnded",{Id=previous.Id,Reason=reason,Returned=restored,
            StartedAt=previous.StartedAt,EndedAt=d.Now(),TriggerAt=previous.TriggerAt})
        d.Save()
    end
    local function lift(plan)
        local reason=blocked()
        local character,root=d.Character()
        if reason or not root then record("FloatSkipped",{Id=plan.Id,Reason=reason or "Character missing"});return end
        local height=math.clamp(tonumber(d.Settings.Height)or 7.5,5,10)
        local hold=math.clamp(tonumber(d.Settings.Hold)or 0.8,0.2,2)
        local start=root.CFrame
        local target=start+Vector3.new(0,height,0)
        flight={Id=plan.Id,Character=character,Root=root,Start=start,Target=target,
            StartedAt=d.Now(),TriggerAt=plan.TriggerAt,Until=math.max(d.Now()+0.2,plan.TriggerAt+hold),NextSample=0}
        root.CFrame=target
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        record("FloatStarted",{Id=plan.Id,Height=height,Origin=start,Target=target,TriggerAt=plan.TriggerAt,
            SecondsBeforeTrigger=plan.TriggerAt-d.Now(),HoldAfterTrigger=hold,Manual=plan.Manual==true})
    end
    function api.SetEnabled(value)
        if not alive then return end
        enabled=value==true
        if not enabled then release("Disabled",true)end
        record("Enabled",{Value=enabled})
    end
    function api.Feedback(kind,payload)
        if not alive then return end
        if kind=="Snared"then
            if flight or pending then record("SnaredDuringTest",{Payload=payload,Context=d.Snapshot()});release("Snared: game owns movement",false)end
            return
        end
        if not enabled then return end
        if kind=="Cancel"or kind=="Finish"then
            local id=type(payload)=="table"and payload.id or payload
            if id~=nil and((pending and pending.Id==id)or(flight and flight.Id==id))then release(kind,true)end
            return
        end
        if kind~="Vines"or type(payload)~="table"or type(payload.list)~="table"then return end
        for _,area in ipairs(payload.list)do
            if area.u==d.UserId and type(area.t)=="number"and area.t==area.t and math.abs(area.t)<math.huge then
                local now=d.Now()
                local lead=math.clamp(tonumber(d.Settings.Lead)or 0.25,0.05,0.6)
                record("LocalVineWarning",{Payload=payload,Area=area,ReceivedAt=now,TriggerAt=area.t,
                    LeadRemaining=area.t-now,Context=d.Snapshot()})
                if area.t<now then record("FloatSkipped",{Id=payload.id,Reason="Warning already expired"});return end
                if flight then record("FloatSkipped",{Id=payload.id,Reason="Already floating"});return end
                pending={Id=payload.id,TriggerAt=area.t,StartAt=area.t-lead}
                return
            end
        end
    end
    function api.Tick()
        if not alive then return end
        local now=d.Now()
        if flight then
            local character,root=d.Character()
            local reason=blocked()
            if reason or character~=flight.Character or root~=flight.Root then release(reason or "Character changed",false);return end
            if(root.Position-flight.Target.Position).Magnitude>=25 then release("External position change",false);return end
            if now>=flight.Until then release("Hold completed",true);return end
            root.CFrame=flight.Target
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
            if now>=flight.NextSample then flight.NextSample=now+0.1;record("FloatSample",{Id=flight.Id,TriggerAt=flight.TriggerAt,Context=d.Snapshot()})end
        elseif pending and enabled and now>=pending.StartAt then
            local plan=pending;pending=nil
            if now>plan.TriggerAt+0.1 then record("FloatSkipped",{Id=plan.Id,Reason="Missed trigger deadline"});return end
            lift(plan)
        end
    end
    function api.Test()
        if not alive or flight then return end
        pending=nil;lift({Id="manual",TriggerAt=d.Now(),Manual=true})
    end
    function api.Abort(reason,restore)release(reason or "Released manually",restore~=false)end
    function api.State()return flight and "Floating"or pending and "Waiting for trigger"or enabled and "Armed"or "Off"end
    function api.Stop()
        if not alive then return end
        release("Unloaded",true);enabled=false;alive=false
    end
    return api
end


local Players=game:GetService("Players")
local World=game:GetService("Workspace")
local Storage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then return end
local singleton="__BEYY_CH4_SNARE_FLOAT_STOP"
if type(_G[singleton])=="function"then pcall(_G[singleton])end

local settings={Height=7.5,Lead=0.25,Hold=0.8}
local ui=createNativeUI()
local window=ui:CreateWindow({Title="Chapter 4 | Vine Snare Float Test",Folder="BeyySnareFloatTest"})
window:SetToggleKey(Enum.KeyCode.F8)
local tab=window:Tab({Title="Snare Float"})
local status=tab:Paragraph({Title="Test Status",Desc="Off | F8 toggles this menu. Experimental vertical-avoidance test."})
local help=tab:Paragraph({Title="Session",Desc="Enable Auto Float, then close this menu with F8. Floats only for your targeted vine warning. Export records whether the server still snares you."})
local alive=true
local history,total,dropped={},0,0
local lastStatus,lastError=nil,nil
local remote,remoteConnection,boss,encounter
local nextBind,nextStatus=0,0
local connections={}
local controller
local function now()return World:GetServerTimeNow()end
local function character()
    local char=player.Character
    return char,char and char:FindFirstChild("HumanoidRootPart"),char and char:FindFirstChildOfClass("Humanoid")
end
local function snapshot()
    local char,root,hum=character()
    local flags={}
    for _,key in ipairs({"PumpkinSnared","PumpkinGrabbed","PumpkinPulled","BossHeld","BossRagdolled","BossRagdollRecovering",
        "BossKnockdownCamera","BossStunnedUntil","CutsceneActive","NeedleInputLocked","PumpkinFinaleCast"})do flags[key]=player:GetAttribute(key)end
    return {Character=char and char.Name,Position=root and root.Position,Velocity=root and root.AssemblyLinearVelocity,
        Anchored=root and root.Anchored,Health=hum and hum.Health,State=hum and tostring(hum:GetState()),
        Floor=hum and tostring(hum.FloorMaterial),Player=flags,Boss=boss and boss:GetAttributes()}
end
local function blocked()
    local _,root,hum=character()
    if not root or not root.Parent or not hum or hum.Health<=0 then return "Character unavailable"end
    if root.Anchored then return "Character anchored by game"end
    for _,key in ipairs({"PumpkinSnared","PumpkinGrabbed","PumpkinPulled","BossHeld","BossRagdolled","BossRagdollRecovering",
        "BossKnockdownCamera","CutsceneActive","NeedleInputLocked","PumpkinFinaleCast"})do
        if player:GetAttribute(key)==true then return key end
    end
    if now()<(tonumber(player:GetAttribute("BossStunnedUntil"))or 0)then return "Stunned"end
end
local function serial(value,depth,seen)
    local kind=typeof(value)
    if kind=="nil"then return "<nil>"end
    if kind=="number"then return value==value and math.abs(value)<math.huge and value or tostring(value)end
    if kind=="boolean"or kind=="string"then return value end
    if kind=="Vector3"then return {X=value.X,Y=value.Y,Z=value.Z}end
    if kind=="CFrame"then return {Components={value:GetComponents()}}end
    if kind~="table"then return tostring(value)end
    depth=depth or 0;seen=seen or {}
    if depth>8 or seen[value]then return "<bounded>"end
    seen[value]=true
    local out,count={},0
    for k,v in pairs(value)do count+=1;if count>256 then out.Truncated=true;break end;out[tostring(k)]=serial(v,depth+1,seen)end
    seen[value]=nil;return out
end
local function record(kind,data)
    total+=1
    history[#history+1]={Sequence=total,At=os.clock(),ServerAt=now(),Kind=kind,Data=serial(data)}
    if #history>2048 then table.remove(history,1);dropped+=1 end
end
local function save(manual)
    local ok,json=pcall(function()return Http:JSONEncode({Schema=1,Feature="Chapter4VineSnareFloatTest",PlaceId=game.PlaceId,
        JobId=game.JobId,UserId=player.UserId,ExportedAt=os.time(),Settings=settings,TotalEvents=total,DroppedEvents=dropped,
        LastError=lastError,Events=history,Current=serial(snapshot()),
        Interpretation="Experimental local float; server snare avoidance is not assumed. No snare/escape remotes are sent."})end)
    if not ok then lastError=tostring(json);return end
    if type(writefile)=="function"then
        if type(makefolder)=="function"then pcall(makefolder,"BeyyHub")end
        local written,err=pcall(writefile,"BeyyHub/chapter4_snare_float_test.json",json)
        if not written then lastError=tostring(err)end
    else lastError="writefile unavailable; use Export to copy JSON"end
    if manual and type(setclipboard)=="function"then pcall(setclipboard,json)end
end
controller=createVineSnareFloatController({UserId=player.UserId,Settings=settings,Now=now,Character=character,
    Blocked=blocked,Record=record,Snapshot=snapshot,Save=function()save(false)end})
local function sync()
    local folder=Storage:FindFirstChild("PumpkinBoss")
    local nextRemote=folder and folder:FindFirstChild("Feedback")
    local nextBoss=World:FindFirstChild("PumpkinGolem_Rig")
    local nextEncounter=nextBoss and nextBoss:GetAttribute("Encounter")
    if nextBoss~=boss or nextEncounter~=encounter then controller.Abort("Encounter changed");boss,encounter=nextBoss,nextEncounter end
    if nextRemote~=remote then
        controller.Abort("Feedback remote changed")
        if remoteConnection then remoteConnection:Disconnect();remoteConnection=nil end
        remote=nextRemote
        if remote and remote:IsA("RemoteEvent")then remoteConnection=remote.OnClientEvent:Connect(function(kind,payload)
            if not alive then return end
            local ok,err=pcall(function()
                if kind=="Vines"or kind=="Snared"or kind=="SnareFreed"or kind=="Cancel"or kind=="Finish"or kind=="PlayerHit"then
                    record("Feedback",{Kind=kind,Payload=payload,Context=snapshot()})
                end
                controller.Feedback(kind,payload)
                if kind=="Snared"or kind=="SnareFreed"then save(false)end
            end)
            if not ok then lastError=tostring(err);controller.Abort("Feedback error")end
        end)end
    end
    if boss and(tonumber(boss:GetAttribute("BossHealth"))or 0)<=0 then controller.Abort("Boss ended")end
end
tab:Toggle({Title="Auto Float Before Vine Snare",Value=false,Callback=function(on)controller.SetEnabled(on)end})
tab:Slider({Title="Float Height (studs)",Step=0.5,Value={Min=5,Max=10,Default=7.5},Callback=function(v)settings.Height=v end})
tab:Slider({Title="Lead Before Grab (seconds)",Step=0.05,Value={Min=0.05,Max=0.6,Default=0.25},Callback=function(v)settings.Lead=v end})
tab:Slider({Title="Hold After Grab Time (seconds)",Step=0.1,Value={Min=0.2,Max=2,Default=0.8},Callback=function(v)settings.Hold=v end})
tab:Button({Title="Test Float Now",Callback=controller.Test})
tab:Button({Title="Release Float Now",Callback=function()controller.Abort("Released manually")end})
tab:Button({Title="Export Float Diagnostics",Callback=function()save(true)end})
local originalDestroy=window.Destroy
local function stop()
    if not alive then return end
    controller.Stop();alive=false
    if remoteConnection then remoteConnection:Disconnect()end
    for _,c in ipairs(connections)do c:Disconnect()end
    save(false);originalDestroy(window)
    if _G[singleton]==stop then _G[singleton]=nil end
end
window.Destroy=function()stop()end
_G[singleton]=stop
tab:Button({Title="Unload Standalone Test",Callback=stop})
connections[1]=RunService.Heartbeat:Connect(function()
    if not alive then return end
    local ok,err=pcall(function()
        if os.clock()>=nextBind then nextBind=os.clock()+0.25;sync()end
        controller.Tick()
        if os.clock()>=nextStatus then
            nextStatus=os.clock()+0.25
            local text=controller.State().." | Feedback: "..(remote and "connected"or "waiting")..(lastError and " | "..lastError or "")
            if text~=lastStatus then lastStatus=text;status:SetDesc(text)end
        end
    end)
    if not ok then lastError=tostring(err);pcall(controller.Abort,"Controller error")end
end)
if player.CharacterRemoving then connections[#connections+1]=player.CharacterRemoving:Connect(function()controller.Abort("Respawn",false)end)end
sync()
