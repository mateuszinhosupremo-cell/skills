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
    ChestTravelSpeed = 150,     -- studs/s indo pro bau (abaixo do limite de kick)
    ChestMaxWait     = 1.2,     -- maximo parado no bau esperando o servidor contar
    ChestMinWait     = 0.25,    -- minimo parado no bau (deixa a posicao replicar)
    ChestMaxFails    = 2,       -- falhas no mesmo bau antes de ignorar ele
    ChestIgnoreTime  = 45,      -- segundos ignorando bau que falhou
    ChestNoclip      = true,    -- atravessa parede no caminho

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

getgenv().BFHUB = getgenv().BFHUB or {}
local HUB = getgenv().BFHUB
HUB.alive = true
HUB.toggles = HUB.toggles or {
    farm = false, quest = false, chest = false, stat = false, idle = true,
}
HUB.config  = HUB.config or table.clone(DEFAULTS)
HUB.custom  = HUB.custom or {}   -- { {name=, verb=, args={}} }

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
        msg = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(msg)
        table.insert(Core.logLines, msg)
        if #Core.logLines > 80 then table.remove(Core.logLines, 1) end
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
        local data = { toggles = T, config = cfgOut, custom = HUB.custom }
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
                Core.log("settings carregados do arquivo")
            end
        end)
    end

    -- character refs com refresh automatico
    Core.char, Core.root, Core.hum = nil, nil, nil
    local function bind(c)
        Core.char = c
        Core.root = c:WaitForChild("HumanoidRootPart", 10)
        Core.hum  = c:WaitForChild("Humanoid", 10)
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
            if #Net.resolve() > 0 then return false, "sem CommF_" end
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
        if Feat.chestBusy then return end
        local es = enemies()
        local tgt = es[1]
        if not tgt or tgt.dist > CFG.AttackRange then return end
        equip()
        local r = Core.root
        if not r then return end
        r.CFrame = tgt.hrp.CFrame * CFrame.new(0, 0, CFG.ApproachOffset)
        Net.fire(Net.R.Attack, 1)
        Net.fire(Net.R.Hit, tgt.model, 1)
    end
end

-- ---- 5.4 auto-quest ----
function Feat.questStep()
    if CFG.QuestGiverId == "" then return end
    local gui = lp:FindFirstChild("PlayerGui")
    local tracker = gui and gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Quest")
    if not (tracker and tracker.Visible) then
        Net.commf("StartQuest", CFG.QuestGiverId, CFG.QuestIndex)
    end
end

-- ---- 5.5 auto-stat ----
function Feat.statStep()
    for label, weight in pairs(CFG.StatPlan) do
        if weight and weight > 0 then
            Net.commf("AddPoint", label, CFG.StatPerTick * weight)
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
    local requireTI = true
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
        if not p.CanTouch or p.Transparency >= 0.95 then return false end
        if requireTI and not p:FindFirstChildWhichIsA("TouchTransmitter") then return false end
        return true
    end

    local function register(inst)
        if not isChest(inst) then return end
        local p = touchPart(inst)
        if p then live[p] = inst end
    end

    local function unregister(inst)
        for p, c in pairs(live) do
            if p == inst or c == inst or not p:IsDescendantOf(workspace) then
                live[p] = nil; fails[p] = nil; ignored[p] = nil
            end
        end
    end

    local function fullScan()
        table.clear(live)
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
        local was = requireTI
        requireTI = not (total > 0 and withTI == 0)
        if was ~= requireTI and not requireTI then
            Core.log("baus sem TouchInterest visivel - filtro relaxado")
        end
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
            task.wait(15)
            if T.chest then fullScan() end
        end
    end)

    local function beli()
        local data = lp:FindFirstChild("Data")
        local b = data and data:FindFirstChild("Beli")
        if b and (b:IsA("IntValue") or b:IsA("NumberValue")) then return b.Value end
        if not warnedBeli then
            warnedBeli = true
            Core.log("sem Data.Beli - confirmando pelo bau sumir (menos preciso)")
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

    -- noclip so enquanto o coletor ta andando
    local noclipConn
    local function setNoclip(on)
        if on and CFG.ChestNoclip and not noclipConn then
            noclipConn = RunSvc.Stepped:Connect(function()
                local c = Core.char
                if not c then return end
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
                end
            end)
        elseif not on and noclipConn then
            noclipConn:Disconnect(); noclipConn = nil
        end
    end

    -- anda ate o alvo numa velocidade fixa, frame a frame.
    -- se o servidor puxar de volta (rubberband), reduz a velocidade.
    local function travelTo(p)
        local r = Core.root
        if not r then return false end
        local startDist = (p.Position - r.Position).Magnitude
        local deadline = os.clock() + startDist / math.max(CFG.ChestTravelSpeed, 30) * 2 + 4
        local lastSet
        while T.chest and Core.alive() and isLive(p) do
            r = Core.root
            local cur = r.Position
            if lastSet and (cur - lastSet).Magnitude > 25 then
                HUB.stats.snaps += 1
                CFG.ChestTravelSpeed = math.max(60, math.floor(CFG.ChestTravelSpeed * 0.85))
                Core.log("rubberband - velocidade baixou pra " .. CFG.ChestTravelSpeed)
            end
            local delta = p.Position - cur
            local dist = delta.Magnitude
            if dist < 3 then return true end
            if os.clock() > deadline then
                Core.log("travel estourou o tempo - pulando bau")
                return false
            end
            local dt = RunSvc.Heartbeat:Wait()
            local step = math.min(dist, CFG.ChestTravelSpeed * dt)
            lastSet = cur + delta.Unit * step
            r.AssemblyLinearVelocity = Vector3.zero
            r.CFrame = CFrame.new(lastSet)
        end
        return false
    end

    -- fica encostado no bau ate o servidor pagar (ou ate o tempo maximo)
    local function holdUntilPaid(p, before)
        local t0 = os.clock()
        if firetouchinterest then
            pcall(function() firetouchinterest(Core.root, p, 0) end)
        end
        local paid = false
        while os.clock() - t0 < CFG.ChestMaxWait do
            local r = Core.root
            if not r or not T.chest then break end
            if p.Parent then
                r.AssemblyLinearVelocity = Vector3.zero
                r.CFrame = p.CFrame
            end
            local now = beli()
            if before and now and now > before then paid = true end
            if not before and not isLive(p) then paid = true end
            if paid and os.clock() - t0 >= CFG.ChestMinWait then break end
            RunSvc.Heartbeat:Wait()
        end
        if firetouchinterest then
            pcall(function() firetouchinterest(Core.root, p, 1) end)
        end
        return paid, os.clock() - t0
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
        -- carrega a area antes (StreamingEnabled): evita bau "fantasma"
        if workspace.StreamingEnabled then
            pcall(function() lp:RequestStreamAroundAsync(p.Position, 2) end)
        end
        if not isLive(p) then Feat.chestBusy = false; return end

        setNoclip(true)
        local before = beli()
        local arrived = travelTo(p)
        if arrived and isLive(p) then
            local paid, took = holdUntilPaid(p, before)
            if paid then
                local gain = (before and beli()) and (beli() - before) or 0
                HUB.stats.chests += 1
                HUB.stats.beli += gain
                fails[p] = nil
                Core.log(("bau ok +%d beli (%.2fs) | total %d baus, %d beli")
                    :format(math.floor(gain), took, HUB.stats.chests, math.floor(HUB.stats.beli)))
            else
                HUB.stats.fails += 1
                fails[p] = (fails[p] or 0) + 1
                Core.log("servidor nao contou esse bau (" .. fails[p] .. "x)")
                if fails[p] >= CFG.ChestMaxFails then
                    ignored[p] = os.clock() + CFG.ChestIgnoreTime
                    fails[p] = nil
                    Core.log("ignorando esse bau por " .. CFG.ChestIgnoreTime .. "s")
                end
            end
        end
        Feat.chestBusy = false
    end

    fullScan()
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
        if T.chest and Core.alive() then
            local ok, err = pcall(Feat.chestStep)
            if not ok then
                Feat.chestBusy = false
                Core.log("erro no bau: " .. tostring(err))
                task.wait(1)
            end
        else
            if Feat.chestStop then Feat.chestStop() end
            task.wait(0.5)
        end
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
    sg.Parent = (gethui and gethui()) or lp:WaitForChild("PlayerGui")

    local win = Instance.new("Frame", sg)
    win.Size = UDim2.fromOffset(250, 300)
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
        win.Size = body.Visible and UDim2.fromOffset(250,300) or UDim2.fromOffset(250,40)
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
    local function addTab(name)
        local btn = Instance.new("TextButton", tabs)
        btn.Size = UDim2.fromOffset(72,28); btn.Text = name
        btn.BackgroundColor3 = COL.panel; btn.TextColor3 = COL.txt
        btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
        local page = Instance.new("ScrollingFrame", pages)
        page.Size = UDim2.fromScale(1,1); page.Visible = false
        page.BackgroundTransparency = 1; page.ScrollBarThickness = 3
        page.CanvasSize = UDim2.new(); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        local lay = Instance.new("UIListLayout", page)
        lay.Padding = UDim.new(0,6); lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
        pageMap[name] = page
        btn.MouseButton1Click:Connect(function()
            for _, p in pairs(pageMap) do p.Visible = false end
            page.Visible = true
        end)
        return page
    end

    local function mkToggle(page, label, key)
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.fromOffset(210,32)
        b.BackgroundColor3 = T[key] and COL.on or COL.off
        b.Text = label..": "..(T[key] and "ON" or "OFF")
        b.TextColor3 = COL.txt; b.Font = Enum.Font.GothamMedium; b.TextSize = 13
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        b.MouseButton1Click:Connect(function()
            T[key] = not T[key]
            b.Text = label..": "..(T[key] and "ON" or "OFF")
            b.BackgroundColor3 = T[key] and COL.on or COL.off
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
        local dragging
        local function setFromX(px)
            local rel = math.clamp((px - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
            local v = min + rel*(max-min)
            v = math.floor(v/step + 0.5)*step
            CFG[cfgKey] = v; render(); Core.save()
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
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
        end)
    end

    -- aba MAIN
    local main = addTab("Main")
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
    end

    -- aba TUNE (sliders)
    local tune = addTab("Tune")
    mkSlider(tune, "Attack Range", "AttackRange", 100, 600, 10)
    mkSlider(tune, "Attack Interval", "AttackInterval", 0.05, 1, 0.05)
    mkSlider(tune, "Chest Speed", "ChestTravelSpeed", 60, 300, 10)
    mkSlider(tune, "Chest Max Wait", "ChestMaxWait", 0.4, 2.5, 0.1)
    mkSlider(tune, "Call Cooldown", "CallCooldown", 0.05, 0.5, 0.01)

    -- aba CUSTOM (verbos logados)
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
            if v ~= "" then
                table.insert(HUB.custom, { name = v, verb = v })
                addCustomBtn(v, v); Core.save()
            end
        end)
    end

    -- aba LOG (console)
    local logpage = addTab("Log")
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
        for i = math.max(1, n-18), n do table.insert(lines, Core.logLines[i]) end
        console.Text = table.concat(lines, "\n")
    end

    main.Visible = true

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
versionGuard()
buildGui()
Core.log("hub PRO carregado")
Core.log("desligar tudo: getgenv().BFHUB.alive = false")
