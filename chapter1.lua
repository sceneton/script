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
    stopEarlyIntro()
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
        ArcadeFarm = false,
        ClassRoller = false,
        ClassTarget = "The Chosen One",
        ClassRollInterval = 1.1,
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
        local previousBehavior,previousIcon,cursorBound
        local function releaseCursor()
            if cursorBound then return end
            previousBehavior,previousIcon=input.MouseBehavior,input.MouseIconEnabled
            cursorBound=true
            run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+100,function()
                input.MouseBehavior=Enum.MouseBehavior.Default; input.MouseIconEnabled=true
            end)
        end
        local function restoreCursor()
            if not cursorBound then return end
            run:UnbindFromRenderStep(bind); cursorBound=false
            input.MouseBehavior=previousBehavior; input.MouseIconEnabled=previousIcon
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
    ClassRollInterval = true, AutoFarmWins = true,
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

local ArcadeFolder = ReplicatedStorage:FindFirstChild("Arcade")
local ArcadeReport = ArcadeFolder and ArcadeFolder:FindFirstChild("ArcadeReport")
local ArcadeSession = ArcadeFolder and ArcadeFolder:FindFirstChild("ArcadeSession")
local ArcadeMachine = Workspace:FindFirstChild("Arcade Machine")
local ArcadePrompt = ArcadeMachine and ArcadeMachine:FindFirstChild("PlayPrompt", true)

local ClassSystem = ReplicatedStorage:FindFirstChild("ClassSystem")
local RollClass = ClassSystem and ClassSystem:FindFirstChild("RollClass")

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
    local now = tick()
    if HayCache.part and HayCache.part.Parent and (now - HayCache.time) < HayCache.ttl then return HayCache.part end
    local hoveredId = LocalPlayer:GetAttribute("HoveredHayId")
    if hoveredId then
        local part = findHayById(hoveredId)
        if part then
            HayCache.part = part; HayCache.id = hoveredId; HayCache.time = now
            return part
        end
    end
    local hrp = getHRP()
    if not hrp then return nil end
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return nil end
    local best, bestDist = nil, math.huge
    for _, inst in ipairs(folder:GetChildren()) do
        if inst:IsA("BasePart") and inst:GetAttribute("HayId") then
            local d = (inst.Position - hrp.Position).Magnitude
            if d < bestDist and d < 30 then bestDist = d; best = inst end
        end
    end
    HayCache.part = best; HayCache.time = now
    return best
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
    for _, inst in ipairs(folder:GetChildren()) do
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
    local now = tick()
    if DroppedCache.part and DroppedCache.part.Parent and (now - DroppedCache.time) < DroppedCache.ttl then return DroppedCache.part end
    local folder = DroppedFolder
    if not folder or not folder.Parent then DroppedFolder = Workspace:FindFirstChild("DroppedHay"); folder = DroppedFolder end
    if not folder then return nil end
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, 28
    for _, m in ipairs(folder:GetChildren()) do
        local part = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then bestDist = d; best = part.Parent:IsA("BasePart") and part.Parent or m end
        end
    end
    DroppedCache.part = best; DroppedCache.time = now
    return best
end

local GemsCache = { part = nil, id = nil, time = 0, ttl = 1.5 }

local function findClosestGemCached()
    local now = tick()
    if GemsCache.part and GemsCache.part.Parent and (now - GemsCache.time) < GemsCache.ttl then return GemsCache.part, GemsCache.id end
    local root = GemsFolder
    if not root or not root.Parent then GemsFolder = Workspace:FindFirstChild("GemsClient"); root = GemsFolder end
    if not root then return nil, nil end
    local hrp = getHRP()
    if not hrp then return nil, nil end
    local best, bestDist, bestId = nil, 35, nil
    for _, mdl in ipairs(root:GetChildren()) do
        local p = mdl
        if mdl:IsA("Model") then p = mdl.PrimaryPart or mdl:FindFirstChildWhichIsA("BasePart") end
        if p and p:IsA("BasePart") then
            local gId = p:GetAttribute("GemId")
            if gId then
                local d = (p.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = p; bestId = gId end
            end
        end
    end
    GemsCache.part = best; GemsCache.id = bestId; GemsCache.time = now
    return best, bestId
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
local lastUnusableNeedleLogAt = -math.huge
local function findExposedNeedlePart()
    if not IN_GAME then return nil end
    local server = Workspace:FindFirstChild("NeedleObjectiveServer")
    local folder = server and server:FindFirstChild("Needle")
    if not folder then return nil end
    local invalidCount, invalidIdType = 0, nil
    for _, part in ipairs(folder:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective") == true
            and part:GetAttribute("HIDDEN_WITHIN") == nil then
            local id = part:GetAttribute("HayId")
            if type(id) == "number" then return part end
            invalidCount += 1
            invalidIdType = type(id)
        end
    end
    if invalidCount > 0 and State.AutoPickupNeedle and os.clock() - lastUnusableNeedleLogAt >= 30 then
        lastUnusableNeedleLogAt = os.clock()
        warn(string.format("[Needle] %d exposed marker(s) have unusable HayId (%s); waiting for valid objective, not attempting pickup", invalidCount, tostring(invalidIdType)))
    end
    return nil
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

local function tryBuyTrack(trackName)
    if not IN_GAME or not GameConfig then return end
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

local vacuumSuctionActive = false
local function farmLoopEnabled()
    return not Unloaded and not cutsceneBypassActive and not needleHasPriority() and not roundEndingVisible()
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

    { name = "base", radius = 22.0, standoff = 2.2, cameraLift = 5.0, focusYOffset = 1.5 },
    { name = "lower-middle", radius = 18.0, standoff = 2.0, cameraLift = 5.0, focusYOffset = -0.1 },
    { name = "upper-middle", radius = 14.0, standoff = 1.9, cameraLift = 5.2, focusYOffset = -1.5 },
    { name = "peak", radius = 8.0, standoff = 1.7, cameraLift = 6.0, focusYOffset = 0.0 },
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
    local radialTops = {{}, {}, {}, {}}
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
    local fractions = {0.12, 0.36, 0.63, 0.88}
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
    print(string.format("[AFK Orbit] Fixed level heights: base=%.1f lower=%.1f upper=%.1f peak=%.1f", table.unpack(surfaces)))
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
local function bindAfkCameraView()
    local ok, err = pcall(function()
        RunService:BindToRenderStep(AFK_CAMERA_BIND, Enum.RenderPriority.Last.Value + 10, function(dt)
            if Unloaded or not IN_GAME or not afkFarmModeActive() or needleHasPriority() or roundEndingVisible() then return end
            local current = Workspace.CurrentCamera
            if not current or not afkCameraAnchor then return end
            local delta = math.max(0, math.min(dt, 0.25))
            local nextAngle = afkOrbitAngle + math.rad(AFK_ORBIT_SPEED_DEG) * delta
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
                    afkCameraAnchor.X + radial.X * (afkSweepRadius + 2.6),
                    afkSweepSurfaceY + band.cameraLift,
                    afkCameraAnchor.Z + radial.Z * (afkSweepRadius + 2.6)
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
local function startAfkCamera()
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
    afkSweepSurfaceY = afkBandSurfaceHeights[1]
    afkSweepFocusOffsetY = afkCurrentBand().focusYOffset
    afkPreviousCamera = cam
    afkPreviousType = cam.CameraType
    afkPreviousSubject = cam.CameraSubject
    afkPreviousCFrame = cam.CFrame
    pcall(function() RunService:UnbindFromRenderStep(AFK_CAMERA_BIND) end)
    if bindAfkCameraView() then
        print(string.format("[Camera] FIXED 4-band sweep started: %.1f deg/s, %ds full sweep, bands base/lower/upper/peak = 22/18/14/8 studs",
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
                if now - lastHayReadinessScan >= 0.45 then
                    lastHayReadinessScan = now
                    local scanStart = os.clock()
                    local folder = HayFolder
                    if not folder or not folder.Parent then
                        folder = Workspace:FindFirstChild("HaystackClient")
                        HayFolder = folder
                    end
                    local nearby, checked = false, 0
                    if folder then
                        local probe = anchor + radial * afkCurrentBand().radius
                        for _, hay in ipairs(folder:GetChildren()) do
                            checked += 1
                            if isPileHay(hay) then
                                local dx, dz = hay.Position.X - probe.X, hay.Position.Z - probe.Z
                                if dx * dx + dz * dz <= 12 * 12
                                    and math.abs(hay.Position.Y - surface) <= 12 then
                                    nearby = true
                                    break
                                end
                            end
                        end
                    end
                    afkVacuumTargetReady = nearby
                    local spentMs = (os.clock() - scanStart) * 1000
                    scanSamples += 1
                    scannedHayParts += checked
                    scanTotalMs += spentMs
                    scanMaxMs = math.max(scanMaxMs, spentMs)
                    if now - lastPerfReport >= 30 then
                        print(string.format("[Perf] v103.00 hay scans=%d, parts examined=%d, average=%.2fms, max=%.2fms per scan",
                            scanSamples, scannedHayParts, scanTotalMs / math.max(1, scanSamples), scanMaxMs))
                        scanSamples, scannedHayParts, scanTotalMs, scanMaxMs = 0, 0, 0, 0
                        lastPerfReport = now
                    end
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
        return count ~= nil and tonumber(count) > 0 and tonumber(total) > 0
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
                                    print("[AutoUI] Replay vote registered; waiting for next round")
                                end
                            elseif not replayFiredForThisEnding then
                                local cooldown = getReplayCooldown()
                                if now - replayButtonFirstSeenAt >= REPLAY_READY_DELAY
                                    and now - lastReplayClickTime >= cooldown and not autoUiMouseBusy and not needlePickupActive then
                                    replayClickStreak = replayClickStreak + 1
                                    lastReplayClickTime = now
                                    local clicked = activateButton(replayButton)
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

local MainTab = Window:Tab({ Title = "Overview & Settings", Icon = "house" })
local FarmingSection = Window:Section({ Title = "Farming", Icon = "wheat", Opened = true })
local CollectingTab = FarmingSection:Tab({ Title = "Collecting", Icon = "wheat" })
local SellingTab = FarmingSection:Tab({ Title = "Selling", Icon = "coins" })
local ToolsTab = FarmingSection:Tab({ Title = "Tools", Icon = "hammer" })
local NeedleTab = FarmingSection:Tab({ Title = "Needle", Icon = "search" })
local InventorySection = Window:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
local ShopTab = InventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
local UpgradesTab = InventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
local ExploitTab = Window:Tab({ Title = "Exploit", Icon = "zap" })
local SettingsTab = MainTab

do
    Header(MainTab, "Dashboard")
    Info(MainTab, "Game: ".. (IN_GAME and "Chapter 1 (FARMHOUSE)" or "Lobby"))
    Info(MainTab, "Toggle UI: RightControl")

    AddToggle(MainTab, "AutoFarmWins", "Auto Farm Wins (AFK Farm Mode)", false,
        "AFK round-create, 48 deg/s four-band sweep (22 / 18 / 14 / 8 studs), and automatic vacuum when enabled below.",
        function(v)
            if not v then releaseAfkCamera() end
            safeWrite(CACHE_FOLDER .. "/autofarmwins_shared.txt", tostring(v))
            print("[Mode] AFK Farm Mode = ".. tostring(State.AutoFarmWins))
        end)
    AddToggle(MainTab, "AutoFarmVacuum", "Vacuum During Auto Farm Wins", true,
        "Use heat-bar-controlled suction while the character follows the base, lower-middle, upper-middle and peak sweep.")

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
    Info(ToolsTab, "Tools work independently of AFK mode. With AFK enabled, TNT targets remaining hay around the orbiting camera's current angle.")
    AddToggle(ToolsTab, "AutoUseTNT", "Auto Use TNT", false)
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
    Header(ExploitTab, "Lobby Exploits")

    Registry.ArcadeFarm = ExploitTab:Toggle({
        Title = "Arcade Gem Farm",
        Value = false,
        Callback = function(v) State.ArcadeFarm = v end,
    })

    Registry.ClassRoller = ExploitTab:Toggle({
        Title = "Auto Class Roller",
        Value = false,
        Callback = function(v) State.ClassRoller = v end,
    })

    local targetDropdown = ExploitTab:Dropdown({
        Title = "Target Class",
        Values = { "The Chosen One", "Ultimate Farmer", "Hoover", "Drone Specialist", "Prospector" },
        Value = "The Chosen One",
        Callback = function(v) State.ClassTarget = v end,
    })
    Registry.ClassTarget = targetDropdown
    AddSlider(ExploitTab, "ClassRollInterval", "Roll Interval (s)", 0.5, 3, 1.1, 0.1)
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

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.CollectInterval) or 0.5)
        if not IN_GAME then break end
        local findingNeedle = State.AutoFindNeedle and LocalPlayer:GetAttribute("NeedleOwned") ~= true
            and findExposedNeedlePart() == nil
        if farmLoopEnabled() and (State.AutoPickHay or findingNeedle) and not isBagFull() then
            HayCache.ttl = 1.5
            local hay = findClosestHayCached()
            if hay then
                local id = hay:GetAttribute("HayId")
                if id then
                    local radiusHint = tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                    local candidates = getGrabCandidates(hay, radiusHint)
                    if not needleHasPriority() then pcall(function() PickHay:FireServer(id, candidates) end) end
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
        if farmLoopEnabled() and State.AutoCollectDroppedHay and not isBagFull() then
            DroppedCache.ttl = 1.5
            local d = findClosestDroppedCached()
            if d then
                pcall(function() PickDroppedHay:FireServer(d) end)
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.CollectInterval) or 0.5)
        if not IN_GAME then break end
        if farmLoopEnabled() and State.AutoCollectGems then
            GemsCache.ttl = 1.5
            local gemPart, id = findClosestGemCached()
            if gemPart and id then
                pcall(function() CollectGem:FireServer(id) end)
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(1)
        if not IN_GAME then break end
        if farmLoopEnabled() and State.AutoSellHay then
            local held = getHayHeld()
            local thresh = tonumber(State.SellThreshold) or 25
            if (State.SellOnlyIfFull and isBagFull()) or (held >= thresh) then
                if held > 0 then trySell() end
            end
        end
    end
end)

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
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil then
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
        if farmLoopEnabled() and State.AutoUseTNT and owns("TntOwned") then
            if not LocalPlayer:GetAttribute("NeedleInputLocked") then
                local afk = afkFarmModeActive()
                local root = getHRP()
                local target = afkPlayerAnchor or afkCameraAnchor
                local maxAfkDistance = afkVacuumOrbitEnabled() and (afkOrbitRadius + 9) or 10
                if not afk or (root and target and afkHorizontalDistance(root.Position, target) <= maxAfkDistance) then
                    pcall(function() TntAction:FireServer("light") end)
                    task.wait(0.4)
                    if farmLoopEnabled() and not LocalPlayer:GetAttribute("NeedleInputLocked") then
                        local c = Workspace.CurrentCamera
                        root = getHRP()
                        target = afkPlayerAnchor or afkCameraAnchor
                        if afk then
                            if root and target and afkHorizontalDistance(root.Position, target) <= maxAfkDistance then
                                local throwCFrame, velocity = afkTntThrow(root, target)
                                pcall(function() TntAction:FireServer("throw", throwCFrame, velocity) end)
                            end
                        elseif c then
                            local velocity = c.CFrame.LookVector * 40 + Vector3.new(0, 8, 0)
                            pcall(function() TntAction:FireServer("throw", c.CFrame, velocity) end)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ToolInterval) or 0.5)
        if not IN_GAME then break end
        if farmLoopEnabled() and State.AutoUsePitchfork and owns("PitchforkOwned") then
            HayCache.ttl = 1.5
            local hay = findClosestHayCached()
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
        if farmLoopEnabled() and State.AutoDeployDrone and owns("DroneOwned") then
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

    local function readHeat()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local hud = playerGui and playerGui:FindFirstChild("HUD")
        local overheat = hud and hud:FindFirstChild("Overheat")
        local fill = overheat and overheat:FindFirstChild("Fill")
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

    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        releaseVacuum()
        if previousCleanup then pcall(previousCleanup) end
    end

    local function mustReleaseForPriority()
        return Unloaded or not IN_GAME or not vacuumRequested() or not Window.Closed
            or earlyIntroPending or introSkipPending or needleHasPriority() or roundEndingVisible() or needlePickupActive
            or LocalPlayer:GetAttribute("NeedleInputLocked") == true
            or getHRP() == nil or Workspace.CurrentCamera == nil
    end

    local function canVacuum()
        return not mustReleaseForPriority()
            and (not afkVacuumOrbitEnabled() or afkVacuumTargetReady)
    end

    local function equipVacuum()
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
                    releaseVacuum()
                    if heat ~= nil then
                        if heat <= HEAT_EMPTY then
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
                                    local current = activeFill.Size.Y.Scale

                                    if current >= HEAT_FULL or (previousValue and previousValue >= 0.95 and current < previousValue - 0.15) then
                                        reachedFull = true
                                        releaseVacuum()
                                    end
                                    previousValue = current
                                end)
                            end
                            local pressed = pcall(function()
                                VirtualInputManager:SendMouseMoveEvent(x, y, game)
                                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                            end)
                            if not pressed then return end
                            held = true
                            didHold = true
                            print(string.format("[Vacuum] Cycle %d: holding Mouse1 to 100%% heat (Runtime L%d)", cycle, runtimeLevel))

                            local started = os.clock()
                            local lastHeat = startHeat
                            local lastRisingAt = started

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
                                    if lastHeat == nil or current > lastHeat + 0.0002 then
                                        lastRisingAt = os.clock()
                                    end
                                    lastHeat = current

                                    if os.clock() - lastRisingAt > HEAT_STALLED_SECONDS then
                                        if os.clock() - lastStallWarning > 30 then
                                            lastStallWarning = os.clock()
                                            warn("[Vacuum] Heat not increasing; releasing Mouse1 and retrying equip (not cooling)")
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

                            readyAt = os.clock() + 0.3
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
        if busy or Unloaded or roundEndingVisible() or not State.AutoPickupNeedle or owned() or not needle or not needle.Parent then return false end
        busy = true
        needlePickupActive = true
        local started = os.clock()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        local needleId = needle:GetAttribute("HayId")
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
        if type(needleId) ~= "number" then
            reportPrerequisite("needle HayId invalid (type=" .. type(needleId) .. "); refreshing target")
            trackedNeedle = nil
            busy = false
            needlePickupActive = false
            return false
        end
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
                        for _, part in ipairs(folder:GetDescendants()) do
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
                if LocalPlayer:GetAttribute("HoveredHayId") == needleId then
                    LocalPlayer:SetAttribute("HoveredHayId", originalHover)
                end
            end)
            if success then
                confirmedNeedlePart, confirmedNeedleId = needle, needleId
            elseif char.Parent then
                pcall(function() char:PivotTo(initialPivot) end)
            end
            local elapsed = os.clock() - started
            if success then
                print(string.format("[Needle] Picked up HayId=%s in %.2fs (%d clicks)",
                    tostring(needleId), elapsed, clicks))
            else
                warn(string.format("[Needle] Pickup failed HayId=%s: %s (%d clicks)",
                    tostring(needleId), tostring(failureReason), clicks))
            end
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
            local targetRootPosition = needle.Position - horizontalForward * SETTINGS.HorizontalOffsetStuds
                + Vector3.new(0, SETTINGS.HeightAboveNeedle, 0)
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
            local function aimAtNeedle()
                if Unloaded or not needle.Parent or observedOwnership or roundEndingVisible() then return end
                if Workspace.CurrentCamera ~= cam then return end
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.lookAt(cameraPosition, needle.Position, Vector3.yAxis)
            end
            placeNearNeedle()
            captureOwnership()
            if observedOwnership then success = true; return end
            local function forceHover()
                if not Unloaded and State.AutoPickupNeedle and needle.Parent and not observedOwnership then
                    aimAtNeedle()
                    if LocalPlayer:GetAttribute("HoveredHayId") ~= needleId then
                        LocalPlayer:SetAttribute("HoveredHayId", needleId)
                    end
                end
            end
            LocalPlayer:SetAttribute("HoveredHayId", needleId)
            aimAtNeedle()
            RunService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value + 30, forceHover)
            bound = true
            RunService.RenderStepped:Wait()
            applyQueryFilter()

            RunService.RenderStepped:Wait()
            for i = 1, SETTINGS.MaxClicks do
                captureOwnership()
                if observedOwnership then success = true; break end
                if Unloaded or not State.AutoPickupNeedle or roundEndingVisible() then failureReason = "Pickup cancelled at round end"; break end
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
                local hoverMatches = LocalPlayer:GetAttribute("HoveredHayId") == needleId
                local projectedNeedle, onScreen = cam:WorldToViewportPoint(needle.Position)
                local screenOffset = onScreen and (Vector2.new(projectedNeedle.X, projectedNeedle.Y) - center).Magnitude or -1
                if not hoverMatches then failureReason = "HoveredHayId did not stick"; break end
                if not onScreen or screenOffset > 15 then
                    failureReason = "Needle camera did not centre the target"
                    break
                end
                local pressed, pressErr = pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                end)
                if not pressed then failureReason = "VIM press failed: " .. tostring(pressErr); break end
                clicks += 1
                mouseDown = true
                task.wait(SETTINGS.MousePressSeconds)
                releaseMouse()
                if waitForConfirmation(SETTINGS.OwnershipWaitSeconds) then success = true; break end
                if i == 4 then applyQueryFilter() end
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
                    or type(trackedNeedle:GetAttribute("HayId")) ~= "number" then
                    trackedNeedle = findExposedNeedlePart()
                end
                if trackedNeedle and trackedNeedle == confirmedNeedlePart
                    and trackedNeedle:GetAttribute("HayId") == confirmedNeedleId then
                    continue
                end
                if trackedNeedle and not busy and (os.clock() - lastAttempt) >= SETTINGS.RetryDelay then
                    lastAttempt = os.clock()
                    local target = trackedNeedle
                    task.spawn(function() tryPickup(target) end)
                end
            end
        end
    end)
end

local lastNeedleHandIn = 0
RunService.Heartbeat:Connect(function()
    if Unloaded or not IN_GAME then return end
    if not State.AutoHandInNeedle then return end
    if needlePickupActive or roundEndingVisible() then return end
    if LocalPlayer:GetAttribute("NeedleOwned") ~= true then return end
    if os.clock() - lastNeedleHandIn < 0.12 then return end
    lastNeedleHandIn = os.clock()
    local farmer = Workspace:FindFirstChild("NPC") and Workspace.NPC:FindFirstChild("Farmer_NPC")
    local hrp = getHRP()
    if not farmer or not hrp then return end
    local target = farmer:GetPivot().Position
    if (hrp.Position - target).Magnitude > 15 then
        hrp.CFrame = farmer:GetPivot() * CFrame.new(0, 0, 4)
    end
    pcall(function() NeedleHandIn:FireServer() end)
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.BuyInterval) or 1)
        if not IN_GAME then break end
        if State.AutoBuyTools then
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

task.spawn(function()
    while not Unloaded do
        task.wait(3)
        if not IN_GAME then break end
        if State.UpgCapacity then tryBuyTrack("Capacity") end
        if State.UpgHandSpeed then tryBuyTrack("Speed") end
        if State.UpgHandGrab then tryBuyTrack("Grab") end
        if State.UpgHandHold then tryBuyTrack("HandHold") end
        if State.UpgTntLuck then tryBuyTrack("TntLuck") end
        if State.UpgTntCooldown then tryBuyTrack("TntCooldown") end
        if State.UpgTntPower then tryBuyTrack("TntPower") end
        if State.UpgPitchCooldown then tryBuyTrack("PitchforkCooldown") end
        if State.UpgPitchHold then tryBuyTrack("PitchforkHold") end
        if State.UpgPitchSweep then tryBuyTrack("Pitchfork") end
        if State.UpgDroneSpeed then tryBuyTrack("DroneSpeed") end
        if State.UpgDroneGrab then tryBuyTrack("DroneGrab") end
        if State.UpgDroneCapacity then tryBuyTrack("DroneCapacity") end
        if State.UpgVacPower then tryBuyTrack("VacuumPower") end
        if State.UpgVacCooling then tryBuyTrack("VacuumCooling") end
        if State.UpgVacRuntime then tryBuyTrack("VacuumRuntime") end
    end
end)

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

local KILLS_PER_CYCLE  = 6
local CYCLES_PER_YIELD = 10
local YIELD_DURATION   = 0.001

local function fastLeave()
    local sg = LocalPlayer.PlayerGui:FindFirstChild("ArcadeScreen")
    if sg then sg.Enabled = false end

    pcall(function()
        LocalPlayer:SetAttribute("ArcadePlaying", nil)
        LocalPlayer:SetAttribute("NeedleInputLocked", nil)
    end)

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end

    local cam = workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom end
    pcall(function() ArcadeSession:FireServer("quit", 0, 0) end)
end

local function arcadeCycle()
    pcall(function() fireproximityprompt(ArcadePrompt) end)
    for i = 1, KILLS_PER_CYCLE do
        pcall(function() ArcadeReport:FireServer("kills", 40, 0) end)
    end
    fastLeave()
end

task.spawn(function()
    local cycles = 0
    while not Unloaded do
        if IN_GAME then

            if State.ArcadeFarm then
                State.ArcadeFarm = false
                Notify("Arcade", "Lobby only.", 3, "x")
            end
            task.wait(0.1)
        elseif State.ArcadeFarm and ArcadePrompt and ArcadeReport then
            cycles = cycles + 1
            arcadeCycle()
            if cycles % CYCLES_PER_YIELD == 0 then
                task.wait(YIELD_DURATION)
            end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ClassRollInterval) or 1.1)
        if IN_GAME then
            if State.ClassRoller then State.ClassRoller = false; Notify("Roller", "Lobby only.", 3, "x") end
        else
            if State.ClassRoller and RollClass then
                local ok, result = pcall(function() return RollClass:InvokeServer() end)
                if ok and type(result) == "table" and result.success and result.className == State.ClassTarget then
                    Notify("Class Roller", "FOUND: "..result.className, 5, "check")
                end
            end
        end
    end
end)

pcall(function()
    task.defer(function()
        if not Unloaded then pcall(function() CollectingTab:Select() end) end

    end)
end)

print("[Needle] Loaded v103.00")
