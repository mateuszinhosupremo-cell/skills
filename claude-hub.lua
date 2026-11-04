--[[
  ╔══════════════════════════════════════════╗
     CLAUDE HUB  •  Halloween Edition 2026
     Blox Fruits  •  mobile + PC
  ╚══════════════════════════════════════════╝
  - farm de abóbora (workspace.PumpkinHunt): tween + clique humano
  - Jack O'Lantern: pausa o clique, voa em cima e usa killaura remoto
    (RE/RegisterAttack + RE/RegisterHit); quando morre, volta o clique
  - aba Evento: contagem da Harvest Moon, fim do evento, Candy Corn,
    Pumpkin Bits, sementes, rolls do gacha e Great Pumpkin
  - tela de carregamento, avisos, abas, sliders, minimizar

  Se o executor não aceitar colar tudo: salva este arquivo na pasta
  "workspace" do executor e roda:  loadstring(readfile("claude_hub.txt"))()
]]

local genv = (getgenv and getgenv()) or _G
if genv.ClaudeHub and genv.ClaudeHub.Stop then pcall(genv.ClaudeHub.Stop) end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local VirtualUser  = game:GetService("VirtualUser")
local okVim, VIM   = pcall(function() return game:GetService("VirtualInputManager") end)
if not okVim then VIM = nil end
local LP = Players.LocalPlayer
local VERSION = "1.4"

local Config = {
  FarmPumpkins   = false,
  KillJack       = true,
  JackRemote     = true,
  JackFallback   = true,
  AntiAFK        = true,
  NotifyPumpkins = false,
  AutoMinimize   = true,
  AutoMode       = true,   -- testa outro modo de soco se o atual não registrar
  AllowMouse     = false,  -- mouse VIM faz o Roblox virar layout de PC no celular   -- minimiza o hub ao ligar o farm (o clique não acerta o menu)

  TweenSpeed   = 300,
  HitDistance  = 3.5,
  StandHeight  = 1.5,
  JackHeight   = 8,
  JackClickH   = 3,
  JackHitDelay = 0.12,

  ClickMin     = 0.14,
  ClickMax     = 0.26,
  MaxClicks    = 20,
  SwitchAfter  = 12,
  Cooldown     = 300,
  WaitForJack  = 1.0,
  JackKeys     = {"jack", "lantern"},
  JackRadius   = 400,
  Weapon       = "",
}

local MODES = {"Touch", "Activate", "Remote", "VirtualUser", "Mouse"}
local MODE_LABEL = {
  Touch = "Toque (mobile)", Activate = "Activate (ferramenta)", Remote = "Remote (hit direto)",
  VirtualUser = "VirtualUser", Mouse = "Mouse VIM (vira PC)",
}
local State = {
  running = true, active = false, lock = nil, gui = nil,
  pumpkins = {}, done = setmetatable({}, {__mode = "k"}), jackQueue = {},
  modeIndex = 3, modeConfirmed = true, switches = 0, modeRefresh = nil, -- 3 = Remote
  status = "carregando", lastOpenPos = nil, lastOpenTime = 0,
  jackMode = nil, conns = {}, huntHooked = nil, lastErr = 0, avoid = {},
}
local Stats = {opened = 0, jacks = 0, start = os.clock()}

local notify = function() end -- a UI troca isso pelos avisos de verdade

local function log(msg)
  State.status = msg
  print("[Claude Hub] " .. msg)
end

local function getChar() return LP.Character end
local function getRoot() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h = getHum() return h ~= nil and h.Health > 0 end

------------------------------------------------------------------
-- MOVIMENTO
------------------------------------------------------------------
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

------------------------------------------------------------------
-- CLIQUE HUMANO
------------------------------------------------------------------
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

-- o clique simulado nunca pode cair em cima do hub: era isso que desligava o farm
local SPOTS = {{0.5, 0.45}, {0.5, 0.25}, {0.72, 0.3}, {0.28, 0.3}, {0.5, 0.7}, {0.82, 0.5}}
local function overUI(x, y)
  for _, g in ipairs(State.avoid) do
    if g.Parent and g.Visible and g.AbsoluteSize.Y > 0 then
      local p, s = g.AbsolutePosition, g.AbsoluteSize
      if x >= p.X - 14 and x <= p.X + s.X + 14 and y >= p.Y - 14 and y <= p.Y + s.Y + 14 then return true end
    end
  end
  return false
end
local function clickPoint(vp)
  for _, c in ipairs(SPOTS) do
    local x, y = vp.X * c[1] + math.random(-10, 10), vp.Y * c[2] + math.random(-10, 10)
    if not overUI(x, y) then return x, y end
  end
  return nil
end

local remoteHit -- definido no killaura, mais abaixo

local function modeUsable(m)
  if (m == "Touch" or m == "Mouse") and not VIM then return false end
  if m == "Mouse" and not Config.AllowMouse then return false end
  return true
end

-- target/part: o alvo atual (usado só no modo Remote)
local function click(target, part)
  local mode = MODES[State.modeIndex]
  local tool = equip()
  local cam = workspace.CurrentCamera
  if mode == "Remote" then
    if target and remoteHit and remoteHit(target, part) then return end
    mode = "Activate"
  end
  if not modeUsable(mode) then mode = "Activate" end
  local x, y
  if mode ~= "Activate" then
    x, y = clickPoint(cam.ViewportSize)
    if not x then mode = "Activate" end
  end
  if mode == "Activate" then
    if tool then tool:Activate() end
  elseif mode == "Touch" then
    VIM:SendTouchEvent(7, 0, x, y)
    task.wait(0.03 + math.random() * 0.04)
    VIM:SendTouchEvent(7, 2, x, y)
  elseif mode == "Mouse" then
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.02 + math.random() * 0.04)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
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
  task.wait(math.max(t, 0.03))
end

local function confirmMode()
  if not State.modeConfirmed then
    State.modeConfirmed = true
    local label = MODE_LABEL[MODES[State.modeIndex]]
    log("soco confirmado: " .. label)
    notify("Soco confirmado", label .. " registrando os socos", "ok")
    if State.modeRefresh then State.modeRefresh() end
  end
end

local function nextMode()
  for _ = 1, #MODES do
    State.modeIndex = State.modeIndex % #MODES + 1
    if modeUsable(MODES[State.modeIndex]) then break end
  end
  State.switches = State.switches + 1
  local label = MODE_LABEL[MODES[State.modeIndex]]
  log("testando soco " .. label)
  notify("Trocando modo de soco", "Testando " .. label, "warn")
  if State.modeRefresh then State.modeRefresh() end
end

------------------------------------------------------------------
-- KILLAURA REMOTO
------------------------------------------------------------------
local Hit = {attack = nil, hit = nil, mode = 1, ok = false, required = false}

local function getHitRemotes()
  if Hit.attack and Hit.hit and Hit.attack.Parent and Hit.hit.Parent then return true end
  local mods = RS:FindFirstChild("Modules")
  local net = mods and mods:FindFirstChild("Net")
  if not net then return false end
  if not Hit.required then
    Hit.required = true
    task.spawn(pcall, function() require(net):RemoteEvent("RegisterHit", true) end)
  end
  Hit.attack = net:FindFirstChild("RE/RegisterAttack")
  Hit.hit = net:FindFirstChild("RE/RegisterHit")
  return Hit.attack ~= nil and Hit.hit ~= nil
end

remoteHit = function(m, part)
  local head = part or m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
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

------------------------------------------------------------------
-- ABÓBORAS
------------------------------------------------------------------
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

------------------------------------------------------------------
-- JACK
------------------------------------------------------------------
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

local function attachHunt(f)
  if State.huntHooked == f then return end
  State.huntHooked = f
  table.insert(State.conns, f.DescendantAdded:Connect(function(d)
    if d:IsA("Model") then watchJack(d) end
  end))
end

local function hookWatchers()
  local en = workspace:FindFirstChild("Enemies")
  if en then table.insert(State.conns, en.ChildAdded:Connect(watchJack)) end
  table.insert(State.conns, workspace.ChildAdded:Connect(function(c)
    if c.Name == "PumpkinHunt" then attachHunt(c) end
    watchJack(c)
  end))
  local h = workspace:FindFirstChild("PumpkinHunt")
  if h then attachHunt(h) end
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
  notify("Jack O'Lantern!", "Clique pausado, focando só nele", "warn")
  if not tweenTo(above()) then return end
  State.lock = above
  local t0, lastHp, lastDrop = os.clock(), hum.Health, os.clock()
  while State.running and State.active and Config.KillJack and alive() and m.Parent and hum.Health > 0 do
    State.jackMode = useClick and "clique" or ("remoto " .. Hit.mode)
    if os.clock() - t0 > 60 then log("Jack demorou demais") break end
    if useClick then
      pcall(click, m, m:FindFirstChild("Head") or hrp)
      humanPause(0.7)
    else
      equip()
      local ok, sent = pcall(remoteHit, m)
      if not (ok and sent) then
        log("remote de hit não achado")
        notify("Remote não achado", Config.JackFallback and "Usando clique no Jack" or "Killaura parado", "err")
        useClick = Config.JackFallback
        if not useClick then break end
      end
      task.wait(Config.JackHitDelay)
    end
    if hum.Health < lastHp - 0.01 then
      lastHp, lastDrop = hum.Health, os.clock()
      if not useClick and not Hit.ok then
        Hit.ok = true
        notify("Killaura funcionando", "Remote modo " .. Hit.mode .. " dando dano", "ok")
      end
    elseif os.clock() - lastDrop > 2.5 then
      lastDrop = os.clock()
      if not useClick and not Hit.ok then
        if Hit.mode == 1 then
          Hit.mode = 2
          log("killaura modo 1 sem dano, testando 2")
        else
          Hit.mode = 1
          useClick = Config.JackFallback
          notify("Killaura sem dano", useClick and "Voltando pro clique no Jack" or "Me manda o console", "err", 5)
          if not useClick then break end
        end
      end
    end
  end
  State.lock = nil
  State.jackMode = nil
  if hum.Health <= 0 then
    Stats.jacks = Stats.jacks + 1
    log("Jack derrotado")
    notify("Jack derrotado", "Voltando pras abóboras", "ok")
  end
end

------------------------------------------------------------------
-- FARM DE UMA ABÓBORA
------------------------------------------------------------------
local function farmPumpkin(t)
  local tpos, root = center(t.parts), getRoot()
  if not (tpos and root) then return end
  local flat = Vector3.new(root.Position.X - tpos.X, 0, root.Position.Z - tpos.Z)
  local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
  local stand = tpos + dir * Config.HitDistance + Vector3.new(0, Config.StandHeight, 0)
  local cf = CFrame.lookAt(stand, Vector3.new(tpos.X, stand.Y, tpos.Z))

  log("indo até a abóbora")
  if not tweenTo(cf) then return end
  State.lock = cf

  local base = snapshot(t)
  local prev, noHit = base, 0
  for _ = 1, Config.MaxClicks do
    if not (State.running and State.active and Config.FarmPumpkins and alive()) then break end
    if Config.KillJack and findJack() then State.lock = nil return end
    pcall(click, t.key:IsA("Model") and t.key or t.key.Parent, t.parts[1])
    humanPause()
    local opened, hit, now = compare(t, base, prev)
    if now then prev = now end
    if hit then confirmMode() noHit = 0 else noHit = noHit + 1 end
    if opened then
      confirmMode()
      State.done[t.key] = os.clock()
      State.lastOpenPos, State.lastOpenTime = tpos, os.clock()
      Stats.opened = Stats.opened + 1
      log("abóbora aberta (" .. Stats.opened .. ")")
      if Config.NotifyPumpkins then notify("Abóbora aberta", "Total na sessão: " .. Stats.opened, "ok", 1.5) end
      local w0 = os.clock()
      while Config.KillJack and os.clock() - w0 < Config.WaitForJack do
        if findJack() then break end
        task.wait(0.1)
      end
      State.lock = nil
      return
    end
    if Config.AutoMode and not State.modeConfirmed and noHit >= Config.SwitchAfter then
      nextMode()
      noHit = 0
    end
  end
  State.lock = nil
  State.done[t.key] = os.clock() - Config.Cooldown + 30
end

------------------------------------------------------------------
-- LOOPS
------------------------------------------------------------------
local function step()
  if not alive() then State.active = false State.lock = nil return end
  if Config.KillJack then
    local j = findJack()
    if j then State.active = true killJack(j) return end
  end
  if Config.FarmPumpkins then
    local t = nearestPumpkin()
    if t then State.active = true farmPumpkin(t) return end
    State.status = "nenhuma abóbora livre"
  else
    State.status = "parado"
  end
  State.active = false
  State.lock = nil
end

local function startLoops()
  task.spawn(function()
    while State.running do
      pcall(scanPumpkins)
      task.wait(2)
    end
  end)
  task.spawn(function()
    while State.running do
      local ok, err = pcall(step)
      if not ok then
        log("erro: " .. tostring(err))
        State.lock = nil
        if os.clock() - State.lastErr > 10 then
          State.lastErr = os.clock()
          notify("Erro no farm", tostring(err), "err", 5)
        end
        task.wait(1)
      end
      task.wait(0.15)
    end
  end)
  table.insert(State.conns, LP.Idled:Connect(function()
    if Config.AntiAFK then
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end
  end))
end

------------------------------------------------------------------
-- EVENTO HALLOWEEN
------------------------------------------------------------------
local EVENT_END = 1794704400 -- 15/11/2026 01:00 UTC
local Event = {
  candy = nil, bits = nil, seeds = nil, totalOk = false, source = nil,
  gain = {candy = 0, bits = 0, seeds = 0}, seen = setmetatable({}, {__mode = "k"}),
  lastRead = 0, invName = nil, invProbed = false,
  moonActive = nil, warned = false, capWarned = false, gpWarned = false,
}

local function fmt(s)
  s = math.max(0, math.floor(s))
  local d = math.floor(s / 86400)
  local h, m, sec = math.floor(s / 3600) % 24, math.floor(s / 60) % 60, s % 60
  if d > 0 then return string.format("%dd %02d:%02d:%02d", d, h, m, sec) end
  return string.format("%02d:%02d:%02d", h, m, sec)
end

local function clockAt(t)
  local d = os.date("*t", t)
  return string.format("%02d:%02d", d.hour, d.min)
end

-- Harvest Moon: XX:00 a XX:10 UTC, toda hora
local function moonInfo()
  local t = os.time()
  local into = t % 3600
  if into < 600 then return true, 600 - into, t - into end
  return false, 3600 - into, t - into + 3600
end

local function plainText(s)
  s = tostring(s or "")
  s = s:gsub("<[^>]->", ""):gsub("&lt;", ""):gsub("&gt;", ""):gsub("&amp;", "&")
  return s
end

local ITEMS = {candy = "candy corn", bits = "pumpkin bit", seeds = "pumpkin seed"}

-- "Obtained <Candy Corn>", "Obtained 3x <Candy Corn>", "Obtained <Candy Corn> x3"
local function parseObtained(text, key)
  local l = string.lower(plainText(text))
  local a, b = l:find(key, 1, true)
  if not a then return nil end
  local before, after = l:sub(1, a - 1), l:sub(b + 1)
  local n = before:match("(%d+)%s*x?%s*$") or after:match("^s?%s*x%s*(%d+)") or after:match("^s?%s*%((%d+)%)")
  return tonumber(n) or 1
end

local function notifText(nobj)
  local inner = nobj:FindFirstChild("Text")
  if inner and (inner:IsA("TextLabel") or inner:IsA("TextButton")) then return inner.Text end
  if nobj:IsA("TextLabel") or nobj:IsA("TextButton") then return nobj.Text end
  return ""
end

-- ganho na sessão: lê os avisos "Obtained <Candy Corn>" que o próprio jogo mostra
local function pollNotifications()
  local pg = LP:FindFirstChild("PlayerGui")
  local root = pg and pg:FindFirstChild("Notifications")
  local stack = root and root:FindFirstChild("NotificationStack")
  if not stack then return end
  for _, nobj in ipairs(stack:GetChildren()) do
    if not Event.seen[nobj] then
      local txt = notifText(nobj)
      if txt ~= "" then
        Event.seen[nobj] = true
        for field, key in pairs(ITEMS) do
          local n = parseObtained(txt, key)
          if n then
            Event.gain[field] = Event.gain[field] + n
            if Event.totalOk and Event[field] then Event[field] = Event[field] + n end
          end
        end
      end
    end
  end
end

local INV_NAMES = {"getInventory", "GetInventory", "getInventoryItems", "GetInventoryItems", "getInventoryMaterials"}

local function countIn(inv)
  local found = {}
  for k, e in pairs(inv) do
    if type(e) == "table" then
      local name = e.Name or e.name or e.ItemName or (type(k) == "string" and k or nil)
      local n = tonumber(e.Count or e.count or e.Amount or e.Quantity or e.Value)
      if type(name) == "string" then
        local l = string.lower(name)
        for field, key in pairs(ITEMS) do
          if l:find(key, 1, true) then found[field] = n or 1 end
        end
      end
    end
  end
  return found
end

-- total, jeito 1: a lista de itens pelo CommF_ (testa os nomes conhecidos uma vez)
local function readFromRemote()
  local remotes = RS:FindFirstChild("Remotes")
  local comm = remotes and remotes:FindFirstChild("CommF_")
  if not comm then return nil end
  local names = Event.invName and {Event.invName} or (Event.invProbed and {} or INV_NAMES)
  Event.invProbed = true
  for _, name in ipairs(names) do
    local ok, inv = pcall(function() return comm:InvokeServer(name) end)
    if ok and type(inv) == "table" and next(inv) ~= nil then
      Event.invName = name
      return countIn(inv)
    end
  end
  return nil
end

local function numberIn(container, skip)
  for _, c in ipairs(container:GetDescendants()) do
    if c ~= skip and (c:IsA("TextLabel") or c:IsA("TextButton")) then
      local t = plainText(c.Text):gsub("%s", "")
      local n = t:match("^[xX]?(%d+)$") or t:match("^(%d+)/%d+$")
      if n then return tonumber(n) end
    end
  end
  return nil
end

-- total, jeito 2: o cartão do item na tela do inventário (nome + quantidade)
local function readFromGui()
  local pg = LP:FindFirstChild("PlayerGui")
  if not pg then return nil end
  local found = {}
  for _, g in ipairs(pg:GetDescendants()) do
    if (g:IsA("TextLabel") or g:IsA("TextButton")) and not g:FindFirstAncestor("Notifications")
      and not g:FindFirstAncestor("ClaudeHub") then
      local l = string.lower(plainText(g.Text)):gsub("^%s+", ""):gsub("%s+$", "")
      for field, key in pairs(ITEMS) do
        if not found[field] and (l == key or l == key .. "s" or l == "cursed " .. key or l == "cursed " .. key .. "s") then
          local n = g.Parent and numberIn(g.Parent, g)
          if n then found[field] = n end
        end
      end
    end
  end
  return next(found) and found or nil
end

local function readEvent()
  local found, source = readFromRemote(), nil
  if found then source = "remote " .. tostring(Event.invName) end
  if not found then
    found = readFromGui()
    source = found and "tela do inventário" or nil
  end
  Event.lastRead = os.clock()
  if not found then return false end
  Event.totalOk, Event.source = true, source
  Event.candy = found.candy or Event.candy or 0
  Event.bits = found.bits or Event.bits or 0
  Event.seeds = found.seeds or Event.seeds or 0
  if Event.candy >= 5000 and not Event.capWarned then
    Event.capWarned = true
    notify("Candy Corn no limite!", "5000 de 5000: gasta no Spooky Gacha", "warn", 6)
  end
  if Event.bits >= 200 and Event.seeds >= 3 and not Event.gpWarned then
    Event.gpWarned = true
    notify("Great Pumpkin liberada!", "200 bits + 3 sementes: fala com a Witch", "ok", 6)
  end
  return true
end

local function candyDiag()
  local out = {}
  local function add(s) out[#out + 1] = tostring(s) end
  local remotes = RS:FindFirstChild("Remotes")
  local comm = remotes and remotes:FindFirstChild("CommF_")
  add("v" .. VERSION .. " | CommF_: " .. tostring(comm ~= nil))
  if comm then
    for _, name in ipairs(INV_NAMES) do
      local ok, inv = pcall(function() return comm:InvokeServer(name) end)
      local n = 0
      if ok and type(inv) == "table" then for _ in pairs(inv) do n = n + 1 end end
      add(name .. ": ok=" .. tostring(ok) .. " tipo=" .. typeof(inv) .. " itens=" .. n)
    end
  end
  add("ganho na sessão (avisos): candy=" .. Event.gain.candy .. " bits=" .. Event.gain.bits .. " sementes=" .. Event.gain.seeds)
  add("total: " .. (Event.totalOk and (tostring(Event.candy) .. " via " .. tostring(Event.source)) or "não achado"))
  local pg = LP:FindFirstChild("PlayerGui")
  local root = pg and pg:FindFirstChild("Notifications")
  local stack = root and root:FindFirstChild("NotificationStack")
  if stack then
    for _, nobj in ipairs(stack:GetChildren()) do
      local txt = notifText(nobj)
      if txt ~= "" then add("aviso completo: " .. string.sub(plainText(txt), 1, 120)) break end
    end
  end
  if pg then
    local c = 0
    for _, g in ipairs(pg:GetDescendants()) do
      if c >= 8 then break end
      if (g:IsA("TextLabel") or g:IsA("TextButton")) and not g:FindFirstAncestor("Notifications")
        and not g:FindFirstAncestor("ClaudeHub") then
        local l = string.lower(plainText(g.Text))
        if l:find("candy corn", 1, true) or l:find("pumpkin bit", 1, true) or l:find("pumpkin seed", 1, true) then
          c = c + 1
          local sib = {}
          if g.Parent then
            for _, s in ipairs(g.Parent:GetDescendants()) do
              if s ~= g and (s:IsA("TextLabel") or s:IsA("TextButton")) and s.Text ~= "" and #sib < 6 then
                sib[#sib + 1] = s.Name .. "='" .. string.sub(plainText(s.Text), 1, 25) .. "'"
              end
            end
          end
          add("tela: " .. g:GetFullName() .. " = '" .. string.sub(plainText(g.Text), 1, 40) .. "' | vizinhos: " .. table.concat(sib, ", "))
        end
      end
    end
    add("cartões de item achados: " .. c .. (c == 0 and " (abre o inventário de materiais e roda de novo)" or ""))
  end
  local text = table.concat(out, "\n")
  print("[Claude Hub] diagnostico de doces:\n" .. text)
  return setclipboard and pcall(setclipboard, text)
end

local function startEventLoop()
  task.spawn(function()
    while State.running do
      local active, left = moonInfo()
      if Event.moonActive ~= nil and active ~= Event.moonActive then
        if active then
          notify("Harvest Moon começou! 🌕", "10 minutos de portas e bosses", "ok", 6)
        else
          notify("Harvest Moon acabou", "A próxima é em 50 minutos", "info", 4)
        end
        Event.warned = false
      end
      Event.moonActive = active
      if not active and left <= 60 and not Event.warned then
        Event.warned = true
        notify("Harvest Moon em 1 minuto!", "Portas de doces abrindo", "warn", 6)
      end
      pcall(pollNotifications)
      if os.clock() - Event.lastRead > 20 then
        Event.lastRead = os.clock()
        task.spawn(readEvent)
      end
      task.wait(0.5)
    end
  end)
end

local function Stop()
  State.running, State.active, State.lock = false, false, nil
  for _, c in ipairs(State.conns) do pcall(function() c:Disconnect() end) end
  for p, v in pairs(savedCollide) do if p.Parent then p.CanCollide = v end end
  if State.gui then State.gui:Destroy() end
  if genv.ClaudeHub and genv.ClaudeHub.Stop == Stop then genv.ClaudeHub = nil end
  print("[Claude Hub] fechado")
end
genv.ClaudeHub = {Stop = Stop, Config = Config}

------------------------------------------------------------------
-- UI: TEMA E PEÇAS
------------------------------------------------------------------
local T = {
  bg      = Color3.fromRGB(16, 11, 20),
  bg2     = Color3.fromRGB(30, 14, 38),
  panel   = Color3.fromRGB(26, 18, 32),
  card    = Color3.fromRGB(38, 26, 46),
  orange  = Color3.fromRGB(255, 122, 24),
  orange2 = Color3.fromRGB(255, 190, 70),
  purple  = Color3.fromRGB(138, 63, 252),
  green   = Color3.fromRGB(120, 220, 110),
  red     = Color3.fromRGB(235, 70, 70),
  text    = Color3.fromRGB(242, 233, 220),
  dim     = Color3.fromRGB(165, 148, 175),
  dark    = Color3.fromRGB(25, 12, 0),
}
local function fontOr(name, fallback)
  local ok, f = pcall(function() return Enum.Font[name] end)
  return ok and f or fallback
end
local F = {
  title = fontOr("Creepster", Enum.Font.GothamBlack),
  bold  = Enum.Font.GothamBold,
  semi  = Enum.Font.GothamSemibold,
  body  = Enum.Font.Gotham,
}

local function new(class, props)
  local o = Instance.new(class)
  local parent
  for k, v in pairs(props or {}) do
    if k == "Parent" then parent = v else o[k] = v end
  end
  if parent then o.Parent = parent end
  return o
end
local function corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = o}) return o end
local function stroke(o, c, th, tr)
  new("UIStroke", {Color = c, Thickness = th or 1, Transparency = tr or 0,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o})
  return o
end
local function tween(o, t, props, style)
  local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
  tw:Play()
  return tw
end
local function isPress(i)
  return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1
end
local function isMove(i)
  return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement
end

local function makeDraggable(handle, target, onTap)
  local dragging, moved, start, startPos = false, false, nil, nil
  handle.InputBegan:Connect(function(i)
    if isPress(i) then dragging, moved, start, startPos = true, false, i.Position, target.Position end
  end)
  table.insert(State.conns, UIS.InputChanged:Connect(function(i)
    if dragging and isMove(i) then
      local d = i.Position - start
      if d.Magnitude > 6 then moved = true end
      if moved then
        target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
      end
    end
  end))
  table.insert(State.conns, UIS.InputEnded:Connect(function(i)
    if dragging and isPress(i) then
      dragging = false
      if not moved and onTap then onTap() end
    end
  end))
end

local function makeGui()
  local gui = new("ScreenGui", {Name = "ClaudeHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999})
  local placed = false
  if gethui then placed = pcall(function() gui.Parent = gethui() end) end
  if not placed then placed = pcall(function() gui.Parent = game:GetService("CoreGui") end) end
  if not placed then gui.Parent = LP:WaitForChild("PlayerGui") end
  State.gui = gui
  return gui
end

------------------------------------------------------------------
-- UI: AVISOS (toasts)
------------------------------------------------------------------
local function buildToasts(gui)
  local box = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 70),
    Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    ZIndex = 30, Parent = gui})
  table.insert(State.avoid, box)
  new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box})
  local KIND = {
    info = {T.purple, "👻"}, ok = {T.green, "🎃"}, warn = {T.orange, "⚠️"}, err = {T.red, "💀"},
  }
  local n = 0
  notify = function(title, text, kind, dur)
    if not (State.running and box.Parent) then return end
    local k = KIND[kind or "info"] or KIND.info
    n = n + 1
    local holder = new("Frame", {Size = UDim2.fromOffset(250, 56), BackgroundTransparency = 1, LayoutOrder = n, Parent = box})
    local card = new("Frame", {Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(280, 0),
      BackgroundColor3 = T.panel, Parent = holder})
    corner(card, 10) stroke(card, k[1], 1, 0.35)
    corner(new("Frame", {Size = UDim2.new(0, 4, 1, -14), Position = UDim2.fromOffset(7, 7),
      BackgroundColor3 = k[1], BorderSizePixel = 0, Parent = card}), 2)
    new("TextLabel", {Text = k[2], TextSize = 20, Font = F.bold, BackgroundTransparency = 1, TextColor3 = T.text,
      Size = UDim2.fromOffset(30, 56), Position = UDim2.fromOffset(14, 0), Parent = card})
    new("TextLabel", {Text = title, Font = F.bold, TextSize = 13, TextColor3 = k[1], BackgroundTransparency = 1,
      Position = UDim2.fromOffset(48, 8), Size = UDim2.new(1, -56, 0, 18),
      TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card})
    new("TextLabel", {Text = text or "", Font = F.body, TextSize = 11, TextColor3 = T.dim, BackgroundTransparency = 1,
      Position = UDim2.fromOffset(48, 27), Size = UDim2.new(1, -56, 0, 24), TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card})
    tween(card, 0.35, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back)
    task.delay(dur or 3.5, function()
      if not card.Parent then return end
      tween(card, 0.3, {Position = UDim2.fromOffset(280, 0)})
      task.wait(0.32)
      holder:Destroy()
    end)
    local frames = {}
    for _, c in ipairs(box:GetChildren()) do if c:IsA("Frame") then frames[#frames + 1] = c end end
    if #frames > 4 then
      table.sort(frames, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
      frames[1]:Destroy()
    end
  end
end

------------------------------------------------------------------
-- UI: TELA DE CARREGAMENTO
------------------------------------------------------------------
local function runLoading(gui, steps)
  local overlay = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, ZIndex = 20, Parent = gui})
  tween(overlay, 0.4, {BackgroundTransparency = 0.3})

  local floaters = {}
  for i = 1, 6 do
    floaters[i] = new("TextLabel", {Text = ({"🦇", "👻", "🎃"})[i % 3 + 1], TextSize = 22 + (i % 3) * 4,
      BackgroundTransparency = 1, TextTransparency = 0.25, Size = UDim2.fromOffset(34, 34),
      Position = UDim2.fromScale(math.random() * 0.9, math.random() * 0.9), Parent = overlay})
  end
  local animating = true
  task.spawn(function()
    while animating do
      for _, f in ipairs(floaters) do
        tween(f, 1.8, {Position = UDim2.fromScale(math.random() * 0.9, math.random() * 0.9)}, Enum.EasingStyle.Sine)
      end
      task.wait(1.8)
    end
  end)

  local card = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(330, 196), BackgroundColor3 = T.bg, Parent = overlay})
  corner(card, 16) stroke(card, T.orange, 1.5, 0.25)
  new("UIGradient", {Color = ColorSequence.new(T.bg, T.bg2), Rotation = 90, Parent = card})
  local cscale = new("UIScale", {Scale = 0.6, Parent = card})
  tween(cscale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)

  new("TextLabel", {Text = "🎃", TextSize = 34, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40),
    Position = UDim2.fromOffset(0, 10), Parent = card})
  local title = new("TextLabel", {Text = "CLAUDE HUB", Font = F.title, TextSize = 40, TextColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 48), Parent = card})
  new("UIGradient", {Color = ColorSequence.new(T.orange, T.orange2), Rotation = 90, Parent = title})
  new("TextLabel", {Text = "Halloween Edition  •  Blox Fruits", Font = F.semi, TextSize = 12, TextColor3 = T.dim,
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 94), Parent = card})

  local bar = new("Frame", {Position = UDim2.new(0, 24, 0, 130), Size = UDim2.new(1, -48, 0, 8),
    BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = card})
  corner(bar, 4)
  local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.orange, BorderSizePixel = 0, Parent = bar})
  corner(fill, 4)
  new("UIGradient", {Color = ColorSequence.new(T.purple, T.orange), Parent = fill})
  local stepL = new("TextLabel", {Text = "Iniciando...", Font = F.body, TextSize = 11, TextColor3 = T.text,
    BackgroundTransparency = 1, Size = UDim2.new(1, -48, 0, 16), Position = UDim2.new(0, 24, 0, 144),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = card})
  local pct = new("TextLabel", {Text = "0%", Font = F.bold, TextSize = 11, TextColor3 = T.orange,
    BackgroundTransparency = 1, Size = UDim2.new(0, 50, 0, 16), Position = UDim2.new(1, -74, 0, 144),
    TextXAlignment = Enum.TextXAlignment.Right, Parent = card})
  new("TextLabel", {Text = "v" .. VERSION, Font = F.body, TextSize = 10, TextColor3 = T.dim,
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -20), Parent = card})

  task.wait(0.5)
  for i, s in ipairs(steps) do
    stepL.Text = s[1]
    local done, ok, err = false, true, nil
    task.spawn(function()
      ok, err = pcall(s[2])
      done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < 6 do task.wait(0.05) end
    if not done then
      warn("[Claude Hub] etapa demorou demais, pulando: " .. s[1])
      stepL.Text = s[1] .. " (pulado)"
      task.wait(0.3)
    elseif not ok then
      warn("[Claude Hub] " .. s[1] .. " " .. tostring(err))
    end
    tween(fill, 0.35, {Size = UDim2.fromScale(i / #steps, 1)})
    pct.Text = math.floor(i / #steps * 100) .. "%"
    task.wait(0.3 + math.random() * 0.3)
  end
  stepL.Text = "Pronto! Feliz Halloween 🎃"
  task.wait(0.6)
  animating = false
  tween(cscale, 0.3, {Scale = 0})
  tween(overlay, 0.35, {BackgroundTransparency = 1})
  for _, f in ipairs(floaters) do tween(f, 0.3, {TextTransparency = 1}) end
  task.wait(0.4)
  overlay:Destroy()
end

------------------------------------------------------------------
-- UI: JANELA PRINCIPAL
------------------------------------------------------------------
local function buildWindow(gui)
  local W, H = 390, 262
  local win = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H), BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = gui})
  corner(win, 14) stroke(win, T.orange, 1.2, 0.45)
  new("UIGradient", {Color = ColorSequence.new(T.bg, T.bg2), Rotation = 90, Parent = win})
  local scale = new("UIScale", {Scale = 0, Parent = win})
  local minimizeFn
  table.insert(State.avoid, win)
  local function fit()
    local vp = workspace.CurrentCamera.ViewportSize
    return math.min(1, (vp.X - 30) / W, (vp.Y - 30) / H)
  end
  tween(scale, 0.45, {Scale = fit()}, Enum.EasingStyle.Back)

  -- cabeçalho
  local header = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = win})
  corner(header, 14)
  new("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = T.panel,
    BorderSizePixel = 0, Parent = header})
  local brand = new("Frame", {Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1, Parent = header})
  new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = brand})
  new("TextLabel", {Text = "🎃", TextSize = 20, BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 40),
    LayoutOrder = 1, Parent = brand})
  local title = new("TextLabel", {Text = "CLAUDE HUB", Font = F.title, TextSize = 24, TextColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
    LayoutOrder = 2, Parent = brand})
  new("UIGradient", {Color = ColorSequence.new(T.orange, T.orange2), Rotation = 90, Parent = title})
  local badge = new("TextLabel", {Text = "HALLOWEEN", Font = F.bold, TextSize = 10, TextColor3 = T.text,
    BackgroundColor3 = T.purple, Size = UDim2.fromOffset(78, 18), LayoutOrder = 3, Parent = brand})
  corner(badge, 9)

  local function hbtn(txt, x)
    local b = new("TextButton", {Text = txt, Font = F.bold, TextSize = 16, TextColor3 = T.text,
      BackgroundColor3 = T.card, AutoButtonColor = false, Size = UDim2.fromOffset(28, 28),
      Position = UDim2.new(1, x, 0.5, -14), Parent = header})
    corner(b, 8)
    return b
  end
  local minB, closeB = hbtn("–", -72), hbtn("×", -38)
  makeDraggable(header, win)

  -- abas
  local side = new("Frame", {Position = UDim2.fromOffset(8, 48), Size = UDim2.new(0, 96, 1, -56),
    BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = win})
  corner(side, 10)
  new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = side})
  new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side})
  local content = new("Frame", {Position = UDim2.fromOffset(112, 48), Size = UDim2.new(1, -120, 1, -56),
    BackgroundTransparency = 1, Parent = win})

  local pages, tabs, tabN, ord = {}, {}, 0, 0
  local function nxt() ord = ord + 1 return ord end
  local function selectTab(name)
    for k, p in pairs(pages) do p.Visible = (k == name) end
    for k, b in pairs(tabs) do
      tween(b, 0.2, {BackgroundColor3 = k == name and T.orange or T.card})
      b.TextColor3 = k == name and T.dark or T.text
    end
  end
  local function page(name, label)
    tabN = tabN + 1
    local p = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
      ScrollBarThickness = 3, ScrollBarImageColor3 = T.orange, CanvasSize = UDim2.new(),
      AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content})
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p})
    new("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = p})
    local b = new("TextButton", {Text = label, Font = F.semi, TextSize = 12, TextColor3 = T.text,
      BackgroundColor3 = T.card, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = tabN, Parent = side})
    corner(b, 8)
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    pages[name], tabs[name] = p, b
    return p
  end

  -- componentes
  local function section(p, text)
    new("TextLabel", {Text = text, Font = F.bold, TextSize = 11, TextColor3 = T.orange, BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nxt(), Parent = p})
  end

  local function toggle(p, label, desc, key, onChange)
    local h = desc and 46 or 36
    local card = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = T.card,
      Size = UDim2.new(1, 0, 0, h), LayoutOrder = nxt(), Parent = p})
    corner(card, 8)
    new("TextLabel", {Text = label, Font = F.semi, TextSize = 13, TextColor3 = T.text, BackgroundTransparency = 1,
      Position = UDim2.fromOffset(10, desc and 6 or 0), Size = UDim2.new(1, -66, 0, desc and 18 or h),
      TextXAlignment = Enum.TextXAlignment.Left, Parent = card})
    if desc then
      new("TextLabel", {Text = desc, Font = F.body, TextSize = 10, TextColor3 = T.dim, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -66, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card})
    end
    local track = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
      Size = UDim2.fromOffset(40, 20), BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = card})
    corner(track, 10) stroke(track, T.dim, 1, 0.6)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
      Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.dim, BorderSizePixel = 0, Parent = track})
    corner(knob, 8)
    local function paint(t)
      local on = Config[key]
      tween(track, t, {BackgroundColor3 = on and T.orange or T.panel})
      tween(knob, t, {Position = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        BackgroundColor3 = on and Color3.new(1, 1, 1) or T.dim})
    end
    card.MouseButton1Click:Connect(function()
      Config[key] = not Config[key]
      paint(0.2)
      if onChange then onChange(Config[key]) end
    end)
    paint(0)
  end

  local function slider(p, label, key, min, max, stepV, suffix)
    local card = new("Frame", {BackgroundColor3 = T.card, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = nxt(), Parent = p})
    corner(card, 8)
    new("TextLabel", {Text = label, Font = F.semi, TextSize = 12, TextColor3 = T.text, BackgroundTransparency = 1,
      Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -90, 0, 16),
      TextXAlignment = Enum.TextXAlignment.Left, Parent = card})
    local val = new("TextLabel", {Font = F.bold, TextSize = 12, TextColor3 = T.orange, BackgroundTransparency = 1,
      AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(80, 16),
      TextXAlignment = Enum.TextXAlignment.Right, Parent = card})
    local bar = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = T.panel,
      Position = UDim2.new(0, 10, 0, 32), Size = UDim2.new(1, -20, 0, 8), Parent = card})
    corner(bar, 4)
    local fill = new("Frame", {BackgroundColor3 = T.orange, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar})
    corner(fill, 4)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
      Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar})
    corner(knob, 7)
    local function show()
      local a = (Config[key] - min) / (max - min)
      fill.Size = UDim2.fromScale(a, 1)
      knob.Position = UDim2.fromScale(a, 0.5)
      val.Text = (stepV < 1 and string.format("%.2f", Config[key]) or tostring(math.floor(Config[key] + 0.5))) .. (suffix or "")
    end
    local dragging = false
    local function setFrom(x)
      local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
      local v = math.floor((min + a * (max - min)) / stepV + 0.5) * stepV
      Config[key] = math.clamp(v, min, max)
      show()
    end
    bar.InputBegan:Connect(function(i)
      if isPress(i) then dragging = true p.ScrollingEnabled = false setFrom(i.Position.X) end
    end)
    table.insert(State.conns, UIS.InputChanged:Connect(function(i)
      if dragging and isMove(i) then setFrom(i.Position.X) end
    end))
    table.insert(State.conns, UIS.InputEnded:Connect(function(i)
      if dragging and isPress(i) then dragging = false p.ScrollingEnabled = true end
    end))
    show()
  end

  local function button(p, label, cb, color)
    local b = new("TextButton", {Text = label, Font = F.semi, TextSize = 13, TextColor3 = T.text,
      BackgroundColor3 = T.card, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nxt(), Parent = p})
    corner(b, 8) stroke(b, color or T.orange, 1, 0.5)
    b.MouseButton1Click:Connect(function()
      tween(b, 0.08, {BackgroundColor3 = color or T.orange})
      task.delay(0.12, function() tween(b, 0.25, {BackgroundColor3 = T.card}) end)
      cb(b)
    end)
    return b
  end

  local function para(p, text)
    local l = new("TextLabel", {Text = text, Font = F.body, TextSize = 11, TextColor3 = T.dim, BackgroundColor3 = T.card,
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nxt(), Parent = p})
    corner(l, 8)
    new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10),
      PaddingRight = UDim.new(0, 10), Parent = l})
    return l
  end

  local function statRow(p, label)
    local card = new("Frame", {BackgroundColor3 = T.card, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nxt(), Parent = p})
    corner(card, 8)
    new("TextLabel", {Text = label, Font = F.body, TextSize = 12, TextColor3 = T.dim, BackgroundTransparency = 1,
      Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.45, 0, 1, 0),
      TextXAlignment = Enum.TextXAlignment.Left, Parent = card})
    return new("TextLabel", {Text = "-", Font = F.bold, TextSize = 12, TextColor3 = T.text, BackgroundTransparency = 1,
      AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.55, -10, 1, 0),
      TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card})
  end

  -- página: Farm
  local farm = page("farm", "🎃  Farm")
  section(farm, "ABÓBORAS")
  toggle(farm, "Farm de Abóbora", "Tween + clique humano até abrir", "FarmPumpkins", function(on)
    notify(on and "Farm ligado" or "Farm desligado", on and "Indo atrás das abóboras" or "Personagem liberado",
      on and "ok" or "info", 2)
    if on and Config.AutoMinimize and minimizeFn then
      task.delay(0.8, function()
        if Config.FarmPumpkins then
          minimizeFn()
          notify("Hub minimizado", "Pro clique não acertar o menu. Toca na 🎃 pra abrir", "info", 4)
        end
      end)
    end
  end)
  toggle(farm, "Avisar cada abóbora", nil, "NotifyPumpkins")
  section(farm, "JACK O'LANTERN")
  toggle(farm, "Matar Jack", "Pausa o clique e foca só nele", "KillJack")
  toggle(farm, "Killaura remoto", "RegisterHit, sem clique", "JackRemote")
  toggle(farm, "Clique se o remote falhar", "Desce e soca se não der dano", "JackFallback")
  section(farm, "OUTROS")
  toggle(farm, "Anti-AFK", nil, "AntiAFK")

  -- página: Evento
  local ev = page("event", "🦇  Evento")
  section(ev, "HARVEST MOON")
  local er = {
    moon    = statRow(ev, "Agora"),
    nextAt  = statRow(ev, "Próxima às"),
    ends    = statRow(ev, "Evento acaba em"),
  }
  section(ev, "DOCES")
  er.candy  = statRow(ev, "Candy Corn")
  er.gain   = statRow(ev, "Ganho na sessão")
  er.bits   = statRow(ev, "Pumpkin Bits")
  er.seeds  = statRow(ev, "Sementes amaldiçoadas")
  section(ev, "GACHA E BOSS")
  er.rolls  = statRow(ev, "Rolls no Spooky Gacha")
  er.gp     = statRow(ev, "Great Pumpkin")
  button(ev, "🔍  Diagnóstico de doces", function()
    task.spawn(function()
      if candyDiag() then notify("Diagnóstico copiado", "Cola aqui no chat pro Claude", "ok", 5)
      else notify("Diagnóstico no console", "Abre o console e me manda", "info", 5) end
    end)
  end)
  button(ev, "🔄  Atualizar doces agora", function()
    task.spawn(function()
      if readEvent() then notify("Doces atualizados", "Candy Corn: " .. tostring(Event.candy) .. " (" .. tostring(Event.source) .. ")", "ok", 3)
      else notify("Total não achado", "Abre o inventário de materiais e toca de novo", "warn", 4) end
    end)
  end)

  -- página: Ajustes
  local cfg = page("cfg", "⚙️  Ajustes")
  section(cfg, "INTERFACE")
  toggle(cfg, "Minimizar ao ligar o farm", "Evita o clique cair no menu", "AutoMinimize")
  section(cfg, "MODO DE SOCO")
  local modeBtns = {}
  for i, key in ipairs(MODES) do
    local b = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = T.card,
      Size = UDim2.new(1, 0, 0, 32), LayoutOrder = nxt(), Parent = cfg})
    corner(b, 8)
    local dot = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
      Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = b})
    corner(dot, 6) stroke(dot, T.orange, 1, 0.3)
    local lbl = new("TextLabel", {Text = MODE_LABEL[key], Font = F.semi, TextSize = 12, TextColor3 = T.text,
      BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -40, 1, 0),
      TextXAlignment = Enum.TextXAlignment.Left, Parent = b})
    modeBtns[i] = {b = b, dot = dot, lbl = lbl}
    b.MouseButton1Click:Connect(function()
      if not modeUsable(key) then
        notify("Modo indisponível", key == "Mouse" and "Liga 'Permitir Mouse' aqui embaixo" or "Teu executor não tem VIM", "warn", 3)
        return
      end
      State.modeIndex, State.modeConfirmed = i, true
      notify("Modo de soco", MODE_LABEL[key], "ok", 2)
      State.modeRefresh()
    end)
  end
  State.modeRefresh = function()
    for i, r in ipairs(modeBtns) do
      local sel = i == State.modeIndex
      r.dot.BackgroundColor3 = sel and T.orange or T.panel
      r.b.BackgroundColor3 = sel and T.bg2 or T.card
      r.lbl.TextColor3 = modeUsable(MODES[i]) and T.text or T.dim
    end
  end
  State.modeRefresh()
  toggle(cfg, "Trocar sozinho", "Se o soco não registrar, testa o próximo", "AutoMode")
  toggle(cfg, "Permitir Mouse", "O Roblox vira layout de PC", "AllowMouse", function(on)
    if not on and MODES[State.modeIndex] == "Mouse" then nextMode() end
    State.modeRefresh()
  end)
  button(cfg, "🔁  Testar modos de novo", function()
    State.modeConfirmed, State.switches = false, 0
    notify("Testando de novo", "Começando por " .. MODE_LABEL[MODES[State.modeIndex]], "info", 3)
  end)
  section(cfg, "MOVIMENTO")
  slider(cfg, "Velocidade do tween", "TweenSpeed", 150, 350, 10, " st/s")
  slider(cfg, "Distância da abóbora", "HitDistance", 2, 6, 0.5, " st")
  section(cfg, "JACK")
  slider(cfg, "Altura no remoto", "JackHeight", 3, 15, 1, " st")
  slider(cfg, "Altura no clique", "JackClickH", 1, 6, 0.5, " st")
  slider(cfg, "Intervalo do killaura", "JackHitDelay", 0.05, 0.4, 0.01, "s")
  section(cfg, "CLIQUE HUMANO")
  slider(cfg, "Intervalo mínimo", "ClickMin", 0.08, 0.3, 0.01, "s")
  slider(cfg, "Intervalo máximo", "ClickMax", 0.12, 0.5, 0.01, "s")


  -- página: Status
  local st = page("stats", "📊  Status")
  section(st, "SESSÃO")
  local rows = {
    status = statRow(st, "Agora"),
    opened = statRow(st, "Abóboras abertas"),
    jacks  = statRow(st, "Jacks derrotados"),
    free   = statRow(st, "Abóboras livres"),
    click  = statRow(st, "Clique"),
    aura   = statRow(st, "Killaura"),
    time   = statRow(st, "Tempo"),
  }

  -- página: Info
  local info = page("info", "📜  Info")
  para(info, "CLAUDE HUB v" .. VERSION .. "  •  Halloween Edition\nFarm do evento de Halloween do Blox Fruits, feito sob medida pro mobile.")
  section(info, "AVISOS")
  para(info, "• Use em conta alternativa: farm automático pode dar ban.\n"
    .. "• O evento acaba 15/11 às 01:00 UTC (22:00 de 14/11 em Brasília).\n"
    .. "• Soco não registra ou a tela vira PC? Ajustes → Modo de soco.\n"
    .. "• Killaura sem dano? Me manda o console.\n"
    .. "• Doces errados? Evento → Diagnóstico de doces e me manda.")
  section(info, "CONTROLES")
  para(info, "– minimiza pra abóbora flutuante (arrasta e toca pra abrir).\n× fecha o hub (toca duas vezes).")

  selectTab("farm")

  -- minimizar / fechar
  local fab = new("TextButton", {Text = "🎃", TextSize = 26, Font = F.bold, BackgroundColor3 = T.panel,
    AutoButtonColor = false, Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, 16, 0.5, -25),
    Visible = false, Parent = gui})
  corner(fab, 25) stroke(fab, T.orange, 2, 0)
  table.insert(State.avoid, fab)
  local function restore()
    fab.Visible = false
    win.Visible = true
    tween(scale, 0.35, {Scale = fit()}, Enum.EasingStyle.Back)
  end
  makeDraggable(fab, fab, restore)
  minimizeFn = function()
    if not win.Visible then return end
    tween(scale, 0.25, {Scale = 0})
    task.delay(0.26, function() win.Visible = false fab.Visible = true end)
  end
  minB.MouseButton1Click:Connect(minimizeFn)
  local armed = false
  closeB.MouseButton1Click:Connect(function()
    if armed then Stop() return end
    armed = true
    notify("Fechar o Claude Hub?", "Toca no × de novo pra confirmar", "warn", 2.5)
    task.delay(2.5, function() armed = false end)
  end)

  -- status ao vivo
  task.spawn(function()
    while State.running and gui.Parent do
      local free = 0
      for _, t in ipairs(State.pumpkins) do
        local last = State.done[t.key]
        if not (last and os.clock() - last < Config.Cooldown) then free = free + 1 end
      end
      local s = math.floor(os.clock() - Stats.start)
      rows.status.Text = State.status
      rows.opened.Text = tostring(Stats.opened)
      rows.jacks.Text = tostring(Stats.jacks)
      rows.free.Text = free .. " / " .. #State.pumpkins
      rows.click.Text = MODE_LABEL[MODES[State.modeIndex]] .. (State.modeConfirmed and " (ok)" or " (testando)")
      rows.aura.Text = State.jackMode or (Hit.ok and ("remoto " .. Hit.mode .. " (ok)") or "aguardando Jack")
      rows.time.Text = string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)

      local active, left, startAt = moonInfo()
      if active then
        er.moon.Text = "ATIVA • acaba em " .. fmt(left):sub(4)
        er.moon.TextColor3 = T.green
        er.nextAt.Text = clockAt(startAt + 3600)
        badge.Text = "🌕 ATIVA"
        badge.BackgroundColor3 = T.orange
        badge.TextColor3 = T.dark
      else
        er.moon.Text = "próxima em " .. fmt(left):sub(4)
        er.moon.TextColor3 = T.text
        er.nextAt.Text = clockAt(startAt)
        badge.Text = "🌕 " .. fmt(left):sub(4)
        badge.BackgroundColor3 = T.purple
        badge.TextColor3 = T.text
      end
      local endLeft = EVENT_END - os.time()
      er.ends.Text = endLeft > 0 and fmt(endLeft) or "acabou"
      er.gain.Text = "+" .. Event.gain.candy .. " candy • +" .. Event.gain.bits .. " bits"
      if Event.totalOk then
        er.candy.Text = Event.candy .. " / 5000"
        er.bits.Text = Event.bits .. " / 1000"
        er.seeds.Text = tostring(Event.seeds)
        er.rolls.Text = math.floor(Event.candy / 500) .. " (500 cada, 2/h)"
        er.gp.Text = (Event.bits >= 200 and Event.seeds >= 3) and "pronta pra invocar!"
          or (math.min(Event.bits, 200) .. "/200 bits • " .. math.min(Event.seeds, 3) .. "/3 sem.")
      else
        er.candy.Text = "? (abre o inventário)"
        er.bits.Text = "+" .. Event.gain.bits .. " na sessão"
        er.seeds.Text = "+" .. Event.gain.seeds .. " na sessão"
        er.rolls.Text = "precisa do total"
        er.gp.Text = "precisa do total"
      end
      task.wait(0.5)
    end
  end)
end

------------------------------------------------------------------
-- INICIALIZAÇÃO
------------------------------------------------------------------
local gui = makeGui()
buildToasts(gui)

local checks = {}
runLoading(gui, {
  {"Verificando executor...", function() checks.vim = VIM ~= nil end},
  {"Procurando abóboras (PumpkinHunt)...", function()
    checks.hunt = workspace:FindFirstChild("PumpkinHunt") or workspace:WaitForChild("PumpkinHunt", 4)
  end},
  {"Procurando remotes de combate...", function() checks.remote = getHitRemotes() end},
  {"Ligando detector de Jack...", function() hookWatchers() end},
  {"Lendo doces do inventário...", function() checks.inv = readEvent() end},
  {"Montando interface...", function() end},
})

if State.running then
  buildWindow(gui)
  startLoops()
  startEventLoop()
  State.status = "parado"
  notify("Bem-vindo, " .. LP.DisplayName .. "!", "Claude Hub v" .. VERSION .. " • Feliz Halloween", "ok", 4)
  if not checks.hunt then notify("Abóboras não achadas", "Chega perto de uma ilha com abóboras", "warn", 5) end
  if not checks.remote then notify("Remote de hit não achado", "O Jack vai ser no clique", "warn", 5) end
  if not checks.vim then notify("Sem VirtualInputManager", "O soco vai usar Activate/Remote", "warn", 5) end
  if not checks.inv then notify("Total de doces não achado", "O ganho da sessão já conta pelos avisos do jogo", "info", 6) end
  local active, left = moonInfo()
  task.delay(2.4, function()
    notify(active and "Harvest Moon ATIVA 🌕" or "Próxima Harvest Moon",
      active and ("Acaba em " .. fmt(left):sub(4)) or ("Em " .. fmt(left):sub(4)), active and "ok" or "info", 5)
  end)
  task.delay(1.2, function() notify("Aviso", "Use em conta alternativa", "info", 5) end)
end
