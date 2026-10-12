-- Beyy Chapter 2 standalone | Native GUI, puzzles and tools | 1.0.0
if game.PlaceId ~= 83445806734780 then warn("[Beyy CH2] Join Chapter 2 before running this script") return end
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local LocalPlayer=Players.LocalPlayer
if not LocalPlayer then warn("[Beyy CH2] Player is not ready; rerun after joining") return end
local env=_G
if type(getgenv)=="function" then
    local ok,result=pcall(getgenv)
    if ok and type(result)=="table" then env=result end
end
if type(env.__BEYY_CH2_STANDALONE_STOP)=="function" then pcall(env.__BEYY_CH2_STANDALONE_STOP) end
-- Release the full hub before acquiring its camera/mouse controls.
if type(_G.__BEYY_HUB_CLEANUP)=="function" then pcall(_G.__BEYY_HUB_CLEANUP) end
local hubUnloaded=false
local hubRestoreAction
local connections={}
local function connect(signal,callback)
    local connection=signal:Connect(callback)
    connections[#connections+1]=connection
    return connection
end
local gui=Instance.new("ScreenGui")
gui.Name="BeyyChapter2Standalone"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=100
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=LocalPlayer:WaitForChild("PlayerGui")
local function create(kind,props,parent)
    local item=Instance.new(kind)
    for key,value in pairs(props) do item[key]=value end
    item.Parent=parent
    return item
end
local panel=create("Frame",{Size=UDim2.fromOffset(360,510),Position=UDim2.new(0,24,0.5,-255),BackgroundColor3=Color3.fromRGB(24,27,34),BorderSizePixel=0},gui)
create("UICorner",{CornerRadius=UDim.new(0,9)},panel)
local header=create("TextLabel",{Size=UDim2.new(1,-16,0,34),Position=UDim2.fromOffset(8,0),BackgroundTransparency=1,Text="Beyy • Chapter 2",Font=Enum.Font.GothamBold,TextSize=17,TextColor3=Color3.fromRGB(240,242,248),TextXAlignment=Enum.TextXAlignment.Left,Active=true},panel)
local body=create("ScrollingFrame",{Size=UDim2.new(1,-16,1,-44),Position=UDim2.fromOffset(8,38),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},panel)
create("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},body)
local order=0
local function row(kind,props)
    order+=1
    props.LayoutOrder=order
    props.Size=props.Size or UDim2.new(1,-6,0,30)
    props.Font=props.Font or Enum.Font.Gotham
    props.TextSize=props.TextSize or 13
    props.TextColor3=props.TextColor3 or Color3.fromRGB(227,232,244)
    props.BorderSizePixel=0
    return create(kind,props,body)
end
local statuses={}
local function statusRow(name)
    local label=row("TextLabel",{Size=UDim2.new(1,-6,0,38),BackgroundTransparency=1,Text=name..": Idle",TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
    statuses[name]=label
end
local function updateStatus(name,message)
    local label=statuses[name]
    local text=name..": "..tostring(message)
    if label and label.Text~=text then label.Text=text end
end
row("TextLabel",{BackgroundTransparency=1,Text="Right Ctrl shows/hides • Drag the title to move",TextSize=11})
local function button(title,callback)
    local item=row("TextButton",{BackgroundColor3=Color3.fromRGB(44,53,71),Text=title,AutoButtonColor=true})
    create("UICorner",{CornerRadius=UDim.new(0,5)},item)
    connect(item.Activated,function() if not hubUnloaded then callback() end end)
    return item
end
local sharedFarmPuzzleBusy=function() return false end
local toolState={TNT=false,Pitchfork=false,Drone=false,Vacuum=false,Slot=5}
local vacuumHeld=false
local vacuumPoint=Vector2.zero
local vacuumEquipKey
local function releaseVacuum()
    if vacuumEquipKey then
        pcall(function() VirtualInputManager:SendKeyEvent(false,vacuumEquipKey,false,game) end)
        vacuumEquipKey=nil
    end
    if vacuumHeld then
        vacuumHeld=false
        pcall(function() VirtualInputManager:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0) end)
    end
end
local hubWindow={Closed=false}
local savedMouseBehavior,savedMouseIcon
function hubWindow:Close()
    self.Closed=true;panel.Visible=false
    if savedMouseBehavior then UserInputService.MouseBehavior=savedMouseBehavior end
    if savedMouseIcon~=nil then UserInputService.MouseIconEnabled=savedMouseIcon end
    savedMouseBehavior,savedMouseIcon=nil,nil
end
function hubWindow:Open()
    if hubUnloaded then return end
    if savedMouseBehavior==nil then savedMouseBehavior=UserInputService.MouseBehavior;savedMouseIcon=UserInputService.MouseIconEnabled end
    self.Closed=false;panel.Visible=true
    UserInputService.MouseBehavior=Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled=true
    releaseVacuum()
end
local cleanup
cleanup=function()
    if hubUnloaded then return end
    hubUnloaded=true
    hubWindow:Close()
    releaseVacuum()
    if hubRestoreAction then pcall(hubRestoreAction) end
    for _,name in ipairs({"BeyyCH2StandaloneLever_","BeyyCH2StandaloneColour_"}) do
        pcall(function() RunService:UnbindFromRenderStep(name..tostring(LocalPlayer.UserId)) end)
    end
    local numberClose=env.__BEYY_NUMBER_FINDER_CLOSE
    if type(numberClose)=="function" then pcall(numberClose) end
    for _,connection in ipairs(connections) do connection:Disconnect() end
    gui:Destroy()
    if env.__BEYY_CH2_STANDALONE_STOP==cleanup then env.__BEYY_CH2_STANDALONE_STOP=nil end
    if _G.__BEYY_HUB_CLEANUP==cleanup then _G.__BEYY_HUB_CLEANUP=nil end
end
env.__BEYY_CH2_STANDALONE_STOP=cleanup
_G.__BEYY_HUB_CLEANUP=cleanup
hubWindow:Open()
connect(UserInputService.InputBegan,function(input,processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.RightControl then
        if hubWindow.Closed then hubWindow:Open() else hubWindow:Close() end
    end
end)
local dragStart,startPosition,dragging
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;dragStart=input.Position;startPosition=panel.Position
    end
end)
connect(UserInputService.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
connect(UserInputService.InputChanged,function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local delta=input.Position-dragStart
        panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
    end
end)
-- Native adapter for the existing action buttons; no UI library is downloaded.
local puzzleTab={}
function hubWindow:Tab() return puzzleTab end
function puzzleTab:Section() end
function puzzleTab:Button(options) return button(options.Title,options.Callback) end
statusRow("Puzzles")
statusRow("Levers")
statusRow("Number")
statusRow("Colour")
statusRow("Picture")
local function stopTools()
    for _,key in ipairs({"TNT","Pitchfork","Drone","Vacuum"}) do toolState[key]=false end
    releaseVacuum()
end
do
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
        local COLOUR_RENDER_BIND = "BeyyCH2StandaloneColour_" .. tostring(LocalPlayer.UserId)

        local COLOUR_CAMERA_SETTLE = 0.12
        local COLOUR_MOUSE_SETTLE = 0.025
        local COLOUR_CLICK_HOLD = 0.10
        local COLOUR_CLICK_GAP = 0.14
        local COLOUR_BETWEEN_PEDESTALS = 0.06
        local function colourStatus(message)
            updateStatus("Colour",message)
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
            releaseVacuum()
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
                pcall(function() updateStatus("Colour",string.format("Red: %d | Purple: %d | Green: %d", counts[1], counts[2], counts[3])) end)
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
                        task.wait(math.max(COLOUR_MOUSE_SETTLE, 0.06))
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

                        task.wait(clickIndex < counts[i] and COLOUR_CLICK_GAP or 0.18)
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
        local LEVER_RENDER_BIND = "BeyyCH2StandaloneLever_" .. tostring(LocalPlayer.UserId)

        local function status(message)
            updateStatus("Levers",message)
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
        local function pictureStatus(message)
            updateStatus("Picture",message)
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

                local acknowledgementTimeout = 2.25
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
        sharedFarmPuzzleBusy = function() return allPuzzlesRunning or puzzleControllerBusy or pictureRunning end
        local allPuzzlesCancel = false
        local allPuzzlesStage = "Idle"
        local function allStatus(message)
            allPuzzlesStage = message
            updateStatus("Puzzles",message)
        end
        local isNumberStageCancelled = function()
            return hubUnloaded or allPuzzlesCancel
        end
        local numberFactory
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
            local runner, compileErr
            if not numberFactory then
                runner, compileErr = loadstring(
                    "return function(__beNumberStatus, __beCancelled)\n" .. numberCode .. "\nend")
            end
            if not numberFactory and not runner then
                allStatus("Number solver compile failed: " .. tostring(compileErr))
                return false
            end
            local okFactory, entry = true, numberFactory
            if not entry then okFactory, entry = pcall(runner) end
            if not okFactory or type(entry) ~= "function" then
                allStatus("Number solver initialization failed: " .. tostring(entry))
                return false
            end
            numberFactory = entry
            local ok, solved = pcall(entry, function(message)
                updateStatus("Number",message)
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
                allStatus("No complete puzzle sequence is running")
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
            releaseVacuum()
            hubWindow:Close()
            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()
            return not hubUnloaded and not allPuzzlesCancel and hubWindow.Closed
        end
        local function runAllPuzzles()
            if allPuzzlesRunning then allStatus("Already running"); return end
            if hubUnloaded or puzzleControllerBusy or leverRunning or colourRunning then
                allStatus("Cannot start while another puzzle controller is active")
                return
            end
            releaseVacuum()
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
                    releaseVacuum()
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


end
row("TextLabel",{BackgroundTransparency=1,Text="Automatic tools • pause during puzzles / cutscenes",TextSize=12})
local toggleButtons={}
for _,entry in ipairs({{"TNT","TNT"},{"Pitchfork","Pitchfork"},{"Drone","Drone"},{"Vacuum","Vacuum"}}) do
    local key,label=entry[1],entry[2]
    local item
    item=button(label..": OFF",function()
        toolState[key]=not toolState[key]
        item.Text=label..": "..(toolState[key] and "ON" or "OFF")
        if key=="Vacuum" and not toolState.Vacuum then releaseVacuum() end
    end)
    toggleButtons[key]=item
end
local slotButton
slotButton=button("Vacuum slot: 5 (click to cycle)",function()
    toolState.Slot=toolState.Slot%9+1
    slotButton.Text="Vacuum slot: "..toolState.Slot.." (click to cycle)"
    releaseVacuum()
end)
statusRow("Tools")
button("Stop tools",function()
    stopTools()
    for key,item in pairs(toggleButtons) do item.Text=key..": OFF" end
end)
button("Unload",function() if _G.__BEYY_HUB_CLEANUP then _G.__BEYY_HUB_CLEANUP() else cleanup() end end)
local remoteCache={}
local function remote(name)
    local item=remoteCache[name]
    if item and item.Parent then return item end
    local folder=ReplicatedStorage:FindFirstChild("NeedleHaystack")
    item=folder and folder:FindFirstChild(name)
    if item and item:IsA("RemoteEvent") then remoteCache[name]=item;return item end
end
local function send(name,...)
    local item=remote(name)
    if not item then return false end
    return pcall(item.FireServer,item,...)
end
local function toolBlockReason()
    if sharedFarmPuzzleBusy() then return "Paused: puzzle solver owns controls" end
    if not hubWindow.Closed then return "Paused: close GUI with Right Ctrl" end
    if LocalPlayer:GetAttribute("CutsceneActive")==true or LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true then return "Paused: cutscene" end
    if LocalPlayer:GetAttribute("NeedleInputLocked")==true or LocalPlayer:GetAttribute("HintViewerOpen")==true then return "Paused: input locked" end
    local character=LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return "Waiting for character" end
end
local function nearestHayId()
    local character=LocalPlayer.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local folder=Workspace:FindFirstChild("HaystackClient")
    if not root or not folder then return nil end
    local best,score=nil,30*30
    for _,part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") then
            local id=part:GetAttribute("HayId")
            if type(id)=="number" and part:GetAttribute("IsHeld")~=true and part:GetAttribute("Held")~=true then
                local d=part.Position-root.Position
                local distance=d:Dot(d)
                if distance<score then score=distance;best=id end
            end
        end
    end
    return best
end
local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,
    Enum.KeyCode.Five,Enum.KeyCode.Six,Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
local fillCache
local function vacuumHeat()
    if not fillCache or not fillCache.Parent then
        local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local hud=pg and pg:FindFirstChild("HUD")
        local heat=hud and hud:FindFirstChild("Overheat")
        fillCache=heat and heat:FindFirstChild("Fill")
    end
    return fillCache and fillCache:IsA("GuiObject") and fillCache.Size.Y.Scale or nil
end
-- One adaptive scheduler handles all four tools. Puzzle workers exist only while requested.
task.spawn(function()
    local nextPitch,nextDrone,nextTnt=0,0,0
    local throwAt
    local vacuumStage="idle"
    local stageAt,startedAt=0,0
    local cooling=false
    local coolingUntil=0
    while not hubUnloaded do
        local enabled=toolState.TNT or toolState.Pitchfork or toolState.Drone or toolState.Vacuum
        task.wait(enabled and 0.08 or 0.5)
        if hubUnloaded then break end
        local reason
        if enabled then reason=toolBlockReason() else reason="All tools off" end
        if reason then
            releaseVacuum();vacuumStage="idle";throwAt=nil
            updateStatus("Tools",reason)
        else
            local now=os.clock()
            updateStatus("Tools","Active • owned tools only")
            if toolState.Pitchfork and now>=nextPitch then
                nextPitch=now+0.5
                if LocalPlayer:GetAttribute("PitchforkOwned")==true then
                    local id=nearestHayId()
                    if id then send("PitchforkDig",id) end
                end
            end
            if toolState.Drone and now>=nextDrone then
                nextDrone=now+1
                if LocalPlayer:GetAttribute("DroneOwned")==true and LocalPlayer:GetAttribute("DroneDeployed")~=true then send("DeployDrone") end
            end
            if not toolState.TNT then throwAt=nil
            elseif throwAt and now>=throwAt then
                throwAt=nil
                local camera=Workspace.CurrentCamera
                if camera then send("TntAction","throw",camera.CFrame,camera.CFrame.LookVector*40+Vector3.new(0,8,0)) end
                nextTnt=now+0.5
            elseif not throwAt and now>=nextTnt and LocalPlayer:GetAttribute("TntOwned")==true then
                nextTnt=now+0.8
                if send("TntAction","light") then throwAt=now+0.4 end
            end
            if not toolState.Vacuum then releaseVacuum();vacuumStage="idle"
            else
                local heat=vacuumHeat()
                if vacuumHeld and (heat and heat>=0.98 or not heat and now-startedAt>=30) then
                    releaseVacuum();vacuumStage="idle";cooling=true;coolingUntil=now+13.5
                end
                if cooling and (heat and heat<=0.001 or not heat and now>=coolingUntil) then cooling=false end
                if not cooling then
                    if vacuumStage=="idle" then
                        vacuumEquipKey=hotbar[toolState.Slot]
                        pcall(function() VirtualInputManager:SendKeyEvent(true,vacuumEquipKey,false,game) end)
                        vacuumStage="key";stageAt=now+0.05
                    elseif vacuumStage=="key" and now>=stageAt then
                        if vacuumEquipKey then pcall(function() VirtualInputManager:SendKeyEvent(false,vacuumEquipKey,false,game) end) end
                        vacuumEquipKey=nil;vacuumStage="settle";stageAt=now+0.15
                    elseif vacuumStage=="settle" and now>=stageAt then
                        local camera=Workspace.CurrentCamera
                        if camera then
                            vacuumPoint=camera.ViewportSize/2
                            local ok=pcall(function() VirtualInputManager:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,true,game,0) end)
                            if ok then vacuumHeld=true;startedAt=now;vacuumStage="holding" else vacuumStage="idle" end
                        end
                    end
                end
            end
        end
    end
    releaseVacuum()
end)

