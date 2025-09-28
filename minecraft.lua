-- Martil Auto Joiner Bootyyy (micro-scheduled / frame-safe, FIFO-queued)

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")

-- ===== Micro Scheduling (frame-accurate) =====
-- You can set this to 0.00001; we never busy-wait. We just yield 0 frames (defer) or 1 frame.
local MICRO_DELAY = 0.00001

-- Yield to the next frame exactly once (no time-based wait)
local function yieldOneFrame()
    RunService.Heartbeat:Wait()
end

-- Yield N frames (integer)
local function yieldFrames(n)
    for i = 1, (n or 1) do
        RunService.Heartbeat:Wait()
    end
end

-- "Instant" defer: schedule a function to run on the next scheduler slice safely
local function microDefer(fn)
    -- If the desired delay is truly tiny, we defer; otherwise we use task.delay
    local d = tonumber(MICRO_DELAY) or 0
    if d <= 0.001 then
        task.defer(fn) -- schedules for the next tick without blocking
    else
        -- Roblox still won’t honor sub-frame waits precisely; this will be ~1 frame minimum.
        task.delay(d, fn)
    end
end

-- A very short “pause” that never busy-waits: 0 frames (defer) or 1 frame.
local function microPause(optionalFrames)
    local d = tonumber(MICRO_DELAY) or 0
    if optionalFrames and optionalFrames > 0 then
        yieldFrames(optionalFrames)
        return
    end
    if d <= 0.001 then
        -- 0-frame style: just yield back control minimally
        -- Using task.wait(0) returns control, but Heartbeat is more deterministic for UI
        -- We use a tiny defer to avoid blocking the current thread:
        local resumed = false
        microDefer(function() resumed = true end)
        while not resumed do
            -- We must allow the scheduler to breathe; wait 1 frame at most
            yieldOneFrame()
        end
    else
        -- If someone raises MICRO_DELAY above 1ms, we still won’t spin—just do one frame
        yieldOneFrame()
    end
end

-- ===== Message Queue (guarantee every message runs, in order) =====
local queue = {}
local pumping = false

-- tune these if any UI needs more breathing room
local FRAMES_BEFORE_CLICK = 1   -- wait after typing before clicking
local FRAMES_AFTER_CLICK  = 2   -- wait after clicking before next item

local function classifyMessage(msg)
    if type(msg) ~= "string" then return {kind="unknown"} end
    if string.find(msg, "TeleportService") then
        return {kind="script", src = msg}
    end
    return {kind="job", id = tostring(msg)}
end

local function pushMessage(item)
    table.insert(queue, item)
end

local function pumpQueue(processJob, processScript)
    if pumping then return end
    pumping = true
    task.spawn(function()
        while #queue > 0 do
            local item = table.remove(queue, 1)
            if item.kind == "job" then
                processJob(item.id)
                -- spacing between steps/items (frame-accurate, crash-safe)
                for i=1, FRAMES_BEFORE_CLICK do RunService.Heartbeat:Wait() end
                for i=1, FRAMES_AFTER_CLICK do RunService.Heartbeat:Wait() end
            elseif item.kind == "script" then
                processScript(item.src)
                for i=1, FRAMES_AFTER_CLICK do RunService.Heartbeat:Wait() end
            end
        end
        pumping = false
    end)
end

-- ===== UI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MartilAutoJoiner"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 250)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local Shadow = Instance.new("ImageLabel")
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0, -15, 0, -15)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://1316045217"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(10,10,118,118)
Shadow.ZIndex = -1
Shadow.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0, 40)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Martil Auto Joiner Bootyyy"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -20, 0, 1)
Divider.Position = UDim2.new(0, 10, 0, 42)
Divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 120, 1, -50)
Sidebar.Position = UDim2.new(0, 0, 0, 50)
Sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideUICorner = Instance.new("UICorner")
SideUICorner.CornerRadius = UDim.new(0, 12)
SideUICorner.Parent = Sidebar

local SideButton = Instance.new("TextButton")
SideButton.Size = UDim2.new(1, -10, 0, 40)
SideButton.Position = UDim2.new(0, 5, 0, 10)
SideButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SideButton.Text = "Main"
SideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SideButton.Font = Enum.Font.Gotham
SideButton.TextSize = 16
SideButton.Parent = Sidebar

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 8)
SideCorner.Parent = SideButton

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -130, 1, -60)
ContentFrame.Position = UDim2.new(0, 130, 0, 60)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local ToggleText = Instance.new("TextLabel")
ToggleText.Size = UDim2.new(0.7, 0, 0, 30)
ToggleText.Position = UDim2.new(0, 0, 0, 0)
ToggleText.BackgroundTransparency = 1
ToggleText.Text = "Start Joiner"
ToggleText.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleText.Font = Enum.Font.Gotham
ToggleText.TextSize = 16
ToggleText.TextXAlignment = Enum.TextXAlignment.Left
ToggleText.Parent = ContentFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 70, 0, 30)
ToggleButton.Position = UDim2.new(1, -80, 0, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
ToggleButton.Text = "OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 14
ToggleButton.Parent = ContentFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = ToggleButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 100)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Disconnected"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ContentFrame

-- Keybind
local toggleKey = Enum.KeyCode.RightShift
local waitingForKey = false

local KeybindButton = Instance.new("TextButton")
KeybindButton.Size = UDim2.new(0, 150, 0, 30)
KeybindButton.Position = UDim2.new(0, 0, 0, 50)
KeybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
KeybindButton.Text = "Keybind: " .. toggleKey.Name
KeybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
KeybindButton.Font = Enum.Font.GothamBold
KeybindButton.TextSize = 14
KeybindButton.AutoButtonColor = true
KeybindButton.Parent = ContentFrame

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 8)
KeybindCorner.Parent = KeybindButton

KeybindButton.MouseButton1Click:Connect(function()
    if waitingForKey then return end
    waitingForKey = true
    local oldText = KeybindButton.Text
    KeybindButton.Text = "Press a key..."

    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if gp or UserInputService:GetFocusedTextBox() then return end
        toggleKey = input.KeyCode
        KeybindButton.Text = "Keybind: " .. toggleKey.Name
        waitingForKey = false
        if conn then conn:Disconnect() end
    end)

    -- micro timeout using microDefer chain (~instant, safe)
    microDefer(function()
        -- If still waiting after a couple frames, restore
        yieldFrames(2)
        if waitingForKey then
            waitingForKey = false
            KeybindButton.Text = oldText
            if conn then conn:Disconnect() end
        end
    end)
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if gp or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == toggleKey then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

-- ===== Status helpers =====
local function updateStatus(text, color)
    StatusLabel.Text = "Status: " .. text
    StatusLabel.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

-- ===== Auto Joiner =====
local running = false
local connectThread = nil

local function safePlayerGui()
    local lp = Players.LocalPlayer
    -- Yield minimally without hammering CPU:
    local tries = 0
    while not lp and running do
        microPause()  -- yields to next tick/frame
        lp = Players.LocalPlayer
        tries += 1
        if tries > 3000 then break end -- ~safety valve
    end
    if not lp then return nil end
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if not pg then
        -- Wait a couple frames for PlayerGui to appear
        yieldFrames(2)
        pg = lp:FindFirstChildOfClass("PlayerGui")
    end
    return pg or lp:WaitForChild("PlayerGui", 5)
end

local function startAutoJoiner()
    if running then return end
    running = true
    ToggleButton.Text = "ON"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    updateStatus("Starting...", Color3.fromRGB(255, 255, 0))

    connectThread = task.spawn(function()
        repeat microPause() until game:IsLoaded()

        local WebSocketURL = "ws://127.0.0.1:51948"

        local function prints(s)
            print("[AutoJoiner]: " .. tostring(s))
            updateStatus(tostring(s), Color3.fromRGB(255, 255, 255))
        end

        local function contains(str, needle)
            if type(str) ~= "string" then return false end
            return string.find(string.lower(str), string.lower(needle), 1, true) ~= nil
        end

        -- ===== Direct Path Helpers =====
        local function getScreenGuiIdx4()
            local sg = CoreGui:FindFirstChild("ScreenGui")
            if not sg then return nil end
            local kids = sg:GetChildren()
            if #kids >= 4 then return kids[4] end
            return nil
        end

        local function getDirectNodes()
            local ok, sg4 = pcall(getScreenGuiIdx4)
            if not ok or not sg4 or not sg4:IsA("ScreenGui") then return nil end

            local Main1 = sg4:FindFirstChild("Main")
            if not Main1 then return nil end
            local Main2  = Main1:FindFirstChild("Main") or Main1

            local Server = Main2 and Main2:FindFirstChild("Server")
            local SF     = Server and Server:FindFirstChild("ScrollingFrame")
            if not SF then return nil end

            local JobInputNode = SF:FindFirstChild("Job-ID Input")
            local JoinJobNode  = SF:FindFirstChild("Join Job-ID")
            if not JobInputNode or not JoinJobNode then return nil end

            local innerMain  = JobInputNode:FindFirstChild("Main")
            local jobTextBox = innerMain and innerMain:FindFirstChild("Input")
            if not (jobTextBox and jobTextBox:IsA("TextBox")) then
                jobTextBox = JobInputNode:FindFirstChildOfClass("TextBox")
            end

            local joinButton = JoinJobNode.Parent and JoinJobNode.Parent:FindFirstChildOfClass("TextButton")

            return {
                sg4 = sg4,
                server = Server,
                sf = SF,
                jobInputNode = JobInputNode,
                joinJobNode = JoinJobNode,
                jobTextBox = jobTextBox,
                joinButton = joinButton
            }
        end

        -- ===== Fallback Heuristics =====
        local function getRoots()
            local roots = { CoreGui }
            local pg = safePlayerGui()
            if pg then table.insert(roots, pg) end
            return roots
        end

        local function findJoinButtonFallback()
            for _, root in ipairs(getRoots()) do
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("TextButton") and (contains(d.Text, "join job-id") or contains(d.Name, "join job-id")) then
                        return d
                    end
                    if d:IsA("TextLabel") and contains(d.Text, "join job-id") then
                        local btn = d.Parent and d.Parent:FindFirstChildOfClass("TextButton")
                        if btn then return btn end
                    end
                end
            end
            return nil
        end

        local function findJobIdTextBoxFallback()
            local joinBtn = findJoinButtonFallback()
            if not joinBtn then return nil end

            local scope = joinBtn:FindFirstAncestorWhichIsA("ScrollingFrame")
                        or joinBtn.Parent
                        or joinBtn:FindFirstAncestorWhichIsA("Frame")
                        or joinBtn:FindFirstAncestorWhichIsA("ScreenGui")
                        or CoreGui

            local best, bestScore = nil, -1
            local candidates = {}

            for _, d in ipairs(scope:GetDescendants()) do
                if d:IsA("TextBox") then
                    table.insert(candidates, d)
                    local n, t, p = d.Name or "", d.Text or "", d.PlaceholderText or ""
                    local score = 0
                    if contains(n, "job") then score += 1 end
                    if contains(n, "id")  then score += 1 end
                    if contains(t, "job") then score += 1 end
                    if contains(t, "id")  then score += 1 end
                    if contains(p, "job") then score += 1 end
                    if contains(p, "id")  then score += 1 end
                    if score > bestScore then best, bestScore = d, score end
                end
            end

            if best and bestScore > 0 then return best end
            if #candidates > 0 then
                warn("[AutoJoiner] Heuristic couldn't confirm Job-ID box. Falling back to first TextBox: " .. candidates[1]:GetFullName())
                return candidates[1]
            end
            warn("[AutoJoiner] Job-ID TextBox not found under scope: " .. scope:GetFullName())
            return nil
        end

        -- ===== Actions =====
        local function clickJoin(button)
            local btn = button
            if not btn then
                local nodes = getDirectNodes()
                btn = nodes and nodes.joinButton or findJoinButtonFallback()
            end
            if not btn then
                warn("[AutoJoiner] Join button not found.")
                return false
            end

            local fired = false
            if typeof(getconnections) == "function" then
                local ok1, ups = pcall(getconnections, btn.MouseButton1Up)
                if ok1 and ups then for _, c in ipairs(ups) do pcall(function() c:Fire() end); fired = true end end
                local ok2, clicks = pcall(getconnections, btn.MouseButton1Click)
                if ok2 and clicks then for _, c in ipairs(clicks) do pcall(function() c:Fire() end); fired = true end end
            end
            if not fired then
                pcall(function() btn:Activate() end)
                pcall(function() btn.MouseButton1Click:Fire() end)
                pcall(function() btn.MouseButton1Up:Fire() end)
            end
            prints("Join server clicked (10m+ bypass)")
            return true
        end

        local function trySetServerMirror(nodes, jobId)
            if not nodes or not nodes.server then return end
            local val = nodes.server:FindFirstChild("Value")
            if val and (val:IsA("StringValue") or val:IsA("ObjectValue") or val:IsA("NumberValue")) then
                pcall(function() val.Value = tostring(jobId) end)
            end
        end

        local function commitTextBox(tb)
            -- Fire Text change listeners safely
            if typeof(getconnections) == "function" then
                local ok1, sig = pcall(function() return tb:GetPropertyChangedSignal("Text") end)
                if ok1 and sig then
                    for _, c in ipairs(getconnections(sig)) do
                        pcall(function() c:Fire() end)
                    end
                end
            end

            -- Commit on next couple frames, no hard waits
            microDefer(function()
                pcall(function() VIM:SendKeyEvent(true,  Enum.KeyCode.Return,      false, game) end)
                pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Return,      false, game) end)
                pcall(function() VIM:SendKeyEvent(true,  Enum.KeyCode.KeypadEnter, false, game) end)
                pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.KeypadEnter, false, game) end)

                if typeof(getconnections) == "function" then
                    local okFL, fl = pcall(function() return tb.FocusLost end)
                    if okFL and fl then
                        for _, c in ipairs(getconnections(fl)) do
                            pcall(function() c:Fire(true) end)
                        end
                    end
                end

                pcall(function() tb:ReleaseFocus() end)
            end)
        end

        local function setJobIDText(jobId)
            local nodes = getDirectNodes()
            local tb = nodes and nodes.jobTextBox or findJobIdTextBoxFallback()
            if not tb then
                warn("[AutoJoiner] Job-ID TextBox not found.")
                return nil
            end

            pcall(function() tb.ClearTextOnFocus = false end)
            pcall(function() tb.TextEditable = true end)
            pcall(function() tb:CaptureFocus() end)

            tb.Text = tostring(jobId)
            trySetServerMirror(nodes, jobId)
            commitTextBox(tb)

            prints("Textbox updated: " .. tostring(jobId) .. " (10m+ bypass)")
            return tb
        end

        -- Each queued JobId performs its own “type then click” sequence
        local function bypass10M(jobId)
            local tb = setJobIDText(jobId)
            if not tb then
                prints("No Job-ID textbox; skipping " .. tostring(jobId))
                return
            end

            -- give the UI a breath before clicking (frame-accurate, super short)
            RunService.Heartbeat:Wait()

            -- click join for THIS jobId
            local ok = clickJoin(nil)
            if not ok then
                prints("Join button not found for " .. tostring(jobId))
            else
                prints("Join clicked for " .. tostring(jobId))
            end
        end

        local function justJoin(scriptSource)
            local fn, err = loadstring(scriptSource)
            if not fn then prints("Load error: " .. tostring(err)); return end
            local ok, res = pcall(fn)
            if not ok then prints("Runtime error: " .. tostring(res)) end
        end

        local function getWebSocketConnect()
            if rawget(getfenv() or {}, "WebSocket") and WebSocket.connect then return WebSocket.connect end
            if rawget(getfenv() or {}, "WebSocket") and WebSocket.Connect then return WebSocket.Connect end
            if typeof(syn) == "table" and syn.websocket and syn.websocket.connect then return syn.websocket.connect end
            if typeof(WebSocket) == "table" and WebSocket.connect then return WebSocket.connect end
            return nil
        end

        local function connectLoop()
            local backoff = 1
            local connect = getWebSocketConnect()
            if not connect then
                prints("No websocket implementation found.")
                updateStatus("No WebSocket support", Color3.fromRGB(255, 0, 0))
                return
            end

            while running do
                prints("Trying to connect to " .. WebSocketURL)
                local ok, socket = pcall(connect, WebSocketURL)
                if ok and socket then
                    prints("Connected to WebSocket")
                    updateStatus("Connected", Color3.fromRGB(0, 255, 0))

                    socket.OnMessage:Connect(function(msg)
                        local item = classifyMessage(msg)
                        if item.kind == "job" then
                            prints("Enqueue JobId: " .. item.id)
                            pushMessage(item)
                            pumpQueue(function(jobId) bypass10M(jobId) end,
                                      function(src)   justJoin(src)     end)
                        elseif item.kind == "script" then
                            prints("Enqueue script")
                            pushMessage(item)
                            pumpQueue(function(jobId) bypass10M(jobId) end,
                                      function(src)   justJoin(src)     end)
                        else
                            -- ignore unknown payloads
                        end
                    end)

                    local closed = false
                    socket.OnClose:Connect(function()
                        if not closed then
                            closed = true
                            prints("WebSocket closed. Reconnecting...")
                            updateStatus("Reconnecting...", Color3.fromRGB(255, 255, 0))
                            backoff = 1
                            -- small, safe pause via frames
                            microDefer(function() end)
                        end
                    end)

                    -- idle loop without hard waits
                    while socket and not closed and running do
                        microPause() -- frame yield keeps CPU healthy
                    end
                else
                    prints("Unable to connect. Retrying in ~" .. tostring(backoff) .. "s (frame-paced)")
                    updateStatus("Retrying...", Color3.fromRGB(255, 165, 0))

                    -- Frame-paced backoff (no blocking sleep): ~backoff seconds worth of frames
                    local targetFrames = math.max(1, math.floor((backoff or 1) * 60))
                    yieldFrames(targetFrames)

                    backoff = math.clamp((backoff or 1) * 2, 1, 10)
                end
            end
        end

        connectLoop()
    end)
end

local function stopAutoJoiner()
    if not running then return end
    running = false
    ToggleButton.Text = "OFF"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    updateStatus("Stopped", Color3.fromRGB(255, 0, 0))

    if connectThread then
        task.cancel(connectThread)
        connectThread = nil
    end
end

ToggleButton.MouseButton1Click:Connect(function()
    if not running then
        startAutoJoiner()
    else
        stopAutoJoiner()
    end
end)

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Position = UDim2.new(1, -25, 0, 10)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    stopAutoJoiner()
    ScreenGui:Destroy()
end)

-- Initial status
updateStatus("Ready", Color3.fromRGB(0, 255, 0))
