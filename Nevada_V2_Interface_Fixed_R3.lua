-- NEVADA V28 | Botón exacto de Xero + Macro Anti-Lobby
print("[Nevada] Iniciando script...")

local function CargarWindUI()
    local url = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    local exito, source = pcall(function() return game:HttpGet(url) end)
    if not exito or not source or #source < 1000 then return nil end
    local chunk, err = loadstring(source)
    if not chunk then return nil end
    local ok, ui = pcall(chunk)
    if ok and ui then return ui end
    return nil
end

local WindUI = CargarWindUI()
if not WindUI then
    game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Error", Text = "No se pudo cargar la UI."})
    return
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local requestFn = (syn and syn.request) or (http and http.request) or request or http_request

local OWNER, REPO, BRANCH = "sanxsmov", "Mis-soundsp", "main"
local FOLDERS = {"sounds", "SoundsV2"}
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"
local API_ROOT = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/contents/"
local SKYBOX_REPO = "sanxsmov/Onyx-web"
local SKYBOX_FOLDER = "skyboxes"
local SKYBOX_RAW = "https://raw.githubusercontent.com/" .. SKYBOX_REPO .. "/main/" .. SKYBOX_FOLDER .. "/"
local SKYBOX_API = "https://api.github.com/repos/" .. SKYBOX_REPO .. "/contents/" .. SKYBOX_FOLDER

-- ==========================================
-- CATÁLOGO DE TUS 5 FONDOS
-- ==========================================
local BG_LIST = {
    { name = "Fondo 1", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/1.jpg" },
    { name = "Fondo 2", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/2.jpg" },
    { name = "Fondo 3", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/3.jpg" },
    { name = "Fondo 4", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/4.jpg" },
    { name = "Fondo 5", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/5.jpg" }
}

local function CargarFondo(url)
    if not url or url == "" then return nil end
    if writefile and isfile and getcustomasset then
        local fileName = "NevadaBG_" .. tostring(math.random(1, 10000)) .. ".jpg"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and body and #body > 0 then
            pcall(writefile, fileName, body)
            local success, asset = pcall(getcustomasset, fileName)
            if success then return asset end
        end
    end
    return nil
end

local FondoAsset = CargarFondo(BG_LIST[1].url)

local AnimationPacks = {
    ["Default"]     = {Idle="507766666", Walk="507777826", Run="507767714", Jump="507765000", Fall="507767968", Swim="507784897", SwimIdle="507785072"},
    ["Hombre Lobo"] = {Idle="1083195517", Walk="1083178339", Run="1083216690", Jump="1083218792", Fall="1083189019", Swim="1083178339", SwimIdle="1083214717"},
    ["Ninja"]       = {Idle="616006778", Walk="656121766", Run="656118852", Jump="656117878", Fall="656115606", Swim="656119721", SwimIdle="656121397"},
    ["Zombie"]      = {Idle="616158929", Walk="616168032", Run="616163682", Jump="616161997", Fall="616157476", Swim="616168032", SwimIdle="616158929"},
    ["Robot"]       = {Idle="616088211", Walk="616095330", Run="616091570", Jump="616090535", Fall="616087089", Swim="616092998", SwimIdle="616094091"},
    ["Levitation"]  = {Idle="616006778", Walk="616013216", Run="616010382", Jump="616008936", Fall="616005863", Swim="616011509", SwimIdle="616012453"},
    ["Toy"]         = {Idle="10921301576", Walk="10921312010", Run="10921306285", Jump="10921308158", Fall="10921307241", Swim="10921309319", SwimIdle="10921310341"},
    ["Superhero"]   = {Idle="10921288909", Walk="10921298616", Run="10921291831", Jump="10921294559", Fall="10921293373", Swim="10921295495", SwimIdle="10921297391"},
    ["Cartoony"]    = {Idle="742637544", Walk="742640026", Run="742638842", Jump="742637942", Fall="742637151", Swim="742640026", SwimIdle="742638445"},
    ["Vampire"]     = {Idle="1083445855", Walk="1083473930", Run="1083462077", Jump="1083455352", Fall="1083443587", Swim="1083473930", SwimIdle="1083450166"},
    ["Elder"]       = {Idle="845397899", Walk="845403856", Run="845386501", Jump="845398858", Fall="845396048", Swim="845403856", SwimIdle="845400520"},
    ["Stylish"]     = {Idle="616136790", Walk="616146177", Run="616140816", Jump="616139451", Fall="616134815", Swim="616143378", SwimIdle="616138447"},
    ["Astronaut"]   = {Idle="891621366", Walk="891667138", Run="891636393", Jump="891627522", Fall="891617961", Swim="891667138", SwimIdle="891633237"},
    ["Bubbly"]      = {Idle="910004836", Walk="910034870", Run="910025107", Jump="910016857", Fall="910001910", Swim="910028158", SwimIdle="910009958"},
    ["Knight"]      = {Idle="657595757", Walk="657552124", Run="657564596", Jump="658409194", Fall="657600338", Swim="657552124", SwimIdle="657568135"},
    ["Mage"]        = {Idle="707742142", Walk="707897309", Run="707861613", Jump="707853694", Fall="707829716", Swim="707897309", SwimIdle="707855907"},
    ["Pirate"]      = {Idle="750781874", Walk="750785693", Run="750783738", Jump="750782230", Fall="750780242", Swim="750785693", SwimIdle="750782770"},
    ["Patrol"]      = {Idle="1149612882", Walk="1151231493", Run="1150967949", Jump="1148811837", Fall="1148863382", Swim="1151231493", SwimIdle="1150842221"},
    ["Confident"]   = {Idle="1069977950", Walk="1070017263", Run="1070001516", Jump="1069984524", Fall="1069973677", Swim="1070017263", SwimIdle="1069987858"},
    ["Popstar"]     = {Idle="1212900985", Walk="1212980338", Run="1212980348", Jump="1212954642", Fall="1212900995", Swim="1212980338", SwimIdle="1150842221"},
    ["Cowboy"]      = {Idle="1014390418", Walk="1014421541", Run="1014401683", Jump="1014394726", Fall="1014384571", Swim="1014421541", SwimIdle="1014398616"},
    ["Sneaky"]      = {Idle="1132473842", Walk="1132510133", Run="1132494274", Jump="1132489853", Fall="1132469004", Swim="1132510133", SwimIdle="1132477671"},
    ["Princess"]    = {Idle="941003647", Walk="941028902", Run="941015281", Jump="941008832", Fall="941000007", Swim="941028902", SwimIdle="941013098"},
}

local state = {
  macro = false, equipDelay = 0.05, shootDelay = 0.10,
  knifeMacroEnabled = false, knifeEquipDelay = 0.10, knifeThrowDelay = 0.10,
  macro360Enabled = false, macro360Fov = 120, macro360HitChance = 100, macro360Reaction = 0, macro360Cooldown = 0.05, 
  autoLoadSky = false, selectedSky = "",
  selected = {Arma={Name="Ninguno",URL=""}, Saltar={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
  enabled = {Arma=true, Saltar=true, Matar=true}, muted = {Arma=false, Saltar=false, Matar=false},
  folder = FOLDERS[1], animEnabled = false, animMode = "pack", selectedAnimPack = "Default",
  customMix = {Idle="Default", Walk="Default", Run="Default", Jump="Default", Fall="Default", Swim="Default", SwimIdle="Default"},
}
local sounds, soundCache, currentSoundCategory = {}, {}, "Arma"

-- ==========================================
-- FUNCIÓN ANTI-LOBBY ESTRICTA
-- ==========================================
local function estaEnLobby()
    local char = player.Character
    if not char then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    if char:FindFirstChildOfClass("ForceField") then return true end

    if player.Team then
        local t = player.Team.Name:lower()
        if t:find("lobby") or t:find("spectat") or t:find("menu") or t:find("waiting") or t:find("dead") then return true end
    end

    local gui = player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("MainGameFrame")
    local score = frame and frame:FindFirstChild("IngameScore")
    if not score then return true end 

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local safeZones = {
            {Center = Vector3.new(-320.50, 280.82, 16.00), Radius = 500},
            {Center = Vector3.new(1564.14, -155.45, 40.04), Radius = 300}
        }
        for _, zone in ipairs(safeZones) do
            if (hrp.Position - zone.Center).Magnitude <= zone.Radius then return true end
        end
    end
    return false
end

local originalSky = Lighting:FindFirstChildOfClass("Sky")
local originalSkyProperties = nil
if originalSky then
    originalSkyProperties = {
        SkyboxBk = originalSky.SkyboxBk, SkyboxDn = originalSky.SkyboxDn,
        SkyboxFt = originalSky.SkyboxFt, SkyboxLf = originalSky.SkyboxLf,
        SkyboxRt = originalSky.SkyboxRt, SkyboxUp = originalSky.SkyboxUp
    }
end

local originalAnimations = nil
local animationGuards = setmetatable({}, {__mode = "k"})

local function captureOriginalAnimations(char)
    char = char or player.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    if originalAnimations then return end
    local function getAnim(folderName, animName)
        local folder = animate:FindFirstChild(folderName)
        local anim = folder and folder:FindFirstChild(animName)
        if anim and anim:IsA("Animation") then return anim.AnimationId end
        return nil
    end
    originalAnimations = {
        Idle1 = getAnim("idle", "Animation1"), Idle2 = getAnim("idle", "Animation2"),
        Walk = getAnim("walk", "WalkAnim"), Run = getAnim("run", "RunAnim"),
        Jump = getAnim("jump", "JumpAnim"), Fall = getAnim("fall", "FallAnim"),
        Swim = getAnim("swim", "Swim"), SwimIdle = getAnim("swimidle", "SwimIdle"),
    }
end

local function clearAnimationGuards()
    for anim, conn in pairs(animationGuards) do if conn then pcall(function() conn:Disconnect() end) end end
    animationGuards = setmetatable({}, {__mode = "k"})
end

local function guardAnimation(animate, folderName, animName, id)
    if not id then return end
    local folder = animate:FindFirstChild(folderName)
    if not folder then return end
    local anim = folder:FindFirstChild(animName)
    if not anim or not anim:IsA("Animation") then return end
    local target = "rbxassetid://" .. tostring(id)
    if anim.AnimationId ~= target then anim.AnimationId = target end
    if animationGuards[anim] then pcall(function() animationGuards[anim]:Disconnect() end) end
    animationGuards[anim] = anim:GetPropertyChangedSignal("AnimationId"):Connect(function()
        if state.animEnabled and anim.Parent and anim.AnimationId ~= target then anim.AnimationId = target end
    end)
end

local function fastApply(char)
    if not state.animEnabled or not char or not char.Parent then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    captureOriginalAnimations(char)
    clearAnimationGuards()

    if state.animMode == "mix" then
        local mix = state.customMix
        if mix.Idle == "Default" then
            if originalAnimations then
                local id1 = originalAnimations.Idle1 and originalAnimations.Idle1:match("%d+")
                local id2 = originalAnimations.Idle2 and originalAnimations.Idle2:match("%d+")
                if id1 then guardAnimation(animate, "idle", "Animation1", id1) end
                if id2 then guardAnimation(animate, "idle", "Animation2", id2) end
            end
        else
            local p = AnimationPacks[mix.Idle] or AnimationPacks["Default"]
            guardAnimation(animate, "idle", "Animation1", p.Idle)
            guardAnimation(animate, "idle", "Animation2", p.Idle)
        end
        if mix.Walk == "Default" then if originalAnimations and originalAnimations.Walk then guardAnimation(animate, "walk", "WalkAnim", originalAnimations.Walk:match("%d+")) end
        else local p = AnimationPacks[mix.Walk] or AnimationPacks["Default"]; guardAnimation(animate, "walk", "WalkAnim", p.Walk) end
        if mix.Run == "Default" then if originalAnimations and originalAnimations.Run then guardAnimation(animate, "run", "RunAnim", originalAnimations.Run:match("%d+")) end
        else local p = AnimationPacks[mix.Run] or AnimationPacks["Default"]; guardAnimation(animate, "run", "RunAnim", p.Run) end
        if mix.Jump == "Default" then if originalAnimations and originalAnimations.Jump then guardAnimation(animate, "jump", "JumpAnim", originalAnimations.Jump:match("%d+")) end
        else local p = AnimationPacks[mix.Jump] or AnimationPacks["Default"]; guardAnimation(animate, "jump", "JumpAnim", p.Jump) end
        if mix.Fall == "Default" then if originalAnimations and originalAnimations.Fall then guardAnimation(animate, "fall", "FallAnim", originalAnimations.Fall:match("%d+")) end
        else local p = AnimationPacks[mix.Fall] or AnimationPacks["Default"]; guardAnimation(animate, "fall", "FallAnim", p.Fall) end
        if mix.Swim == "Default" then if originalAnimations and originalAnimations.Swim then guardAnimation(animate, "swim", "Swim", originalAnimations.Swim:match("%d+")) end
        else local p = AnimationPacks[mix.Swim] or AnimationPacks["Default"]; guardAnimation(animate, "swim", "Swim", p.Swim) end
        if mix.SwimIdle == "Default" then if originalAnimations and originalAnimations.SwimIdle then guardAnimation(animate, "swimidle", "SwimIdle", originalAnimations.SwimIdle:match("%d+")) end
        else local p = AnimationPacks[mix.SwimIdle] or AnimationPacks["Default"]; guardAnimation(animate, "swimidle", "SwimIdle", p.SwimIdle) end
    else
        local pack = AnimationPacks[state.selectedAnimPack] or AnimationPacks["Default"]
        guardAnimation(animate, "idle", "Animation1", pack.Idle)
        guardAnimation(animate, "idle", "Animation2", pack.Idle)
        guardAnimation(animate, "walk", "WalkAnim", pack.Walk)
        guardAnimation(animate, "run", "RunAnim", pack.Run)
        guardAnimation(animate, "jump", "JumpAnim", pack.Jump)
        guardAnimation(animate, "fall", "FallAnim", pack.Fall)
        guardAnimation(animate, "swim", "Swim", pack.Swim)
        guardAnimation(animate, "swimidle", "SwimIdle", pack.SwimIdle)
    end
end

local function restoreAllOriginal()
    local char = player.Character; if not char then return end
    local animate = char:FindFirstChild("Animate"); if not animate then return end
    clearAnimationGuards(); captureOriginalAnimations(char)
    if originalAnimations then
        local function setOrig(folderName, animName, origKey)
            local folder = animate:FindFirstChild(folderName); if not folder then return end
            local anim = folder:FindFirstChild(animName)
            if anim and anim:IsA("Animation") and originalAnimations[origKey] then anim.AnimationId = originalAnimations[origKey] end
        end
        setOrig("idle", "Animation1", "Idle1"); setOrig("idle", "Animation2", "Idle2")
        setOrig("walk", "WalkAnim", "Walk"); setOrig("run", "RunAnim", "Run")
        setOrig("jump", "JumpAnim", "Jump"); setOrig("fall", "FallAnim", "Fall")
        setOrig("swim", "Swim", "Swim"); setOrig("swimidle", "SwimIdle", "SwimIdle")
    end
end

local function onCharacterAdded(char)
    originalAnimations = nil
    if not state.animEnabled then return end
    task.spawn(function()
        char:WaitForChild("Humanoid", 5); char:WaitForChild("Animate", 5)
        task.wait(0.35)
        if char and char.Parent and state.animEnabled then fastApply(char) end
    end)
end
if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

local function downloadImg(url, name)
    if not (writefile and isfile and getcustomasset) then return nil end
    local path = "NevadaSky_" .. name .. ".png"
    if not isfile(path) then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and body and #body > 0 then pcall(writefile, path, body) else return nil end
    end
    local success, asset = pcall(getcustomasset, path); if success then return asset end
    return nil
end

local function applySkyFromGitHub(skyName)
    local baseUrl = SKYBOX_RAW .. skyName .. "/"
    local aBk = downloadImg(baseUrl .. "bk.png", skyName.."_bk"); local aDn = downloadImg(baseUrl .. "dn.png", skyName.."_dn")
    local aFt = downloadImg(baseUrl .. "ft.png", skyName.."_ft"); local aLf = downloadImg(baseUrl .. "lf.png", skyName.."_lf")
    local aRt = downloadImg(baseUrl .. "rt.png", skyName.."_rt"); local aUp = downloadImg(baseUrl .. "up.png", skyName.."_up")
    if aBk and aDn and aFt and aLf and aRt and aUp then
        pcall(function()
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
            sky.SkyboxBk=aBk; sky.SkyboxDn=aDn; sky.SkyboxFt=aFt
            sky.SkyboxLf=aLf; sky.SkyboxRt=aRt; sky.SkyboxUp=aUp
        end)
        return true
    end
    return false
end

local function getPlayerTeam(p)
    if not p then return nil end
    if p.Team and p.Team.Name ~= "" then return p.Team.Name end
    local attr = p:GetAttribute("Team") or p:GetAttribute("team")
    if attr and tostring(attr) ~= "" then return tostring(attr) end
    local gui = player:FindFirstChild("PlayerGui"); local main = gui and gui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("MainGameFrame"); local score = frame and frame:FindFirstChild("IngameScore")
    if score then
        for _, teamName in ipairs({"TeamRed", "TeamBlue"}) do
            local teamFolder = score:FindFirstChild(teamName)
            if teamFolder then
                if teamFolder:FindFirstChild(p.Name) then return teamName == "TeamRed" and "Red" or "Blue" end
                for _, entry in ipairs(teamFolder:GetChildren()) do
                    local txt = entry:FindFirstChild("PlayerName", true)
                    if txt and txt:IsA("TextLabel") and string.lower(txt.Text) == string.lower(p.Name) then return teamName == "TeamRed" and "Red" or "Blue" end
                end
            end
        end
    end
    return nil
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    local myTeam = getPlayerTeam(player); local targetTeam = getPlayerTeam(targetPlayer)
    if myTeam and targetTeam then return string.lower(myTeam) ~= string.lower(targetTeam) end
    return false
end

local function esPistola(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool:FindFirstChild("showBeam") ~= nil or tool.Name:lower():find("gun") or tool.Name:lower():find("pistol") or tool.Name:lower():find("revolver")
end

getgenv().NevadaTargetPart = nil
local oldNamecall
if hookmetamethod and getnamecallmethod and checkcaller then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and getgenv().NevadaTargetPart then
            if method == "Raycast" and self == workspace then
                local target = getgenv().NevadaTargetPart
                if target and target.Parent then
                    local origin, direction, p3 = ...
                    if typeof(direction) == "Vector3" and direction.Magnitude > 20 then
                        local camOrigin = workspace.CurrentCamera.CFrame.Position
                        if (origin - camOrigin).Magnitude >= 1 then
                            local newDir = (target.Position - origin).Unit * 5000
                            return oldNamecall(self, origin, newDir, p3)
                        end
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

local function playSound(url)
  if type(url) ~= "string" or url == "" then return end
  local asset = soundCache[url]
  if not asset then
    if writefile and isfile and getcustomasset then
      local name = "nevada_" .. (url:match("([^/]+)$") or "sound.mp3"); name = name:gsub("[^%w%._%-]", "_")
      if not isfile(name) then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or type(body) ~= "string" or #body == 0 then return end
        local wrote = pcall(writefile, name, body); if not wrote then return end
      end
      local ok, result = pcall(getcustomasset, name); if not ok then return end; asset = result
    else asset = url end
    soundCache[url] = asset
  end
  local s = Instance.new("Sound"); s.SoundId, s.Volume, s.Parent = asset, 1, SoundService
  s:Play(); s.Ended:Connect(function() s:Destroy() end); task.delay(20, function() if s.Parent then s:Destroy() end end)
end

local ORIGINAL_SHOT="10209603"; local ORIGINAL_KILL="296102734"
local watchedSounds=setmetatable({}, {__mode="k"})
local function watchNativeSound(obj)
  if not obj:IsA("Sound") or watchedSounds[obj] then return end
  watchedSounds[obj]=true
  local function check()
    if not obj.Parent then return end
    local id = tostring(obj.SoundId or ""):match("(%d+)"); local n = obj.Name:lower(); local category = nil
    if n:find("jump") or n:find("saltar") or n:find("land") or n:find("fall") then category = "Saltar"
    elseif id == ORIGINAL_SHOT or (n:find("gun") and obj:FindFirstAncestorWhichIsA("Tool")) then category = "Arma"
    elseif id == ORIGINAL_KILL or n:find("kill") then category = "Matar" end
    if not category then return end
    local custom=state.selected[category]
    if not state.enabled[category] or state.muted[category] or not custom or custom.URL=="" then return end
    pcall(function() obj.Volume=0 end); playSound(custom.URL)
  end
  obj.Played:Connect(check); if obj.IsPlaying or obj.Playing then task.defer(check) end
end
local function scanSoundTree(root)
  if not root then return end
  if root:IsA("Sound") then watchNativeSound(root) end
  for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("Sound") then watchNativeSound(obj) end end
  root.DescendantAdded:Connect(watchNativeSound)
end
scanSoundTree(workspace); scanSoundTree(SoundService)

local lastJumpState = setmetatable({}, {__mode = "k"}); local lastJumpSoundAt = 0
RunService.Heartbeat:Connect(function()
    local char = player.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local isJumping = (hum:GetState() == Enum.HumanoidStateType.Jumping); local wasJumping = lastJumpState[char] or false
    if isJumping and not wasJumping then
        local custom = state.selected["Saltar"]
        if state.enabled["Saltar"] and not state.muted["Saltar"] and custom and custom.URL ~= "" then
            local now = os.clock(); if now - lastJumpSoundAt > 0.15 then lastJumpSoundAt = now; playSound(custom.URL) end
        end
    end
    lastJumpState[char] = isJumping
end)

local function fetchFolder(folder)
  if not requestFn then return false end
  local ok,res=pcall(function() return requestFn({Url=API_ROOT..folder,Method="GET",Headers={ ["User-Agent"]="NevadaV2" }}) end)
  if not ok or not res or (res.StatusCode~=200 and res.StatusCode~=201) or type(res.Body)~="string" then return false end
  local parsedOk,data=pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not parsedOk or type(data)~="table" then return false end
  local found={}
  for _,item in ipairs(data) do
    if item.type=="file" and type(item.name)=="string" and item.name:lower():match("%.mp3$") then
      local url=item.download_url or (RAW..folder.."/"..item.name)
      table.insert(found,{Name=item.name:gsub("%.[Mm][Pp]3$",""),URL=url,File=item.name})
    end
  end
  if #found>0 then sounds=found; state.folder=folder; return true end
  return false
end

local function refreshCatalog()
  local loaded=false
  for _,folder in ipairs(FOLDERS) do if fetchFolder(folder) then loaded=true; break end end
  table.sort(sounds,function(a,b) return a.Name:lower()<b.Name:lower() end); return loaded
end

local CONFIG_FOLDER = "NevadaV28_Configs"
if isfolder and not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

local function serializeV28()
    return {
        Version = "V28",
        Sonidos = { Selected = { Arma = state.selected.Arma, Saltar = state.selected.Saltar, Matar = state.selected.Matar }, Enabled = state.enabled, Muted = state.muted },
        Skybox = { Selected = state.selectedSky, AutoLoad = state.autoLoadSky },
        Animaciones = { Enabled = state.animEnabled, Mode = state.animMode, SelectedPack = state.selectedAnimPack, CustomMix = state.customMix },
        Macros = { Weapon = state.macro, WeaponEquipDelay = state.equipDelay, WeaponShootDelay = state.shootDelay, Knife = state.knifeMacroEnabled, KnifeEquipDelay = state.knifeEquipDelay, KnifeThrowDelay = state.knifeThrowDelay, Macro360 = state.macro360Enabled, Macro360Fov = state.macro360Fov, Macro360HitChance = state.macro360HitChance, Macro360Reaction = state.macro360Reaction, Macro360Cooldown = state.macro360Cooldown },
    }
end

local function applyV28Config(data)
    if type(data) ~= "table" then return false end
    if data.Sonidos then
        if data.Sonidos.Selected then for cat in pairs(state.selected) do if data.Sonidos.Selected[cat] then state.selected[cat] = data.Sonidos.Selected[cat] end end end
        if data.Sonidos.Enabled then for cat in pairs(state.enabled) do if data.Sonidos.Enabled[cat] ~= nil then state.enabled[cat] = data.Sonidos.Enabled[cat] end end end
        if data.Sonidos.Muted then for cat in pairs(state.muted) do if data.Sonidos.Muted[cat] ~= nil then state.muted[cat] = data.Sonidos.Muted[cat] end end end
    end
    if data.Skybox then state.selectedSky = data.Skybox.Selected or ""; state.autoLoadSky = data.Skybox.AutoLoad == true end
    if data.Animaciones then
        state.animMode = data.Animaciones.Mode or "pack"; state.selectedAnimPack = data.Animaciones.SelectedPack or "Default"
        if data.Animaciones.CustomMix then for slot, pack in pairs(data.Animaciones.CustomMix) do if state.customMix[slot] ~= nil then state.customMix[slot] = pack end end end
        state.animEnabled = data.Animaciones.Enabled == true
        if state.animEnabled then task.spawn(function() fastApply(player.Character) end) else restoreAllOriginal() end
    end
    if data.Macros then for k, v in pairs(data.Macros) do if state[k] ~= nil then state[k] = v end end end
    return true
end

local function listV28Configs()
    local list = {}
    if listfiles and isfolder and isfolder(CONFIG_FOLDER) then
        for _, f in ipairs(listfiles(CONFIG_FOLDER)) do if f:match("%.json$") then local n = f:match("([^/\\]+)%.json$"); if n and n ~= "_autosave" then table.insert(list, n) end end end
    end
    if #list == 0 then list = {"Ninguna"} end
    return list
end

-- ==========================================
-- INTERFAZ WINDUI (EXACTAMENTE COMO XERO)
-- ==========================================
local Window = WindUI:CreateWindow({
    Title = "Nevada | DUELS",
    Subtitle = "by Ti",
    Theme = "Dark",
    Size = UDim2.fromOffset(620, 350),
    MinSize = Vector2.new(330, 270),
    Resizable = true,
    Transparent = false,
    Acrylic = false,
    ElementsRadius = 12,
    Background = FondoAsset,
    BackgroundImageTransparency = 0.25,
    -- AQUÍ ESTÁ EL BOTÓN DE XERO EXACTO
    OpenButton = {
        Enabled = true,
        Title = "Abri NVD",
        Icon = "rbxassetid://85755059842228",
        OnlyMobile = false,
        Draggable = true,
        Scale = 0.82,
        StrokeThickness = 1,
        Color = ColorSequence.new(Color3.fromRGB(118,118,124), Color3.fromRGB(164,164,170))
    }
})

-- Función para cambiar el fondo
local WindUI_BgCache = nil
local function findWindUIBackground()
    if WindUI_BgCache and WindUI_BgCache.Parent then return WindUI_BgCache end
    WindUI_BgCache = nil
    local best, bestSize = nil, 0
    local roots = {}
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function() local pg = player:FindFirstChild("PlayerGui"); if pg then table.insert(roots, pg) end end)

    local function scan(inst, depth)
        if depth > 10 then return end
        if inst:IsA("ImageLabel") and inst.Name == "Background" then best = inst; return end
        if inst:IsA("ImageLabel") then
            local sz = inst.AbsoluteSize.X * inst.AbsoluteSize.Y
            if sz > bestSize then bestSize = sz; best = inst end
        end
        for _, c in ipairs(inst:GetChildren()) do scan(c, depth + 1) end
    end
    for _, root in ipairs(roots) do if root then for _, c in ipairs(root:GetChildren()) do scan(c, 0) end end end
    WindUI_BgCache = best
    return best
end

local function setWindowBackground(assetId)
    if not assetId then return end
    pcall(function() if Window.SetBackground then Window:SetBackground(assetId) end end)
    pcall(function() if Window.SetBackgroundImage then Window:SetBackgroundImage(assetId) end end)
    pcall(function() if Window.Background then Window.Background = assetId end end)
    local bg = findWindUIBackground()
    if bg then
        pcall(function()
            bg.Image = assetId
            if bg.ImageTransparency > 0.6 then bg.ImageTransparency = 0.25 end
        end)
    end
end

local MainSection = Window:Section({ Title = "PRINCIPAL", Opened = true })
local PersonalSection = Window:Section({ Title = "PERSONAL", Opened = true })

local Tabs = {
    Inicio = MainSection:Tab({Title = "Inicio", Icon = "home"}),
    Macro = MainSection:Tab({Title = "Macro", Icon = "crosshair"}),
    Cuchillo = MainSection:Tab({Title = "Cuchillo", Icon = "target"}),
    Macro360 = MainSection:Tab({Title = "Macro 360", Icon = "eye"}),
    Animaciones = PersonalSection:Tab({Title = "Animaciones", Icon = "activity"}),
    Sonidos = PersonalSection:Tab({Title = "Sonidos", Icon = "volume-2"}),
    Skybox = PersonalSection:Tab({Title = "Skybox", Icon = "cloud"}),
    Configs = PersonalSection:Tab({Title = "Configs", Icon = "settings"}),
}

Tabs.Configs:Section({ Title = "Catálogo de Fondos" })
local bgNames = {}
for _, bg in ipairs(BG_LIST) do table.insert(bgNames, bg.name) end
Tabs.Configs:Dropdown({
    Title = "Selecciona un Fondo", Values = bgNames, Value = "Fondo 1",
    Callback = function(selectedName)
        for _, bg in ipairs(BG_LIST) do
            if bg.name == selectedName then
                local newAsset = CargarFondo(bg.url)
                if newAsset then setWindowBackground(newAsset) end
                break
            end
        end
    end
})

-- MACRO
Tabs.Macro:Toggle({ Title = "Activar Macro de Arma", Value = state.macro, Callback = function(v) state.macro = v end })
Tabs.Macro:Slider({ Title = "Tiempo de Equipar", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.equipDelay}, Callback = function(v) state.equipDelay = v end })
Tabs.Macro:Slider({ Title = "Tiempo de Disparo", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.shootDelay}, Callback = function(v) state.shootDelay = v end })

-- CUCHILLO
Tabs.Cuchillo:Toggle({ Title = "Activar Macro Cuchillo (L2)", Value = state.knifeMacroEnabled, Callback = function(v) state.knifeMacroEnabled = v end })
Tabs.Cuchillo:Slider({ Title = "Delay al Equipar", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.knifeEquipDelay}, Callback = function(v) state.knifeEquipDelay = v end })
Tabs.Cuchillo:Slider({ Title = "Delay al Lanzar", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.knifeThrowDelay}, Callback = function(v) state.knifeThrowDelay = v end })

-- MACRO 360
Tabs.Macro360:Toggle({ Title = "Activar Auto Shoot / Macro 360", Value = state.macro360Enabled, Callback = function(v) 
    state.macro360Enabled = v
end })
Tabs.Macro360:Slider({ Title = "Tamaño del FOV", Step = 10, Value = {Min = 10, Max = 500, Default = state.macro360Fov}, Callback = function(v) state.macro360Fov = v end })
Tabs.Macro360:Slider({ Title = "Probabilidad de acierto (%)", Step = 1, Value = {Min = 1, Max = 100, Default = state.macro360HitChance}, Callback = function(v) state.macro360HitChance = v end })
Tabs.Macro360:Slider({ Title = "Tiempo de reacción (s)", Step = 0.1, Value = {Min = 0, Max = 1, Default = state.macro360Reaction}, Callback = function(v) state.macro360Reaction = v end })
Tabs.Macro360:Slider({ Title = "Delay entre Disparos (s)", Step = 0.01, Value = {Min = 0.01, Max = 1.0, Default = state.macro360Cooldown}, Callback = function(v) state.macro360Cooldown = v end })

-- ANIMACIONES
local animToggle
animToggle = Tabs.Animaciones:Toggle({ Title = "Activar Animaciones Custom", Value = state.animEnabled, Callback = function(v) state.animEnabled = v; if v then fastApply(player.Character) else restoreAllOriginal() end end })

Tabs.Animaciones:Section({Title = "Packs Completos"})
local sortedPacks = {}
for name in pairs(AnimationPacks) do if name ~= "Default" then table.insert(sortedPacks, name) end end
table.sort(sortedPacks)

Tabs.Animaciones:Dropdown({ Title = "Selecciona un Pack", Values = sortedPacks, Value = state.selectedAnimPack, Callback = function(packName)
    state.selectedAnimPack = packName; state.animMode = "pack"; state.animEnabled = true
    if animToggle then animToggle:Set(true) end; fastApply(player.Character)
end })

Tabs.Animaciones:Section({Title = "Personalizar (Mixer)"})
local slotOrder = {"Idle", "Walk", "Run", "Jump", "Fall", "Swim", "SwimIdle"}
local slotDisplay = {Idle="Reposo", Walk="Caminar", Run="Correr", Jump="Saltar", Fall="Caer", Swim="Nadar", SwimIdle="Nadar (quieto)"}
local mixerOptions = {"Default"}
for name in pairs(AnimationPacks) do if name ~= "Default" then table.insert(mixerOptions, name) end end
table.sort(mixerOptions)
for i, v in ipairs(mixerOptions) do if v == "Default" then table.remove(mixerOptions, i); break end end
table.insert(mixerOptions, 1, "Default")

for _, slot in ipairs(slotOrder) do
    Tabs.Animaciones:Dropdown({ Title = "Mix: " .. slotDisplay[slot], Values = mixerOptions, Value = state.customMix[slot] or "Default", Callback = function(val)
        state.customMix[slot] = val; state.animMode = "mix"; state.animEnabled = true
        if animToggle then animToggle:Set(true) end; fastApply(player.Character)
    end })
end

Tabs.Animaciones:Button({ Title = "Restaurar Default", Callback = function()
    state.animMode = "pack"; state.selectedAnimPack = "Default"; state.animEnabled = false
    if animToggle then animToggle:Set(false) end; restoreAllOriginal()
end })

-- SONIDOS
local soundDropdown, enableToggle, muteToggle
local function listSoundNames()
    local names = {}
    for _, s in ipairs(sounds) do table.insert(names, s.Name) end
    if #names == 0 then names = {"Cargando..."} end
    return names
end

Tabs.Sonidos:Dropdown({ Title = "Categoría", Values = {"Arma", "Saltar", "Matar"}, Value = "Arma", Callback = function(v)
    currentSoundCategory = v
    if soundDropdown then soundDropdown:Refresh(listSoundNames()) end
    if enableToggle then enableToggle:Set(state.enabled[currentSoundCategory]) end
    if muteToggle then muteToggle:Set(state.muted[currentSoundCategory]) end
end })

soundDropdown = Tabs.Sonidos:Dropdown({ Title = "Selecciona Sonido", Values = listSoundNames(), Value = "Cargando...", Callback = function(selectedName)
    for _, s in ipairs(sounds) do if s.Name == selectedName then state.selected[currentSoundCategory] = {Name=s.Name, URL=s.URL} break end end
end })

enableToggle = Tabs.Sonidos:Toggle({ Title = "Activar este sonido", Value = state.enabled[currentSoundCategory], Callback = function(v) state.enabled[currentSoundCategory] = v end })
muteToggle = Tabs.Sonidos:Toggle({ Title = "Silenciar este sonido", Value = state.muted[currentSoundCategory], Callback = function(v) state.muted[currentSoundCategory] = v end })

Tabs.Sonidos:Button({ Title = "Actualizar Catálogo (GitHub)", Callback = function() task.spawn(function() if refreshCatalog() and soundDropdown then soundDropdown:Refresh(listSoundNames()) end end) end })
task.spawn(function() refreshCatalog(); if soundDropdown then soundDropdown:Refresh(listSoundNames()) end end)

-- SKYBOX
Tabs.Skybox:Toggle({ Title = "Auto-Cargar último cielo", Value = state.autoLoadSky, Callback = function(v) state.autoLoadSky = v; if v and state.selectedSky ~= "" then applySkyFromGitHub(state.selectedSky) end end })
Tabs.Skybox:Button({ Title = "Restaurar Cielo Original", Callback = function()
    if originalSkyProperties then
        local sky = Lighting:FindFirstChildOfClass("Sky"); if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
        sky.SkyboxBk=originalSkyProperties.SkyboxBk; sky.SkyboxDn=originalSkyProperties.SkyboxDn
        sky.SkyboxFt=originalSkyProperties.SkyboxFt; sky.SkyboxLf=originalSkyProperties.SkyboxLf
        sky.SkyboxRt=originalSkyProperties.SkyboxRt; sky.SkyboxUp=originalSkyProperties.SkyboxUp
    end
    state.selectedSky = ""
end })

task.spawn(function()
    if not requestFn then return end
    local ok, res = pcall(function() return requestFn({Url=SKYBOX_API, Method="GET", Headers={["User-Agent"]="NevadaV2"}}) end)
    if not ok or not res or res.StatusCode ~= 200 then return end
    local parsedOk, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not parsedOk or type(data) ~= "table" then return end
    local skyNames = {}
    for _, item in ipairs(data) do if item.type == "dir" then table.insert(skyNames, item.name) end end
    if #skyNames > 0 then Tabs.Skybox:Dropdown({ Title = "Selecciona un Cielo", Values = skyNames, Value = skyNames[1], Callback = function(skyName) state.selectedSky = skyName; applySkyFromGitHub(skyName) end }) end
end)

-- CONFIGS
local selectedConfigName = "Ninguna"
local configNameInput = "config1"
local configDropdown
configDropdown = Tabs.Configs:Dropdown({ Title = "Configs Guardadas", Values = listV28Configs(), Value = "Ninguna", Callback = function(v) selectedConfigName = v end })
Tabs.Configs:Input({ Title = "Nombre de la Config", Placeholder = "Ej: aimbot_pro", Callback = function(txt) configNameInput = txt end })
Tabs.Configs:Button({ Title = "💾 Guardar", Callback = function()
    if configNameInput == "" or configNameInput == nil then return end
    local safeName = configNameInput:gsub("[^%w%-_ ]", ""):gsub("%s+", "_"); if safeName == "" then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(serializeV28()) end)
    if ok then pcall(writefile, CONFIG_FOLDER .. "/" .. safeName .. ".json", encoded); if configDropdown then configDropdown:Refresh(listV28Configs()) end end
end })
Tabs.Configs:Button({ Title = "📂 Cargar", Callback = function()
    if selectedConfigName == "Ninguna" or selectedConfigName == "" then return end
    local path = CONFIG_FOLDER .. "/" .. selectedConfigName .. ".json"
    if isfile and isfile(path) then local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end); if ok and type(data) == "table" then applyV28Config(data) end end
end })
Tabs.Configs:Button({ Title = "🗑️ Borrar", Callback = function()
    if selectedConfigName == "Ninguna" then return end
    local path = CONFIG_FOLDER .. "/" .. selectedConfigName .. ".json"
    if isfile and isfile(path) and delfile then pcall(delfile, path); if configDropdown then configDropdown:Refresh(listV28Configs()) end end
end })

-- MACROS CON ANTI-LOBBY
local macroBusy=false; local lastMacro=0
local function runMacro()
  if not state.macro or macroBusy then return end
  if estaEnLobby() then
      local char = player.Character
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      if hum and char:FindFirstChildOfClass("Tool") then pcall(function() hum:UnequipTools() end) end
      return
  end

  local char=player.Character; if not char then return end
  local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
  local backpack=player:FindFirstChildOfClass("Backpack"); if not backpack then return end
  local tool=char:FindFirstChildOfClass("Tool")
  if not tool then for _,item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") and (item.name:lower():find("pistol") or item.name:lower():find("gun") or item.name:lower():find("sheriff") or item.name:lower():find("revolver")) then tool=item; break end end end
  if not tool then return end
  local now=os.clock(); if now-lastMacro< (tonumber(state.shootDelay) or 0.10) then return end
  macroBusy=true; lastMacro=now
  task.spawn(function()
    local shouldHolster=false
    pcall(function()
      if not state.macro or player.Character~=char then return end
      if tool.Parent==backpack then hum:EquipTool(tool); shouldHolster=true end
      task.wait(math.max(0.01, tonumber(state.equipDelay) or 0.05))
      if state.macro and player.Character==char and hum.Health>0 and tool.Parent==char then
        shouldHolster=true; tool:Activate(); task.wait(math.max(0.01, tonumber(state.shootDelay) or 0.10))
        pcall(function() tool:Deactivate() end); task.wait(0.15)
      end
    end)
    if shouldHolster and player.Character==char and hum.Parent==char then pcall(function() hum:UnequipTools() end) end
    macroBusy=false
  end)
end

local knifeBusy = false
local function runKnifeMacro()
  if not state.knifeMacroEnabled or knifeBusy then return end
  if estaEnLobby() then return end

  local character = player.Character; local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  local knife = nil
  for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") and item:FindFirstChild("Throw") then knife = item break end end
  if not knife and character:FindFirstChildOfClass("Backpack") then for _, item in ipairs(character:FindFirstChildOfClass("Backpack"):GetChildren()) do if item:IsA("Tool") and item:FindFirstChild("Throw") then knife = item break end end end
  if not (knife and humanoid) then return end
  knifeBusy = true
  task.spawn(function()
    pcall(function()
        if knife.Parent ~= character then humanoid:EquipTool(knife); task.wait(0.15) end
        pcall(function() knife:Activate() end); task.wait(state.knifeThrowDelay); task.wait(0.15)
        pcall(function() if humanoid and humanoid.Parent then humanoid:UnequipTools() end end)
    end)
    knifeBusy = false
  end)
end

UserInputService.InputBegan:Connect(function(input,processed)
  if processed then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then runMacro() end
  if input.KeyCode == Enum.KeyCode.ButtonL2 then runKnifeMacro() end
end)
local touchStart,touchTime=nil,nil
UserInputService.TouchStarted:Connect(function(input,processed) if processed then return end; touchStart=input.Position; touchTime=os.clock() end)
UserInputService.TouchEnded:Connect(function(input,processed)
  if processed or not touchStart or not touchTime then touchStart=nil; touchTime=nil; return end
  local delta=(input.Position-touchStart).Magnitude; local elapsed=os.clock()-touchTime
  touchStart=nil; touchTime=nil
  if delta<18 and elapsed>=0.025 and elapsed<0.6 then runMacro() end
end)

-- MACRO 360
task.spawn(function()
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
    while task.wait(0.05) do
        if not state.macro360Enabled then continue end
        local char = player.Character; if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not hrp then continue end
        local myPos = hrp.Position; local bestPart, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and isEnemy(p) and p.Character then
                local eChar = p.Character; local eHum = eChar:FindFirstChildOfClass("Humanoid"); local eHrp = eChar:FindFirstChild("HumanoidRootPart")
                if eHum and eHum.Health > 0 and eHrp then
                    local dist = (eHrp.Position - myPos).Magnitude
                    if dist <= state.macro360Fov then
                        params.FilterDescendantsInstances = {char, eChar}
                        if not workspace:Raycast(myPos, eHrp.Position - myPos, params) then
                            for _, part in ipairs(eChar:GetChildren()) do
                                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                    if part.Position:Distance(myPos) < bestDist then bestDist = part.Position:Distance(myPos); bestPart = part end
                                end
                            end
                        end
                    end
                end
            end
        end
        if bestPart then
            local backpack = player:FindFirstChildOfClass("Backpack"); local tool = char:FindFirstChildOfClass("Tool")
            if not tool and backpack then for _, item in ipairs(backpack:GetChildren()) do if esPistola(item) then tool = item break end end end
            if tool and tool.Parent == char then
                getgenv().NevadaTargetPart = bestPart
                pcall(function() tool:Activate() end); task.wait(state.macro360Cooldown)
                pcall(function() tool:Deactivate() end); getgenv().NevadaTargetPart = nil
            end
        end
    end
end)

print("[Nevada V28] ✅ Cargado correctamente.")
