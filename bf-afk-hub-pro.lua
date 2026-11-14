--[[
================================================================
  BF AFK HUB  ::  PRO
  Blox Fruits  ::  Luau  ::  Delta (mobile)
  Feito do zero. Sem loadstring, sem codigo de terceiros, sem rede.
================================================================

ABAS (a barra de abas rola pro lado)
  Main   - Auto Farm, Auto Quest, Auto Chest, Auto Stat, Auto Buso,
           Anti-Idle, Hop Server manual, PARAR TUDO
  Farm   - mob (vazio = quest do teu level), metodo de ataque, arma,
           altura, velocidade
  Boat   - Boat Speed, Levantar Barco, Auto Leviathan
  Extra  - avisar/pegar/guardar fruta, avisos de evento e lua cheia,
           tela branca, FPS boost, elite, gacha
  Tune   - ajustes finos do bau
  Custom - rodar/salvar verbos do CommF_
  Log    - console, Diagnostico e Copiar Log

ANTI-PUXAO
  O puxao e o server corrigindo tua posicao; nao da pra desligar.
  O hub voa com teto de velocidade, usa pulo instantaneo so em
  distancia curta e, quando percebe um puxao, pausa e recua
  (mais devagar, pulo menor) em vez de brigar.

AVISO
  Automatizar o jogo quebra as regras do Roblox / Blox Fruits e pode
  dar kick ou ban. Usa conta alt.
================================================================
]]

-- ============================================================
-- 0. CONFIG (defaults; sobrescrito pelo arquivo salvo)
-- ============================================================
local DEFAULTS = {
    -- farm de combate
    EnemyFolders    = { "Enemies" },
    AttackRange     = 300,
    AttackInterval  = 0.25,
    ApproachOffset  = 4,        -- chega a X studs do mob (nao teleporta em cima)
    QuestPriority   = true,     -- foca o mob da quest ativa

    -- auto-quest
    QuestGiverId    = "",
    QuestIndex      = 1,

    -- auto-stat (AddPoint) -- labels variam por versao, confere no logger
    StatPlan        = { Melee = 1, Defense = 1, Sword = 0, Gun = 0, ["Demon Fruit"] = 0 },
    StatPerTick     = 3,

    -- baus
    ChestTag        = "_ChestTagged",
    ChestNames      = { "Chest1", "Chest2", "Chest3" },
    ChestHold        = 0.18,     -- DELAYZIN parado em cima do bau (sobe se nao contar)
    ChestMaxWait     = 0.9,      -- teto de espera esperando o Beli subir
    ChestMaxFails    = 2,       -- falhas no mesmo bau antes de ignorar ele
    ChestIgnoreTime  = 45,      -- segundos ignorando bau que falhou
    ChestNoclip      = true,    -- atravessa parede no caminho
    ChestStreamWait  = 2.0,     -- teto esperando a area RENDERIZAR apos o TP (streaming)
    ChestSettle      = 0.12,    -- respiro extra depois que carregou, antes de tocar
    ChestDisabledAttr = "IsDisabled", -- atributo que marca bau ja pego (nao renasceu ainda)
    ChestFarDist     = 200,     -- TP FINAL: voa ate ficar a essa distancia do bau e ai da TP instantaneo
    ChestFarMode     = 2,       -- bau longe: 1 = tp instantaneo | 2 = voo (o server aceita)
    ChestFlySpeed    = 300,     -- studs/s do voo ate bau longe (~300 e o que a comunidade usa)
    ChestFlyUp       = 40,      -- voa essa altura acima do bau (fora da agua e das paredes)
    ChestFarWait     = 2.0,     -- teto de espera no bau longe
    ChestPreTouch    = 0.25,    -- bau longe: fica parado isso ANTES do 1o toque
    ChestRetouch     = 0.35,    -- re-toca nesse intervalo enquanto espera pagar
    ChestFailPause   = 6,       -- tantos baus seguidos sem pagar = pausa de 30s

    -- auto farm
    FarmMob         = "",        -- nome do mob (vazio = decide pela quest do teu level)
    FarmHover       = 8,         -- altura em cima do mob
    FarmHop         = 150,       -- ate essa distancia vai de pulo instantaneo; mais longe, voa
    FarmFlySpeed    = 280,       -- studs/s do voo ate o mob / NPC
    FarmAttack      = 0,         -- 0 = auto (testa e escolhe) | 1 remote | 2 tecla | 3 clique | 4 tool | 5 tecla+clique
    FarmKeys        = "ZXC",     -- teclas de skill do metodo "tecla"
    FarmWeapon      = 1,         -- 1 qualquer | 2 Melee | 3 Sword | 4 Blox Fruit | 5 Gun
    FarmSetSpawn    = true,      -- salva o spawn perto do NPC da quest (morreu, volta ali)

    -- avisos (filhos de workspace.Map que valem um aviso quando aparecem)
    WatchNames      = { "MysticIsland", "LeviathanGate", "KitsuneIsland", "PrehistoricIsland" },

    -- barco (levantar / velocidade / auto leviathan)
    BoatFolder      = "Boats",   -- pasta dos barcos no workspace (fallback: o modelo do assento)
    BoatMethod      = 1,         -- voo: 1 = cframe | 2 = velocity | 3 = body (troca na aba Boat)
    BoatLift        = 150,       -- altura do "Levantar Barco" (studs acima de onde ligou)
    BoatRiseSpeed   = 60,        -- studs/s subindo e descendo (suave, sem TP)
    BoatSpeed       = 200,       -- velocidade do "Boat Speed"
    SpeedMethod     = 1,         -- 1 = maxspeed (muda o MaxSpeed do assento) | 2 = empurrao (velocidade direta)
    LeviHeight      = 400,       -- altura de cruzeiro do Auto Leviathan
    LeviSpeed       = 180,       -- studs/s de cruzeiro (alto demais = server puxa de volta)
    LeviOutDist     = 5000,      -- quanto anda reto na direcao do barco antes de patrulhar
    LeviLeg         = 2500,      -- tamanho de cada perna da patrulha (quadrado)
    -- o que conta como "a dimensao apareceu" (nomes mudam por update: confere no Explorer)
    LeviSigns       = { "LeviathanGate", "Frozen Dimension", "Leviathan" },
    LeviContainers  = { "Map", "SeaBeasts", "_WorldOrigin/Locations" },
    LeviDirMode     = 2,         -- 1 = frente do barco | 2 = pra longe das ilhas (perigo cresce com a distancia)

    -- geral
    RejoinOnDrop    = true,
    CallCooldown    = 0.12,     -- pacing global dos remotes
    GuiKeybind      = Enum.KeyCode.RightShift,
    SaveFile        = "bfhub_settings.json",
}

-- ============================================================
-- 1. SERVICES / STATE
-- ============================================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local CS      = game:GetService("CollectionService")
local TS      = game:GetService("TeleportService")
local UIS     = game:GetService("UserInputService")
local HttpSvc = game:GetService("HttpService")
local lp      = Players.LocalPlayer

-- re-execucao: derruba a instancia anterior antes de subir a nova
-- (sem isso: dois loops de bau brigando, duas GUIs, log congelado)
do
    local prev = rawget(getgenv(), "BFHUB")
    if type(prev) == "table" then
        prev.alive = false
        if prev._gui then pcall(function() prev._gui:Destroy() end) end
    end
    local hosts = {}
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then table.insert(hosts, h) end
    end
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then table.insert(hosts, pg) end
    for _, host in ipairs(hosts) do
        local stale = host:FindFirstChild("BFHUB_PRO")
        if stale then pcall(function() stale:Destroy() end) end
    end
    if type(prev) == "table" then task.wait(0.35) end
end

getgenv().BFHUB = {}
local HUB = getgenv().BFHUB
HUB.alive = true
HUB.toggles = { farm = false, quest = true, chest = false, stat = false, idle = true,
                lift = false, levi = false, speed = false,
                buso = false, fruit = false, fruitGrab = false, fruitStore = false,
                watch = false, white = false }
HUB.config  = table.clone(DEFAULTS)
HUB.custom  = {}   -- { {name=, verb=, args={}} }

local CFG = HUB.config
local T   = HUB.toggles
for k, v in pairs(DEFAULTS) do
    if CFG[k] == nil then CFG[k] = v end
end
HUB.stats = HUB.stats or { chests = 0, beli = 0, fails = 0, snaps = 0, kills = 0 }

-- ============================================================
-- 2. CORE: log, persistencia, utils, character refresh
-- ============================================================
local Core = {}

do
    -- ring buffer de log (mostrado na GUI)
    Core.logLines = {}
    Core.logHook  = nil
    function Core.log(msg)
        msg = tostring(msg)
        table.insert(Core.logLines, "[" .. os.date("%H:%M:%S") .. "] " .. msg)
        if #Core.logLines > 150 then table.remove(Core.logLines, 1) end
        print("[BFHUB] " .. msg)
        if Core.logHook then pcall(Core.logHook) end
    end

    -- resposta de remote em texto curto (tabela vira JSON)
    function Core.fmt(v)
        if type(v) == "table" then
            local ok, js = pcall(function() return HttpSvc:JSONEncode(v) end)
            if ok and type(js) == "string" then return string.sub(js, 1, 140) end
            return "tabela"
        end
        return tostring(v)
    end

    -- persistencia (guardada; Delta as vezes nao expoe writefile)
    local hasFS = (writefile and readfile and isfile) ~= nil
    function Core.save()
        if not hasFS then return end
        local cfgOut = {}
        for k, v in pairs(CFG) do
            local t = type(v)
            if t == "number" or t == "string" or t == "boolean" or t == "table" then cfgOut[k] = v end
        end
        local data = { toggles = T, config = cfgOut, custom = HUB.custom, stats = HUB.stats }
        local ok, err = pcall(function() writefile(CFG.SaveFile, HttpSvc:JSONEncode(data)) end)
        if not ok then print("[BFHUB] save falhou: " .. tostring(err)) end
    end
    function Core.load()
        if not hasFS then return end
        pcall(function()
            if isfile(CFG.SaveFile) then
                local data = HttpSvc:JSONDecode(readfile(CFG.SaveFile))
                if data.config then
                    for k, v in pairs(data.config) do
                        if k ~= "GuiKeybind" then CFG[k] = v end
                    end
                end
                if data.toggles then for k, v in pairs(data.toggles) do T[k] = v end end
                if data.custom then HUB.custom = data.custom end
                if data.stats then
                    HUB.stats = HUB.stats or {}
                    for k, v in pairs(data.stats) do
                        if type(v) == "number" then HUB.stats[k] = v end
                    end
                end
                Core.log("settings carregados do arquivo")
            end
        end)
    end

    -- character refs com refresh automatico
    Core.char, Core.root, Core.hum = nil, nil, nil
    local bindGen = 0
    local function bind(c)
        bindGen += 1
        local myGen = bindGen
        local root = c:WaitForChild("HumanoidRootPart", 10)
        local hum  = c:WaitForChild("Humanoid", 10)
        if myGen ~= bindGen then return end  -- respawnou de novo no meio: aborta
        if not root or not hum then
            -- timeout (ping alto/streaming): nao morre mudo NEM espera outra
            -- morte - loga e re-tenta em background ate o char completar
            Core.log("bind: root/hum nao chegaram em 10s - re-tentando em background")
            task.spawn(function()
                while myGen == bindGen and c.Parent do
                    root = root or c:FindFirstChild("HumanoidRootPart")
                    hum  = hum  or c:FindFirstChildWhichIsA("Humanoid")
                    if root and hum then
                        if myGen == bindGen then
                            Core.char, Core.root, Core.hum = c, root, hum
                            Core.log("bind: recuperado")
                        end
                        return
                    end
                    task.wait(1)
                end
            end)
            return
        end
        Core.char, Core.root, Core.hum = c, root, hum
    end
    if lp.Character then bind(lp.Character) end
    lp.CharacterAdded:Connect(bind)

    function Core.alive() return Core.char and Core.hum and Core.hum.Health > 0 and Core.root end

    -- pacing global
    local lastCall = 0
    function Core.pace()
        local dt = os.clock() - lastCall
        if dt < CFG.CallCooldown then task.wait(CFG.CallCooldown - dt) end
        lastCall = os.clock()
    end
end

-- ============================================================
-- 2.5 MOVE: viagem com velocidade limitada + ANTI-PUXAO
-- ============================================================
-- O "puxao" (rubberband) e o SERVER corrigindo tua posicao. Nao tem como
-- desligar isso pelo cliente (quem promete "bypass" entrega placebo).
-- O que funciona de verdade, e o que esse modulo faz:
--   1) voar com teto de velocidade em vez de pular longe
--   2) pulo instantaneo so em distancia curta
--   3) PERCEBER quando o server puxa e recuar (pausa + mais devagar + pulo
--      menor) em vez de brigar - brigar e o que acumula pro Security Kick
local Move = {}
do
    local RunSvc = game:GetService("RunService")
    Move.scale    = 1            -- multiplicador da velocidade (cai a cada puxao)
    Move.hopScale = 1            -- multiplicador do pulo instantaneo
    Move.pulls    = 0
    Move.lastPull = -math.huge

    function Move.speed(base)
        return math.max(60, (tonumber(base) or 250) * Move.scale)
    end

    function Move.hop(base)
        return math.max(40, (tonumber(base) or 150) * Move.hopScale)
    end

    -- registra um puxao e recua
    function Move.pulled(what, dist)
        Move.pulls += 1
        Move.lastPull = os.clock()
        HUB.stats.snaps = (HUB.stats.snaps or 0) + 1
        Move.scale = math.max(0.4, Move.scale * 0.85)
        Move.hopScale = math.max(0.25, Move.hopScale * 0.75)
        Core.log(("puxao #%d (%s, %d studs) - recuando: velocidade %d%%, pulo %d%%"):format(
            Move.pulls, tostring(what), math.floor(dist or 0),
            math.floor(Move.scale * 100), math.floor(Move.hopScale * 100)))
    end

    -- um minuto sem puxao: devolve a velocidade aos poucos
    task.spawn(function()
        while HUB.alive do
            task.wait(20)
            if os.clock() - Move.lastPull > 60 then
                Move.scale = math.min(1, Move.scale + 0.05)
                Move.hopScale = math.min(1, Move.hopScale + 0.05)
            end
        end
    end)

    -- fica parado no ar (sem escrever posicao) deixando o server "assentar"
    function Move.settle(sec)
        local t0 = os.clock()
        while os.clock() - t0 < sec and HUB.alive do
            local r = Core.root
            if r then r.AssemblyLinearVelocity = Vector3.zero end
            RunSvc.Heartbeat:Wait()
        end
    end

    -- noclip compartilhado (cada modulo pede com o proprio nome)
    local ncOwners, ncConn = {}, nil
    function Move.noclip(owner, on)
        ncOwners[owner] = on and true or nil
        local any = next(ncOwners) ~= nil
        if any and not ncConn then
            ncConn = RunSvc.Stepped:Connect(function()
                if not HUB.alive then
                    if ncConn then ncConn:Disconnect(); ncConn = nil end
                    return
                end
                local c = Core.char
                if not c then return end
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
                end
            end)
        elseif not any and ncConn then
            ncConn:Disconnect()
            ncConn = nil
        end
    end

    -- Voa ate goalFn() (Vector3) e devolve true quando faltar stopDist.
    -- goalFn devolvendo nil ou keepFn() == false aborta (devolve false).
    function Move.fly(goalFn, stopDist, baseSpeed, keepFn, flyUp)
        local r = Core.root
        local goal = goalFn()
        if not r or not goal then return false end
        stopDist = math.max(stopDist or 3, 3)
        local cruiseY = math.max(r.Position.Y, goal.Y) + (flyUp or 40)
        local deadline = os.clock() + 180
        local lastSet = nil
        while HUB.alive and Core.alive() and (keepFn == nil or keepFn()) do
            local dt = RunSvc.Heartbeat:Wait()
            r = Core.root
            if not r then return false end
            goal = goalFn()
            if not goal then return false end
            if os.clock() > deadline then
                Core.log("voo estourou o tempo (3 min) - desistindo desse destino")
                return false
            end
            local pos = r.Position
            -- ANTI-PUXAO: eu deixei o personagem em lastSet. Se ele apareceu
            -- longe dali, foi o server que corrigiu: para, espera e recua.
            if lastSet then
                local drift = (pos - lastSet).Magnitude
                if drift > math.max(18, Move.speed(baseSpeed) * dt * 3) then
                    Move.pulled("voo", drift)
                    lastSet = nil
                    Move.settle(1.2)
                    continue
                end
            end
            if (goal - pos).Magnitude <= stopDist then return true end
            local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Magnitude
            -- longe: voa na altura de cruzeiro; chegando: desce no destino
            local aim = goal
            if flat > math.max(stopDist, 25) then
                aim = Vector3.new(goal.X, cruiseY, goal.Z)
            end
            local delta = aim - pos
            local dist = delta.Magnitude
            if dist > 0.01 then
                local stepLen = math.min(dist, Move.speed(baseSpeed) * dt)
                lastSet = pos + delta.Unit * stepLen
                r.AssemblyLinearVelocity = Vector3.zero
                r.CFrame = CFrame.new(lastSet)
            end
        end
        return false
    end

    -- Vai ate um ponto: perto = pulo instantaneo; longe = voo + pulo final curto.
    function Move.goTo(goalFn, hopBase, baseSpeed, keepFn)
        local r = Core.root
        local goal = goalFn()
        if not r or not goal then return false end
        local hop = Move.hop(hopBase)
        if (goal - r.Position).Magnitude > hop then
            if not Move.fly(goalFn, hop, baseSpeed, keepFn) then return false end
        end
        r = Core.root
        goal = goalFn()
        if not r or not goal then return false end
        r.AssemblyLinearVelocity = Vector3.zero
        r.CFrame = CFrame.new(goal)
        return true
    end
end

-- ============================================================
-- 3. REMOTES: resolucao dinamica + watchdog
-- ============================================================
local Net = {}

do
    Net.R = {}
    Net.fails = 0

    local function findInst(className, name, root)
        for _, d in ipairs((root or RS):GetDescendants()) do
            if d:IsA(className) and d.Name == name then return d end
        end
    end

    -- fallback pro bug do Delta (nome >15 chars vira "Unreadable_name")
    local function findNet(name)
        local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
        if not net then return findInst("RemoteEvent", name) end
        return net:FindFirstChild(name) or findInst("RemoteEvent", name, net)
    end

    function Net.resolve()
        local remotes = RS:FindFirstChild("Remotes")
        Net.R.CommF  = (remotes and remotes:FindFirstChild("CommF_")) or findInst("RemoteFunction", "CommF_")
        Net.R.Attack = findNet("RE/RegisterAttack")
        Net.R.Hit    = findNet("RE/RegisterHit")
        Net.R.Browser= remotes and remotes:FindFirstChild("__ServerBrowser") or findInst("RemoteFunction", "__ServerBrowser")

        local miss = {}
        if not Net.R.CommF  then table.insert(miss, "CommF_") end
        if not Net.R.Attack then table.insert(miss, "RegisterAttack") end
        if not Net.R.Hit    then table.insert(miss, "RegisterHit") end
        return miss
    end

    -- invoca CommF_ com pacing, pcall e watchdog (re-resolve se falhar demais)
    function Net.commf(verb, ...)
        if not Net.R.CommF then
            Net.resolve()
            if not Net.R.CommF then return false, "sem CommF_" end
        end
        Core.pace()
        local args = table.pack(...)
        local ok, res = pcall(function()
            return Net.R.CommF:InvokeServer(verb, table.unpack(args, 1, args.n))
        end)
        if not ok then
            Net.fails += 1
            if Net.fails >= 5 then
                Core.log("5 falhas seguidas - re-resolvendo remotes")
                Net.resolve(); Net.fails = 0
            end
        else
            Net.fails = 0
        end
        return ok, res
    end

    function Net.fire(remote, ...)
        if not remote then return end
        local a = table.pack(...)
        pcall(function() remote:FireServer(table.unpack(a, 1, a.n)) end)
    end
end

-- ============================================================
-- 4. VERSION GUARD (fingerprint + PlaceVersion persistido)
-- ============================================================
local function versionGuard()
    local miss = Net.resolve()
    Core.log("PlaceVersion = " .. tostring(game.PlaceVersion))
    if #miss > 0 then
        Core.log("!! remotes faltando: " .. table.concat(miss, ", "))
        Core.log("!! o jogo deve ter atualizado - o que depender deles pode nao funcionar")
        return false
    end
    Core.log("remotes ok")
    return true
end

-- ============================================================
-- 5. FEATURES
-- ============================================================
local Feat = {}

function Feat.notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            { Title = title, Text = text, Duration = 8 })
    end)
end

-- ---- 5.1 anti-idle ----
do
    local VU; pcall(function() VU = game:GetService("VirtualUser") end)
    if VU then
        lp.Idled:Connect(function()
            if not T.idle then return end
            pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
        end)
        Core.log("anti-idle disponivel")
    else
        Core.log("VirtualUser nao exposto - anti-idle off")
    end
end

-- ---- 5.2 auto-rejoin / server hop ----
do
    if CFG.RejoinOnDrop then
        game:GetService("GuiService").ErrorMessageChanged:Connect(function()
            if HUB.alive then pcall(function() TS:Teleport(game.PlaceId, lp) end) end
        end)
        lp.OnTeleport:Connect(function(s)
            if s == Enum.TeleportState.Failed then
                task.wait(2); pcall(function() TS:Teleport(game.PlaceId, lp) end)
            end
        end)
    end
    -- hop pra outro servidor via __ServerBrowser (shape de 1 fonte; best-effort)
    function Feat.hopServer()
        if not Net.R.Browser then Core.log("sem __ServerBrowser"); return end
        local ok, page = pcall(function() return Net.R.Browser:InvokeServer(1) end)
        if ok and type(page) == "table" then
            for jobId in pairs(page) do
                if jobId ~= game.JobId then
                    pcall(function() Net.R.Browser:InvokeServer("teleport", jobId) end)
                    Core.log("hop -> " .. tostring(jobId))
                    return
                end
            end
        end
        Core.log("hop falhou (shape do browser mudou?)")
    end
end

-- ---- 5.3 auto-farm v2 (quest + mob + ataque) ----
-- Montado em cima do que a pesquisa achou nos scripts publicos (as ideias,
-- em palavras - nenhum codigo copiado):
--   - level em Data.Level; a quest certa sai dos modulos do proprio jogo
--     (Quests / GuideModule) e, se eles mudaram, de uma tabela reserva
--   - StartQuest direto pelo CommF_ (sem andar ate o NPC nem clicar)
--   - mob vivo em workspace.Enemies; sem mob vivo, espera no ponto de spawn
--   - fica parado EM CIMA do mob: velocidade zerada, noclip, nunca ancorado
--   - ataque: o update 30 quebrou o "fast attack" antigo, entao o hub TESTA
--     cada metodo no mob (tecla de skill / clique / tool / remote) e fica com
--     o que tirar vida de verdade
do
    local RunSvc = game:GetService("RunService")
    local VIM, VU
    pcall(function() VIM = game:GetService("VirtualInputManager") end)
    pcall(function() VU = game:GetService("VirtualUser") end)

    local ATTACKS = { "remote", "tecla", "clique", "tool", "tecla+clique" }
    local WEAPONS = { "qualquer", "Melee", "Sword", "Blox Fruit", "Gun" }
    Feat.farmAttacks = ATTACKS
    Feat.farmWeapons = WEAPONS

    local SEA1, SEA2, SEA3 = 2753915549, 4442272183, 7449423635
    -- tabela reserva (ids antigos do Sea 1; o update 30 refez as ilhas, entao
    -- so e usada se o modulo Quests do jogo nao abrir)
    local SEA1_QUESTS = {
        { 1,   "BanditQuest1",   1, "Bandit" },
        { 10,  "JungleQuest",    1, "Monkey" },
        { 15,  "JungleQuest",    2, "Gorilla" },
        { 30,  "BuggyQuest1",    1, "Pirate" },
        { 40,  "BuggyQuest1",    2, "Brute" },
        { 60,  "DesertQuest",    1, "Desert Bandit" },
        { 75,  "DesertQuest",    2, "Desert Officer" },
        { 90,  "SnowQuest",      1, "Snow Bandit" },
        { 100, "SnowQuest",      2, "Snowman" },
        { 120, "MarineQuest2",   1, "Chief Petty Officer" },
        { 150, "SkyQuest",       1, "Sky Bandit" },
        { 175, "SkyQuest",       2, "Dark Master" },
        { 190, "PrisonerQuest",  1, "Prisoner" },
        { 210, "PrisonerQuest",  2, "Dangerous Prisoner" },
        { 250, "ColosseumQuest", 1, "Toga Warrior" },
        { 275, "ColosseumQuest", 2, "Gladiator" },
        { 300, "MagmaQuest",     1, "Military Soldier" },
        { 325, "MagmaQuest",     2, "Military Spy" },
        { 375, "FishmanQuest",   1, "Fishman Warrior" },
        { 400, "FishmanQuest",   2, "Fishman Commando" },
        { 450, "SkyExp1Quest",   1, "God's Guard" },
        { 475, "SkyExp1Quest",   2, "Shanda" },
        { 525, "SkyExp2Quest",   1, "Royal Squad" },
        { 550, "SkyExp2Quest",   2, "Royal Soldier" },
        { 625, "FountainQuest",  1, "Galley Pirate" },
        { 650, "FountainQuest",  2, "Galley Captain" },
    }

    local st = {
        db = nil, dbSrc = "ainda nao carregada", npcs = nil,
        quest = nil, questLevel = -1, questAt = 0,
        lastStart = 0, lastAbandon = -math.huge, titleBad = false,
        npcTried = {}, spawnSet = {},
        best = nil, reprobeAt = 0,
        lastWarn = {}, skip = {},
        status = "parado",
    }

    local function warnOnce(key, sec, msg)
        local now = os.clock()
        if now - (st.lastWarn[key] or -math.huge) >= sec then
            st.lastWarn[key] = now
            Core.log(msg)
        end
    end

    -- "Bandit [Lv. 5]" -> "Bandit"
    local function baseName(name)
        return (string.gsub(name, "%s*%[.-%]%s*$", ""))
    end

    local function isMob(name, mob)
        return name == mob or baseName(name) == mob
    end

    local function playerLevel()
        local lvl
        pcall(function() lvl = lp.Data.Level.Value end)
        if type(lvl) == "number" then return lvl end
        return nil
    end

    -- ---------- dados de quest ----------
    local function loadDB()
        local list = {}
        -- modulos do proprio jogo. o formato pode ter mudado no update 30,
        -- entao tudo aqui e pcall + conferencia de tipo
        local okQ, quests = pcall(function()
            local m = RS:FindFirstChild("Quests")
            if m and m:IsA("ModuleScript") then return require(m) end
            return nil
        end)
        if okQ and type(quests) == "table" then
            for id, tiers in pairs(quests) do
                if type(id) == "string" and type(tiers) == "table" then
                    for tier, info in pairs(tiers) do
                        if type(tier) == "number" and type(info) == "table"
                            and type(info.LevelReq) == "number" and type(info.Task) == "table" then
                            local mob, count = next(info.Task)
                            -- count 1 = quest de chefe; fica de fora do farm de level
                            if type(mob) == "string" and type(count) == "number" and count > 1 then
                                table.insert(list, { level = info.LevelReq, id = id, tier = tier, mob = mob })
                            end
                        end
                    end
                end
            end
        end
        if #list > 0 then
            st.dbSrc = "modulo do jogo (" .. #list .. " quests)"
        elseif game.PlaceId == SEA1 then
            for _, q in ipairs(SEA1_QUESTS) do
                table.insert(list, { level = q[1], id = q[2], tier = q[3], mob = q[4] })
            end
            st.dbSrc = "tabela reserva do Sea 1 (" .. #list .. " quests, ids antigos)"
        else
            st.dbSrc = "nenhuma (modulo Quests nao abriu e nao tenho tabela desse mar)"
        end
        table.sort(list, function(a, b) return a.level < b.level end)
        st.db = list

        local okG, guide = pcall(function()
            local m = RS:FindFirstChild("GuideModule")
            if m and m:IsA("ModuleScript") then return require(m) end
            return nil
        end)
        if okG and type(guide) == "table" and type(guide.Data) == "table"
            and type(guide.Data.NPCList) == "table" then
            st.npcs = guide.Data.NPCList
        end
        Core.log("farm: quests = " .. st.dbSrc .. (st.npcs and " + posicao dos NPCs" or ""))
    end

    -- nomes de mob que existem NESSE mar (vivos, pontos de spawn, estacionados)
    local function namesHere()
        local set = {}
        local function add(container)
            if not container then return end
            for _, c in ipairs(container:GetChildren()) do
                set[baseName(c.Name)] = true
            end
        end
        for _, fname in ipairs(CFG.EnemyFolders) do
            add(workspace:FindFirstChild(fname))
        end
        local wo = workspace:FindFirstChild("_WorldOrigin")
        add(wo and wo:FindFirstChild("EnemySpawns"))
        for _, c in ipairs(RS:GetChildren()) do
            if c:IsA("Model") then set[baseName(c.Name)] = true end
        end
        return set
    end

    local function chooseQuest()
        if type(CFG.QuestGiverId) == "string" and CFG.QuestGiverId ~= "" then
            -- quest escolhida na mao (config): usa ela e pronto
            local manualMob = nil
            if type(CFG.FarmMob) == "string" and CFG.FarmMob ~= "" then manualMob = CFG.FarmMob end
            return { id = CFG.QuestGiverId, tier = CFG.QuestIndex, level = 0, mob = manualMob, manual = true }
        end
        if not st.db then loadDB() end
        if #st.db == 0 then
            warnOnce("nodb", 120, "farm: sem tabela de quests desse mar - bato no mob mais perto (ou escreve o nome do mob na aba Farm)")
            return nil
        end
        local lvl = playerLevel()
        if not lvl then
            warnOnce("lvl", 30, "farm: nao consegui ler teu level (Data.Level)")
            return nil
        end
        if st.quest and st.questLevel == lvl and os.clock() - st.questAt < 30 then
            return st.quest
        end
        local here = namesHere()
        local pick, first = nil, nil
        for i = #st.db, 1, -1 do
            local q = st.db[i]
            if q.level <= lvl then
                first = first or q
                if here[q.mob] then
                    pick = q
                    break
                end
            end
        end
        pick = pick or first
        if pick and (not st.quest or st.quest.id ~= pick.id or st.quest.tier ~= pick.tier) then
            Core.log(("farm: level %d -> quest %s %s (%s)"):format(
                math.floor(lvl), tostring(pick.id), tostring(pick.tier), tostring(pick.mob)))
        end
        st.quest, st.questLevel, st.questAt = pick, lvl, os.clock()
        return pick
    end

    -- painel da quest: devolve visivel (true/false, ou nil se nao achei o
    -- painel) e o texto do titulo
    local function questState()
        local pg = lp:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local q = main and main:FindFirstChild("Quest")
        if not q then return nil, "" end
        local vis = false
        pcall(function() vis = q.Visible and true or false end)
        local title = ""
        pcall(function() title = q.Container.QuestTitle.Title.Text end)
        if title == "" and vis then
            local bits = {}
            for _, d in ipairs(q:GetDescendants()) do
                if d:IsA("TextLabel") and #d.Text > 3 and #bits < 6 then
                    table.insert(bits, d.Text)
                end
            end
            title = table.concat(bits, " ")
        end
        return vis, title
    end

    local function npcPosFor(q)
        if not st.npcs or not q.level then return nil end
        for key, e in pairs(st.npcs) do
            if type(e) == "table" and type(e.Levels) == "table" then
                for _, lv in pairs(e.Levels) do
                    if lv == q.level then
                        local p = e.Position or e.CFrame
                        if typeof(p) == "CFrame" then p = p.Position end
                        if typeof(p) ~= "Vector3" and typeof(key) == "Instance" then
                            local ok, piv = pcall(function() return key:GetPivot().Position end)
                            if ok then p = piv end
                        end
                        if typeof(p) == "Vector3" then return p end
                    end
                end
            end
        end
        return nil
    end

    local function startQuest(q)
        st.lastStart = os.clock()
        local _, res = Net.commf("StartQuest", q.id, q.tier)
        task.wait(0.7)
        local vis, title = questState()
        if vis then
            Core.log(("farm: quest pega - %s %s"):format(tostring(q.id), tostring(q.tier)))
            -- se o titulo nao cita o mob nem depois de EU pegar a quest, o
            -- titulo nao serve pra conferir: nunca mais abandono por causa dele
            if q.mob and title ~= "" and not string.find(title, q.mob, 1, true) then
                st.titleBad = true
            end
            return true
        end
        if vis == false then
            warnOnce("startfail", 30, ("farm: StartQuest %s %s nao pegou daqui (resposta: %s)"):format(
                tostring(q.id), tostring(q.tier), Core.fmt(res)))
        end
        return false
    end

    -- ---------- segurar o personagem em cima do mob ----------
    local hold = { pos = nil, look = nil, lastSet = nil, pause = 0, replan = false }
    local holdConn = nil

    local function holdOn()
        if holdConn then return end
        holdConn = RunSvc.Heartbeat:Connect(function()
            if not HUB.alive then
                if holdConn then holdConn:Disconnect(); holdConn = nil end
                return
            end
            local r = Core.root
            if not r or not hold.pos then return end
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if os.clock() < hold.pause then return end
            -- ANTI-PUXAO: se o server me tirou de onde eu me deixei, nao brigo:
            -- solto a posicao e o farm replaneja a partir de onde ele me pos
            if hold.lastSet then
                local drift = (r.Position - hold.lastSet).Magnitude
                if drift > 25 then
                    Move.pulled("farm", drift)
                    hold.pos, hold.look, hold.lastSet = nil, nil, nil
                    hold.pause = os.clock() + 1.2
                    hold.replan = true
                    return
                end
            end
            if hold.look and (hold.look - hold.pos).Magnitude > 0.5 then
                r.CFrame = CFrame.lookAt(hold.pos, hold.look)
            else
                r.CFrame = CFrame.new(hold.pos)
            end
            hold.lastSet = hold.pos
        end)
    end

    local function holdClear()
        hold.pos, hold.look, hold.lastSet = nil, nil, nil
    end

    local function aimAt(t)
        local p = t.hrp.Position
        -- um pouco pra tras pra nunca olhar reto pra baixo (CFrame.lookAt degenera)
        hold.pos = p + Vector3.new(0, CFG.FarmHover, 3)
        hold.look = p
    end

    local function keep()
        return T.farm and not T.chest and not Feat.boatBusy and not Feat.fruitBusy
    end

    function Feat.farmStop()
        st.status = "parado"
        holdClear()
        hold.replan = false
        if holdConn then holdConn:Disconnect(); holdConn = nil end
        Move.noclip("farm", false)
        Feat.farmBusy = false
    end

    -- ---------- quest ----------
    local function manageQuest(q)
        local vis, title = questState()
        local now = os.clock()
        if vis == nil then
            -- o HUD mudou e nao acho o painel: sem como saber se tem quest ativa
            warnOnce("notrack", 60, "farm: nao achei o painel da quest (Main.Quest) - pegando quest as cegas a cada 45s")
            if now - st.lastStart > 45 then startQuest(q) end
            return
        end
        if vis then
            if q.mob and not q.manual and not st.titleBad and title ~= ""
                and not string.find(title, q.mob, 1, true)
                and now - st.lastAbandon > 60 then
                st.lastAbandon = now
                st.lastStart = 0
                Core.log("farm: a quest ativa e de outro mob - abandonando pra pegar a certa")
                Net.commf("AbandonQuest")
            end
            return
        end
        if now - st.lastStart < 4 then return end
        if startQuest(q) then return end

        -- o server nao aceitou daqui: chega perto do NPC (se eu souber onde
        -- ele fica) e tenta de novo. so tenta isso 1x a cada 2 min por quest.
        local key = tostring(q.id) .. ":" .. tostring(q.tier)
        if (st.npcTried[key] or 0) > now then return end
        st.npcTried[key] = now + 120
        local pos = npcPosFor(q)
        if not pos then
            Core.log("farm: nao sei onde fica o NPC dessa quest - sigo farmando sem quest e tento de novo em 2 min")
            return
        end
        st.status = "indo ate o NPC da quest"
        holdOn()
        Move.noclip("farm", true)
        holdClear()
        local spot = pos + Vector3.new(0, 4, 4)
        if Move.goTo(function() return spot end, CFG.FarmHop, CFG.FarmFlySpeed, keep) then
            hold.pos, hold.look = spot, pos
            task.wait(1.1)
            if startQuest(q) and CFG.FarmSetSpawn and not st.spawnSet[q.id] then
                st.spawnSet[q.id] = true
                Net.commf("SetSpawnPoint")
            end
        end
    end

    -- ---------- alvo ----------
    local function pickTarget(mob)
        local r = Core.root
        if not r then return nil end
        local now, best = os.clock(), nil
        for _, fname in ipairs(CFG.EnemyFolders) do
            local f = workspace:FindFirstChild(fname)
            if f then
                for _, e in ipairs(f:GetChildren()) do
                    if (mob == nil or isMob(e.Name, mob)) and (st.skip[e] or 0) < now then
                        local h = e:FindFirstChildWhichIsA("Humanoid")
                        local hr = e:FindFirstChild("HumanoidRootPart")
                        if h and hr and h.Health > 0 then
                            local d = (hr.Position - r.Position).Magnitude
                            -- sem mob definido: so pega o que ta perto (nao sai cacando chefe)
                            if (mob ~= nil or d <= CFG.AttackRange) and (best == nil or d < best.dist) then
                                best = { model = e, hum = h, hrp = hr, dist = d }
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    -- onde esse mob nasce (pra esperar no lugar certo quando nao tem nenhum vivo)
    local function areaOf(mob)
        local r = Core.root
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local sp = wo and wo:FindFirstChild("EnemySpawns")
        local best, bestD = nil, math.huge
        if sp and r then
            for _, s in ipairs(sp:GetChildren()) do
                if isMob(s.Name, mob) then
                    local ok, pos = pcall(function()
                        if s:IsA("BasePart") then return s.Position end
                        return s:GetPivot().Position
                    end)
                    if ok and typeof(pos) == "Vector3" then
                        local d = (pos - r.Position).Magnitude
                        if d < bestD then best, bestD = pos, d end
                    end
                end
            end
        end
        if best then return best end
        -- inimigo "estacionado" no ReplicatedStorage guarda a posicao de onde nasce
        for _, e in ipairs(RS:GetChildren()) do
            if e:IsA("Model") and isMob(e.Name, mob) then
                local ok, pos = pcall(function() return e:GetPivot().Position end)
                if ok and typeof(pos) == "Vector3" and pos.Magnitude > 1 then return pos end
            end
        end
        return nil
    end

    -- ---------- arma ----------
    local function usable(tool)
        if not tool:IsA("Tool") then return false end
        if tool:FindFirstChild("EatRemote") then return false end   -- fruta de comer: clicar COME ela
        if string.find(string.lower(tool.Name), "fishing", 1, true) then return false end
        return true
    end

    local function equip()
        local char, hum = Core.char, Core.hum
        if not char or not hum then return nil end
        local want = nil
        if type(CFG.FarmWeapon) == "number" and CFG.FarmWeapon > 1 then want = WEAPONS[CFG.FarmWeapon] end
        local function fits(tool)
            return usable(tool) and (want == nil or tool.ToolTip == want)
        end
        local held = char:FindFirstChildWhichIsA("Tool")
        if held and fits(held) then return held end
        local bp = lp:FindFirstChild("Backpack")
        local pick = nil
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                if fits(tool) then
                    pick = tool
                    break
                end
            end
            if not pick and want then
                warnOnce("weapon", 60, "farm: nao achei arma do tipo " .. tostring(want) .. " - usando a primeira que servir")
                for _, tool in ipairs(bp:GetChildren()) do
                    if usable(tool) then
                        pick = tool
                        break
                    end
                end
            end
        end
        if pick then
            pcall(function() hum:EquipTool(pick) end)
            return pick
        end
        if held and usable(held) then return held end
        warnOnce("notool", 30, "farm: nenhuma arma no inventario pra equipar")
        return nil
    end

    -- ---------- metodos de ataque ----------
    local keyIdx = 0
    local function pressKey()
        if not VIM then return end
        local keys = CFG.FarmKeys
        if type(keys) ~= "string" or #keys == 0 then keys = "ZXC" end
        keyIdx = keyIdx % #keys + 1
        local letter = string.upper(string.sub(keys, keyIdx, keyIdx))
        pcall(function()
            local kc = Enum.KeyCode[letter]
            VIM:SendKeyEvent(true, kc, false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, kc, false, game)
        end)
    end

    -- ponto da tela pra "clicar" que nao cai em cima da janela do hub
    local function clickPoint()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
        local cands = {
            Vector2.new(vp.X * 0.50, vp.Y * 0.45),
            Vector2.new(vp.X * 0.68, vp.Y * 0.40),
            Vector2.new(vp.X * 0.50, vp.Y * 0.22),
            Vector2.new(vp.X * 0.32, vp.Y * 0.40),
        }
        local win = HUB._win
        for _, c in ipairs(cands) do
            local inside = false
            if win and win.Parent then
                local a, s = win.AbsolutePosition, win.AbsoluteSize
                inside = c.X >= a.X - 45 and c.X <= a.X + s.X + 45
                    and c.Y >= a.Y - 45 and c.Y <= a.Y + s.Y + 45
            end
            if not inside then return c end
        end
        return cands[1]
    end

    local function click()
        local c = clickPoint()
        if VIM then
            if UIS.TouchEnabled then
                pcall(function()
                    VIM:SendTouchEvent(7, 0, c.X, c.Y)
                    task.wait(0.03)
                    VIM:SendTouchEvent(7, 2, c.X, c.Y)
                end)
            end
            pcall(function()
                VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 1)
                task.wait(0.03)
                VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 1)
            end)
        elseif VU then
            pcall(function()
                VU:CaptureController()
                VU:ClickButton1(c)
            end)
        end
    end

    local function hitRemote(t)
        -- shape relatado: Attack(numero pequeno) / Hit(parte do alvo, {extras}).
        -- as fontes recentes dizem que sem o id da sessao o server costuma
        -- recusar; por isso ele e so UM dos metodos testados, nao o padrao.
        Net.fire(Net.R.Attack, 0.5)
        Net.fire(Net.R.Hit, t.hrp, {})
    end

    local function attack(method, t, tool)
        if method == 1 then
            hitRemote(t)
        elseif method == 2 then
            pressKey()
        elseif method == 3 then
            click()
        elseif method == 4 then
            if tool then pcall(function() tool:Activate() end) end
        else
            pressKey()
            click()
        end
    end

    -- testa cada metodo por ~2s no mob e fica com o que tirar mais vida
    local function probe(t, tool)
        local order = { 2, 3, 4, 1 }
        local results, best, bestDmg = {}, nil, 0
        local dmgOf = {}
        for _, m in ipairs(order) do
            if not (keep() and HUB.alive and Core.alive()) or hold.replan then return nil end
            if not t.model.Parent or t.hum.Health <= 0 then break end
            local hp0 = t.hum.Health
            local t0 = os.clock()
            while os.clock() - t0 < 2 and t.model.Parent and t.hum.Health > 0
                and keep() and HUB.alive and not hold.replan do
                aimAt(t)
                attack(m, t, tool)
                task.wait(math.max(0.15, CFG.AttackInterval))
            end
            local dmg = math.max(0, hp0 - t.hum.Health)
            dmgOf[m] = dmg
            table.insert(results, ATTACKS[m] .. " " .. math.floor(dmg))
            if dmg > bestDmg then best, bestDmg = m, dmg end
        end
        -- skill tem cooldown: se o clique tambem bate, usa os dois juntos
        if (dmgOf[2] or 0) > 0 and (dmgOf[3] or 0) > 0 then best = 5 end
        if #results > 0 then
            Core.log("teste de ataque: " .. table.concat(results, " | ")
                .. (best and (" -> usando " .. ATTACKS[best]) or " -> NENHUM tirou vida"))
        end
        return best
    end

    function Feat.farmReprobe()
        st.best = nil
        st.reprobeAt = 0
        Core.log("farm: vou testar os metodos de ataque de novo no proximo mob")
    end

    function Feat.farmStatus()
        return st.status
    end

    -- ---------- passo principal (cuida de UM alvo e volta) ----------
    function Feat.farmStep()
        if T.chest or Feat.boatBusy or Feat.fruitBusy then
            Feat.farmStop()
            if T.chest then warnOnce("chest", 20, "auto farm esperando: desliga o Auto Chest pra farmar") end
            if Feat.boatBusy then warnOnce("boat", 20, "auto farm esperando: barco no ar") end
            task.wait(0.5)
            return
        end
        Feat.farmBusy = true
        hold.replan = false
        local now = os.clock()
        for model, untilT in pairs(st.skip) do
            if untilT < now or not model.Parent then st.skip[model] = nil end
        end

        -- 1) qual quest / qual mob
        local q = chooseQuest()
        local mob = nil
        if type(CFG.FarmMob) == "string" and CFG.FarmMob ~= "" then
            mob = CFG.FarmMob
        elseif q then
            mob = q.mob
        end

        -- 2) quest (so com o Auto Quest ligado)
        if T.quest and q then manageQuest(q) end
        if not keep() then return end

        -- 3) alvo
        local t = pickTarget(mob)
        if not t then
            if mob then
                local pos = areaOf(mob)
                if pos then
                    st.status = "esperando " .. mob .. " nascer"
                    local spot = pos + Vector3.new(0, CFG.FarmHover + 12, 0)
                    local r = Core.root
                    if r and (r.Position - spot).Magnitude > 20 then
                        holdOn()
                        Move.noclip("farm", true)
                        holdClear()
                        if Move.goTo(function() return spot end, CFG.FarmHop, CFG.FarmFlySpeed, keep) then
                            hold.pos, hold.look = spot, nil
                        end
                    end
                else
                    st.status = "sem " .. mob .. " por aqui"
                    warnOnce("nomob", 30, "farm: nao achei '" .. mob .. "' nesse mar (nem vivo, nem ponto de spawn)")
                end
            else
                st.status = "sem mob por perto"
                warnOnce("noany", 30, "farm: nenhum mob a menos de " .. tostring(CFG.AttackRange)
                    .. " studs e nao sei tua quest - escreve o nome do mob na aba Farm")
            end
            task.wait(0.5)
            return
        end

        -- 4) chegar (perto = pulo; longe = voo com anti-puxao)
        holdOn()
        Move.noclip("farm", true)
        if t.dist > Move.hop(CFG.FarmHop) then
            st.status = "indo ate " .. t.model.Name
            holdClear()
            local arrived = Move.fly(function()
                if t.model.Parent and t.hum.Health > 0 then
                    return t.hrp.Position + Vector3.new(0, CFG.FarmHover, 3)
                end
                return nil
            end, Move.hop(CFG.FarmHop), CFG.FarmFlySpeed, keep)
            if not arrived then
                task.wait(0.1)
                return
            end
        end

        -- 5) bater ate morrer
        local tool = equip()
        local method = CFG.FarmAttack
        if type(method) ~= "number" or method < 1 or method > #ATTACKS then
            -- automatico: testa os metodos (de novo a cada 10 min, ou em 20s se nenhum funcionou)
            if st.best == nil or os.clock() > st.reprobeAt then
                st.status = "testando ataque em " .. t.model.Name
                aimAt(t)
                st.best = probe(t, tool)
                st.reprobeAt = os.clock() + (st.best and 600 or 20)
            end
            method = st.best or 5
        end
        st.status = ("batendo em %s (%s)"):format(t.model.Name, ATTACKS[method] or "?")
        local hp, lastDrop = t.hum.Health, os.clock()
        while keep() and HUB.alive and Core.alive() and t.model.Parent and t.hum.Health > 0 do
            if hold.replan then break end
            aimAt(t)
            attack(method, t, tool)
            if t.hum.Health < hp - 0.5 then
                hp = t.hum.Health
                lastDrop = os.clock()
            end
            if os.clock() - lastDrop > 8 then
                -- 8s batendo sem tirar vida: larga esse mob e re-testa o ataque
                st.skip[t.model] = os.clock() + 20
                if (type(CFG.FarmAttack) ~= "number" or CFG.FarmAttack < 1) and st.best ~= nil then
                    st.best = nil
                    st.reprobeAt = 0
                end
                warnOnce("nodmg", 10, "farm: 8s sem tirar vida de " .. t.model.Name
                    .. " - trocando de alvo e testando o ataque de novo")
                break
            end
            task.wait(CFG.AttackInterval)
        end
        if t.hum.Health <= 0 then
            HUB.stats.kills = (HUB.stats.kills or 0) + 1
        end
    end

    -- linhas pro Diagnostico
    function Feat.farmInfo()
        local out = {}
        local lvl = playerLevel()
        local sea = "mar desconhecido"
        if game.PlaceId == SEA1 then sea = "Sea 1"
        elseif game.PlaceId == SEA2 then sea = "Sea 2"
        elseif game.PlaceId == SEA3 then sea = "Sea 3" end
        table.insert(out, "level " .. tostring(lvl) .. " | " .. sea)
        if not st.db then pcall(loadDB) end
        table.insert(out, "quests: " .. tostring(st.dbSrc) .. " | NPCs: " .. (st.npcs and "sim" or "nao"))
        local q = nil
        pcall(function() q = chooseQuest() end)
        if q then
            table.insert(out, "quest do level: " .. tostring(q.id) .. " " .. tostring(q.tier)
                .. " (" .. tostring(q.mob) .. ")")
        else
            table.insert(out, "quest do level: nenhuma")
        end
        local vis, title = questState()
        local panel = "sem quest ativa"
        if vis == nil then panel = "NAO ACHADO" elseif vis then panel = "quest ativa" end
        if title ~= "" then panel = panel .. " | " .. string.sub(title, 1, 60) end
        table.insert(out, "painel da quest: " .. panel)
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local sp = wo and wo:FindFirstChild("EnemySpawns")
        table.insert(out, "EnemySpawns: " .. (sp and (#sp:GetChildren() .. " pontos") or "NAO EXISTE"))
        table.insert(out, "teclas virtuais: " .. (VIM and "sim" or "NAO") .. " | ataque escolhido: "
            .. (st.best and ATTACKS[st.best] or "ainda nao testado"))
        local tools = {}
        local function scan(c)
            if not c then return end
            for _, tool in ipairs(c:GetChildren()) do
                if tool:IsA("Tool") and #tools < 8 then
                    table.insert(tools, tool.Name .. "[" .. tostring(tool.ToolTip) .. "]")
                end
            end
        end
        scan(Core.char)
        scan(lp:FindFirstChild("Backpack"))
        table.insert(out, "armas: " .. (#tools > 0 and table.concat(tools, ", ") or "nenhuma"))
        return out
    end
end

-- ---- 5.4 auto buso (haki) ----
function Feat.busoStep()
    local c = Core.char
    if c and not c:FindFirstChild("HasBuso") then
        Net.commf("Buso")
    end
end

-- ---- 5.5 auto-stat ----
function Feat.statStep()
    for label, weight in pairs(CFG.StatPlan) do
        if weight and weight > 0 then
            local pts = math.floor(CFG.StatPerTick * weight + 0.5)
            if pts > 0 then Net.commf("AddPoint", label, pts) end
        end
    end
end

-- ---- 5.6 coletor de bau ----
-- Como funciona (tudo isso veio de log real + pesquisa):
--   - registro AO VIVO dos baus (entra quando aparece, sai quando some)
--   - pula bau desativado (ja pego, esperando renascer): tocar nele nunca paga
--   - bau perto: pulo instantaneo. bau longe: voa e so pula no final
--     (salto de ilha pra ilha num frame so o server recusa e nao paga)
--   - fica colado no bau, re-tocando, ate o Beli subir de verdade
--   - anti-puxao: se o server me tirar de cima do bau, recua em vez de brigar
--   - bau que falha repetido fica de fora cada vez mais tempo; varios
--     seguidos sem pagar = pausa de 30s
do
    local RunSvc = game:GetService("RunService")
    local live      = {}  -- [touchPart] = chestInstance
    local fails     = {}  -- [touchPart] = n
    local ignored   = {}  -- [touchPart] = os.clock() ate quando ignorar
    local strikes   = {}  -- [touchPart] = quantas vezes ja foi ignorado (ignora cada vez mais)
    local requireTI = false
    local warnedBeli = false

    local function isChestName(inst)
        for _, n in ipairs(CFG.ChestNames) do
            if inst.Name == n then return true end
        end
        return false
    end

    local function isChest(inst)
        local tagged = false
        pcall(function() tagged = CS:HasTag(inst, CFG.ChestTag) end)
        return tagged or isChestName(inst)
    end

    -- a peca que realmente recebe o toque (a que tem TouchInterest)
    local function touchPart(inst)
        if inst:IsA("BasePart") and inst:FindFirstChildWhichIsA("TouchTransmitter") then return inst end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("TouchTransmitter") and d.Parent:IsA("BasePart") then return d.Parent end
        end
        if inst:IsA("BasePart") then return inst end
        if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true) end
    end

    -- bau desativado = ja foi pego e ainda nao renasceu. o jogo NAO destroi o
    -- bau coletado, so marca o atributo; tocar nele nunca paga.
    local function isDisabled(p)
        local attr = CFG.ChestDisabledAttr
        if type(attr) ~= "string" or attr == "" then return false end
        local holder = live[p]
        local ok, v = pcall(function()
            if p:GetAttribute(attr) then return true end
            if holder ~= nil and holder ~= p and holder:GetAttribute(attr) then return true end
            return false
        end)
        return ok and v == true
    end

    local function isLive(p)
        if not p or not p.Parent or not p:IsDescendantOf(workspace) then return false end
        if not p.CanTouch then return false end
        if isDisabled(p) then return false end
        -- visivel OU tem TouchInterest (BF tem baus solidos sem TT ate encostar)
        if p.Transparency >= 0.95 and not p:FindFirstChildWhichIsA("TouchTransmitter") then return false end
        if requireTI and not p:FindFirstChildWhichIsA("TouchTransmitter") then return false end
        return true
    end

    local function register(inst)
        if not isChest(inst) then return end
        local p = touchPart(inst)
        if p then live[p] = inst end
    end

    local function unregister(inst)
        local dead = {}
        for p, c in pairs(live) do
            if p == inst or c == inst or not p:IsDescendantOf(workspace) then
                table.insert(dead, p)
            end
        end
        for _, p in ipairs(dead) do
            live[p] = nil; fails[p] = nil; ignored[p] = nil; strikes[p] = nil
        end
    end

    local function fullScan()
        table.clear(live)
        -- GC: solta referencias a baus ja destruidos (leak em sessao longa)
        for part in pairs(fails) do
            if not part:IsDescendantOf(workspace) then fails[part] = nil end
        end
        for part in pairs(ignored) do
            if not part:IsDescendantOf(workspace) then ignored[part] = nil end
        end
        for part in pairs(strikes) do
            if not part:IsDescendantOf(workspace) then strikes[part] = nil end
        end
        pcall(function()
            for _, c in ipairs(CS:GetTagged(CFG.ChestTag)) do register(c) end
        end)
        for _, d in ipairs(workspace:GetDescendants()) do
            if isChestName(d) then register(d) end
        end
        -- se nenhum bau tem TouchInterest visivel, o jogo usa outro esquema:
        -- relaxa o filtro em vez de ignorar todos
        local total, withTI = 0, 0
        for p in pairs(live) do
            total += 1
            if p:FindFirstChildWhichIsA("TouchTransmitter") then withTI += 1 end
        end
        -- so aperta o filtro se TODO bau tiver TouchInterest (nao e o caso do BF)
        requireTI = (total > 0 and withTI == total)
        return total
    end

    -- sinais: bau que spawna/carrega entra na hora, bau que some sai na hora
    pcall(function()
        CS:GetInstanceAddedSignal(CFG.ChestTag):Connect(function(i) task.delay(0.2, register, i) end)
        CS:GetInstanceRemovedSignal(CFG.ChestTag):Connect(unregister)
    end)
    workspace.DescendantAdded:Connect(function(d)
        if isChestName(d) then task.delay(0.2, register, d) end
    end)
    workspace.DescendantRemoving:Connect(function(d)
        if live[d] or isChestName(d) then unregister(d) end
    end)
    task.spawn(function()
        while HUB.alive do
            task.wait(45)
            if T.chest then fullScan() end
        end
    end)

    -- acha o valor de dinheiro sozinho: tenta Data.Beli, senao procura
    -- qualquer Int/NumberValue com "beli"/"money"/"cash" no nome dentro
    -- do player. cacheia quando acha.
    local beliObj
    local beliSearchAt = -math.huge
    local function beli()
        if beliObj and beliObj.Parent then return beliObj.Value end
        if beliObj then
            beliObj = nil
            beliSearchAt = -math.huge   -- cache morreu: re-busca JA (senao perde o pagamento)
        end
        if os.clock() - beliSearchAt < 2 then return nil end
        beliSearchAt = os.clock()
        local data = lp:FindFirstChild("Data")
        local b = data and data:FindFirstChild("Beli")
        if not b then
            for _, d in ipairs(lp:GetDescendants()) do
                if (d:IsA("IntValue") or d:IsA("NumberValue")) then
                    local n = d.Name:lower()
                    if n:find("beli") or n == "money" or n == "cash" then b = d break end
                end
            end
        end
        if b and (b:IsA("IntValue") or b:IsA("NumberValue")) then
            beliObj = b
            Core.log("moeda encontrada: " .. b:GetFullName())
            return b.Value
        end
        if not warnedBeli then
            warnedBeli = true
            Core.log("sem valor de moeda achavel - confirmando pelo bau sumir (menos preciso)")
        end
        return nil
    end

    local function nextChest()
        local r = Core.root
        if not r then return end
        local now, best, bestD = os.clock(), nil, math.huge
        for p in pairs(live) do
            if (not ignored[p] or ignored[p] < now) and isLive(p) then
                local d = (p.Position - r.Position).Magnitude
                if d < bestD then best, bestD = p, d end
            end
        end
        return best, bestD
    end

    -- noclip enquanto o coletor estiver coletando (teleporte por CFrame nao
    -- precisa de colisao; evita travar em hitbox no caminho).
    -- nota: o Humanoid re-liga CanCollide do CORPO todo frame (por isso
    -- noclip e um loop) - ao desligar, o motor restaura o corpo sozinho.
    -- originalCollide cobre o que o Humanoid NAO gerencia (ex: Handle de
    -- tool), e o guard de HUB.alive mata loop orfao em re-execucao.
    local noclipConn
    local originalCollide = {}
    local function noclipOff()
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        for part in pairs(originalCollide) do
            if part and part.Parent then pcall(function() part.CanCollide = true end) end
        end
        table.clear(originalCollide)
    end
    local function setNoclip(on)
        if on and CFG.ChestNoclip and not noclipConn then
            noclipConn = RunSvc.Stepped:Connect(function()
                if not HUB.alive then noclipOff(); return end
                local c = Core.char
                if not c then return end
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        if originalCollide[v] == nil then originalCollide[v] = true end
                        v.CanCollide = false
                    end
                end
            end)
        elseif not on and noclipConn then
            noclipOff()
        end
    end

    -- TP INSTANTANEO: pula direto em cima do bau (um frame). sem tween.
    local function tpTo(p)
        local r = Core.root
        if not r or not isLive(p) then return false end
        r.AssemblyLinearVelocity = Vector3.zero
        r.CFrame = p.CFrame
        return true
    end

    -- VOO pra bau longe (usa o Move: teto de velocidade + anti-puxao).
    -- Voa ate faltar o "TP final" e o resto do caminho e pulo instantaneo.
    local function flyTo(p)
        if not Core.root or not isLive(p) then return false end
        local arrived = Move.fly(
            function()
                if isLive(p) then return p.Position end
                return nil
            end,
            Move.hop(CFG.ChestFarDist), CFG.ChestFlySpeed,
            function() return T.chest and not Feat.fruitBusy end,
            CFG.ChestFlyUp)
        if not arrived then return false end
        return tpTo(p)
    end

    -- Fica colado no bau ate o server pagar (Beli sobe) ou estourar maxWait.
    --  - preTouch: tempo parado ANTES do primeiro toque (o server precisa me
    --    ver ali antes; toque cedo demais se perde)
    --  - re-toca a cada ChestRetouch (um toque so nao da segunda chance)
    --  - devolve tambem o quanto o server me puxou (rubberband) durante a espera
    local function holdUntilPaid(p, before, maxWait, preTouch)
        local t0 = os.clock()
        local touching, lastTouch = false, -math.huge
        local paid, maxDev = false, 0
        local function touch(state)
            if firetouchinterest then
                pcall(function() firetouchinterest(Core.root, p, state) end)
            end
        end
        while os.clock() - t0 < maxWait do
            if not HUB.alive then break end   -- re-execucao: instancia velha solta o char
            local r = Core.root
            if not r or not T.chest then break end
            local el = os.clock() - t0
            -- 1) ja pagou? (confere antes de qualquer outra coisa)
            local now = beli()
            if before and now and now > before then paid = true end
            if not before and not isLive(p) then paid = true end
            -- so sai depois do delayzin minimo, pra garantir que replicou
            if paid and el >= CFG.ChestHold then break end
            -- 2) posicao
            if p.Parent then
                if not paid then
                    local dev = (r.Position - p.Position).Magnitude
                    if dev > maxDev then maxDev = dev end
                    -- ANTI-PUXAO: o server me tirou de cima do bau. nao brigo: saio
                    -- do laco e o coletor recua (pulo menor, voo mais lento)
                    if dev > 15 and el > 0.1 then break end
                end
                r.AssemblyLinearVelocity = Vector3.zero
                r.CFrame = p.CFrame          -- cola em cima (o delayzin)
            end
            -- 3) toque (e re-toque)
            if not paid and el >= preTouch and os.clock() - lastTouch >= CFG.ChestRetouch then
                if touching then touch(1) end
                touch(0)
                touching = true
                lastTouch = os.clock()
            end
            RunSvc.Heartbeat:Wait()
        end
        if touching then touch(1) end
        if not paid then
            local now = beli()
            if before and now and now > before then paid = true end
        end
        if paid then maxDev = 0 end
        return paid, os.clock() - t0, maxDev
    end

    -- TP pra regiao do bau e espera ela CARREGAR (renderizar) antes de tocar.
    -- pede o stream de forma SINCRONA (espera retornar) e confirma que o chao
    -- sob o bau existe de verdade. teto de tempo pra nao travar.
    local function streamWait(p)
        local pos = p.Position
        -- 1) fica em cima pra virar o centro do streaming, pedindo a area
        local ok = false
        local t0 = os.clock()
        -- RequestStreamAroundAsync YIELDA ate a area em volta carregar (com timeout)
        pcall(function() lp:RequestStreamAroundAsync(pos, CFG.ChestStreamWait) end)
        -- 2) confirma: a parte do bau precisa existir E ter chao embaixo
        while os.clock() - t0 < CFG.ChestStreamWait do
            if not HUB.alive then return false end   -- re-execucao: para de puxar o char
            if not T.chest or not Core.alive() then return false end
            local r = Core.root
            if r then r.CFrame = p.Parent and p.CFrame or CFrame.new(pos) end
            local loaded = p.Parent ~= nil and p:IsDescendantOf(workspace)
            if loaded then
                -- raycast curto pra baixo: se bateu em algo, o terreno carregou
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                -- exclui o proprio bau: senao o ray bate NELE e da falso "carregou"
                local filt = { p }
                if Core.char then table.insert(filt, Core.char) end
                rp.FilterDescendantsInstances = filt
                local hit = workspace:Raycast(pos + Vector3.new(0,6,0), Vector3.new(0,-40,0), rp)
                if hit then ok = true; break end
            end
            task.wait(0.05)
        end
        if ok and CFG.ChestSettle > 0 then task.wait(CFG.ChestSettle) end
        if not ok then Core.log("area nao renderizou a tempo - pulando bau") end
        return ok
    end

    function Feat.chestStop()
        Feat.chestBusy = false
        setNoclip(false)
    end

    -- resumo curto do bau pro log de falha (nome, pasta e atributos)
    local function describe(p)
        local bits = {}
        pcall(function()
            table.insert(bits, p.Name .. "@" .. (p.Parent and p.Parent.Name or "?"))
            local n = 0
            local function addAttrs(inst)
                for k, v in pairs(inst:GetAttributes()) do
                    n += 1
                    if n <= 6 then table.insert(bits, tostring(k) .. "=" .. tostring(v)) end
                end
            end
            addAttrs(p)
            local holder = live[p]
            if holder and holder ~= p then addAttrs(holder) end
            if n == 0 then table.insert(bits, "sem atributos") end
        end)
        return table.concat(bits, " ")
    end

    local failStreak, pauseUntil = 0, 0

    function Feat.chestStep()
        if os.clock() < pauseUntil then
            setNoclip(false)
            task.wait(0.5)
            return
        end
        if next(live) == nil and fullScan() == 0 then
            task.wait(3)
            return
        end
        local p, jump = nextChest()
        if not p then task.wait(1); return end
        jump = jump or 0

        Feat.chestBusy = true
        setNoclip(true)
        local before = beli()
        local hopMax = Move.hop(CFG.ChestFarDist)   -- encolhe sozinho depois de um puxao
        local far = jump > hopMax
        -- tamanho do pulo instantaneo que o server vai julgar
        local hop = (far and CFG.ChestFarMode == 2) and math.min(jump, hopMax) or jump

        -- 1) chegar. perto: TP instantaneo. longe: voo (ou TP, se voce trocar na aba Tune)
        local arrived
        if far and CFG.ChestFarMode == 2 then
            arrived = flyTo(p)
        else
            arrived = tpTo(p)
        end
        if arrived and workspace.StreamingEnabled then
            arrived = streamWait(p)
        end

        -- 2) colar no bau e esperar o server pagar
        local collected = false
        local target = p   -- se assumir o "fresh" e falhar, a falha conta nele
        local took, dev = 0, 0
        if arrived and isLive(p) then
            local fresh = nextChest()
            if fresh and (fresh.Position - p.Position).Magnitude < 8 then target = fresh end
            if tpTo(target) then
                local paid
                paid, took, dev = holdUntilPaid(target, before,
                    far and CFG.ChestFarWait or CFG.ChestMaxWait,
                    far and CFG.ChestPreTouch or 0)
                if paid then
                    collected = true
                    failStreak = 0
                    local nowBeli = beli()
                    local gain = (before and nowBeli) and (nowBeli - before) or 0
                    HUB.stats.chests += 1
                    HUB.stats.beli += gain
                    fails[target] = nil
                    strikes[target] = nil
                    if before then
                        Core.log(("bau ok +%d beli (%.2fs, viagem %d, tp %d) | total %d baus, %d beli")
                            :format(math.floor(gain), took, math.floor(jump), math.floor(hop),
                                    HUB.stats.chests, math.floor(HUB.stats.beli)))
                    else
                        Core.log(("bau ok (%.2fs, sem leitor de moeda) | total %d baus")
                            :format(took, HUB.stats.chests))
                    end
                end
            end
        end

        -- 3) nao pagou
        if not collected and T.chest and HUB.alive then
            if dev > 15 then Move.pulled("bau", dev) end
            if took > 0 or isLive(target) then
                HUB.stats.fails += 1
                failStreak += 1
                fails[target] = (fails[target] or 0) + 1
                Core.log(("bau nao contou (%dx) viagem %d tp %d | esperei %.1fs | puxado %d | %s")
                    :format(fails[target], math.floor(jump), math.floor(hop), took,
                            math.floor(dev), describe(target)))
                if fails[target] >= CFG.ChestMaxFails then
                    strikes[target] = (strikes[target] or 0) + 1
                    -- cada vez que o mesmo bau falha de novo, fica mais tempo de fora
                    local t = math.min(CFG.ChestIgnoreTime * 4 ^ (strikes[target] - 1), 900)
                    ignored[target] = os.clock() + t
                    fails[target] = nil
                    Core.log("ignorando esse bau por " .. math.floor(t) .. "s")
                end
            else
                Core.log("bau sumiu antes de eu chegar (alguem pegou) - proximo")
            end
            -- insistir em toque que o server recusa e o que acumula pro Security Kick
            if failStreak >= CFG.ChestFailPause then
                failStreak = 0
                pauseUntil = os.clock() + 30
                Core.log(CFG.ChestFailPause .. " baus seguidos sem pagar - pausa de 30s (me manda esse log)")
            end
        end
        Feat.chestBusy = false
    end

    -- numeros pro diagnostico: achados, vivos, com TouchInterest, por tag, moeda
    function Feat.chestInfo()
        fullScan()
        local total, alive, withTI, off = 0, 0, 0, 0
        for part in pairs(live) do
            total += 1
            if part:FindFirstChildWhichIsA("TouchTransmitter") then withTI += 1 end
            if isLive(part) then alive += 1 end
            if isDisabled(part) then off += 1 end
        end
        local tagged = 0
        pcall(function() tagged = #CS:GetTagged(CFG.ChestTag) end)
        beli()
        return total, alive, withTI, tagged, (beliObj and beliObj:GetFullName() or nil), off
    end

    fullScan()
end

-- ---- 5.8 barco: levantar + velocidade + auto leviathan ----
-- Nao existe remote de "voar barco": o que move o barco e fisica no cliente
-- (quem ta sentado no assento tem o controle de rede do barco, entao o que
-- o cliente faz nele replica). Tres metodos de voo pra testar qual segura:
--   1 cframe   : posiciona o barco todo frame (mais firme, mais "teleporte")
--   2 velocity : so controla a velocidade (mais suave, cede um pouco)
--   3 body     : BodyVelocity dentro do barco (o motor de fisica segura)
-- Subida e descida sao SUAVES (BoatRiseSpeed) - nada de TP vertical.
do
    local RunSvc  = game:GetService("RunService")
    local METHODS = { "cframe", "velocity", "body" }
    local SPEEDS  = { "maxspeed", "empurrao" }
    Feat.boatMethods  = METHODS
    Feat.speedMethods = SPEEDS
    Feat.leviDirs     = { "frente do barco", "longe das ilhas" }

    -- o perigo do mar cresce com a DISTANCIA das ilhas (nao existe um lado
    -- fixo): acha o centro das ilhas e aponta pro lado oposto.
    local function awayFromIslands(pos)
        local map = workspace:FindFirstChild("Map")
        if not map then return nil end
        local sum, n = Vector3.zero, 0
        for _, isl in ipairs(map:GetChildren()) do
            local ok, piv = pcall(function() return isl:GetPivot().Position end)
            if ok and piv then sum += piv; n += 1 end
        end
        if n == 0 then return nil end
        local c = sum / n
        local d = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
        if d.Magnitude < 50 then return nil end
        return d.Unit
    end

    local boat, boatRoot
    local flyConn, bv
    local active, landing, baseY = false, false, nil
    local lastWarn, errUntil = 0, 0
    local leviOn = false
    local levi = { state = "off" }

    -- acha o barco pelo assento em que o personagem ta sentado (nao depende
    -- do nome do barco). guarda a referencia pra continuar valendo depois.
    local function findBoat()
        local hum = Core.hum
        local seat = hum and hum.SeatPart
        if seat and seat.Parent then
            local m = seat:FindFirstAncestorWhichIsA("Model")
            local folder = workspace:FindFirstChild(CFG.BoatFolder)
            if folder and seat:IsDescendantOf(folder) then
                local cur = seat
                while cur.Parent and cur.Parent ~= folder do cur = cur.Parent end
                if cur:IsA("Model") then m = cur end
            end
            if m then
                boat = m
                boatRoot = seat.AssemblyRootPart or m.PrimaryPart or seat
            end
        end
        if boat and boat.Parent and boatRoot and boatRoot.Parent then return boat, boatRoot end
        boat, boatRoot = nil, nil
    end

    local function release()
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        if bv then pcall(function() bv:Destroy() end); bv = nil end
        active, landing = false, false
        Feat.boatBusy = false
    end

    local function step(dt)
        local _, root = findBoat()
        if not root then
            release()
            Core.log("barco: perdi o barco (destruido ou longe demais)")
            return
        end
        local pos = root.Position

        -- altura alvo: pousando volta pra onde ligou
        local goalY = baseY
        if not landing then
            goalY = baseY + (T.levi and CFG.LeviHeight or CFG.BoatLift)
        end
        local dy = goalY - pos.Y
        if landing and math.abs(dy) < 3 then
            release()
            Core.log("barco: de volta na agua")
            return
        end

        -- velocidade horizontal: so o auto levi dirige. no "levantar" voce pilota.
        local driving = T.levi and not landing
        local hv = Vector3.zero
        -- ANTI-PUXAO do barco: se ele "pulou" bem mais do que eu mandei andar,
        -- foi o server corrigindo. para 2s e segue mais devagar.
        if driving and levi.lastPos then
            local jumped = Vector3.new(pos.X - levi.lastPos.X, 0, pos.Z - levi.lastPos.Z).Magnitude
            if jumped > math.max(30, CFG.LeviSpeed * dt * 4) then
                Move.pulled("barco", jumped)
                levi.pause = os.clock() + 2
            end
        end
        levi.lastPos = pos
        if driving and levi.state == "cruise" and levi.dir and os.clock() >= (levi.pause or 0) then
            hv = levi.dir * (CFG.LeviSpeed * Move.scale)   -- mais devagar depois de puxao
            local flat = Vector3.new(pos.X - levi.legStart.X, 0, pos.Z - levi.legStart.Z).Magnitude
            local limit = (levi.phase == "out") and CFG.LeviOutDist or CFG.LeviLeg
            if flat >= limit then
                -- vira 90 graus pra direita: depois da ida, patrulha em quadrado
                levi.phase = "patrol"
                levi.legStart = pos
                levi.dir = Vector3.new(-levi.dir.Z, 0, levi.dir.X)
            end
        end

        local rise = CFG.BoatRiseSpeed
        local vy = math.clamp(dy * 3, -rise, rise)
        local cur = root.AssemblyLinearVelocity
        local method = CFG.BoatMethod

        if method ~= 3 and bv then pcall(function() bv:Destroy() end); bv = nil end

        if method == 1 then
            local newY = pos.Y + math.clamp(dy, -rise * dt, rise * dt)
            local p
            if driving then
                p = Vector3.new(pos.X + hv.X * dt, newY, pos.Z + hv.Z * dt)
                root.AssemblyLinearVelocity = hv
            else
                p = Vector3.new(pos.X, newY, pos.Z)
                root.AssemblyLinearVelocity = Vector3.new(cur.X, 0, cur.Z)
            end
            -- mantem a rotacao que o barco ja tem (so troca a posicao)
            root.CFrame = CFrame.new(p) * root.CFrame.Rotation
        elseif method == 2 then
            if driving then
                root.AssemblyLinearVelocity = Vector3.new(hv.X, vy, hv.Z)
            else
                root.AssemblyLinearVelocity = Vector3.new(cur.X, vy, cur.Z)
            end
        else
            if not bv or bv.Parent ~= root then
                if bv then pcall(function() bv:Destroy() end) end
                bv = Instance.new("BodyVelocity")
                bv.Name = "HubLift"
                bv.P = 9000
                bv.Parent = root
            end
            bv.MaxForce = driving and Vector3.new(math.huge, math.huge, math.huge)
                                   or Vector3.new(0, math.huge, 0)
            bv.Velocity = Vector3.new(hv.X, vy, hv.Z)
        end
        if driving then root.AssemblyAngularVelocity = Vector3.zero end
    end

    local function start()
        if os.clock() < errUntil then return end
        local _, root = findBoat()
        if not root then
            if os.clock() - lastWarn > 5 then
                lastWarn = os.clock()
                Core.log("barco: senta no assento do barco primeiro")
            end
            return
        end
        baseY = root.Position.Y
        active, landing = true, false
        Feat.boatBusy = true
        flyConn = RunSvc.Heartbeat:Connect(function(dt)
            if not HUB.alive then release(); return end
            local ok, err = pcall(step, dt)
            if not ok then
                release()
                errUntil = os.clock() + 5
                Core.log("barco erro: " .. tostring(err))
            end
        end)
        Core.log("barco subindo (metodo " .. (METHODS[CFG.BoatMethod] or "?") .. ")")
    end

    -- ---------- velocidade do barco ----------
    -- maxspeed : muda o MaxSpeed do assento (o proprio jogo acelera ate ele).
    --            e o jeito "limpo"; so funciona se o barco usar VehicleSeat.
    -- empurrao : quando voce acelera, joga a velocidade direto no barco.
    --            funciona em qualquer barco, mas e mais facil o server notar.
    local spSeat, spOrig, speedConn
    local function speedRestore()
        if spSeat and spSeat.Parent and spOrig then
            pcall(function() spSeat.MaxSpeed = spOrig end)
        end
        spSeat, spOrig = nil, nil
    end
    local function speedPushOff()
        if speedConn then speedConn:Disconnect(); speedConn = nil end
    end
    local function speedPush()
        if not HUB.alive then speedPushOff(); return end
        if T.levi then return end                 -- no auto levi quem dirige e o hub
        local hum = Core.hum
        local seat = hum and hum.SeatPart
        if not (seat and seat.Parent) then return end
        local dir
        if seat:IsA("VehicleSeat") then
            local th = seat.ThrottleFloat
            if th == 0 then th = seat.Throttle end
            if math.abs(th) < 0.05 then return end
            local look = seat.CFrame.LookVector
            dir = Vector3.new(look.X, 0, look.Z) * th
        else
            local mv = hum.MoveDirection            -- assento comum: usa o analogico
            dir = Vector3.new(mv.X, 0, mv.Z)
        end
        if dir.Magnitude < 0.1 then return end
        dir = dir.Unit * CFG.BoatSpeed
        local root = seat.AssemblyRootPart or seat
        local cur = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(dir.X, cur.Y, dir.Z)
    end
    local function speedTick()
        local seat = Core.hum and Core.hum.SeatPart
        local wantMax  = T.speed and CFG.SpeedMethod == 1
        local wantPush = T.speed and CFG.SpeedMethod == 2
        if wantMax and seat and seat.Parent and seat:IsA("VehicleSeat") then
            if spSeat ~= seat then
                speedRestore()
                spSeat, spOrig = seat, seat.MaxSpeed
                Core.log("boat speed: MaxSpeed " .. tostring(spOrig) .. " -> " .. tostring(CFG.BoatSpeed))
            end
            if seat.MaxSpeed ~= CFG.BoatSpeed then seat.MaxSpeed = CFG.BoatSpeed end
        elseif spSeat then
            speedRestore()
        end
        if wantPush and not speedConn then
            speedConn = RunSvc.Heartbeat:Connect(function() pcall(speedPush) end)
        elseif not wantPush and speedConn then
            speedPushOff()
        end
    end

    -- procura o sinal de que o Leviathan/dimensao apareceu (busca barata:
    -- so filhos diretos de poucas pastas, 1x a cada 1.5s)
    local function leviSign()
        for _, path in ipairs(CFG.LeviContainers) do
            local node = workspace
            for seg in string.gmatch(path, "[^/]+") do
                node = node and node:FindFirstChild(seg)
            end
            if node then
                for _, name in ipairs(CFG.LeviSigns) do
                    local hit = node:FindFirstChild(name)
                    if hit then return hit end
                end
            end
        end
    end

    local function notify(title, text)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification",
                { Title = title, Text = text, Duration = 10 })
        end)
    end

    function Feat.boatStatus()
        if not active then return "na agua" end
        if landing then return "descendo" end
        if T.levi then return "auto levi: " .. tostring(levi.state) .. " / " .. tostring(levi.phase or "-") end
        return "levantado"
    end

    -- gerente: liga/desliga o voo conforme os toggles e cuida do estado do levi
    task.spawn(function()
        local lastCheck = 0
        while HUB.alive do
            local want = T.lift or T.levi
            if want and not active then
                start()
            elseif want and landing then
                landing = false            -- religou no meio da descida
            elseif not want and active and not landing then
                landing = true
                Core.log("barco: descendo devagar")
            end

            if T.levi and active and not leviOn and boatRoot then
                leviOn = true
                local d, how
                if CFG.LeviDirMode == 2 then
                    d = awayFromIslands(boatRoot.Position)
                    how = "pra longe das ilhas"
                end
                if not d then
                    local seat = Core.hum and Core.hum.SeatPart
                    local look = ((seat and seat.Parent) and seat or boatRoot).CFrame.LookVector
                    d = Vector3.new(look.X, 0, look.Z)
                    d = (d.Magnitude > 0.1) and d.Unit or Vector3.new(0, 0, -1)
                    how = "na direcao do barco"
                end
                levi = { state = "cruise", phase = "out", dir = d, legStart = boatRoot.Position }
                Core.log("auto levi: cruzando " .. how)
                task.spawn(function() pcall(Feat.leviSpy) end)   -- so consulta, nao gasta nada
            elseif not T.levi and leviOn then
                leviOn = false
                levi = { state = "off" }
            end

            if leviOn and levi.state == "cruise" and os.clock() - lastCheck > 1.5 then
                lastCheck = os.clock()
                local ok, hit = pcall(leviSign)
                if ok and hit then
                    levi.state = "found"   -- para de andar, continua flutuando
                    Core.log("auto levi: ACHOU -> " .. hit:GetFullName())
                    notify("BF HUB", "Leviathan / dimensao apareceu: " .. hit.Name)
                end
            end

            pcall(speedTick)
            task.wait(0.2)
        end
        release()
        speedRestore()
        speedPushOff()
    end)

    -- remote REAL do espiao: "1" so CONSULTA (nao gasta fragmento). Respostas
    -- relatadas por varias fontes da comunidade: 5 = o Leviathan ta la fora,
    -- -1 = cooldown, outro numero = da pra subornar. O suborno ("2", 1500
    -- fragmentos) fica de fora de proposito: o hub nao gasta teu recurso sozinho.
    function Feat.leviSpy()
        local ok, res = Net.commf("InfoLeviathan", "1")
        local meaning = "resposta desconhecida"
        if not ok then
            meaning = "remote falhou"
        elseif res == 5 then
            meaning = "o Leviathan TA LA FORA - vai pro mar 6"
        elseif res == -1 then
            meaning = "espiao em cooldown (nao sabe de nada ainda)"
        elseif type(res) == "number" then
            meaning = "ainda nao apareceu - suborna o espiao no Tiki Outpost (1500 fragmentos cada)"
        end
        Core.log("spy: " .. meaning .. " [" .. tostring(res) .. "]")
        return res
    end
end

-- ---- 5.10 frutas no mapa: avisar / pegar / guardar ----
do
    local seen  = setmetatable({}, { __mode = "k" })   -- frutas que ja avisei
    local tries = setmetatable({}, { __mode = "k" })   -- tentativas de pegar

    local function isFruit(inst)
        if not inst:IsA("Tool") then return false end
        if inst:FindFirstChild("EatRemote") then return true end
        return string.find(string.lower(inst.Name), "fruit", 1, true) ~= nil
    end

    local function fruitName(tool)
        local n = nil
        pcall(function() n = tool:GetAttribute("OriginalName") end)
        if type(n) ~= "string" then
            local v = tool:FindFirstChild("OriginalName")
            if v and v:IsA("StringValue") then n = v.Value end
        end
        if type(n) == "string" and n ~= "" then return n end
        return tool.Name
    end

    -- fruta largada por outro jogador: por padrao nao pego
    local function wasDropped(tool)
        local d = false
        pcall(function()
            d = tool:GetAttribute("DroppedBy") ~= nil or tool:FindFirstChild("DroppedBy") ~= nil
        end)
        return d
    end

    local function mine(tool)
        if tool.Parent == nil or tool.Parent == workspace then return false end
        if tool:IsDescendantOf(lp) then return true end
        return Core.char ~= nil and tool:IsDescendantOf(Core.char)
    end

    local function grab(tool, handle)
        Feat.fruitBusy = true
        -- espera o farm / bau soltarem o personagem (eles checam fruitBusy)
        local t0 = os.clock()
        while (Feat.chestBusy or Feat.farmBusy) and os.clock() - t0 < 8 do
            task.wait(0.2)
        end
        if not (Core.alive() and tool.Parent == workspace and handle.Parent) then return false end
        Move.noclip("fruit", true)
        local function keepFn()
            return HUB.alive and T.fruitGrab and tool.Parent == workspace
        end
        local function goal()
            if handle.Parent then return handle.Position end
            return nil
        end
        if not Move.goTo(goal, 120, CFG.ChestFlySpeed, keepFn) then return false end
        local t1 = os.clock()
        while os.clock() - t1 < 2.5 and tool.Parent == workspace and HUB.alive do
            local r = Core.root
            if r and handle.Parent then
                r.AssemblyLinearVelocity = Vector3.zero
                r.CFrame = CFrame.new(handle.Position)
                if firetouchinterest then
                    pcall(function()
                        firetouchinterest(r, handle, 0)
                        firetouchinterest(r, handle, 1)
                    end)
                end
            end
            task.wait(0.15)
        end
        if not mine(tool) then return false end
        local name = fruitName(tool)
        Core.log("fruta pega: " .. name)
        Feat.notify("BF HUB", "Peguei: " .. name)
        if T.fruitStore then
            pcall(function()
                if Core.hum then Core.hum:UnequipTools() end
            end)
            task.wait(0.3)
            -- shape relatado (varia entre fontes): StoreFruit, nome interno, a Tool
            local okS, res = Net.commf("StoreFruit", name, tool)
            Core.log("guardar fruta -> " .. (okS and Core.fmt(res) or "remote falhou"))
        end
        return true
    end

    task.spawn(function()
        while HUB.alive do
            task.wait(3)
            if (T.fruit or T.fruitGrab) and Core.alive() then
                local r = Core.root
                for _, c in ipairs(workspace:GetChildren()) do
                    if isFruit(c) then
                        local h = c:FindFirstChild("Handle")
                        if h and h:IsA("BasePart") then
                            local dropped = wasDropped(c)
                            if not seen[c] then
                                seen[c] = true
                                local d = r and math.floor((h.Position - r.Position).Magnitude) or 0
                                local msg = "FRUTA no mapa: " .. fruitName(c) .. " (" .. d .. " studs)"
                                    .. (dropped and " [largada por jogador]" or "")
                                Core.log(msg)
                                Feat.notify("BF HUB", msg)
                            end
                            if T.fruitGrab and not dropped and not Feat.boatBusy
                                and (tries[c] or 0) < 3 and c.Parent == workspace then
                                tries[c] = (tries[c] or 0) + 1
                                local okG, res = pcall(grab, c, h)
                                Feat.fruitBusy = false
                                Move.noclip("fruit", false)
                                if not okG then
                                    Core.log("erro pegando fruta: " .. tostring(res))
                                elseif not res then
                                    Core.log("nao consegui pegar a fruta (tentativa " .. tries[c] .. "/3)")
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ---- 5.11 avisos: ilhas/eventos e lua cheia ----
do
    local was = {}
    local moonWas = false
    task.spawn(function()
        while HUB.alive do
            task.wait(5)
            if T.watch then
                local map = workspace:FindFirstChild("Map")
                if map and type(CFG.WatchNames) == "table" then
                    for _, name in ipairs(CFG.WatchNames) do
                        local here = map:FindFirstChild(name) ~= nil
                        if here and not was[name] then
                            Core.log("EVENTO: " .. tostring(name) .. " apareceu no mapa")
                            Feat.notify("BF HUB", tostring(name) .. " apareceu!")
                        end
                        was[name] = here
                    end
                end
                local full = false
                pcall(function()
                    local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
                    if sky then
                        full = string.find(sky.MoonTextureId, "9709149431", 1, true) ~= nil
                    end
                end)
                if full and not moonWas then
                    Core.log("EVENTO: lua cheia")
                    Feat.notify("BF HUB", "Lua cheia!")
                end
                moonWas = full
            end
        end
    end)
end

-- ---- 5.12 desempenho: fps boost e tela branca ----
do
    local RunSvc = game:GetService("RunService")
    local whiteOn = false

    function Feat.fpsBoost()
        local Lighting = game:GetService("Lighting")
        local n = 0
        pcall(function() Lighting.GlobalShadows = false end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then
                pcall(function() e.Enabled = false end)
                n += 1
            end
        end
        local all = workspace:GetDescendants()
        for i, d in ipairs(all) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                pcall(function() d.Enabled = false end)
                n += 1
            end
            if i % 3000 == 0 then task.wait() end
        end
        Core.log("fps boost: " .. n .. " efeitos desligados (pra voltar ao normal, reentra no jogo)")
    end

    -- tela branca: desliga o desenho 3D (o hub continua aparecendo). bom pra AFK.
    task.spawn(function()
        while HUB.alive do
            local want = T.white and true or false
            if want ~= whiteOn then
                whiteOn = want
                pcall(function() RunSvc:Set3dRenderingEnabled(not whiteOn) end)
                Core.log(whiteOn and "tela branca LIGADA (economia de bateria)" or "tela normal de volta")
            end
            task.wait(0.5)
        end
        if whiteOn then
            pcall(function() RunSvc:Set3dRenderingEnabled(true) end)
        end
    end)
end

-- ---- 5.13 consultas rapidas por remote (so leem / so agem quando VOCE aperta) ----
function Feat.eliteCheck()
    local ok, res = Net.commf("EliteHunter")
    Core.log("elite hunter -> " .. (ok and Core.fmt(res) or "remote falhou"))
end

function Feat.gachaCheck()
    local ok, res = Net.commf("Cousin", "Check")
    Core.log("gacha (checar) -> " .. (ok and Core.fmt(res) or "remote falhou"))
end

function Feat.gachaBuy()
    local ok, res = Net.commf("Cousin", "Buy")
    Core.log("gacha (comprar) -> " .. (ok and Core.fmt(res) or "remote falhou"))
end

-- ---- 5.9 diagnostico: joga no Log tudo que o hub precisa saber do jogo ----
-- Um toque e eu paro de chutar nome de pasta/remote: manda o resultado no chat.
function Feat.diagnose()
    local L = Core.log
    local function yn(v) return v and "sim" or "NAO" end
    local function fn(name, f) return name .. ":" .. yn(type(f) == "function") end

    L("==== DIAGNOSTICO ====")
    local exec = "?"
    pcall(function() if identifyexecutor then exec = tostring((identifyexecutor())) end end)
    L("exec " .. exec .. " | place " .. tostring(game.PlaceId) .. " v" .. tostring(game.PlaceVersion))
    L(table.concat({
        fn("touch", firetouchinterest), fn("hook", hookmetamethod),
        fn("file", writefile), fn("hui", gethui), fn("clip", setclipboard or toclipboard),
    }, " "))

    Net.resolve()
    L("remotes CommF:" .. yn(Net.R.CommF) .. " Attack:" .. yn(Net.R.Attack)
        .. " Hit:" .. yn(Net.R.Hit) .. " Browser:" .. yn(Net.R.Browser))

    if Feat.farmInfo then
        local okF, lines = pcall(Feat.farmInfo)
        if okF and type(lines) == "table" then
            for _, ln in ipairs(lines) do L(ln) end
        else
            L("farm info: erro -> " .. tostring(lines))
        end
    end
    L(("anti-puxao: %d puxoes | velocidade %d%% | pulo %d%%"):format(
        Move.pulls, math.floor(Move.scale * 100), math.floor(Move.hopScale * 100)))
    local loose = 0
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Tool") then loose += 1 end
    end
    L("tools soltas no workspace (frutas): " .. loose)

    if Feat.chestInfo then
        local ok, total, alive, withTI, tagged, coin, off = pcall(Feat.chestInfo)
        if ok then
            L(("baus: %d achados, %d vivos, %d desativados, %d por tag"):format(total, alive, off or 0, tagged))
            L("moeda: " .. (coin or "NAO ACHADA"))
        else
            L("baus: erro -> " .. tostring(total))
        end
    end
    L("streaming: " .. tostring(workspace.StreamingEnabled))

    for _, name in ipairs(CFG.EnemyFolders) do
        local f = workspace:FindFirstChild(name)
        L("pasta mobs '" .. name .. "': " .. (f and (#f:GetChildren() .. " filhos") or "NAO EXISTE"))
    end
    local cands = {}
    for _, c in ipairs(workspace:GetChildren()) do
        if #cands >= 6 then break end
        if c:IsA("Folder") or c:IsA("Model") then
            local n = 0
            for i, m in ipairs(c:GetChildren()) do
                if i > 40 then break end
                if m:IsA("Model") and m:FindFirstChildWhichIsA("Humanoid") then n += 1 end
            end
            if n > 0 then table.insert(cands, c.Name .. "(" .. n .. ")") end
        end
    end
    L("pastas com mobs/npcs: " .. (#cands > 0 and table.concat(cands, ", ") or "nenhuma"))

    local bf = workspace:FindFirstChild(CFG.BoatFolder)
    L("pasta barcos '" .. CFG.BoatFolder .. "': " .. (bf and (#bf:GetChildren() .. " barcos") or "NAO EXISTE"))
    local seat = Core.hum and Core.hum.SeatPart
    if seat then
        local line = "assento: " .. seat.ClassName .. " em " .. seat:GetFullName()
        if seat:IsA("VehicleSeat") then line = line .. " | MaxSpeed " .. tostring(seat.MaxSpeed) end
        L(line)
    else
        L("assento: voce nao ta sentado (senta no barco e roda de novo)")
    end

    for _, path in ipairs(CFG.LeviContainers) do
        local node = workspace
        for seg in string.gmatch(path, "[^/]+") do node = node and node:FindFirstChild(seg) end
        local found = {}
        if node then
            for _, name in ipairs(CFG.LeviSigns) do
                if node:FindFirstChild(name) then table.insert(found, name) end
            end
        end
        L("levi '" .. path .. "': " .. (node and "existe" or "NAO EXISTE")
            .. (#found > 0 and (" | achou: " .. table.concat(found, ", ")) or ""))
    end
    L("==== FIM (usa Copiar Log ou manda print) ====")
end

-- ---- 5.7 verbo customizado (CDK/Soul/Halloween apos logar) ----
function Feat.runVerb(verb, argsTable)
    local ok, res = Net.commf(verb, table.unpack(argsTable or {}))
    Core.log('run "' .. verb .. '" -> ' .. tostring(ok) .. " / " .. tostring(res))
    return ok, res
end

-- ============================================================
-- 6. SCHEDULER (um loop, intervalos por feature)
-- ============================================================
-- stat / buso: coisas leves, de tempos em tempos
task.spawn(function()
    local tick = 0
    while HUB.alive do
        if Core.alive() then
            if tick % 10 == 0 and T.stat then pcall(Feat.statStep) end
            if tick % 10 == 5 and T.buso then pcall(Feat.busoStep) end
        end
        tick += 1
        task.wait(0.5)
    end
end)

-- auto farm: cada passo cuida de um alvo
task.spawn(function()
    while HUB.alive do
        if T.farm and Core.alive() then
            local ok, err = pcall(Feat.farmStep)
            if not ok then
                pcall(Feat.farmStop)
                Core.log("erro no farm: " .. tostring(err))
                task.wait(1)
            end
            task.wait()
        else
            pcall(Feat.farmStop)
            task.wait(0.4)
        end
    end
    pcall(Feat.farmStop)
end)

task.spawn(function()
    while HUB.alive do
        if T.chest and Core.alive() and not Feat.boatBusy and not Feat.fruitBusy then
            local ok, err = pcall(Feat.chestStep)
            if not ok then
                pcall(Feat.chestStop)   -- solta busy E noclip
                Core.log("erro no bau: " .. tostring(err))
                task.wait(1)
            end
        else
            if T.chest and Feat.boatBusy and os.clock() - (Feat._boatWarn or 0) > 15 then
                Feat._boatWarn = os.clock()
                Core.log("auto chest pausado: barco no ar (desliga Levantar/Auto Levi)")
            end
            if Feat.chestStop then Feat.chestStop() end
            task.wait(0.5)
        end
    end
end)

-- autosave: 1 writefile por minuto enquanto farma (stats persistem sem spam)
task.spawn(function()
    while HUB.alive do
        task.wait(60)
        if T.chest or T.farm then Core.save() end
    end
end)

-- ============================================================
-- 7. GUI (abas, sliders, status, console) - mobile
-- ============================================================
local function buildGui()
    local COL = {
        bg = Color3.fromRGB(18,18,24), panel = Color3.fromRGB(28,28,36),
        on = Color3.fromRGB(40,120,65), off = Color3.fromRGB(48,48,58),
        accent = Color3.fromRGB(95,80,160), txt = Color3.fromRGB(236,236,244),
    }
    local sg = Instance.new("ScreenGui")
    sg.Name = "BFHUB_PRO"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local host = lp:WaitForChild("PlayerGui")
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then host = h end
    end
    sg.Parent = host
    HUB._gui = sg

    local win = Instance.new("Frame", sg)
    win.Size = UDim2.fromOffset(280, 300)
    win.Position = UDim2.fromScale(0.03, 0.18)
    win.BackgroundColor3 = COL.bg; win.BackgroundTransparency = 0.05
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
    HUB._win = win

    -- header + drag + minimize
    local header = Instance.new("TextLabel", win)
    header.Size = UDim2.new(1,-40,0,32); header.Position = UDim2.fromOffset(0,0)
    header.BackgroundTransparency = 1; header.Text = "  BF AFK HUB  ::  PRO"
    header.TextColor3 = COL.txt; header.Font = Enum.Font.GothamBold
    header.TextSize = 14; header.TextXAlignment = Enum.TextXAlignment.Left

    local minBtn = Instance.new("TextButton", win)
    minBtn.Size = UDim2.fromOffset(32,32); minBtn.Position = UDim2.new(1,-34,0,0)
    minBtn.BackgroundTransparency = 1; minBtn.Text = "_"
    minBtn.TextColor3 = COL.txt; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 18

    local body = Instance.new("Frame", win)
    body.Size = UDim2.new(1,-16,1,-76); body.Position = UDim2.fromOffset(8,40)
    body.BackgroundTransparency = 1

    minBtn.MouseButton1Click:Connect(function()
        body.Visible = not body.Visible
        win.Size = body.Visible and UDim2.fromOffset(280,300) or UDim2.fromOffset(280,40)
    end)

    do -- drag
        local dragging, s0, p0
        header.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; s0 = i.Position; p0 = win.Position
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
                local d = i.Position - s0
                win.Position = UDim2.new(p0.X.Scale, p0.X.Offset+d.X, p0.Y.Scale, p0.Y.Offset+d.Y)
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
        end)
    end

    -- abas: barra que rola pro lado (arrasta pra ver as outras)
    local TAB_ORDER = { Main = 1, Farm = 2, Boat = 3, Extra = 4, Tune = 5, Custom = 6, Log = 7 }
    local tabs = Instance.new("ScrollingFrame", body)
    tabs.Size = UDim2.new(1,0,0,30); tabs.BackgroundTransparency = 1
    tabs.BorderSizePixel = 0; tabs.ScrollBarThickness = 0
    tabs.ScrollingDirection = Enum.ScrollingDirection.X
    tabs.CanvasSize = UDim2.new(); tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
    local tl = Instance.new("UIListLayout", tabs)
    tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0,4)
    tl.SortOrder = Enum.SortOrder.LayoutOrder

    local pages = Instance.new("Frame", body)
    pages.Size = UDim2.new(1,0,1,-32); pages.Position = UDim2.fromOffset(0,32)
    pages.BackgroundTransparency = 1

    local pageMap = {}
    local tabBtns = {}
    local function addTab(name)
        local btn = Instance.new("TextButton", tabs)
        btn.Size = UDim2.fromOffset(54,28); btn.Text = name
        btn.LayoutOrder = TAB_ORDER[name] or 99
        btn.BackgroundColor3 = COL.panel; btn.TextColor3 = COL.txt
        btn.Font = Enum.Font.GothamMedium; btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
        local page = Instance.new("ScrollingFrame", pages)
        page.Size = UDim2.fromScale(1,1); page.Visible = false
        page.BackgroundTransparency = 1; page.ScrollBarThickness = 3
        page.CanvasSize = UDim2.new(); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        local lay = Instance.new("UIListLayout", page)
        lay.Padding = UDim.new(0,6); lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
        pageMap[name] = page
        tabBtns[name] = btn
        btn.MouseButton1Click:Connect(function()
            for _, p in pairs(pageMap) do p.Visible = false end
            for _, tb in pairs(tabBtns) do tb.BackgroundColor3 = COL.panel end
            page.Visible = true
            btn.BackgroundColor3 = COL.accent
        end)
        return page
    end

    local togglePaint = {}
    local function mkToggle(page, label, key)
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.fromOffset(210,32)
        b.TextColor3 = COL.txt; b.Font = Enum.Font.GothamMedium; b.TextSize = 13
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        local function paint()
            b.Text = label..": "..(T[key] and "ON" or "OFF")
            b.BackgroundColor3 = T[key] and COL.on or COL.off
        end
        togglePaint[key] = paint
        paint()
        b.MouseButton1Click:Connect(function()
            T[key] = not T[key]
            paint()
            Core.save()
        end)
    end

    local function mkAction(page, text, cb)
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.fromOffset(210,30); b.BackgroundColor3 = COL.accent
        b.Text = text; b.TextColor3 = COL.txt
        b.Font = Enum.Font.GothamMedium; b.TextSize = 13
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        b.MouseButton1Click:Connect(function() cb(b) end)
        return b
    end

    local function mkSlider(page, label, cfgKey, min, max, step)
        local holder = Instance.new("Frame", page)
        holder.Size = UDim2.fromOffset(210,42); holder.BackgroundColor3 = COL.panel
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0,8)
        local cap = Instance.new("TextLabel", holder)
        cap.Size = UDim2.new(1,-10,0,18); cap.Position = UDim2.fromOffset(8,2)
        cap.BackgroundTransparency = 1; cap.TextXAlignment = Enum.TextXAlignment.Left
        cap.TextColor3 = COL.txt; cap.Font = Enum.Font.Gotham; cap.TextSize = 12
        local bar = Instance.new("Frame", holder)
        bar.Size = UDim2.new(1,-16,0,8); bar.Position = UDim2.fromOffset(8,26)
        bar.BackgroundColor3 = COL.off; Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
        local fill = Instance.new("Frame", bar)
        fill.BackgroundColor3 = COL.accent; Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
        local function render()
            local v = CFG[cfgKey]
            cap.Text = label..": "..((step < 1) and string.format("%.2f", v) or tostring(v))
            fill.Size = UDim2.fromScale(math.clamp((v-min)/(max-min),0,1), 1)
        end
        render()
        local dragging, dirty
        local function setFromX(px)
            local rel = math.clamp((px - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
            local v = min + rel*(max-min)
            v = math.floor(v/step + 0.5)*step
            CFG[cfgKey] = v; render(); dirty = true
        end
        bar.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
                dragging=true; setFromX(i.Position.X)
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
                setFromX(i.Position.X)
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
                if dragging and dirty then Core.save(); dirty = false end
                dragging = false
            end
        end)
    end

    -- aba MAIN
    local main = addTab("Main")
    do
        local st = Instance.new("TextLabel", main)
        st.Size = UDim2.fromOffset(210,34); st.BackgroundColor3 = COL.panel
        st.TextWrapped = true
        st.TextColor3 = COL.txt; st.Font = Enum.Font.Gotham; st.TextSize = 12
        st.LayoutOrder = -1
        Instance.new("UICorner", st).CornerRadius = UDim.new(0,8)
        local function paint()
            local d = HUB.stats or {}
            st.Text = ("baus %d | beli %d | kills %d | puxoes %d"):format(
                math.floor(d.chests or 0), math.floor(d.beli or 0),
                math.floor(d.kills or 0), math.floor(Move.pulls or 0))
        end
        paint()
        -- 1x por segundo e so com a aba aberta
        task.spawn(function()
            while HUB.alive and st.Parent do
                if main.Visible then pcall(paint) end
                task.wait(1)
            end
        end)
    end
    mkToggle(main, "Auto Farm", "farm")
    mkToggle(main, "Auto Quest", "quest")
    mkToggle(main, "Auto Chest", "chest")
    mkToggle(main, "Auto Stat", "stat")
    mkToggle(main, "Auto Buso (haki)", "buso")
    mkToggle(main, "Anti-Idle", "idle")
    do
        local hop = Instance.new("TextButton", main)
        hop.Size = UDim2.fromOffset(210,30); hop.BackgroundColor3 = COL.accent
        hop.Text = "Hop Server"; hop.TextColor3 = COL.txt
        hop.Font = Enum.Font.GothamMedium; hop.TextSize = 13
        Instance.new("UICorner", hop).CornerRadius = UDim.new(0,8)
        hop.MouseButton1Click:Connect(function() task.spawn(Feat.hopServer) end)

        local stop = Instance.new("TextButton", main)
        stop.Size = UDim2.fromOffset(210,30); stop.BackgroundColor3 = Color3.fromRGB(150,50,50)
        stop.Text = "PARAR TUDO"; stop.TextColor3 = COL.txt
        stop.Font = Enum.Font.GothamBold; stop.TextSize = 13
        Instance.new("UICorner", stop).CornerRadius = UDim.new(0,8)
        stop.MouseButton1Click:Connect(function()
            for k in pairs(T) do
                if k ~= "idle" then T[k] = false end
            end
            for _, paint in pairs(togglePaint) do pcall(paint) end
            Core.save()
            Core.log("tudo desligado (o barco desce devagar)")
        end)
    end

    -- aba FARM
    local farmTab = addTab("Farm")
    do
        local status = Instance.new("TextLabel", farmTab)
        status.Size = UDim2.fromOffset(210, 34); status.BackgroundColor3 = COL.panel
        status.TextColor3 = COL.txt; status.Font = Enum.Font.Gotham; status.TextSize = 12
        status.TextWrapped = true
        status.Text = "farm: parado"
        Instance.new("UICorner", status).CornerRadius = UDim.new(0,8)
        -- 2x por segundo e so com a aba aberta
        task.spawn(function()
            while HUB.alive and status.Parent do
                if farmTab.Visible and Feat.farmStatus then
                    status.Text = "farm: " .. tostring(Feat.farmStatus())
                end
                task.wait(0.5)
            end
        end)

        local function mkBox(placeholder, cfgKey, lettersOnly)
            local box = Instance.new("TextBox", farmTab)
            box.Size = UDim2.fromOffset(210,28); box.PlaceholderText = placeholder
            box.Text = tostring(CFG[cfgKey] or ""); box.ClearTextOnFocus = false
            box.BackgroundColor3 = COL.panel; box.TextColor3 = COL.txt
            box.Font = Enum.Font.Gotham; box.TextSize = 12
            Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)
            box.FocusLost:Connect(function()
                local v = (string.gsub(box.Text, "^%s+", ""))
                v = (string.gsub(v, "%s+$", ""))
                if lettersOnly then v = string.upper((string.gsub(v, "[^%a]", ""))) end
                CFG[cfgKey] = v
                box.Text = v
                Core.save()
                Core.log(cfgKey .. " = '" .. v .. "'")
            end)
        end

        mkBox("mob (vazio = quest do teu level)", "FarmMob", false)

        local function atkName()
            local m = CFG.FarmAttack
            if type(m) ~= "number" or m < 1 then return "Ataque: auto (testa sozinho)" end
            return "Ataque: " .. (Feat.farmAttacks[m] or "auto")
        end
        mkAction(farmTab, atkName(), function(b)
            local m = (type(CFG.FarmAttack) == "number") and CFG.FarmAttack or 0
            CFG.FarmAttack = (m + 1) % (#Feat.farmAttacks + 1)
            b.Text = atkName(); Core.save()
        end)
        local function wepName()
            return "Arma: " .. (Feat.farmWeapons[CFG.FarmWeapon] or "qualquer")
        end
        mkAction(farmTab, wepName(), function(b)
            local w = (type(CFG.FarmWeapon) == "number") and CFG.FarmWeapon or 1
            CFG.FarmWeapon = (w % #Feat.farmWeapons) + 1
            b.Text = wepName(); Core.save()
        end)
        mkAction(farmTab, "Testar ataque de novo", function() Feat.farmReprobe() end)
        mkBox("teclas de skill (ex: ZXC)", "FarmKeys", true)
        mkSlider(farmTab, "Altura em cima do mob", "FarmHover", 0, 60, 1)
        mkSlider(farmTab, "Pulo instantaneo ate", "FarmHop", 40, 400, 10)
        mkSlider(farmTab, "Voo (velocidade)", "FarmFlySpeed", 100, 350, 10)
        mkSlider(farmTab, "Intervalo do ataque", "AttackInterval", 0.05, 1, 0.05)
        mkSlider(farmTab, "Alcance sem quest", "AttackRange", 100, 600, 10)
    end

    -- aba EXTRA
    local extra = addTab("Extra")
    mkToggle(extra, "Avisar fruta", "fruit")
    mkToggle(extra, "Pegar fruta", "fruitGrab")
    mkToggle(extra, "Guardar fruta", "fruitStore")
    mkToggle(extra, "Avisar eventos / lua", "watch")
    mkToggle(extra, "Tela branca (AFK)", "white")
    mkAction(extra, "FPS Boost", function() task.spawn(Feat.fpsBoost) end)
    mkAction(extra, "Elite Hunter (consultar)", function() task.spawn(Feat.eliteCheck) end)
    mkAction(extra, "Gacha: consultar", function() task.spawn(Feat.gachaCheck) end)
    mkAction(extra, "Gacha: comprar (gasta beli)", function() task.spawn(Feat.gachaBuy) end)

    -- aba TUNE (ajustes finos do bau)
    local tune = addTab("Tune")
    mkSlider(tune, "Chest Hold (delay)", "ChestHold", 0.05, 0.6, 0.01)
    mkSlider(tune, "Chest Max Wait", "ChestMaxWait", 0.3, 2.0, 0.1)
    do
        local names = { "tp", "voo" }
        local b = Instance.new("TextButton", tune)
        b.Size = UDim2.fromOffset(210,30); b.BackgroundColor3 = COL.accent
        b.TextColor3 = COL.txt; b.Font = Enum.Font.GothamMedium; b.TextSize = 13
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        local function paint() b.Text = "Bau longe: " .. (names[CFG.ChestFarMode] or "voo") end
        paint()
        b.MouseButton1Click:Connect(function()
            CFG.ChestFarMode = (CFG.ChestFarMode % #names) + 1
            paint(); Core.save()
        end)
    end
    mkSlider(tune, "TP final (studs)", "ChestFarDist", 50, 1500, 50)
    mkSlider(tune, "Voo do bau (vel.)", "ChestFlySpeed", 100, 350, 10)
    mkSlider(tune, "Espera bau longe", "ChestFarWait", 1, 4, 0.1)
    mkSlider(tune, "Call Cooldown", "CallCooldown", 0.05, 0.5, 0.01)

    -- aba BOAT (levantar + velocidade + auto leviathan)
    local boatTab = addTab("Boat")
    do
        local status = Instance.new("TextLabel", boatTab)
        status.Size = UDim2.fromOffset(210, 22); status.BackgroundColor3 = COL.panel
        status.TextColor3 = COL.txt; status.Font = Enum.Font.Gotham; status.TextSize = 12
        status.Text = "barco: na agua"
        Instance.new("UICorner", status).CornerRadius = UDim.new(0,8)
        -- atualiza 2x por segundo e so com a aba aberta (nao pesa)
        task.spawn(function()
            while HUB.alive and status.Parent do
                if boatTab.Visible and Feat.boatStatus then
                    status.Text = "barco: " .. Feat.boatStatus()
                end
                task.wait(0.5)
            end
        end)

        local function actionBtn(text, cb)
            local b = Instance.new("TextButton", boatTab)
            b.Size = UDim2.fromOffset(210,30); b.BackgroundColor3 = COL.accent
            b.Text = text; b.TextColor3 = COL.txt
            b.Font = Enum.Font.GothamMedium; b.TextSize = 13
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
            b.MouseButton1Click:Connect(function() cb(b) end)
            return b
        end

        -- velocidade
        mkToggle(boatTab, "Boat Speed", "speed")
        mkSlider(boatTab, "Velocidade do barco", "BoatSpeed", 50, 500, 10)
        local function speedName()
            return "Speed: " .. (Feat.speedMethods[CFG.SpeedMethod] or "maxspeed")
        end
        actionBtn(speedName(), function(b)
            CFG.SpeedMethod = (CFG.SpeedMethod % #Feat.speedMethods) + 1
            b.Text = speedName(); Core.save()
        end)

        -- voo
        mkToggle(boatTab, "Levantar Barco", "lift")
        mkToggle(boatTab, "Auto Leviathan", "levi")
        local function methodName()
            return "Voo: " .. (Feat.boatMethods[CFG.BoatMethod] or "cframe")
        end
        actionBtn(methodName(), function(b)
            CFG.BoatMethod = (CFG.BoatMethod % #Feat.boatMethods) + 1
            b.Text = methodName(); Core.save()
        end)
        local function dirName()
            return "Levi: " .. (Feat.leviDirs[CFG.LeviDirMode] or "longe das ilhas")
        end
        actionBtn(dirName(), function(b)
            CFG.LeviDirMode = (CFG.LeviDirMode % #Feat.leviDirs) + 1
            b.Text = dirName(); Core.save()
        end)
        actionBtn("Checar Spy (remote)", function() task.spawn(Feat.leviSpy) end)

        mkSlider(boatTab, "Altura (levantar)", "BoatLift", 20, 600, 10)
        mkSlider(boatTab, "Altura (auto levi)", "LeviHeight", 100, 1500, 50)
        mkSlider(boatTab, "Velocidade levi", "LeviSpeed", 40, 350, 10)
        mkSlider(boatTab, "Subida/descida", "BoatRiseSpeed", 20, 150, 5)
        mkSlider(boatTab, "Ida reta", "LeviOutDist", 0, 20000, 500)
        mkSlider(boatTab, "Perna da patrulha", "LeviLeg", 500, 6000, 250)
    end

    -- aba CUSTOM (verbos do CommF_)
    local custom = addTab("Custom")
    do
        local box = Instance.new("TextBox", custom)
        box.Size = UDim2.fromOffset(210,28); box.PlaceholderText = 'verbo ex: BuyBoat'
        box.Text = ""; box.ClearTextOnFocus = false
        box.BackgroundColor3 = COL.panel; box.TextColor3 = COL.txt
        box.Font = Enum.Font.Gotham; box.TextSize = 12
        Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)

        local function addCustomBtn(name, verb)
            local b = Instance.new("TextButton", custom)
            b.Size = UDim2.fromOffset(210,28); b.BackgroundColor3 = COL.off
            b.Text = name; b.TextColor3 = COL.txt
            b.Font = Enum.Font.Gotham; b.TextSize = 12
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
            b.MouseButton1Click:Connect(function() Feat.runVerb(verb) end)
        end
        for _, c in ipairs(HUB.custom) do addCustomBtn(c.name, c.verb) end

        local row = Instance.new("Frame", custom)
        row.Size = UDim2.fromOffset(210,28); row.BackgroundTransparency = 1
        local rl = Instance.new("UIListLayout", row)
        rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,6)
        local function smallBtn(txt, cb)
            local b = Instance.new("TextButton", row)
            b.Size = UDim2.fromOffset(102,28); b.BackgroundColor3 = COL.accent
            b.Text = txt; b.TextColor3 = COL.txt; b.Font = Enum.Font.GothamMedium; b.TextSize = 12
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
            b.MouseButton1Click:Connect(cb)
        end
        smallBtn("Run", function()
            local v = box.Text:gsub('["\']','')
            if v ~= "" then Feat.runVerb(v) end
        end)
        smallBtn("Save", function()
            local v = box.Text:gsub('["\']','')
            if v == "" then return end
            for _, c in ipairs(HUB.custom) do
                if c.verb == v then return end   -- ja existe, nao duplica
            end
            table.insert(HUB.custom, { name = v, verb = v })
            addCustomBtn(v, v); Core.save()
        end)
    end

    -- aba LOG (console)
    local logpage = addTab("Log")
    do
        local row = Instance.new("Frame", logpage)
        row.Size = UDim2.fromOffset(210,28); row.BackgroundTransparency = 1
        row.LayoutOrder = -1
        local rl = Instance.new("UIListLayout", row)
        rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,6)
        local function logBtn(txt, cb)
            local b = Instance.new("TextButton", row)
            b.Size = UDim2.fromOffset(102,28); b.BackgroundColor3 = COL.accent
            b.Text = txt; b.TextColor3 = COL.txt; b.Font = Enum.Font.GothamMedium; b.TextSize = 12
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
            b.MouseButton1Click:Connect(cb)
        end
        logBtn("Diagnostico", function()
            task.spawn(function()
                local ok, err = pcall(Feat.diagnose)
                if not ok then Core.log("diag erro: " .. tostring(err)) end
            end)
        end)
        logBtn("Copiar Log", function()
            local clip = setclipboard or toclipboard
            if type(clip) == "function" then
                local ok = pcall(clip, table.concat(Core.logLines, "\n"))
                Core.log(ok and "log copiado - cola no chat" or "falha ao copiar")
            else
                Core.log("sem clipboard nesse executor - tira print da tela")
            end
        end)
    end
    local console = Instance.new("TextLabel", logpage)
    console.Size = UDim2.fromOffset(210,200); console.BackgroundColor3 = COL.panel
    console.TextColor3 = COL.txt; console.Font = Enum.Font.Code; console.TextSize = 11
    console.TextXAlignment = Enum.TextXAlignment.Left; console.TextYAlignment = Enum.TextYAlignment.Top
    console.TextWrapped = true; console.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", console).CornerRadius = UDim.new(0,8)
    Instance.new("UIPadding", console).PaddingLeft = UDim.new(0,6)
    Core.logHook = function()
        local n = #Core.logLines
        local lines = {}
        for i = math.max(1, n-39), n do table.insert(lines, Core.logLines[i]) end
        console.Text = table.concat(lines, "\n")
    end

    main.Visible = true
    if tabBtns.Main then tabBtns.Main.BackgroundColor3 = COL.accent end

    -- animacao de entrada: o nome aparece, some, e a janela "salta" pro lugar.
    -- roda uma vez so (nao pesa); se qualquer tween falhar a janela aparece igual.
    do
        local TweenSvc = game:GetService("TweenService")
        local scale = Instance.new("UIScale", win)
        scale.Scale = 0.6
        win.Visible = false

        local splash = Instance.new("TextLabel", sg)
        splash.AnchorPoint = Vector2.new(0.5, 0.5)
        splash.Position = UDim2.fromScale(0.5, 0.45)
        splash.Size = UDim2.fromOffset(280, 60)
        splash.BackgroundTransparency = 1
        splash.Text = "BF AFK HUB"
        splash.Font = Enum.Font.GothamBlack; splash.TextSize = 34
        splash.TextColor3 = COL.txt; splash.TextTransparency = 1
        local stroke = Instance.new("UIStroke", splash)
        stroke.Color = COL.accent; stroke.Thickness = 2; stroke.Transparency = 1
        local sub = Instance.new("TextLabel", splash)
        sub.AnchorPoint = Vector2.new(0.5, 0)
        sub.Position = UDim2.new(0.5, 0, 1, -6)
        sub.Size = UDim2.fromOffset(280, 18)
        sub.BackgroundTransparency = 1
        sub.Text = "carregando..."
        sub.Font = Enum.Font.Gotham; sub.TextSize = 13
        sub.TextColor3 = COL.txt; sub.TextTransparency = 1

        task.spawn(function()
            pcall(function()
                local tin = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenSvc:Create(splash, tin, { TextTransparency = 0 }):Play()
                TweenSvc:Create(stroke, tin, { Transparency = 0 }):Play()
                TweenSvc:Create(sub, tin, { TextTransparency = 0.3 }):Play()
                task.wait(0.9)
                local tout = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                TweenSvc:Create(splash, tout, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.40) }):Play()
                TweenSvc:Create(stroke, tout, { Transparency = 1 }):Play()
                TweenSvc:Create(sub, tout, { TextTransparency = 1 }):Play()
                task.wait(0.3)
            end)
            pcall(function() splash:Destroy() end)
            win.Visible = true
            local okT = pcall(function()
                TweenSvc:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { Scale = 1 }):Play()
            end)
            if not okT then scale.Scale = 1 end
        end)
    end

    -- keybind toggle da janela
    UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == CFG.GuiKeybind then sg.Enabled = not sg.Enabled end
    end)
end

-- ============================================================
-- 8. BOOT
-- ============================================================
Core.load()
T.lift = false; T.levi = false; T.speed = false   -- barco so mexe quando VOCE ligar
if type(CFG.BoatMethod) ~= "number" or CFG.BoatMethod < 1 or CFG.BoatMethod > 3 then CFG.BoatMethod = 1 end
if type(CFG.SpeedMethod) ~= "number" or CFG.SpeedMethod < 1 or CFG.SpeedMethod > 2 then CFG.SpeedMethod = 1 end
if CFG.ChestFarMode ~= 1 and CFG.ChestFarMode ~= 2 then CFG.ChestFarMode = 2 end
if CFG.LeviDirMode ~= 1 and CFG.LeviDirMode ~= 2 then CFG.LeviDirMode = 2 end
T.white = false                                    -- nunca abre com a tela branca
if type(CFG.FarmAttack) ~= "number" or CFG.FarmAttack < 0 or CFG.FarmAttack > 5 then CFG.FarmAttack = 0 end
if type(CFG.FarmWeapon) ~= "number" or CFG.FarmWeapon < 1 or CFG.FarmWeapon > 5 then CFG.FarmWeapon = 1 end
if type(CFG.FarmMob) ~= "string" then CFG.FarmMob = "" end
if type(CFG.FarmKeys) ~= "string" or CFG.FarmKeys == "" then CFG.FarmKeys = "ZXC" end
do  -- config salva antiga ganha os nomes novos (LeviathanGate fica em workspace.Map)
    local function ensure(list, value)
        if type(list) ~= "table" then return end
        for _, v in ipairs(list) do
            if v == value then return end
        end
        table.insert(list, 1, value)
    end
    ensure(CFG.LeviSigns, "LeviathanGate")
    ensure(CFG.LeviContainers, "SeaBeasts")
    ensure(CFG.LeviContainers, "Map")
end
versionGuard()
buildGui()
Core.log("hub PRO carregado")
Core.log("desligar tudo: getgenv().BFHUB.alive = false")
