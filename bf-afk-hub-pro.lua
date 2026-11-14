--[[
================================================================
  BF AFK HUB  ::  PRO
  auto-farm / anti-idle  ::  Luau  ::  Delta (mobile)
  Do zero. Sem loadstring, sem codigo de terceiros, sem rede.
================================================================

NOVO NESSA VERSAO
  - Arquitetura modular (Core / Remotes / Features / UI)
  - Resolver de remotes com WATCHDOG: se os remotes somem apos
    update, ele re-resolve sozinho e so desliga a feature se
    realmente nao achar (em vez de disparar verbo errado)
  - GUI com ABAS, sliders, status ao vivo e CONSOLE embutido
    (pra voce ver o que ta rolando sem o dev console do Delta)
  - Persistencia: salva seus toggles/sliders em arquivo e
    recarrega no proximo boot (se o Delta tiver writefile)
  - Coletor de bau com RETRY MEDIDO: confirma se o bau sumiu,
    e so entao vai pro proximo. O mais rapido sem perder bau.
  - Auto-farm com PRIORIDADE DE QUEST: le o mob da quest no
    tracker e foca nele; senao, o mais perto
  - Auto-stat (AddPoint) com distribuicao configuravel
  - VERBOS CUSTOMIZADOS salvos: depois de logar CDK / Soul /
    Halloween, salva como botao nomeado e reusa

O QUE CONTINUA SENDO SEU (muda por update, logger resolve):
  - nome da pasta de mobs           -> CONFIG.EnemyFolders
  - QuestGiverId / QuestIndex        -> do logger (CommF_ StartQuest)
  - CDK / Soul / Halloween           -> aba "Custom", botao Run+Save

Roda o logger (bf_remotes_e_baus.txt) pra achar os verbos reais.
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
    LeviSigns       = { "Frozen Dimension", "Leviathan" },
    LeviContainers  = { "_WorldOrigin/Locations", "Map", "SeaBeasts" },

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
HUB.toggles = { farm = false, quest = false, chest = false, stat = false, idle = true,
                lift = false, levi = false, speed = false }
HUB.config  = table.clone(DEFAULTS)
HUB.custom  = {}   -- { {name=, verb=, args={}} }

local CFG = HUB.config
local T   = HUB.toggles
for k, v in pairs(DEFAULTS) do
    if CFG[k] == nil then CFG[k] = v end
end
HUB.stats = HUB.stats or { chests = 0, beli = 0, fails = 0, snaps = 0 }

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
        Core.log("!! o jogo deve ter atualizado - roda o logger e ajusta antes do farm")
        T.farm = false; T.quest = false
        return false
    end
    Core.log("remotes ok")
    return true
end

-- ============================================================
-- 5. FEATURES
-- ============================================================
local Feat = {}

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

-- ---- 5.3 auto-farm de combate ----
do
    -- le o nome do mob da quest no tracker da UI
    local function questMobName()
        local gui = lp:FindFirstChild("PlayerGui")
        local q = gui and gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Quest")
        if not q or not q.Visible then return nil end
        for _, t in ipairs(q:GetDescendants()) do
            if t:IsA("TextLabel") and t.Text:match("%a") and not t.Text:match("Quest") then
                return t.Text:gsub("%s*%[.-%]", ""):gsub("%d+/%d+", ""):match("^%s*(.-)%s*$")
            end
        end
    end

    local function enemies()
        local out, r = {}, Core.root
        if not r then return out end
        local want = CFG.QuestPriority and questMobName() or nil
        for _, fname in ipairs(CFG.EnemyFolders) do
            local folder = workspace:FindFirstChild(fname)
            if folder then
                for _, e in ipairs(folder:GetChildren()) do
                    local h  = e:FindFirstChildWhichIsA("Humanoid")
                    local hr = e:FindFirstChild("HumanoidRootPart")
                    if h and hr and h.Health > 0 then
                        local priority = (want and e.Name:find(want, 1, true)) and 0 or 1
                        table.insert(out, { model = e, hrp = hr, prio = priority,
                                            dist = (hr.Position - r.Position).Magnitude })
                    end
                end
            end
        end
        table.sort(out, function(a, b)
            if a.prio ~= b.prio then return a.prio < b.prio end
            return a.dist < b.dist
        end)
        return out
    end

    local function equip()
        local char, bp = Core.char, lp:FindFirstChild("Backpack")
        if not char or not bp then return end
        if char:FindFirstChildWhichIsA("Tool") then return end
        local tool = bp:FindFirstChildWhichIsA("Tool")
        if tool and Core.hum then Core.hum:EquipTool(tool) end
    end

    function Feat.farmStep()
        if Feat.chestBusy or Feat.boatBusy then return end
        local es = enemies()
        local tgt = es[1]
        if not tgt or tgt.dist > CFG.AttackRange then return end
        equip()
        local r = Core.root
        if not r then return end
        r.CFrame = tgt.hrp.CFrame * CFrame.new(0, 0, CFG.ApproachOffset)
        -- shape observado: Attack(numero pequeno) / Hit(parte do alvo, {alvos extras}).
        -- e a parte mais volatil do jogo: se nao bater, confirma no logger.
        Net.fire(Net.R.Attack, 0.4)
        Net.fire(Net.R.Hit, tgt.hrp, {})
    end
end

-- ---- 5.4 auto-quest ----
local questMiss = 0
function Feat.questStep()
    if CFG.QuestGiverId == "" then return end
    local gui = lp:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local tracker = main and main:FindFirstChild("Quest")
    if not tracker then
        -- caminho Main.Quest nao existe (update renomeou?): nao spamma StartQuest
        questMiss += 1
        if questMiss == 10 then
            Core.log("tracker Main.Quest nao achado - auto-quest DESLIGADO (update?)")
            T.quest = false
        end
        return
    end
    questMiss = 0
    if not tracker.Visible then
        Net.commf("StartQuest", CFG.QuestGiverId, CFG.QuestIndex)
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

-- ---- 5.6 coletor de bau v3 ----
-- Por que o dinheiro nao contava antes:
--   1) TP instantaneo + sair em 0.12s: o servidor nunca via teu personagem
--      encostado no bau (a posicao replica com atraso/ping), entao nao pagava.
--   2) StreamingEnabled: ao teleportar longe, a area ainda nao tinha carregado.
--      O bau que tu "pegava" era copia velha/descarregada -> nao renderizava.
--   3) Lista congelada: o loop usava uma foto antiga dos baus, entao ia em
--      bau que ja tinha sido pego/descarregado.
-- O que mudou:
--   - registro AO VIVO de baus (entra quando spawna/carrega, sai quando some)
--   - so vai em bau VIVO (no workspace, tocavel, visivel, com TouchInterest)
--   - pede pro jogo carregar a area antes de ir (RequestStreamAroundAsync)
--   - viaja suave numa velocidade fixa (sem TP gigante), com noclip
--   - fica no bau ATE O SERVIDOR PAGAR (Beli sobe) ou ate o tempo maximo
--   - detecta rubberband e diminui a velocidade sozinho
--   - bau que falha repetido vai pra lista de ignorados por um tempo
do
    local RunSvc = game:GetService("RunService")
    local live      = {}  -- [touchPart] = chestInstance
    local fails     = {}  -- [touchPart] = n
    local ignored   = {}  -- [touchPart] = os.clock() ate quando ignorar
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

    local function isLive(p)
        if not p or not p.Parent or not p:IsDescendantOf(workspace) then return false end
        if not p.CanTouch then return false end
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
            live[p] = nil; fails[p] = nil; ignored[p] = nil
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

    -- TP em cima + DELAYZIN colado ate o server contar (Beli sobe) ou o bau sumir.
    -- segura o CFrame todo frame pra posicao replicar antes de pular pro proximo.
    local function holdUntilPaid(p, before)
        local t0 = os.clock()
        if firetouchinterest then
            pcall(function() firetouchinterest(Core.root, p, 0) end)
        end
        local paid = false
        while os.clock() - t0 < CFG.ChestMaxWait do
            if not HUB.alive then break end   -- re-execucao: instancia velha solta o char
            local r = Core.root
            if not r or not T.chest then break end
            if p.Parent then
                r.AssemblyLinearVelocity = Vector3.zero
                r.CFrame = p.CFrame          -- cola em cima (o delayzin)
            end
            local now = beli()
            if before and now and now > before then paid = true end
            if not before and not isLive(p) then paid = true end
            -- so sai depois do delayzin minimo, pra garantir que replicou
            if paid and os.clock() - t0 >= CFG.ChestHold then break end
            RunSvc.Heartbeat:Wait()
        end
        if firetouchinterest then
            pcall(function() firetouchinterest(Core.root, p, 1) end)
        end
        return paid, os.clock() - t0
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

    function Feat.chestStep()
        if next(live) == nil and fullScan() == 0 then
            task.wait(3)
            return
        end
        local p = nextChest()
        if not p then task.wait(1); return end

        Feat.chestBusy = true
        setNoclip(true)
        local before = beli()

        -- 1) TP pra cima do bau (leva teu personagem pra regiao)
        local arrived = tpTo(p)

        -- 2) ESPERA a area renderizar de verdade antes de tocar.
        --    e isso que resolve o "so conta depois do nome da cidade aparecer":
        --    o nome aparece quando a regiao terminou de carregar. aqui a gente
        --    espera o mesmo evento em vez de tocar num bau meio-carregado.
        if arrived and workspace.StreamingEnabled then
            arrived = streamWait(p)
        end

        local collected = false
        local target = p   -- se assumir o "fresh" e falhar, a falha conta nele
        if arrived and isLive(p) then
            -- reancora: apos carregar, a instancia do bau pode ter sido recriada
            local fresh = nextChest()
            if fresh and (fresh.Position - p.Position).Magnitude < 8 then target = fresh end
            if tpTo(target) then
                local paid, took = holdUntilPaid(target, before)
                if paid then
                    collected = true
                    local nowBeli = beli()
                    local gain = (before and nowBeli) and (nowBeli - before) or 0
                    HUB.stats.chests += 1
                    HUB.stats.beli += gain
                    fails[target] = nil
                    if before then
                        Core.log(("bau ok +%d beli (%.2fs) | total %d baus, %d beli")
                            :format(math.floor(gain), took, HUB.stats.chests, math.floor(HUB.stats.beli)))
                    else
                        Core.log(("bau ok (%.2fs, sem leitor de moeda) | total %d baus")
                            :format(took, HUB.stats.chests))
                    end
                end
            end
        end
        -- QUALQUER falha (stream nao renderizou, tp falhou, server nao pagou)
        -- conta como falha do bau -> ignora apos N. sem isso, bau cuja regiao
        -- nunca streama trava o coletor em loop infinito nele (#9/#10)
        if not collected and T.chest then
            HUB.stats.fails += 1
            fails[target] = (fails[target] or 0) + 1
            Core.log("bau nao contou (" .. fails[target] .. "x)")
            if fails[target] >= CFG.ChestMaxFails then
                ignored[target] = os.clock() + CFG.ChestIgnoreTime
                fails[target] = nil
                Core.log("ignorando esse bau por " .. CFG.ChestIgnoreTime .. "s")
            end
        end
        Feat.chestBusy = false
    end

    -- numeros pro diagnostico: achados, vivos, com TouchInterest, por tag, moeda
    function Feat.chestInfo()
        fullScan()
        local total, alive, withTI = 0, 0, 0
        for part in pairs(live) do
            total += 1
            if part:FindFirstChildWhichIsA("TouchTransmitter") then withTI += 1 end
            if isLive(part) then alive += 1 end
        end
        local tagged = 0
        pcall(function() tagged = #CS:GetTagged(CFG.ChestTag) end)
        beli()
        return total, alive, withTI, tagged, (beliObj and beliObj:GetFullName() or nil)
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
        if driving and levi.state == "cruise" and levi.dir then
            hv = levi.dir * CFG.LeviSpeed
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
                local seat = Core.hum and Core.hum.SeatPart
                local look = ((seat and seat.Parent) and seat or boatRoot).CFrame.LookVector
                local d = Vector3.new(look.X, 0, look.Z)
                d = (d.Magnitude > 0.1) and d.Unit or Vector3.new(0, 0, -1)
                levi = { state = "cruise", phase = "out", dir = d, legStart = boatRoot.Position }
                Core.log("auto levi: cruzando na direcao do barco")
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

    -- remote REAL do espiao (verbo visto em scripts antigos, NAO confirmado
    -- nessa versao): so consulta e mostra a resposta no Log.
    function Feat.leviSpy()
        local ok, res = Net.commf("InfoLeviathan", "1")
        Core.log("spy InfoLeviathan -> " .. tostring(ok) .. " / " .. tostring(res))
    end
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

    if Feat.chestInfo then
        local ok, total, alive, withTI, tagged, coin = pcall(Feat.chestInfo)
        if ok then
            L(("baus: %d achados, %d vivos, %d c/ touch, %d por tag"):format(total, alive, withTI, tagged))
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

    local pg = lp:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("Main")
    local q = mainGui and mainGui:FindFirstChild("Quest")
    L("tracker Main.Quest: " .. yn(q))

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
task.spawn(function()
    local tick = 0
    while HUB.alive do
        if Core.alive() then
            if T.farm  then pcall(Feat.farmStep) end
            if tick % 12 == 0 and T.quest then pcall(Feat.questStep) end
            if tick % 20 == 0 and T.stat  then pcall(Feat.statStep)  end
        end
        tick += 1
        task.wait(CFG.AttackInterval)
    end
end)

task.spawn(function()
    while HUB.alive do
        if T.chest and Core.alive() and not Feat.boatBusy then
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

    -- abas
    local tabs = Instance.new("Frame", body)
    tabs.Size = UDim2.new(1,0,0,28); tabs.BackgroundTransparency = 1
    local tl = Instance.new("UIListLayout", tabs)
    tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0,4)

    local pages = Instance.new("Frame", body)
    pages.Size = UDim2.new(1,0,1,-32); pages.Position = UDim2.fromOffset(0,32)
    pages.BackgroundTransparency = 1

    local pageMap = {}
    local tabBtns = {}
    local function addTab(name)
        local btn = Instance.new("TextButton", tabs)
        btn.Size = UDim2.fromOffset(49,28); btn.Text = name
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
            cap.Text = label..": "..tostring(v)
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
        st.Size = UDim2.fromOffset(210,22); st.BackgroundColor3 = COL.panel
        st.TextColor3 = COL.txt; st.Font = Enum.Font.Gotham; st.TextSize = 12
        st.LayoutOrder = -1
        Instance.new("UICorner", st).CornerRadius = UDim.new(0,8)
        local function paint()
            local d = HUB.stats or {}
            st.Text = ("baus %d | beli %d | falhas %d"):format(
                math.floor(d.chests or 0), math.floor(d.beli or 0), math.floor(d.fails or 0))
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

    -- aba TUNE (sliders)
    local tune = addTab("Tune")
    mkSlider(tune, "Attack Range", "AttackRange", 100, 600, 10)
    mkSlider(tune, "Attack Interval", "AttackInterval", 0.05, 1, 0.05)
    mkSlider(tune, "Chest Hold (delay)", "ChestHold", 0.05, 0.6, 0.01)
    mkSlider(tune, "Chest Stream Wait", "ChestStreamWait", 0.5, 4, 0.1)
    mkSlider(tune, "Chest Max Wait", "ChestMaxWait", 0.3, 2.0, 0.1)
    mkSlider(tune, "Call Cooldown", "CallCooldown", 0.05, 0.5, 0.01)

    -- aba CUSTOM (verbos logados)
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
        actionBtn("Checar Spy (remote)", function() task.spawn(Feat.leviSpy) end)

        mkSlider(boatTab, "Altura (levantar)", "BoatLift", 20, 600, 10)
        mkSlider(boatTab, "Altura (auto levi)", "LeviHeight", 100, 1500, 50)
        mkSlider(boatTab, "Velocidade levi", "LeviSpeed", 40, 350, 10)
        mkSlider(boatTab, "Subida/descida", "BoatRiseSpeed", 20, 150, 5)
        mkSlider(boatTab, "Ida reta", "LeviOutDist", 0, 20000, 500)
        mkSlider(boatTab, "Perna da patrulha", "LeviLeg", 500, 6000, 250)
    end

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
versionGuard()
buildGui()
Core.log("hub PRO carregado")
Core.log("desligar tudo: getgenv().BFHUB.alive = false")
