--[[ Blox Fruits - Farm de Abobora v2 (Halloween 2026)
  abobora: workspace.PumpkinHunt | tween + clique simulado em ritmo humano
  Jack: para o clique, voa em cima e usa killaura por remote
        (RE/RegisterAttack + RE/RegisterHit, o padrao dos hubs publicos)
        quando o Jack morre, volta o clique nas aboboras ]]

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local VirtualUser  = game:GetService("VirtualUser")
local okVim, VIM   = pcall(function() return game:GetService("VirtualInputManager") end)
if not okVim then VIM = nil end
local LP = Players.LocalPlayer

local Config = {
  FarmPumpkins = false,
  KillJack     = true,
  AntiAFK      = true,

  TweenSpeed   = 300,   -- studs/s. acima de ~350 o server te puxa de volta
  HitDistance  = 3.5,   -- distancia da abobora pra socar
  StandHeight  = 1.5,   -- altura em relacao ao centro da abobora
  JackHeight   = 8,     -- altura em cima do Jack com killaura remoto
  JackRemote   = true,  -- killaura por remote no Jack (sem clique)
  JackHitDelay = 0.12,  -- s entre hits do killaura
  JackFallback = true,  -- se o remote nao der dano, volta pro clique
  JackClickH   = 3,     -- altura em cima do Jack no modo clique

  ClickMin     = 0.14,  -- intervalo entre cliques (s), sorteado entre min e max
  ClickMax     = 0.26,
  MaxClicks    = 20,    -- desiste da abobora depois disso (volta em 30s)
  SwitchAfter  = 12,    -- cliques sem registrar antes de trocar o modo
  Cooldown     = 300,   -- s ate voltar numa abobora ja aberta
  WaitForJack  = 1.0,   -- s esperando o Jack nascer depois de abrir
  JackKeys     = {"jack", "lantern"},
  JackRadius   = 400,
  Weapon       = "",    -- nome exato da melee; "" = acha sozinho
  Debug        = true,  -- imprime a estrutura da 1a abobora no console
}

local MODES = {"Activate", "VIM", "Touch", "VirtualUser"}
local State = {
  running = true, active = false, lock = nil,
  pumpkins = {}, done = setmetatable({}, {__mode = "k"}), jackQueue = {},
  modeIndex = 2, modeConfirmed = false, switches = 0, -- 2 = VIM, o que funcionou no teu celular
  status = "pronto", lastOpenPos = nil, lastOpenTime = 0,
  conns = {}, debugged = false,
}

local function log(msg)
  State.status = msg
  print("[Abobora] " .. msg)
end

local function getChar() return LP.Character end
local function getRoot() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h = getHum() return h ~= nil and h.Health > 0 end

-- MOVIMENTO: noclip + segurar posicao enquanto trabalha
local savedCollide = {}
table.insert(State.conns, RunService.Stepped:Connect(function()
  local c = getChar()
  if not c then return end
  if State.active then
    for _, p in ipairs(c:GetChildren()) do
      if p:IsA("BasePart") then
        if savedCollide[p] == nil then savedCollide[p] = p.CanCollide end
        p.CanCollide = false
      end
    end
  elseif next(savedCollide) then
    for p, v in pairs(savedCollide) do if p.Parent then p.CanCollide = v end end
    savedCollide = {}
  end
end))

table.insert(State.conns, RunService.Heartbeat:Connect(function()
  local root = getRoot()
  if not (root and State.active) then return end
  root.AssemblyLinearVelocity = Vector3.zero
  local l = State.lock
  if typeof(l) == "function" then
    local ok, cf = pcall(l)
    if ok and cf then root.CFrame = cf end
  elseif l then
    root.CFrame = l
  end
end))

local function tweenTo(cf)
  local root = getRoot()
  if not root then return false end
  State.lock = nil
  local dist = (root.Position - cf.Position).Magnitude
  if dist < 8 then root.CFrame = cf return true end
  local dur = dist / Config.TweenSpeed
  local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
  tw:Play()
  local t0 = os.clock()
  while tw.PlaybackState == Enum.PlaybackState.Playing do
    if not (State.running and State.active and alive()) or os.clock() - t0 > dur + 3 then
      tw:Cancel()
      break
    end
    task.wait()
  end
  return alive() and State.active
end

-- CLIQUES HUMANOS
local function getMelee()
  local function pick(box)
    if not box then return nil end
    for _, t in ipairs(box:GetChildren()) do
      if t:IsA("Tool") then
        if Config.Weapon ~= "" then
          if t.Name == Config.Weapon then return t end
        elseif t.ToolTip == "Melee" or t.Name == "Combat" then
          return t
        end
      end
    end
  end
  return pick(getChar()) or pick(LP:FindFirstChild("Backpack"))
end

local function equip()
  local tool, hum = getMelee(), getHum()
  if tool and hum and tool.Parent ~= getChar() then
    hum:EquipTool(tool)
    task.wait(0.15)
  end
  return tool
end

local function click()
  local mode = MODES[State.modeIndex]
  local tool = equip()
  local cam = workspace.CurrentCamera
  local vp = cam.ViewportSize
  local x = vp.X * 0.5 + math.random(-12, 12)
  local y = vp.Y * 0.45 + math.random(-12, 12)
  if mode == "Activate" and tool then
    tool:Activate()
  elseif mode == "VIM" and VIM then
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.02 + math.random() * 0.04)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
  elseif mode == "Touch" and VIM then
    VIM:SendTouchEvent(7, 0, x, y)
    task.wait(0.03 + math.random() * 0.04)
    VIM:SendTouchEvent(7, 2, x, y)
  else
    VirtualUser:CaptureController()
    VirtualUser:ClickButton1(Vector2.new(x, y), cam.CFrame)
  end
end

local clickCount = 0
local function humanPause(scale)
  clickCount = clickCount + 1
  local t = (Config.ClickMin + math.random() * (Config.ClickMax - Config.ClickMin)) * (scale or 1)
  if clickCount % math.random(4, 7) == 0 then t = t + 0.2 + math.random() * 0.3 end
  task.wait(t)
end

local function confirmMode()
  if not State.modeConfirmed then
    State.modeConfirmed = true
    log("modo de clique confirmado: " .. MODES[State.modeIndex])
  end
end

local function nextMode()
  State.modeIndex = State.modeIndex % #MODES + 1
  State.switches = State.switches + 1
  log("cliques nao registraram, testando modo " .. MODES[State.modeIndex])
  if State.switches == #MODES then
    print("[Abobora] AVISO: testou todos os modos sem confirmar. me manda o console.")
  end
end

-- KILLAURA REMOTO
local Hit = {attack = nil, hit = nil, mode = 1, ok = false}

local function getHitRemotes()
  if Hit.attack and Hit.hit and Hit.attack.Parent and Hit.hit.Parent then return true end
  local mods = RS:FindFirstChild("Modules")
  local net = mods and mods:FindFirstChild("Net")
  if not net then return false end
  pcall(function() require(net):RemoteEvent("RegisterHit", true) end)
  Hit.attack = net:FindFirstChild("RE/RegisterAttack")
  Hit.hit = net:FindFirstChild("RE/RegisterHit")
  return Hit.attack ~= nil and Hit.hit ~= nil
end

local function remoteHit(m)
  local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
  if not (head and getHitRemotes()) then return false end
  local list = {{m, head}}
  Hit.attack:FireServer(0)
  if Hit.mode == 1 then
    Hit.hit:FireServer(head, list)
  else
    Hit.hit:FireServer(head, list, {}, tostring(LP.UserId):sub(2, 4) .. tostring(coroutine.running()):sub(11, 15))
  end
  return true
end

-- ABOBORAS
local function partsOf(inst)
  local list = {}
  if inst:IsA("BasePart") then list[1] = inst end
  for _, d in ipairs(inst:GetDescendants()) do
    if d:IsA("BasePart") then list[#list + 1] = d end
  end
  return list
end

local function center(parts)
  local sum, n = Vector3.zero, 0
  for _, p in ipairs(parts) do
    if p.Parent then sum = sum + p.Position n = n + 1 end
  end
  return n > 0 and sum / n or nil
end

-- cada abobora vira um alvo, seja ela um Model ou uma peca solta numa pasta
local function collect(inst, out, depth)
  local parts = partsOf(inst)
  if #parts == 0 then return end
  local c, far = center(parts), 0
  for _, p in ipairs(parts) do far = math.max(far, (p.Position - c).Magnitude) end
  if inst:IsA("BasePart") or far <= 15 or depth >= 3 then
    out[#out + 1] = {key = inst, parts = parts}
    return
  end
  for _, ch in ipairs(inst:GetChildren()) do collect(ch, out, depth + 1) end
end

local function scanPumpkins()
  local hunt = workspace:FindFirstChild("PumpkinHunt")
  local out = {}
  if hunt then
    for _, ch in ipairs(hunt:GetChildren()) do collect(ch, out, 1) end
  end
  State.pumpkins = out
end

local function snapshot(t)
  local s = {pos = {}, tr = 0, attrs = {}}
  for i, p in ipairs(t.parts) do
    s.pos[i] = p.Parent and p.Position
    s.tr = s.tr + (p.Parent and p.Transparency or 1)
  end
  local ok, a = pcall(function() return t.key:GetAttributes() end)
  if ok then
    for k, v in pairs(a) do if type(v) == "number" then s.attrs[k] = v end end
  end
  return s
end

-- devolve: abriu?, hit registrou?, snapshot atual
local function compare(t, base, prev)
  local hunt = workspace:FindFirstChild("PumpkinHunt")
  if not t.key.Parent or (hunt and not t.key:IsDescendantOf(hunt)) then return true, true end
  for i, p in ipairs(t.parts) do
    if not p.Parent then return true, true end
    if base.pos[i] and (p.Position - base.pos[i]).Magnitude > 2 then return true, true end
  end
  local now = snapshot(t)
  if now.tr - base.tr > 0.5 then return true, true end
  local hit = false
  for k, v in pairs(now.attrs) do
    if prev.attrs[k] ~= nil and prev.attrs[k] ~= v then
      hit = true
      local lk = string.lower(k)
      if v <= 0 and (lk:find("health") or lk:find("hp")) then return true, true end
    end
  end
  return false, hit, now
end

local function dumpPumpkin(t)
  print("[Abobora] alvo: " .. t.key:GetFullName() .. " (" .. t.key.ClassName .. "), pecas: " .. #t.parts)
  for _, ch in ipairs(t.key:GetChildren()) do print("    " .. ch.ClassName .. " " .. ch.Name) end
  local ok, a = pcall(function() return t.key:GetAttributes() end)
  if ok then for k, v in pairs(a) do print("    @" .. k .. " = " .. tostring(v)) end end
end

local function nearestPumpkin()
  local root = getRoot()
  if not root then return nil end
  local best, bd = nil, math.huge
  for _, t in ipairs(State.pumpkins) do
    local last = State.done[t.key]
    if t.key.Parent and not (last and os.clock() - last < Config.Cooldown) then
      local c = center(t.parts)
      if c then
        local d = (c - root.Position).Magnitude
        if d < bd then best, bd = t, d end
      end
    end
  end
  return best
end

-- JACK
local function nameIsJack(n)
  n = string.lower(n)
  for _, k in ipairs(Config.JackKeys) do
    if string.find(n, k, 1, true) then return true end
  end
  return false
end

local function watchJack(m)
  task.delay(0.4, function()
    if not (State.running and m.Parent and m:IsA("Model")) then return end
    if Players:GetPlayerFromCharacter(m) then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local p = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
    if not (hum and p and hum.Health > 0) then return end
    local nearOpen = State.lastOpenPos and os.clock() - State.lastOpenTime < 8
      and (p.Position - State.lastOpenPos).Magnitude < 80
    if nameIsJack(m.Name) or nearOpen then
      table.insert(State.jackQueue, m)
      log("Jack detectado: " .. m.Name)
    end
  end)
end

local en = workspace:FindFirstChild("Enemies")
if en then table.insert(State.conns, en.ChildAdded:Connect(watchJack)) end
table.insert(State.conns, workspace.ChildAdded:Connect(watchJack))
local huntFolder = workspace:FindFirstChild("PumpkinHunt")
if huntFolder then
  table.insert(State.conns, huntFolder.DescendantAdded:Connect(function(d)
    if d:IsA("Model") then watchJack(d) end
  end))
end

local function findJack()
  local root = getRoot()
  if not root then return nil end
  local best, bd = nil, Config.JackRadius
  local function consider(m)
    local hum = m:FindFirstChildOfClass("Humanoid")
    local p = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
    if m.Parent and hum and hum.Health > 0 and p then
      local d = (p.Position - root.Position).Magnitude
      if d < bd then best, bd = m, d end
    end
  end
  for i = #State.jackQueue, 1, -1 do
    local m = State.jackQueue[i]
    local hum = m.Parent and m:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then table.remove(State.jackQueue, i) else consider(m) end
  end
  local enemies = workspace:FindFirstChild("Enemies")
  if enemies then
    for _, m in ipairs(enemies:GetChildren()) do
      if nameIsJack(m.Name) then consider(m) end
    end
  end
  return best
end

local function killJack(m)
  local hum = m:FindFirstChildOfClass("Humanoid")
  local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
  if not (hum and hrp) then return end
  local useClick = not Config.JackRemote
  local function above()
    local h = useClick and Config.JackClickH or Config.JackHeight
    local pos = hrp.Position + Vector3.new(0, h, 1.5)
    return CFrame.lookAt(pos, hrp.Position)
  end
  log("focando no " .. m.Name)
  if not tweenTo(above()) then return end
  State.lock = above
  State.jackMode = useClick and "clique" or ("remoto " .. Hit.mode)
  local t0, lastHp, lastDrop = os.clock(), hum.Health, os.clock()
  while State.running and State.active and alive() and m.Parent and hum.Health > 0 do
    if os.clock() - t0 > 60 then log("Jack demorou demais, pulando") break end
    if useClick then
      pcall(click)
      humanPause(0.7)
    else
      equip()
      local ok, sent = pcall(remoteHit, m)
      if not (ok and sent) then
        log("remote de hit nao achado" .. (ok and "" or (": " .. tostring(sent))))
        useClick = Config.JackFallback
        if not useClick then break end
      end
      task.wait(Config.JackHitDelay)
    end
    if hum.Health < lastHp - 0.01 then
      lastHp, lastDrop = hum.Health, os.clock()
      if not useClick and not Hit.ok then
        Hit.ok = true
        log("killaura remoto dando dano (modo " .. Hit.mode .. ")")
      end
    elseif os.clock() - lastDrop > 2.5 then
      lastDrop = os.clock()
      if not useClick and not Hit.ok then
        if Hit.mode == 1 then
          Hit.mode = 2
          log("killaura modo 1 sem dano, testando modo 2")
        else
          Hit.mode = 1
          useClick = Config.JackFallback
          log("killaura remoto sem dano" .. (useClick and ", voltando pro clique" or ""))
          if not useClick then break end
        end
      end
    end
    State.jackMode = useClick and "clique" or ("remoto " .. Hit.mode)
  end
  State.lock = nil
  State.jackMode = nil
end

-- FARM DE UMA ABOBORA
local function farmPumpkin(t)
  local tpos, root = center(t.parts), getRoot()
  if not (tpos and root) then return end
  if Config.Debug and not State.debugged then State.debugged = true dumpPumpkin(t) end

  local flat = Vector3.new(root.Position.X - tpos.X, 0, root.Position.Z - tpos.Z)
  local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
  local stand = tpos + dir * Config.HitDistance + Vector3.new(0, Config.StandHeight, 0)
  local cf = CFrame.lookAt(stand, Vector3.new(tpos.X, stand.Y, tpos.Z))

  log("indo ate a abobora")
  if not tweenTo(cf) then return end
  State.lock = cf

  local base = snapshot(t)
  local prev, noHit = base, 0
  for _ = 1, Config.MaxClicks do
    if not (State.running and State.active and alive()) then break end
    if Config.KillJack and findJack() then State.lock = nil return end
    pcall(click)
    humanPause()
    local opened, hit, now = compare(t, base, prev)
    if now then prev = now end
    if hit then confirmMode() noHit = 0 else noHit = noHit + 1 end
    if opened then
      confirmMode()
      State.done[t.key] = os.clock()
      State.lastOpenPos, State.lastOpenTime = tpos, os.clock()
      log("abobora aberta")
      local w0 = os.clock()
      while Config.KillJack and os.clock() - w0 < Config.WaitForJack do
        if findJack() then break end
        task.wait(0.1)
      end
      State.lock = nil
      return
    end
    if not State.modeConfirmed and noHit >= Config.SwitchAfter then
      nextMode()
      noHit = 0
    end
  end
  State.lock = nil
  State.done[t.key] = os.clock() - Config.Cooldown + 30
end

-- LOOPS
task.spawn(function()
  while State.running do
    pcall(scanPumpkins)
    task.wait(2)
  end
end)

local function step()
  if not alive() then State.active = false State.lock = nil return end
  if Config.KillJack then
    local j = findJack()
    if j then State.active = true killJack(j) return end
  end
  if Config.FarmPumpkins then
    local t = nearestPumpkin()
    if t then State.active = true farmPumpkin(t) return end
    State.status = "nenhuma abobora disponivel"
  end
  State.active = false
  State.lock = nil
end

task.spawn(function()
  while State.running do
    local ok, err = pcall(step)
    if not ok then log("erro: " .. tostring(err)) State.lock = nil task.wait(1) end
    task.wait(0.15)
  end
end)

table.insert(State.conns, LP.Idled:Connect(function()
  if Config.AntiAFK then
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
  end
end))

-- MENU (arrasta pelo titulo, funciona no toque)
local Gui = Instance.new("ScreenGui")
Gui.Name = "AboboraFarm"
Gui.ResetOnSpawn = false
local parented = gethui and pcall(function() Gui.Parent = gethui() end)
if not parented then parented = pcall(function() Gui.Parent = game:GetService("CoreGui") end) end
if not parented then Gui.Parent = LP:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 210, 0, 0)
Main.AutomaticSize = Enum.AutomaticSize.Y
Main.Position = UDim2.new(0, 12, 0, 60)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
Main.BorderSizePixel = 0
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local pad = Instance.new("UIPadding", Main)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
local layout = Instance.new("UIListLayout", Main)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local order = 0
local function nextOrder() order = order + 1 return order end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 26)
Title.BackgroundTransparency = 1
Title.Active = true
Title.Text = "Farm de Abobora"
Title.TextColor3 = Color3.fromRGB(255, 140, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.LayoutOrder = nextOrder()
Title.Parent = Main

local dragging, dragStart, startPos
Title.InputBegan:Connect(function(i)
  if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
    dragging, dragStart, startPos = true, i.Position, Main.Position
    i.Changed:Connect(function()
      if i.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
  end
end)
table.insert(State.conns, UIS.InputChanged:Connect(function(i)
  if dragging and (i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseMovement) then
    local d = i.Position - dragStart
    Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
  end
end))

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

local OFF, ON = Color3.fromRGB(32, 32, 32), Color3.fromRGB(200, 110, 0)
local function makeButton(text, onClick)
  local b = Instance.new("TextButton")
  b.Size = UDim2.new(1, 0, 0, 34)
  b.BackgroundColor3 = OFF
  b.BorderSizePixel = 0
  b.TextColor3 = Color3.fromRGB(235, 235, 235)
  b.Font = Enum.Font.GothamSemibold
  b.TextSize = 14
  b.Text = text
  b.LayoutOrder = nextOrder()
  b.Parent = Main
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
  b.MouseButton1Click:Connect(function() onClick(b) end)
  return b
end
local function makeToggle(label, key)
  local btn
  local function paint()
    btn.Text = label .. ": " .. (Config[key] and "ON" or "OFF")
    btn.BackgroundColor3 = Config[key] and ON or OFF
  end
  btn = makeButton(label, function() Config[key] = not Config[key] paint() end)
  paint()
end

makeToggle("Farm Abobora", "FarmPumpkins")
makeToggle("Matar Jack", "KillJack")
makeToggle("Anti-AFK", "AntiAFK")
makeButton("Trocar modo de clique", function()
  State.modeConfirmed = false
  nextMode()
end)
makeButton("PARAR", function()
  State.running, State.active, State.lock = false, false, nil
  for _, c in ipairs(State.conns) do c:Disconnect() end
  for p, v in pairs(savedCollide) do if p.Parent then p.CanCollide = v end end
  Gui:Destroy()
end)

task.spawn(function()
  while State.running do
    local livres = 0
    for _, t in ipairs(State.pumpkins) do
      local last = State.done[t.key]
      if not (last and os.clock() - last < Config.Cooldown) then livres = livres + 1 end
    end
    Status.Text = string.format("%s\nAboboras: %d livres / %d\nClique: %s %s\nKillaura: %s",
      string.sub(State.status, 1, 60), livres, #State.pumpkins,
      MODES[State.modeIndex], State.modeConfirmed and "(ok)" or "(testando)",
      State.jackMode or (Hit.ok and ("remoto " .. Hit.mode .. " (ok)") or "esperando Jack"))
    task.wait(0.5)
  end
end)

log("carregado. liga o Farm Abobora")
