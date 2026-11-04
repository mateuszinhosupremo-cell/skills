--[[
    Blox Fruits - Halloween 2026 Event Farm
    Runtime : Roblox client, Luau, run through an executor
    Event   : live until Nov 15 2026 01:00 UTC

    Uses these executor functions when present (each one falls back if missing):
    hookmetamethod, getnamecallmethod, checkcaller, newcclosure,
    fireproximityprompt, fireclickdetector, firetouchinterest, gethui

    VERIFIED
      - ReplicatedStorage.Remotes.CommF_ (RemoteFunction, InvokeServer)
      - workspace.Enemies is the mob container
      - Harvest Moon = XX:00-XX:10 UTC, each door works once per player per moon
      - Spooky Gacha: 500 Candy Corn, 2 rolls/hour, cooldown SHARED with the regular gacha

    NOT VERIFIED (no readable public source exists)
      - instance names of doors / pumpkins / jack o'lanterns / snowmen
      - whether they trigger by prompt, click, touch or hits
      - the Spooky Gacha remote args
    So the script finds event objects by keyword plus whatever interactable they
    carry, and it never fires a gacha call it hasn't watched you make yourself.

    FIRST RUN
      1. Press SCAN, open the console (F9) and check what it found.
         Wrong or empty? Edit the *Keys lists in CONFIG and scan again.
      2. Press LOGGER, roll the Spooky Gacha ONCE by hand at Zioles, then press
         USE LAST ARGS right away and confirm the console line looks like a gacha
         call. Auto Spin stays locked until then: a wrong arg could roll the
         regular gacha, which burns the shared cooldown for 2 hours.
      3. Toggle what you want.

    Bosses in the Observatory: enter through the door portal first, then turn
    Bosses on. Flying in from outside may leave you unable to hit them.
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser  = game:GetService("VirtualUser")
local Workspace    = game:GetService("Workspace")

local LP    = Players.LocalPlayer
local CommF = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
local unpackArgs = table.unpack or unpack

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local Config = {
    -- features
    AutoPumpkins = false,
    AutoDoors    = false,
    AutoBosses   = false,
    AutoSpin     = false,
    AntiAFK      = true,

    -- movement
    TweenSpeed   = 300,    -- studs/s. past ~350 the server tends to rubber-band you
    HoverOffset  = 5,      -- studs above a mob while hitting it
    Noclip       = true,
    MaxDistance  = 8000,   -- ignore targets farther than this

    -- combat
    Weapon       = "",          -- exact tool name; "" = first Melee/Sword you own
    AttackMode   = "Activate",  -- "Activate" (Tool:Activate) or "Click" (VirtualUser)
    AttackDelay  = 0.1,

    -- gacha
    SpinArgs     = nil,    -- set by LOGGER -> USE LAST ARGS. leave nil
    SpinArgsN    = 0,
    SpinInterval = 180,    -- seconds between attempts; the server caps it at 2/hour anyway

    -- discovery (lowercase substrings)
    PumpkinKeys  = {"pumpkin", "jack o", "jacko", "lantern", "snowman"},
    DoorKeys     = {"door"},
    DoorTextKeys = {"knock", "trick", "treat"},   -- matched against prompt ActionText/ObjectText
    BossKeys     = {"hellfire", "hell rider", "hellrider", "werewolf", "great pumpkin"},
    ScanEvery    = 12,     -- seconds. full workspace walk, raise it if you feel hitches
    TrickRadius  = 80,     -- after a door, kill spawned enemies within this
    MaxTries     = 3,      -- give up on a pumpkin after this many interacts
}

local State = {
    running   = true,
    busy      = false,
    pumpkins  = {},
    doors     = {},
    bosses    = {},
    visited   = {},
    moonHour  = -1,
    tries     = setmetatable({}, {__mode = "k"}),
    lastSpin  = -math.huge,
    lastArgs  = nil,
    lastArgsN = 0,
    lastLog   = "ready",
    conns     = {},
}

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local function log(msg)
    State.lastLog = string.sub(tostring(msg), 1, 90)
    print("[HalloweenFarm] " .. tostring(msg))
end

local function stringify(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "table" then
        if depth > 2 then return "{...}" end
        local parts = {}
        for k, x in pairs(v) do
            if #parts >= 12 then table.insert(parts, "...") break end
            table.insert(parts, tostring(k) .. "=" .. stringify(x, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "Instance" then
        return v:GetFullName()
    end
    return tostring(v)
end

local function matchAny(text, keys)
    text = string.lower(text)
    for _, k in ipairs(keys) do
        if string.find(text, k, 1, true) then return true end
    end
    return false
end

local function ancestorMatch(inst, keys, depth)
    local cur = inst
    for _ = 1, depth do
        if not cur or cur == Workspace or cur == game then return nil end
        if matchAny(cur.Name, keys) then return cur end
        cur = cur.Parent
    end
    return nil
end

local function getChar() return LP.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function alive()
    local h = getHum()
    return h ~= nil and h.Health > 0
end

local function posOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Attachment") then return inst.WorldPosition end
    if inst:IsA("Model") then
        local p = inst.PrimaryPart
            or inst:FindFirstChild("HumanoidRootPart")
            or inst:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position
    end
    return nil
end

local function isPlayerModel(m)
    return m == getChar() or Players:GetPlayerFromCharacter(m) ~= nil
end

local function harvestMoon()
    local t = os.date("!*t")
    return t.min < 10, t.hour
end

--------------------------------------------------------------------
-- MOVEMENT
--------------------------------------------------------------------
local currentTween

local function stopMove()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function moveTo(pos)
    local root = getRoot()
    if not root then return false end
    local dist = (root.Position - pos).Magnitude
    if dist < 6 then
        root.CFrame = CFrame.new(pos)
        return true
    end
    stopMove()
    local duration = dist / Config.TweenSpeed
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    currentTween = tween
    local done = false
    local conn = tween.Completed:Connect(function(status)
        done = status == Enum.PlaybackState.Completed
    end)
    tween:Play()
    local start = os.clock()
    while not done and State.running and alive() and currentTween == tween do
        if os.clock() - start > duration + 3 then break end
        task.wait()
    end
    conn:Disconnect()
    if currentTween == tween then currentTween = nil end
    return done
end

-- noclip + velocity hold while working; restores collision when idle
local savedCollide = {}
table.insert(State.conns, RunService.Stepped:Connect(function()
    local c = getChar()
    if not c then return end
    if State.busy then
        if Config.Noclip then
            for _, p in ipairs(c:GetChildren()) do
                if p:IsA("BasePart") then
                    if savedCollide[p] == nil then savedCollide[p] = p.CanCollide end
                    p.CanCollide = false
                end
            end
        end
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
    elseif next(savedCollide) then
        for p, v in pairs(savedCollide) do
            if p.Parent then p.CanCollide = v end
        end
        savedCollide = {}
    end
end))

--------------------------------------------------------------------
-- COMBAT
--------------------------------------------------------------------
local warnedNoWeapon = false

local function getWeapon()
    local function pick(container)
        if not container then return nil end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                if Config.Weapon ~= "" then
                    if t.Name == Config.Weapon then return t end
                elseif t.ToolTip == "Melee" or t.ToolTip == "Sword" then
                    return t
                end
            end
        end
        return nil
    end
    return pick(getChar()) or pick(LP:FindFirstChild("Backpack"))
end

local function equip()
    local tool, hum = getWeapon(), getHum()
    if not (tool and hum) then
        if not warnedNoWeapon then
            warnedNoWeapon = true
            log("no Melee/Sword found - set Config.Weapon")
        end
        return nil
    end
    if tool.Parent ~= getChar() then
        hum:EquipTool(tool)
        task.wait(0.1)
    end
    return tool
end

local lastAttack = 0
local function attack()
    if os.clock() - lastAttack < Config.AttackDelay then return end
    lastAttack = os.clock()
    local tool = equip()
    if Config.AttackMode == "Activate" and tool then
        pcall(function() tool:Activate() end)
    else
        local cam = Workspace.CurrentCamera
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(1, 1), cam.CFrame)
        task.wait(0.03)
        VirtualUser:Button1Up(Vector2.new(1, 1), cam.CFrame)
    end
end

local function killTarget(model, timeout)
    local hum = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not (hum and hrp) then return end
    local offset = Vector3.new(0, Config.HoverOffset, 0)
    moveTo(hrp.Position + offset)
    local start = os.clock()
    while State.running and alive() and model.Parent and hum.Health > 0 do
        if os.clock() - start > (timeout or 60) then
            log("timeout on " .. model.Name)
            break
        end
        local root = getRoot()
        if not root then break end
        root.CFrame = CFrame.new(hrp.Position + offset, hrp.Position)
        attack()
        task.wait()
    end
end

local function clearNearby(center, radius)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    for _, m in ipairs(enemies:GetChildren()) do
        local hrp = m:FindFirstChild("HumanoidRootPart")
        local hum = m:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 and (hrp.Position - center).Magnitude <= radius then
            killTarget(m, 45)
        end
    end
end

--------------------------------------------------------------------
-- DISCOVERY
--------------------------------------------------------------------
local RANK = {mob = 4, prompt = 3, click = 2, touch = 1}

local function scan()
    local buckets = {pumpkins = {}, doors = {}, bosses = {}}
    local function add(bucket, owner, kind, handle)
        local cur = buckets[bucket][owner]
        if not cur or RANK[kind] > RANK[cur.kind] then
            buckets[bucket][owner] = {inst = owner, kind = kind, handle = handle}
        end
    end

    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, m in ipairs(enemies:GetChildren()) do
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if matchAny(m.Name, Config.BossKeys) then
                    add("bosses", m, "mob", hum)
                elseif matchAny(m.Name, Config.PumpkinKeys) then
                    add("pumpkins", m, "mob", hum)
                end
            end
        end
    end

    local all = Workspace:GetDescendants()
    for i, d in ipairs(all) do
        if i % 3000 == 0 then task.wait() end

        if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("TouchTransmitter") then
            local kind = d:IsA("ProximityPrompt") and "prompt"
                or d:IsA("ClickDetector") and "click"
                or "touch"
            local handle = (kind == "touch") and d.Parent or d

            local door = ancestorMatch(d.Parent, Config.DoorKeys, 4)
            if not door and kind == "prompt" then
                local text = d.ActionText .. " " .. d.ObjectText
                if matchAny(text, Config.DoorTextKeys) then
                    door = d:FindFirstAncestorWhichIsA("Model") or d.Parent
                end
            end

            if door and kind ~= "touch" then
                add("doors", door, kind, handle)
            else
                local owner = ancestorMatch(d.Parent, Config.PumpkinKeys, 4)
                if owner and not matchAny(owner.Name, Config.BossKeys) then
                    add("pumpkins", owner, kind, handle)
                end
            end

        elseif d:IsA("Model") and d.Parent ~= enemies and not isPlayerModel(d) then
            local boss = matchAny(d.Name, Config.BossKeys)
            if boss or matchAny(d.Name, Config.PumpkinKeys) then
                local hum = d:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    add(boss and "bosses" or "pumpkins", d, "mob", hum)
                end
            end
        end
    end

    local function toList(map)
        local list = {}
        for _, e in pairs(map) do table.insert(list, e) end
        return list
    end
    State.pumpkins = toList(buckets.pumpkins)
    State.doors    = toList(buckets.doors)
    State.bosses   = toList(buckets.bosses)
end

local function nearest(list, filter)
    local root = getRoot()
    if not root then return nil end
    local best, bestDist = nil, Config.MaxDistance
    for _, e in ipairs(list) do
        local valid = e.inst.Parent ~= nil and e.handle and e.handle.Parent ~= nil
        if valid and e.kind == "mob" and e.handle.Health <= 0 then valid = false end
        if valid and filter and not filter(e) then valid = false end
        if valid then
            local p = posOf(e.inst)
            if p then
                local d = (p - root.Position).Magnitude
                if d < bestDist then best, bestDist = e, d end
            end
        end
    end
    return best
end

--------------------------------------------------------------------
-- INTERACTION
--------------------------------------------------------------------
local function interact(entry)
    if entry.kind == "mob" then
        killTarget(entry.inst, 45)
        return true
    end

    local h = entry.handle
    if not (h and h.Parent) then return false end
    local pos = posOf(entry.kind == "touch" and h or h.Parent) or posOf(entry.inst)
    if not pos then return false end

    State.tries[entry.inst] = (State.tries[entry.inst] or 0) + 1
    moveTo(pos + Vector3.new(0, 3, 0))
    task.wait(0.2)
    local root = getRoot()
    if not root then return false end

    if entry.kind == "prompt" then
        if fireproximityprompt then
            pcall(fireproximityprompt, h)
        else
            pcall(function()
                h:InputHoldBegin()
                task.wait(h.HoldDuration + 0.1)
                h:InputHoldEnd()
            end)
        end
    elseif entry.kind == "click" then
        if fireclickdetector then
            pcall(fireclickdetector, h)
        else
            log("executor has no fireclickdetector")
        end
    elseif entry.kind == "touch" then
        if firetouchinterest then
            pcall(firetouchinterest, root, h, 0)
            task.wait()
            pcall(firetouchinterest, root, h, 1)
        else
            root.CFrame = h.CFrame
        end
    end
    return true
end

local function doDoor(entry)
    State.visited[entry.inst] = true
    log("door: " .. entry.inst:GetFullName())
    if not interact(entry) then return end
    -- stay put: walking off an open door cancels it server-side
    task.wait(1.5)
    local center = posOf(entry.inst)
    if center then clearNearby(center, Config.TrickRadius) end
    task.wait(0.5)
end

--------------------------------------------------------------------
-- MAIN LOOP  (priority: bosses > doors during moon > pumpkins)
--------------------------------------------------------------------
local function step()
    if not alive() then
        State.busy = false
        return
    end

    local moon, hour = harvestMoon()
    if hour ~= State.moonHour then
        State.moonHour = hour
        State.visited = {}
    end

    if Config.AutoBosses then
        local b = nearest(State.bosses)
        if b then
            State.busy = true
            log("boss: " .. b.inst.Name)
            killTarget(b.inst, 600)
            return
        end
    end

    if Config.AutoDoors and moon then
        local d = nearest(State.doors, function(e)
            if State.visited[e.inst] then return false end
            if e.kind == "prompt" and not e.handle.Enabled then return false end
            return true
        end)
        if d then
            State.busy = true
            doDoor(d)
            return
        end
    end

    if Config.AutoPumpkins then
        local p = nearest(State.pumpkins, function(e)
            return (State.tries[e.inst] or 0) < Config.MaxTries
        end)
        if p then
            State.busy = true
            interact(p)
            task.wait(0.25)
            return
        end
    end

    State.busy = false
end

task.spawn(function()
    while State.running do
        local ok, err = pcall(scan)
        if not ok then log("scan error: " .. tostring(err)) end
        task.wait(Config.ScanEvery)
    end
end)

task.spawn(function()
    while State.running do
        local ok, err = pcall(step)
        if not ok then
            log("step error: " .. tostring(err))
            task.wait(1)
        end
        task.wait(0.1)
    end
end)

--------------------------------------------------------------------
-- GACHA
--------------------------------------------------------------------
task.spawn(function()
    while State.running do
        task.wait(5)
        if Config.AutoSpin and Config.SpinArgs and alive()
            and os.clock() - State.lastSpin >= Config.SpinInterval then
            State.lastSpin = os.clock()
            local ok, res = pcall(function()
                return CommF:InvokeServer(unpackArgs(Config.SpinArgs, 1, Config.SpinArgsN))
            end)
            log("spin -> " .. (ok and stringify(res) or ("error: " .. tostring(res))))
        end
    end
end)

--------------------------------------------------------------------
-- REMOTE LOGGER (installed only when first turned on)
--------------------------------------------------------------------
local loggerOn, hooked = false, false

local function installLogger()
    if hooked then return true end
    if not (hookmetamethod and getnamecallmethod) then
        log("executor has no hookmetamethod - logger unavailable")
        return false
    end
    local old
    local function handler(self, ...)
        if loggerOn and self == CommF and getnamecallmethod() == "InvokeServer"
            and not (checkcaller and checkcaller()) then
            State.lastArgs = {...}
            State.lastArgsN = select("#", ...)
            local line = "CommF_ <- " .. stringify(State.lastArgs)
            task.spawn(log, line)
        end
        return old(self, ...)
    end
    old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
    hooked = true
    return true
end

--------------------------------------------------------------------
-- ANTI-AFK
--------------------------------------------------------------------
table.insert(State.conns, LP.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "HalloweenFarm"
Gui.ResetOnSpawn = false
local parented = false
if gethui then parented = pcall(function() Gui.Parent = gethui() end) end
if not parented then parented = pcall(function() Gui.Parent = game:GetService("CoreGui") end) end
if not parented then Gui.Parent = LP:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 250, 0, 0)
Main.AutomaticSize = Enum.AutomaticSize.Y
Main.Position = UDim2.new(0, 20, 0, 80)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local pad = Instance.new("UIPadding", Main)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)

local layout = Instance.new("UIListLayout", Main)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local order = 0
local function nextOrder()
    order = order + 1
    return order
end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 24)
Title.BackgroundTransparency = 1
Title.Text = "Halloween Farm"
Title.TextColor3 = Color3.fromRGB(255, 140, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.LayoutOrder = nextOrder()
Title.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 0)
Status.AutomaticSize = Enum.AutomaticSize.Y
Status.BackgroundTransparency = 1
Status.TextColor3 = Color3.fromRGB(190, 190, 190)
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.LayoutOrder = nextOrder()
Status.Parent = Main

local OFF_COLOR = Color3.fromRGB(30, 30, 30)
local ON_COLOR  = Color3.fromRGB(200, 110, 0)

local function makeButton(text, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 28)
    b.BackgroundColor3 = OFF_COLOR
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.Text = text
    b.LayoutOrder = nextOrder()
    b.Parent = Main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() onClick(b) end)
    return b
end

local function makeToggle(label, key, guard)
    local btn
    local function paint()
        btn.Text = label .. ": " .. (Config[key] and "ON" or "OFF")
        btn.BackgroundColor3 = Config[key] and ON_COLOR or OFF_COLOR
    end
    btn = makeButton(label, function()
        if not Config[key] and guard and not guard() then return end
        Config[key] = not Config[key]
        paint()
    end)
    paint()
end

makeToggle("Pumpkins", "AutoPumpkins")
makeToggle("Doors (Harvest Moon)", "AutoDoors")
makeToggle("Bosses", "AutoBosses")
makeToggle("Auto Spin", "AutoSpin", function()
    if Config.SpinArgs then return true end
    log("capture spin args first: LOGGER -> roll once -> USE LAST ARGS")
    return false
end)
makeToggle("Anti-AFK", "AntiAFK")

makeButton("LOGGER: OFF", function(b)
    if not loggerOn and not installLogger() then return end
    loggerOn = not loggerOn
    b.Text = "LOGGER: " .. (loggerOn and "ON" or "OFF")
    b.BackgroundColor3 = loggerOn and ON_COLOR or OFF_COLOR
end)

makeButton("USE LAST ARGS", function()
    if not State.lastArgs then
        log("no CommF_ call captured yet")
        return
    end
    Config.SpinArgs = State.lastArgs
    Config.SpinArgsN = State.lastArgsN
    log("spin args set: " .. stringify(State.lastArgs))
end)

makeButton("SCAN -> console", function()
    task.spawn(function()
        scan()
        local function dump(name, list)
            print(string.format("[HalloweenFarm] %s: %d", name, #list))
            for i, e in ipairs(list) do
                if i > 25 then print("    ...") break end
                print(string.format("    [%s] %s", e.kind, e.inst:GetFullName()))
            end
        end
        dump("pumpkins", State.pumpkins)
        dump("doors", State.doors)
        dump("bosses", State.bosses)
        log("scan printed to console (F9)")
    end)
end)

makeButton("STOP", function()
    State.running = false
    State.busy = false
    loggerOn = false
    stopMove()
    for _, c in ipairs(State.conns) do c:Disconnect() end
    for p, v in pairs(savedCollide) do
        if p.Parent then p.CanCollide = v end
    end
    Gui:Destroy()
end)

task.spawn(function()
    while State.running do
        local moon = harvestMoon()
        Status.Text = string.format(
            "Moon: %s  |  P %d  D %d  B %d\nSpin args: %s\n%s",
            moon and "UP" or "down",
            #State.pumpkins, #State.doors, #State.bosses,
            Config.SpinArgs and "set" or "not set",
            State.lastLog
        )
        task.wait(0.5)
    end
end)

log("loaded - press SCAN first")
