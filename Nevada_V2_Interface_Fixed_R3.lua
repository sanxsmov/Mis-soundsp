-- NEVADA V8 | Skybox + Team Check + Sonidos + Silent Aim + Animaciones + Configs + AutoSave
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
-- ANIMATION PACKS
-- ==========================================
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
  macro360Enabled = false, 
  macro360Fov = 120, 
  macro360HitChance = 100, 
  macro360Reaction = 0,
  macro360Cooldown = 0.05, 
  autoLoadSky = false,
  selectedSky = "",
  selected = {Arma={Name="Ninguno",URL=""}, Saltar={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
  enabled = {Arma=true, Saltar=true, Matar=true}, muted = {Arma=false, Saltar=false, Matar=false},
  folder = FOLDERS[1],
  animEnabled = false,
  animMode = "pack",
  selectedAnimPack = "Default",
  customMix = {Idle="Default", Walk="Default", Run="Default", Jump="Default", Fall="Default", Swim="Default", SwimIdle="Default"},
}
local sounds, soundCache, activeTab, soundCategory = {}, {}, "Inicio", "Arma"

-- ==========================================
-- SISTEMA DE ANIMACIONES
-- ==========================================
local originalAnimations = nil
local animationGuards = setmetatable({}, {__mode = "k"})
local animApplyQueued = setmetatable({}, {__mode = "k"})

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

if player.Character then captureOriginalAnimations(player.Character) end

local function clearAnimationGuards()
    for anim, conn in pairs(animationGuards) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
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
        if state.animEnabled and anim.Parent and anim.AnimationId ~= target then
            anim.AnimationId = target
        end
    end)
end

local function forceAnimateReload(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animate = char and char:FindFirstChild("Animate")
    if not hum or not animate then return end
    
    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0) end)
        end
    end
    
    -- [FIX] Ya NO apagamos Animate.Enabled. Al apagarlo, los demás jugadores nos veían en T-Pose.
    -- Solo forzamos un cambio de estado para que el juego cargue las animaciones nuevas.
    if hum.Health > 0 then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Landed) end)
    end
end

local function fastApply(char, forceReload)
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
        if mix.Walk == "Default" then
            if originalAnimations and originalAnimations.Walk then guardAnimation(animate, "walk", "WalkAnim", originalAnimations.Walk:match("%d+")) end
        else local p = AnimationPacks[mix.Walk] or AnimationPacks["Default"]; guardAnimation(animate, "walk", "WalkAnim", p.Walk) end
        if mix.Run == "Default" then
            if originalAnimations and originalAnimations.Run then guardAnimation(animate, "run", "RunAnim", originalAnimations.Run:match("%d+")) end
        else local p = AnimationPacks[mix.Run] or AnimationPacks["Default"]; guardAnimation(animate, "run", "RunAnim", p.Run) end
        if mix.Jump == "Default" then
            if originalAnimations and originalAnimations.Jump then guardAnimation(animate, "jump", "JumpAnim", originalAnimations.Jump:match("%d+")) end
        else local p = AnimationPacks[mix.Jump] or AnimationPacks["Default"]; guardAnimation(animate, "jump", "JumpAnim", p.Jump) end
        if mix.Fall == "Default" then
            if originalAnimations and originalAnimations.Fall then guardAnimation(animate, "fall", "FallAnim", originalAnimations.Fall:match("%d+")) end
        else local p = AnimationPacks[mix.Fall] or AnimationPacks["Default"]; guardAnimation(animate, "fall", "FallAnim", p.Fall) end
        if mix.Swim == "Default" then
            if originalAnimations and originalAnimations.Swim then guardAnimation(animate, "swim", "Swim", originalAnimations.Swim:match("%d+")) end
        else local p = AnimationPacks[mix.Swim] or AnimationPacks["Default"]; guardAnimation(animate, "swim", "Swim", p.Swim) end
        if mix.SwimIdle == "Default" then
            if originalAnimations and originalAnimations.SwimIdle then guardAnimation(animate, "swimidle", "SwimIdle", originalAnimations.SwimIdle:match("%d+")) end
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

    if forceReload then
        task.spawn(function() forceAnimateReload(char) end)
    end
end

local function scheduleInstantApply(char)
    if not char or not char.Parent or not state.animEnabled then return end
    if animApplyQueued[char] then return end
    animApplyQueued[char] = true

    if char:FindFirstChild("Animate") then
        animApplyQueued[char] = nil
        fastApply(char, false)
        return
    end

    task.defer(function()
        animApplyQueued[char] = nil
        if char and char.Parent and state.animEnabled then
            fastApply(char, false)
        end
    end)
end

local function restoreAllOriginal()
    local char = player.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    clearAnimationGuards()
    captureOriginalAnimations(char)
    if originalAnimations then
        local function setOrig(folderName, animName, origKey)
            local folder = animate:FindFirstChild(folderName)
            if not folder then return end
            local anim = folder:FindFirstChild(animName)
            if anim and anim:IsA("Animation") and originalAnimations[origKey] then
                anim.AnimationId = originalAnimations[origKey]
            end
        end
        setOrig("idle", "Animation1", "Idle1"); setOrig("idle", "Animation2", "Idle2")
        setOrig("walk", "WalkAnim", "Walk"); setOrig("run", "RunAnim", "Run")
        setOrig("jump", "JumpAnim", "Jump"); setOrig("fall", "FallAnim", "Fall")
        setOrig("swim", "Swim", "Swim"); setOrig("swimidle", "SwimIdle", "SwimIdle")
    end
    task.spawn(function() forceAnimateReload(char) end)
end

local function onCharacterAdded(char)
    originalAnimations = nil
    if not state.animEnabled then return end

    if char:FindFirstChild("Animate") then
        fastApply(char, false)
    end

    char.ChildAdded:Connect(function(child)
        if child.Name == "Animate" and state.animEnabled and char.Parent then
            fastApply(char, false)
        end
    end)

    char.DescendantAdded:Connect(function(desc)
        if state.animEnabled and char.Parent and desc:IsA("Animation") and desc.Name == "Animation1" then
            fastApply(char, false)
        end
    end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- ==========================================
-- SKYBOX
-- ==========================================
local function downloadImg(url, name)
    if not (writefile and isfile and getcustomasset) then return nil end
    local path = "NevadaSky_" .. name .. ".png"
    if not isfile(path) then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and body and #body > 0 then pcall(writefile, path, body) else return nil end
    end
    local success, asset = pcall(getcustomasset, path)
    if success then return asset end
    return nil
end

local function applySkyFromGitHub(skyName)
    local baseUrl = SKYBOX_RAW .. skyName .. "/"
    local aBk = downloadImg(baseUrl .. "bk.png", skyName.."_bk")
    local aDn = downloadImg(baseUrl .. "dn.png", skyName.."_dn")
    local aFt = downloadImg(baseUrl .. "ft.png", skyName.."_ft")
    local aLf = downloadImg(baseUrl .. "lf.png", skyName.."_lf")
    local aRt = downloadImg(baseUrl .. "rt.png", skyName.."_rt")
    local aUp = downloadImg(baseUrl .. "up.png", skyName.."_up")
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

-- ==========================================
-- TEAM CHECK
-- ==========================================
local function getPlayerTeam(p)
    if not p then return nil end
    if p.Team and p.Team.Name ~= "" then return p.Team.Name end
    local attr = p:GetAttribute("Team") or p:GetAttribute("team")
    if attr and tostring(attr) ~= "" then return tostring(attr) end
    local gui = player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("MainGameFrame")
    local score = frame and frame:FindFirstChild("IngameScore")
    if score then
        for _, teamName in ipairs({"TeamRed", "TeamBlue"}) do
            local teamFolder = score:FindFirstChild(teamName)
            if teamFolder then
                if teamFolder:FindFirstChild(p.Name) then return teamName == "TeamRed" and "Red" or "Blue" end
                for _, entry in ipairs(teamFolder:GetChildren()) do
                    local txt = entry:FindFirstChild("PlayerName", true)
                    if txt and txt:IsA("TextLabel") and string.lower(txt.Text) == string.lower(p.Name) then
                        return teamName == "TeamRed" and "Red" or "Blue"
                    end
                end
            end
        end
    end
    return nil
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    local myTeam = getPlayerTeam(player)
    local targetTeam = getPlayerTeam(targetPlayer)
    if myTeam and targetTeam then return string.lower(myTeam) ~= string.lower(targetTeam) end
    return false
end

local function esPistola(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool:FindFirstChild("showBeam") ~= nil or tool.Name:lower():find("gun") or tool.Name:lower():find("pistol") or tool.Name:lower():find("revolver")
end

-- ==========================================
-- SILENT AIM HOOK
-- ==========================================
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

-- ==========================================
-- SONIDOS
-- ==========================================
local function playSound(url)
  if type(url) ~= "string" or url == "" then return end
  local asset = soundCache[url]
  if not asset then
    if writefile and isfile and getcustomasset then
      local name = "nevada_" .. (url:match("([^/]+)$") or "sound.mp3")
      name = name:gsub("[^%w%._%-]", "_")
      if not isfile(name) then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or type(body) ~= "string" or #body == 0 then return end
        local wrote = pcall(writefile, name, body); if not wrote then return end
      end
      local ok, result = pcall(getcustomasset, name)
      if not ok then return end
      asset = result
    else
      asset = url
    end
    soundCache[url] = asset
  end
  local s = Instance.new("Sound")
  s.SoundId, s.Volume, s.Parent = asset, 1, SoundService
  s:Play()
  s.Ended:Connect(function() s:Destroy() end)
  task.delay(20, function() if s.Parent then s:Destroy() end end)
end

local ORIGINAL_SHOT="10209603"
local ORIGINAL_KILL="296102734"
local watchedSounds=setmetatable({}, {__mode="k"})
local function watchNativeSound(obj)
  if not obj:IsA("Sound") or watchedSounds[obj] then return end
  watchedSounds[obj]=true
  local function check()
    if not obj.Parent then return end
    local id = tostring(obj.SoundId or ""):match("(%d+)")
    local n = obj.Name:lower()
    local category = nil
    if n:find("jump") or n:find("saltar") or n:find("land") or n:find("fall") then category = "Saltar"
    elseif id == ORIGINAL_SHOT or (n:find("gun") and obj:FindFirstAncestorWhichIsA("Tool")) then category = "Arma"
    elseif id == ORIGINAL_KILL or n:find("kill") then category = "Matar" end
    if not category then return end
    local custom=state.selected[category]
    if not state.enabled[category] or state.muted[category] or not custom or custom.URL=="" then return end
    pcall(function() obj.Volume=0 end)
    playSound(custom.URL)
  end
  obj.Played:Connect(check)
  if obj.IsPlaying or obj.Playing then task.defer(check) end
end
local function scanSoundTree(root)
  if not root then return end
  if root:IsA("Sound") then watchNativeSound(root) end
  for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("Sound") then watchNativeSound(obj) end end
  root.DescendantAdded:Connect(watchNativeSound)
end
scanSoundTree(workspace)
scanSoundTree(SoundService)

local lastJumpState = setmetatable({}, {__mode = "k"})
local lastJumpSoundAt = 0
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local currentState = hum:GetState()
    local isJumping = (currentState == Enum.HumanoidStateType.Jumping)
    local wasJumping = lastJumpState[char] or false
    if isJumping and not wasJumping then
        local custom = state.selected["Saltar"]
        if state.enabled["Saltar"] and not state.muted["Saltar"] and custom and custom.URL ~= "" then
            local now = os.clock()
            if now - lastJumpSoundAt > 0.15 then
                lastJumpSoundAt = now
                playSound(custom.URL)
            end
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
  table.sort(sounds,function(a,b) return a.Name:lower()<b.Name:lower() end)
  return loaded
end

-- ==========================================
-- UI
-- ==========================================
if playerGui:FindFirstChild("NevadaV2") then playerGui.NevadaV2:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "NevadaV2", false, true
gui.Parent = playerGui

local C = {bg=Color3.fromRGB(7,10,17), panel=Color3.fromRGB(10,14,23), card=Color3.fromRGB(14,19,30), edge=Color3.fromRGB(48,59,78), text=Color3.fromRGB(241,245,255), sub=Color3.fromRGB(164,177,201), blue=Color3.fromRGB(120,157,224), green=Color3.fromRGB(50,220,153), red=Color3.fromRGB(200, 50, 50)}
local function create(class, props, parent)
  local obj = Instance.new(class)
  for k,v in pairs(props or {}) do obj[k] = v end
  obj.Parent = parent
  return obj
end
local function corner(obj, radius) create("UICorner", {CornerRadius=UDim.new(0,radius or 10)}, obj) end
local function stroke(obj, color, thickness) create("UIStroke", {Color=color or C.edge, Thickness=thickness or 1, Transparency=0.2}, obj) end
local function label(parent, text, size, pos, fontSize, color, bold)
  return create("TextLabel", {BackgroundTransparency=1, Text=text, Size=size, Position=pos, Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize=fontSize or 14, TextColor3=color or C.text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextWrapped=true}, parent)
end
local function button(parent, text, size, pos, callback)
  local b=create("TextButton", {Size=size, Position=pos, BackgroundColor3=C.card, Text=text, TextColor3=C.text, Font=Enum.Font.GothamMedium, TextSize=13, AutoButtonColor=true}, parent)
  corner(b,8); stroke(b)
  if callback then b.MouseButton1Click:Connect(callback) end
  return b
end

local window, openButton
openButton = button(gui,"NEVADA",UDim2.fromOffset(94,34),UDim2.new(0,14,0.18,0),function() if window then window.Visible=true; openButton.Visible=false end end)
window = create("Frame", {Size=UDim2.new(0.94,0,0.84,0), Position=UDim2.new(0.03,0,0.08,0), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true},gui)
corner(window,16); stroke(window,C.edge,1.3)
local scale = create("UIScale", {Scale=1}, window)
local function fitScale()
  local camera=workspace.CurrentCamera; if not camera then return end
  local v=camera.ViewportSize
  scale.Scale=math.clamp(math.min(v.X/1100,v.Y/680),0.58,1)
end
fitScale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale) end

local sidebar=create("Frame",{Size=UDim2.new(0,190,1,0),BackgroundColor3=Color3.fromRGB(6,9,15),BorderSizePixel=0},window)
create("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(0,190,0,0),BackgroundColor3=C.edge,BorderSizePixel=0},window)
label(sidebar,"▲",UDim2.new(1,0,0,48),UDim2.new(0,0,0,20),29,C.text,true).TextXAlignment=Enum.TextXAlignment.Center
label(sidebar,"N E V A D A",UDim2.new(1,0,0,34),UDim2.new(0,0,0,63),21,C.text,true).TextXAlignment=Enum.TextXAlignment.Center
label(sidebar,"V8",UDim2.new(1,0,0,20),UDim2.new(0,0,0,96),12,C.sub,false).TextXAlignment=Enum.TextXAlignment.Center
local navHolder=create("Frame",{Size=UDim2.new(1,-18,0,450),Position=UDim2.new(0,9,0,140),BackgroundTransparency=1},sidebar)
create("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},navHolder)
label(sidebar,"NEVADA V8\nTu experiencia, sin límites.",UDim2.new(1,-24,0,48),UDim2.new(0,12,1,-62),11,C.sub,false)

local top=create("Frame",{Size=UDim2.new(1,-210,0,68),Position=UDim2.new(0,205,0,0),BackgroundTransparency=1},window)
label(top,"▲",UDim2.fromOffset(48,55),UDim2.new(0,0,0,4),28,C.text,true)
local pageTitle=label(top,"Bienvenido a Nevada",UDim2.new(1,-110,0,30),UDim2.new(0,54,0,10),21,C.text,true)
local pageSubtitle=label(top,"Tu hub todo en uno. Macros, sonidos y más.",UDim2.new(1,-80,0,25),UDim2.new(0,54,0,38),12,C.sub,false)
button(window,"—",UDim2.fromOffset(34,30),UDim2.new(1,-80,0,10),function() window.Visible=false; openButton.Visible=true end)
button(window,"×",UDim2.fromOffset(34,30),UDim2.new(1,-42,0,10),function() gui:Destroy() end)
openButton.Visible=false

local dragging, dragStart, startPos = false, nil, nil
top.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
    dragging=true; dragStart=input.Position; startPos=window.Position
    input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
  end
end)
UserInputService.InputChanged:Connect(function(input)
  if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
    local d=input.Position-dragStart
    window.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
  end
end)

local content=create("Frame",{Size=UDim2.new(1,-210,1,-82),Position=UDim2.new(0,205,0,72),BackgroundTransparency=1},window)
local pages={}
local function newPage(name)
  local p=create("ScrollingFrame",{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.blue,Visible=false,CanvasSize=UDim2.new()},content)
  local l=create("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},p)
  l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() p.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16) end)
  pages[name]=p; return p
end

local cardCounter = 0
local function card(parent,height)
  cardCounter = cardCounter + 1
  local f=create("Frame",{Size=UDim2.new(1,-8,0,height),BackgroundColor3=C.card,BorderSizePixel=0,LayoutOrder=cardCounter},parent)
  corner(f,11); stroke(f); return f
end
local function switch(parent,text,initial,callback)
  local row=card(parent,48)
  label(row,text,UDim2.new(1,-100,1,0),UDim2.new(0,14,0,0),14,C.text,true)
  local b
  b=button(row,initial and "ACTIVADO" or "DESACTIVADO",UDim2.fromOffset(92,30),UDim2.new(1,-104,0.5,-15),function()
    initial=not initial; b.Text=initial and "ACTIVADO" or "DESACTIVADO"; b.BackgroundColor3=initial and C.blue or C.card; callback(initial)
  end)
  b.BackgroundColor3=initial and C.blue or C.card
  return b
end
local function actionCard(parent,title,desc,btnText,fn)
  local f=card(parent,70); label(f,title,UDim2.new(0.66,0,0,27),UDim2.new(0,14,0,7),14,C.text,true); label(f,desc,UDim2.new(0.66,0,0,25),UDim2.new(0,14,0,35),11,C.sub,false)
  button(f,btnText,UDim2.fromOffset(125,34),UDim2.new(1,-139,0.5,-17),fn); return f
end
local function slider(parent,title,minV,maxV,initial,callback)
  local f=card(parent,72); local value=initial
  local txt=label(f,title..": "..tostring(value),UDim2.new(1,-24,0,25),UDim2.new(0,13,0,6),13,C.text,true)
  local bar=button(f,"",UDim2.new(1,-28,0,12),UDim2.new(0,14,0,43),function() end); bar.BackgroundColor3=Color3.fromRGB(33,42,59)
  local fill=create("Frame",{Size=UDim2.new((value-minV)/(maxV-minV),0,1,0),BackgroundColor3=C.blue,BorderSizePixel=0},bar); corner(fill,5)
  local function setFromX(x)
    local p=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1); value=math.floor((minV+p*(maxV-minV))*100)/100; fill.Size=UDim2.new(p,0,1,0); txt.Text=title..": "..tostring(value); callback(value)
  end
  bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then setFromX(i.Position.X) end end)
end

local showPage
local home=newPage("Inicio")
local welcome=card(home,108); label(welcome,"Bienvenido a Nevada",UDim2.new(1,-26,0,32),UDim2.new(0,14,0,13),20,C.text,true); label(welcome,"Tu hub todo en uno. Macros, sonidos y más.\nInterfaz Nevada V8",UDim2.new(1,-26,0,45),UDim2.new(0,14,0,51),12,C.sub,false)
actionCard(home,"Sonidos","Catálogo de tu repositorio de GitHub","Abrir sonidos",function() showPage("Sonidos") end)
actionCard(home,"Macro Arma","Disparo rápido automático","Ver macro",function() showPage("Macro") end)
actionCard(home,"Macro Cuchillo","Lanzamiento rápido (L2)","Ver macro",function() showPage("Cuchillo") end)
actionCard(home,"Macro 360","Disparo invisible a todo el cuerpo","Ver Macro 360",function() showPage("Macro360") end)
actionCard(home,"Skybox","Cambia el cielo del mapa","Ver cielos",function() showPage("Skybox") end)
actionCard(home,"Animaciones","Cambia tus animaciones o personalízalas","Ver animaciones",function() showPage("Animaciones") end)
actionCard(home,"Configs","Guarda y carga tus configuraciones","Ver configs",function() showPage("Configs") end)

local macroPage=newPage("Macro")
switch(macroPage,"Activar macro de arma",false,function(v) state.macro=v end)
slider(macroPage,"Tiempo de equipar",0.01,0.50,state.equipDelay,function(v) state.equipDelay=v end)
slider(macroPage,"Tiempo de disparo",0.01,0.50,state.shootDelay,function(v) state.shootDelay=v end)

local knifePage=newPage("Cuchillo")
switch(knifePage,"Activar Macro Cuchillo (L2)",false,function(v) state.knifeMacroEnabled = v end)
slider(knifePage,"Delay al Equipar",0.01,0.50,state.knifeEquipDelay,function(v) state.knifeEquipDelay = v end)
slider(knifePage,"Delay al Lanzar",0.01,0.50,state.knifeThrowDelay,function(v) state.knifeThrowDelay = v end)

local animsPage = newPage("Animaciones")
local animMainToggle
animMainToggle = switch(animsPage, "Activar Animaciones Custom", state.animEnabled, function(v)
    state.animEnabled = v
    if v then fastApply(player.Character, true) else restoreAllOriginal() end
end)

local packHeader = label(animsPage, "PACKS COMPLETOS", UDim2.new(1,-8,0,20), UDim2.new(0,4,0,0), 12, C.sub, true)
packHeader.LayoutOrder = 100
local packListFrame = create("Frame", {Size = UDim2.new(1, -8, 0, 0), BackgroundTransparency = 1, LayoutOrder = 101}, animsPage)
local packLayout = create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, packListFrame)
packLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    packListFrame.Size = UDim2.new(1, -8, 0, packLayout.AbsoluteContentSize.Y)
end)

local packButtons = {}
local sortedPacks = {}
for name in pairs(AnimationPacks) do
    if name ~= "Default" then table.insert(sortedPacks, name) end
end
table.sort(sortedPacks)

for i, packName in ipairs(sortedPacks) do
    local btn = button(packListFrame, "🎬 " .. packName, UDim2.new(1, 0, 0, 38), UDim2.new(), function()
        state.selectedAnimPack = packName
        state.animMode = "pack"
        state.animEnabled = true
        animMainToggle.Text = "ACTIVADO"
        animMainToggle.BackgroundColor3 = C.blue
        fastApply(player.Character, true)
        for _, b in pairs(packButtons) do b.BackgroundColor3 = C.card end
        btn.BackgroundColor3 = C.blue
    end)
    btn.LayoutOrder = i
    packButtons[packName] = btn
end

local mixHeader = label(animsPage, "PERSONALIZAR (MIX)", UDim2.new(1,-8,0,20), UDim2.new(0,4,0,0), 12, C.sub, true)
mixHeader.LayoutOrder = 200
local mixHint = label(animsPage, "Cada slot tiene 'Default' = no tocar. Toca ◀ ▶ para elegir.", UDim2.new(1,-8,0,42), UDim2.new(0,4,0,0), 11, C.sub, false)
mixHint.LayoutOrder = 201

local slotOrder = {"Idle", "Walk", "Run", "Jump", "Fall", "Swim", "SwimIdle"}
local slotDisplay = {Idle="Reposo", Walk="Caminar", Run="Correr", Jump="Saltar", Fall="Caer", Swim="Nadar", SwimIdle="Nadar (quieto)"}
local mixerOptions = {"Default"}
for name in pairs(AnimationPacks) do
    if name ~= "Default" then table.insert(mixerOptions, name) end
end
table.sort(mixerOptions)
for i, v in ipairs(mixerOptions) do if v == "Default" then table.remove(mixerOptions, i); break end end
table.insert(mixerOptions, 1, "Default")

for idx, slot in ipairs(slotOrder) do
    local f = card(animsPage, 48); f.LayoutOrder = 210 + idx
    label(f, slotDisplay[slot], UDim2.new(0.35, 0, 1, 0), UDim2.new(0, 14, 0, 0), 13, C.text, true)
    local currentVal = state.customMix[slot] or "Default"
    local currentIdx = 1
    for i, v in ipairs(mixerOptions) do if v == currentVal then currentIdx = i; break end end
    local valLabel = label(f, currentVal, UDim2.new(0.45, 0, 1, 0), UDim2.new(0.35, 0, 0, 0), 11, (currentVal == "Default") and C.sub or C.blue, true)
    valLabel.TextXAlignment = Enum.TextXAlignment.Center
    local prevBtn = button(f, "◀", UDim2.fromOffset(28, 28), UDim2.new(0.35, 4, 0.5, -14), nil)
    local nextBtn = button(f, "▶", UDim2.fromOffset(28, 28), UDim2.new(1, -32, 0.5, -14), nil)
    prevBtn.MouseButton1Click:Connect(function()
        currentIdx = currentIdx - 1; if currentIdx < 1 then currentIdx = #mixerOptions end
        state.customMix[slot] = mixerOptions[currentIdx]
        valLabel.Text = mixerOptions[currentIdx]
        valLabel.TextColor3 = (mixerOptions[currentIdx] == "Default") and C.sub or C.blue
    end)
    nextBtn.MouseButton1Click:Connect(function()
        currentIdx = currentIdx + 1; if currentIdx > #mixerOptions then currentIdx = 1 end
        state.customMix[slot] = mixerOptions[currentIdx]
        valLabel.Text = mixerOptions[currentIdx]
        valLabel.TextColor3 = (mixerOptions[currentIdx] == "Default") and C.sub or C.blue
    end)
end

local applyMixCard = actionCard(animsPage, "Aplicar combinación", "Usa las animaciones seleccionadas arriba.", "Aplicar", function()
    state.animMode = "mix"; state.animEnabled = true
    animMainToggle.Text = "ACTIVADO"; animMainToggle.BackgroundColor3 = C.blue
    fastApply(player.Character, true)
end)
applyMixCard.LayoutOrder = 300

local restoreAnimCard = actionCard(animsPage, "Restaurar Default", "Vuelve a las animaciones de TU avatar.", "Restaurar", function()
    state.animMode = "pack"; state.selectedAnimPack = "Default"; state.animEnabled = false
    animMainToggle.Text = "DESACTIVADO"; animMainToggle.BackgroundColor3 = C.card
    restoreAllOriginal()
end)
restoreAnimCard.LayoutOrder = 301

-- PÁGINA MACRO 360
local macro360Page = newPage("Macro360")
local toggle360MenuBtn = nil
local floatingBtn = nil
local function setMacro360State(nuevoEstado)
    state.macro360Enabled = nuevoEstado
    if toggle360MenuBtn then
        toggle360MenuBtn.Text = nuevoEstado and "ACTIVADO" or "DESACTIVADO"
        toggle360MenuBtn.BackgroundColor3 = nuevoEstado and C.blue or C.card
    end
    if floatingBtn then
        if nuevoEstado then
            floatingBtn.Text = "MACRO 360: ON"; floatingBtn.BackgroundColor3 = C.green
            for _,v in pairs(floatingBtn:GetChildren()) do if v:IsA("UIStroke") then v.Color = C.green end end
        else
            floatingBtn.Text = "MACRO 360: OFF"; floatingBtn.BackgroundColor3 = C.red
            for _,v in pairs(floatingBtn:GetChildren()) do if v:IsA("UIStroke") then v.Color = C.red end end
        end
    end
end
toggle360MenuBtn = switch(macro360Page, "Activar Auto Shoot / Macro 360", false, function(v) setMacro360State(v) end)
slider(macro360Page, "Tamaño del FOV", 10, 500, state.macro360Fov, function(v) state.macro360Fov = v end)
slider(macro360Page, "Probabilidad de acierto (%)", 1, 100, state.macro360HitChance, function(v) state.macro360HitChance = v end)
slider(macro360Page, "Tiempo de reacción (s)", 0, 1, state.macro360Reaction, function(v) state.macro360Reaction = v end)
slider(macro360Page, "Delay entre Disparos (s)", 0.01, 1.0, state.macro360Cooldown, function(v) state.macro360Cooldown = v end)

floatingBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 45), Position = UDim2.new(0, 20, 0.5, 0), BackgroundColor3 = C.red, Text = "MACRO 360: OFF", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, ZIndex = 100}, gui)
corner(floatingBtn, 8); stroke(floatingBtn, C.red, 1, 0.5)
local draggingBtn = false
local dragStartBtn, startPosBtn
floatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingBtn = true; dragStartBtn = input.Position; startPosBtn = floatingBtn.Position end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartBtn
        floatingBtn.Position = UDim2.new(startPosBtn.X.Scale, startPosBtn.X.Offset + delta.X, startPosBtn.Y.Scale, startPosBtn.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingBtn = false end end)
floatingBtn.MouseButton1Click:Connect(function() setMacro360State(not state.macro360Enabled) end)

-- PÁGINA SKYBOX
local skyboxPage = newPage("Skybox")
local skyInfo = card(skyboxPage, 60)
label(skyInfo, "Elige un cielo. El script buscará las carpetas de tu GitHub automáticamente.", UDim2.new(1,-24,1,-12), UDim2.new(0,12,0,6), 12, C.sub, false)

local originalSky = Lighting:FindFirstChildOfClass("Sky")
local originalSkyProperties = nil
if originalSky then
    originalSkyProperties = {
        SkyboxBk = originalSky.SkyboxBk, SkyboxDn = originalSky.SkyboxDn,
        SkyboxFt = originalSky.SkyboxFt, SkyboxLf = originalSky.SkyboxLf,
        SkyboxRt = originalSky.SkyboxRt, SkyboxUp = originalSky.SkyboxUp
    }
end
local function applySky(bk, dn, ft, lf, rt, up)
    pcall(function()
        local sky = originalSky
        if not sky or not sky.Parent then sky = Instance.new("Sky"); sky.Parent = Lighting end
        if bk then sky.SkyboxBk = bk end
        if dn then sky.SkyboxDn = dn end
        if ft then sky.SkyboxFt = ft end
        if lf then sky.SkyboxLf = lf end
        if rt then sky.SkyboxRt = rt end
        if up then sky.SkyboxUp = up end
    end)
end
switch(skyboxPage, "Auto-Cargar último cielo al entrar", false, function(v)
    state.autoLoadSky = v
    if v and state.selectedSky ~= "" then applySkyFromGitHub(state.selectedSky) end
end)
local skyList = create("ScrollingFrame", {
    Size = UDim2.new(1, -8, 0, 200),
    BackgroundColor3 = C.card, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = C.blue,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 500,
}, skyboxPage)
corner(skyList, 10); stroke(skyList, C.edge)
create("UIPadding", {PaddingTop=UDim.new(0,5), PaddingBottom=UDim.new(0,5), PaddingLeft=UDim.new(0,5), PaddingRight=UDim.new(0,5)}, skyList)
create("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder}, skyList)
local function loadSkyList()
    for _, child in ipairs(skyList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    if not requestFn then return end
    local ok, res = pcall(function() return requestFn({Url=SKYBOX_API, Method="GET", Headers={["User-Agent"]="NevadaV2"}}) end)
    if not ok or not res or res.StatusCode ~= 200 then return end
    local parsedOk, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not parsedOk or type(data) ~= "table" then return end
    for i, item in ipairs(data) do
        if item.type == "dir" then
            local skyName = item.name
            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 35),
                BackgroundColor3 = C.panel, Text = "☁ " .. skyName,
                TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13,
                LayoutOrder = i,
            }, skyList)
            corner(btn, 6); stroke(btn, C.edge)
            btn.MouseButton1Click:Connect(function()
                btn.Text = "Descargando..."
                local success = applySkyFromGitHub(skyName)
                if success then btn.Text = "✅ " .. skyName; state.selectedSky = skyName else btn.Text = "❌ Error: " .. skyName end
                task.delay(2, function() btn.Text = "☁ " .. skyName end)
            end)
        end
    end
end
task.spawn(loadSkyList)
local restoreSkyCard = actionCard(skyboxPage, "Restaurar Cielo Original", "Quita el cielo personalizado.", "Restaurar", function()
    if originalSkyProperties then
        applySky(originalSkyProperties.SkyboxBk, originalSkyProperties.SkyboxDn, originalSkyProperties.SkyboxFt, originalSkyProperties.SkyboxLf, originalSkyProperties.SkyboxRt, originalSkyProperties.SkyboxUp)
    end
    state.selectedSky = ""
end)
restoreSkyCard.LayoutOrder = 501

-- PÁGINA SONIDOS
local soundsPage=newPage("Sonidos")
local categoryBar=card(soundsPage,44)
local categoryButtons={}
local soundListFrame=card(soundsPage,330)
local listSearch=create("TextBox",{Size=UDim2.new(1,-20,0,34),Position=UDim2.new(0,10,0,9),BackgroundColor3=C.panel,Text="",PlaceholderText="Buscar sonido...",PlaceholderColor3=C.sub,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false},soundListFrame); corner(listSearch,8); stroke(listSearch)
local list=create("ScrollingFrame",{Size=UDim2.new(1,-16,1,-54),Position=UDim2.new(0,8,0,48),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new()},soundListFrame)
local listLayout=create("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},list)
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+8) end)
local soundDetails=card(soundsPage,168)
local selectedTitle=label(soundDetails,"Seleccionado: Ninguno",UDim2.new(1,-24,0,28),UDim2.new(0,12,0,8),15,C.text,true)
local selectedFile=label(soundDetails,"Archivo: —",UDim2.new(1,-24,0,24),UDim2.new(0,12,0,38),12,C.sub,false)
local function refreshDetails()
  local s=state.selected[soundCategory]; selectedTitle.Text="Seleccionado: "..s.Name; selectedFile.Text="Archivo: "..(s.URL:match("([^/]+)$") or "—")
end
local function clearSoundRows() for _,ch in ipairs(list:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end end
local function refreshSoundList()
  clearSoundRows(); local q=listSearch.Text:lower()
  for _,s in ipairs(sounds) do
    if q=="" or s.Name:lower():find(q,1,true) then
      local row=create("Frame",{Size=UDim2.new(1,-4,0,43),BackgroundColor3=C.panel,BorderSizePixel=0},list); corner(row,7)
      label(row,s.Name,UDim2.new(0.55,0,1,0),UDim2.new(0,10,0,0),13,C.text,true)
      button(row,"▶ Probar",UDim2.fromOffset(82,29),UDim2.new(1,-176,0.5,-14),function() playSound(s.URL) end)
      button(row,"Elegir",UDim2.fromOffset(76,29),UDim2.new(1,-86,0.5,-14),function()
        state.selected[soundCategory]={Name=s.Name,URL=s.URL}; refreshDetails()
      end)
    end
  end
end
listSearch:GetPropertyChangedSignal("Text"):Connect(refreshSoundList)
local function makeCategory(name,x)
  local b=button(categoryBar,name,UDim2.new(1/3,-8,0,32),UDim2.new(x,4,0.5,-16),function()
    soundCategory=name; refreshDetails(); refreshSoundList()
    for k,v in pairs(categoryButtons) do v.BackgroundColor3=(k==name) and C.blue or C.card end
  end)
  categoryButtons[name]=b
end
makeCategory("Arma",0); makeCategory("Saltar",1/3); makeCategory("Matar",2/3)
switch(soundsPage,"Activar este sonido",true,function(v) state.enabled[soundCategory]=v end)
switch(soundsPage,"Silenciar este sonido",false,function(v) state.muted[soundCategory]=v end)
local githubStatus=label(soundsPage,"Catálogo: buscando archivos MP3 en GitHub…",UDim2.new(1,-8,0,28),UDim2.new(0,4,0,0),12,C.sub,false)
githubStatus.LayoutOrder = 999
task.spawn(function()
    local loaded = refreshCatalog()
    if loaded then githubStatus.Text = "GitHub conectado · "..#sounds.." sonidos" else githubStatus.Text = "No se pudo conectar a GitHub" end
    refreshSoundList()
end)

local configPage=newPage("Configuración")
actionCard(configPage,"Actualizar catálogo","Vuelve a consultar GitHub","Actualizar",function() 
    githubStatus.Text = "Buscando..."
    task.spawn(function()
        if refreshCatalog() then githubStatus.Text = "Catálogo actualizado · "..#sounds.." sonidos" else githubStatus.Text = "Error al actualizar" end
        refreshSoundList()
    end)
end)

-- ==========================================
-- SISTEMA DE CONFIGS
-- ==========================================
local CONFIG_FOLDER = "NevadaV8_Configs"
if isfolder and not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

local function serializeV8()
    return {
        Version = "V8",
        Sonidos = {
            Selected = {
                Arma = { Name = state.selected.Arma.Name, URL = state.selected.Arma.URL },
                Saltar = { Name = state.selected.Saltar.Name, URL = state.selected.Saltar.URL },
                Matar = { Name = state.selected.Matar.Name, URL = state.selected.Matar.URL },
            },
            Enabled = { Arma = state.enabled.Arma, Saltar = state.enabled.Saltar, Matar = state.enabled.Matar },
            Muted = { Arma = state.muted.Arma, Saltar = state.muted.Saltar, Matar = state.muted.Matar },
            Folder = state.folder,
        },
        Skybox = { Selected = state.selectedSky, AutoLoad = state.autoLoadSky },
        Animaciones = {
            Enabled = state.animEnabled, Mode = state.animMode, SelectedPack = state.selectedAnimPack,
            CustomMix = {
                Idle = state.customMix.Idle, Walk = state.customMix.Walk, Run = state.customMix.Run,
                Jump = state.customMix.Jump, Fall = state.customMix.Fall,
                Swim = state.customMix.Swim, SwimIdle = state.customMix.SwimIdle,
            },
        },
        Macros = {
            Weapon = state.macro, WeaponEquipDelay = state.equipDelay, WeaponShootDelay = state.shootDelay,
            Knife = state.knifeMacroEnabled, KnifeEquipDelay = state.knifeEquipDelay, KnifeThrowDelay = state.knifeThrowDelay,
            Macro360 = state.macro360Enabled, Macro360Fov = state.macro360Fov,
            Macro360HitChance = state.macro360HitChance, Macro360Reaction = state.macro360Reaction,
            Macro360Cooldown = state.macro360Cooldown,
        },
    }
end

local function applyV8Config(data)
    if type(data) ~= "table" then return false, "Config inválida" end
    if data.Sonidos then
        if data.Sonidos.Selected then
            for cat in pairs(state.selected) do
                if data.Sonidos.Selected[cat] then
                    state.selected[cat].Name = data.Sonidos.Selected[cat].Name or "Ninguno"
                    state.selected[cat].URL = data.Sonidos.Selected[cat].URL or ""
                end
            end
        end
        if data.Sonidos.Enabled then
            for cat in pairs(state.enabled) do
                if data.Sonidos.Enabled[cat] ~= nil then state.enabled[cat] = data.Sonidos.Enabled[cat] end
            end
        end
        if data.Sonidos.Muted then
            for cat in pairs(state.muted) do
                if data.Sonidos.Muted[cat] ~= nil then state.muted[cat] = data.Sonidos.Muted[cat] end
            end
        end
        if data.Sonidos.Folder then state.folder = data.Sonidos.Folder end
    end
    if data.Skybox then
        state.selectedSky = data.Skybox.Selected or ""
        state.autoLoadSky = data.Skybox.AutoLoad == true
        if state.autoLoadSky and state.selectedSky ~= "" then
            task.spawn(function() pcall(applySkyFromGitHub, state.selectedSky) end)
        end
    end
    if data.Animaciones then
        state.animMode = data.Animaciones.Mode or "pack"
        state.selectedAnimPack = data.Animaciones.SelectedPack or "Default"
        if data.Animaciones.CustomMix then
            for slot, packName in pairs(data.Animaciones.CustomMix) do
                if state.customMix[slot] ~= nil then state.customMix[slot] = packName end
            end
        end
        state.animEnabled = data.Animaciones.Enabled == true
        if state.animEnabled then
            task.spawn(function() fastApply(player.Character, false) end)
        else
            restoreAllOriginal()
        end
    end
    if data.Macros then
        if data.Macros.Weapon ~= nil then state.macro = data.Macros.Weapon end
        if data.Macros.WeaponEquipDelay then state.equipDelay = data.Macros.WeaponEquipDelay end
        if data.Macros.WeaponShootDelay then state.shootDelay = data.Macros.WeaponShootDelay end
        if data.Macros.Knife ~= nil then state.knifeMacroEnabled = data.Macros.Knife end
        if data.Macros.KnifeEquipDelay then state.knifeEquipDelay = data.Macros.KnifeEquipDelay end
        if data.Macros.KnifeThrowDelay then state.knifeThrowDelay = data.Macros.KnifeThrowDelay end
        if data.Macros.Macro360 ~= nil then state.macro360Enabled = data.Macros.Macro360 end
        if data.Macros.Macro360Fov then state.macro360Fov = data.Macros.Macro360Fov end
        if data.Macros.Macro360HitChance then state.macro360HitChance = data.Macros.Macro360HitChance end
        if data.Macros.Macro360Reaction then state.macro360Reaction = data.Macros.Macro360Reaction end
        if data.Macros.Macro360Cooldown then state.macro360Cooldown = data.Macros.Macro360Cooldown end
    end
    return true
end

local function listV8Configs()
    local list = {}
    if listfiles and isfolder and isfolder(CONFIG_FOLDER) then
        for _, f in ipairs(listfiles(CONFIG_FOLDER)) do
            if f:match("%.json$") then
                local n = f:match("([^/\\]+)%.json$")
                if n and n ~= "_autosave" then table.insert(list, n) end
            end
        end
    end
    if #list == 0 then list = {"Ninguna"} end
    return list
end

local configsPage = newPage("Configs")
local configNameInput = "config1"
local selectedConfigName = "Ninguna"

local nameCard = card(configsPage, 60)
label(nameCard, "Nombre de la config", UDim2.new(1,-100,0,20), UDim2.new(0,14,0,6), 13, C.text, true)
label(nameCard, "Ej: aimbot_pro, farm_rapido", UDim2.new(1,-100,0,16), UDim2.new(0,14,0,28), 10, C.sub, false)
local nameInputBox = create("TextBox", {
    Size = UDim2.new(0, 90, 0, 28), Position = UDim2.new(1, -104, 0.5, -14),
    BackgroundColor3 = C.panel, Text = "config1", PlaceholderText = "nombre",
    PlaceholderColor3 = C.sub, TextColor3 = C.text,
    Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false,
}, nameCard)
corner(nameInputBox, 6); stroke(nameInputBox, C.edge)
nameInputBox:GetPropertyChangedSignal("Text"):Connect(function() configNameInput = nameInputBox.Text end)

local configDropdownHolder = card(configsPage, 60)
label(configDropdownHolder, "Configs guardadas", UDim2.new(1,-100,0,20), UDim2.new(0,14,0,6), 13, C.text, true)
label(configDropdownHolder, "Selecciona una para cargar/borrar", UDim2.new(1,-100,0,16), UDim2.new(0,14,0,28), 10, C.sub, false)
local configSelectBtn = button(configDropdownHolder, "Ninguna ▾", UDim2.new(0, 90, 0, 28), UDim2.new(1, -104, 0.5, -14), nil)
configSelectBtn.TextSize = 11

local configListFrame = create("Frame", {
    Size = UDim2.new(0, 130, 0, 0), Position = UDim2.new(1, -104, 0, 44),
    BackgroundColor3 = Color3.fromRGB(18, 20, 30), BorderSizePixel = 0,
    Visible = false, ZIndex = 50,
}, configDropdownHolder)
corner(configListFrame, 6); stroke(configListFrame, C.blue)
local configListScroll = create("ScrollingFrame", {
    Size = UDim2.fromScale(1,1), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
}, configListFrame)
create("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4)}, configListScroll)

local refreshConfigList
refreshConfigList = function()
    for _, child in ipairs(configListScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local configs = listV8Configs()
    configSelectBtn.Text = selectedConfigName .. " ▾"
    for i, name in ipairs(configs) do
        local btn = create("TextButton", {
            Size = UDim2.new(1, -4, 0, 22), BackgroundTransparency = 1,
            Text = name, TextColor3 = C.sub, Font = Enum.Font.Gotham,
            TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = i, ZIndex = 51,
        }, configListScroll)
        create("UIPadding", {PaddingLeft=UDim.new(0,6)}, btn)
        btn.MouseEnter:Connect(function() btn.TextColor3 = C.text; btn.BackgroundTransparency = 0.85 end)
        btn.MouseLeave:Connect(function() btn.TextColor3 = C.sub; btn.BackgroundTransparency = 1 end)
        btn.MouseButton1Click:Connect(function()
            selectedConfigName = name
            configSelectBtn.Text = name .. " ▾"
            configListFrame.Visible = false
        end)
    end
    local totalH = math.min(#configs * 24 + 8, 180)
    configListFrame.Size = UDim2.new(0, 130, 0, totalH)
    configListScroll.CanvasSize = UDim2.new(0, 0, 0, #configs * 24 + 8)
end
configSelectBtn.MouseButton1Click:Connect(function()
    configListFrame.Visible = not configListFrame.Visible
    if configListFrame.Visible then refreshConfigList() end
end)

local function configAction(title, desc, btnText, callback)
    local f = card(configsPage, 60)
    label(f, title, UDim2.new(0.6,0,0,22), UDim2.new(0,14,0,6), 13, C.text, true)
    label(f, desc, UDim2.new(0.6,0,0,18), UDim2.new(0,14,0,28), 10, C.sub, false)
    button(f, btnText, UDim2.fromOffset(110, 30), UDim2.new(1,-124,0.5,-15), callback)
    return f
end

configAction("Guardar", "Guarda el estado actual", "💾 Guardar", function()
    if configNameInput == "" or configNameInput == nil then print("[Config] Escribe un nombre"); return end
    local safeName = configNameInput:gsub("[^%w%-_ ]", ""):gsub("%s+", "_")
    if safeName == "" then print("[Config] Nombre inválido"); return end
    local path = CONFIG_FOLDER .. "/" .. safeName .. ".json"
    local ok, encoded = pcall(function() return HttpService:JSONEncode(serializeV8()) end)
    if not ok then print("[Config] Error al serializar"); return end
    local writeOk = pcall(writefile, path, encoded)
    if writeOk then
        print("[Config] ✅ Guardado: " .. safeName)
        selectedConfigName = safeName
        refreshConfigList()
    else
        print("[Config] ❌ Tu executor no permite writefile")
    end
end)

configAction("Cargar", "Aplica una config guardada", "📂 Cargar", function()
    if selectedConfigName == "Ninguna" or selectedConfigName == "" then print("[Config] Selecciona una config"); return end
    local path = CONFIG_FOLDER .. "/" .. selectedConfigName .. ".json"
    if not (isfile and isfile(path)) then print("[Config] No existe"); return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then print("[Config] Archivo inválido"); return end
    local applyOk, err = applyV8Config(data)
    if applyOk then print("[Config] ✅ Cargado: " .. selectedConfigName) else print("[Config] ❌ " .. tostring(err)) end
end)

configAction("Borrar", "Elimina la config seleccionada", "🗑️ Borrar", function()
    if selectedConfigName == "Ninguna" then return end
    local path = CONFIG_FOLDER .. "/" .. selectedConfigName .. ".json"
    if isfile and isfile(path) and delfile then
        pcall(delfile, path)
        print("[Config] 🗑️ Borrada: " .. selectedConfigName)
        selectedConfigName = "Ninguna"
        configSelectBtn.Text = "Ninguna ▾"
        refreshConfigList()
    end
end)

configAction("Refrescar", "Actualiza la lista de configs", "🔄 Refrescar", function()
    refreshConfigList()
    configListFrame.Visible = true
end)

configAction("Abrir carpeta", "Abre la carpeta de configs", "📁 Abrir", function()
    pcall(function() if openfolder then openfolder(CONFIG_FOLDER) end end)
end)

configAction("Borrar todas", "⚠️ Elimina TODAS las configs", "🔥 Todas", function()
    if isfolder and isfolder(CONFIG_FOLDER) and listfiles and delfile then
        local count = 0
        for _, f in ipairs(listfiles(CONFIG_FOLDER)) do
            if f:match("%.json$") then pcall(delfile, f); count = count + 1 end
        end
        print("[Config] 🔥 " .. count .. " configs borradas")
        selectedConfigName = "Ninguna"
        configSelectBtn.Text = "Ninguna ▾"
        refreshConfigList()
    end
end)

-- ==========================================
-- AUTO-SAVE / AUTO-LOAD
-- ==========================================
local AUTOSAVE_PATH = CONFIG_FOLDER .. "/_autosave.json"
local AUTOSAVE_INTERVAL = 15
local AUTO_LOAD_ENABLED = true

local function doAutoSave()
    if not (writefile and CONFIG_FOLDER) then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(serializeV8()) end)
    if ok then pcall(writefile, AUTOSAVE_PATH, encoded) end
end

task.spawn(function()
    while gui.Parent do
        task.wait(AUTOSAVE_INTERVAL)
        if gui.Parent then pcall(doAutoSave) end
    end
end)

gui.AncestryChanged:Connect(function()
    if not gui.Parent then pcall(doAutoSave) end
end)

player.CharacterRemoving:Connect(function() pcall(doAutoSave) end)

task.spawn(function()
    if not AUTO_LOAD_ENABLED then return end
    if not (isfile and readfile) then return end
    task.wait(1.5)
    if isfile(AUTOSAVE_PATH) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(AUTOSAVE_PATH)) end)
        if ok and type(data) == "table" then
            local applyOk = pcall(applyV8Config, data)
            if applyOk then
                print("[Nevada V8] ✅ Auto-config cargada")
                pcall(refreshConfigList)
            end
        end
    end
end)

local autoSection = card(configsPage, 60)
label(autoSection, "Auto-guardado", UDim2.new(1,-100,0,20), UDim2.new(0,14,0,6), 13, C.text, true)
label(autoSection, "Guarda cada " .. AUTOSAVE_INTERVAL .. "s · Carga al iniciar", UDim2.new(1,-100,0,16), UDim2.new(0,14,0,28), 10, C.sub, false)
local autoToggleState = true
local autoToggleBtn = button(autoSection, "ACTIVADO", UDim2.fromOffset(92, 28), UDim2.new(1,-104,0.5,-14), function()
    autoToggleState = not autoToggleState
    autoToggleBtn.Text = autoToggleState and "ACTIVADO" or "DESACTIVADO"
    autoToggleBtn.BackgroundColor3 = autoToggleState and C.blue or C.card
    AUTO_LOAD_ENABLED = autoToggleState
end)
autoToggleBtn.BackgroundColor3 = C.blue

local clearAutoCard = card(configsPage, 60)
label(clearAutoCard, "Borrar auto-config", UDim2.new(1,-130,0,20), UDim2.new(0,14,0,6), 13, C.text, true)
label(clearAutoCard, "Elimina _autosave.json", UDim2.new(1,-130,0,16), UDim2.new(0,14,0,28), 10, C.sub, false)
button(clearAutoCard, "🗑️ Borrar", UDim2.fromOffset(92, 28), UDim2.new(1,-104,0.5,-14), function()
    if delfile and isfile and isfile(AUTOSAVE_PATH) then
        pcall(delfile, AUTOSAVE_PATH)
        print("[Nevada V8] 🗑️ Autosave eliminado")
    end
end)

task.spawn(function() task.wait(0.5); refreshConfigList() end)

-- ==========================================
-- NAVEGACIÓN
-- ==========================================
local navNames={"Inicio","Macro","Cuchillo","Animaciones","Macro360","Sonidos","Skybox","Configuración","Configs"}
local navIcons={Inicio="⌂",Macro="◎",Cuchillo="🔪",Animaciones="🏃",Macro360="🎯",Sonidos="♫",Skybox="☁",["Configuración"]="⚙",Configs="💾"}
showPage=function(name)
  activeTab=name
  for n,p in pairs(pages) do p.Visible=(n==name) end
  pageTitle.Text=(name=="Inicio") and "Bienvenido a Nevada" or name
  pageSubtitle.Text=(name=="Inicio") and "Tu hub todo en uno." or "Nevada V8 — controles y ajustes"
  for _,obj in ipairs(navHolder:GetChildren()) do if obj:IsA("TextButton") then obj.BackgroundColor3=(obj.Name==name) and Color3.fromRGB(29,39,57) or Color3.fromRGB(6,9,15) end end
end
for i,name in ipairs(navNames) do
  local b=button(navHolder,navIcons[name].."   "..name,UDim2.new(1,0,0,43),UDim2.new(),function() showPage(name) end)
  b.Name=name; b.LayoutOrder=i; b.TextXAlignment=Enum.TextXAlignment.Left; b.TextSize=14
  b.BackgroundColor3=(name=="Inicio") and Color3.fromRGB(29,39,57) or Color3.fromRGB(6,9,15); b.Position=UDim2.new()
end
showPage("Inicio")

-- ==========================================
-- MACROS
-- ==========================================
local macroBusy = false
local function runMacro()
    if not state.macro or macroBusy then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local backpack = player:FindFirstChildOfClass("Backpack")
    local tool = char:FindFirstChildOfClass("Tool")

    -- Si no tiene pistola equipada, la busca
    if tool and not esPistola(tool) then tool = nil end
    if not tool and backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and esPistola(item) then tool = item; break end
        end
    end
    if not tool then return end

    macroBusy = true
    task.spawn(function()
        pcall(function()
            -- 1. Equipar
            if tool.Parent == backpack then
                hum:EquipTool(tool)
                task.wait(state.equipDelay + 0.05) -- Le damos un poco más de tiempo para que el servidor lo registre
            end

            -- 2. Disparar hacia donde apunta la cámara
            if tool.Parent == char then
                tool:Activate()
                task.wait(state.shootDelay)
                pcall(function() tool:Deactivate() end)
                task.wait(0.15) -- [FIX ANTI-GLITCH] Pausa vital para que no se bugee el arma
            end

            -- 3. Guardar
            pcall(function() hum:UnequipTools() end)
        end)
        macroBusy = false
    end)
end

local knifeBusy = false
local function runKnifeMacro()
  if not state.knifeMacroEnabled or knifeBusy then return end
  local character = player.Character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  local knife = nil
  for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") and item:FindFirstChild("Throw") then knife = item break end end
  if not knife and character:FindFirstChildOfClass("Backpack") then
      for _, item in ipairs(character:FindFirstChildOfClass("Backpack"):GetChildren()) do if item:IsA("Tool") and item:FindFirstChild("Throw") then knife = item break end end
  end
  if not (knife and humanoid) then return end
  knifeBusy = true
  task.spawn(function()
    pcall(function()
        if knife.Parent ~= character then humanoid:EquipTool(knife); task.wait(0.15) end
        pcall(function() knife:Activate() end)
        task.wait(state.knifeThrowDelay)
        task.wait(0.15)
        pcall(function() if humanoid and humanoid.Parent then humanoid:UnequipTools() end end)
    end)
    knifeBusy = false
  end)
end

-- [V8 FIX] Macro input táctil + PC + control
local lastMacroAt = 0
local MACRO_DEBOUNCE = 0.15
local function tryRunMacro()
    local now = tick()
    if now - lastMacroAt < MACRO_DEBOUNCE then return end
    lastMacroAt = now
    runMacro()
end
local function isTouchOnHubUI(pos)
    local ok, objs = pcall(function() return UserInputService:GetGuiObjectsAtPosition(pos.X, pos.Y) end)
    if not ok or not objs then return false end
    for _, obj in ipairs(objs) do
        if obj:IsDescendantOf(gui) then return true end
    end
    return false
end

UserInputService.InputBegan:Connect(function(input, processed)
    -- Cuchillo en Control (L2)
    if input.KeyCode == Enum.KeyCode.ButtonL2 then
        runKnifeMacro()
        return
    end

    -- Macro normal (Táctil)
    if input.UserInputType == Enum.UserInputType.Touch then
        if isTouchOnHubUI(input.Position) then return end -- No dispara si tocas el menú
        tryRunMacro()
        return
    end

    -- Macro normal (PC Mouse o Control R2)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
        tryRunMacro()
    end
end)

-- ==========================================
-- MACRO 360 (INTACTA - ANTI-SPAM)
-- ==========================================
local m360 = {wasInLobby = true, gameTicks = 0, isEquipped = false}
local function isInLobbyRobust()
    local char = player.Character
    if not char then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    if char:FindFirstChildOfClass("ForceField") then return true end
    if player.Team then
        local t = player.Team.Name:lower()
        if t:find("lobby") or t:find("spectat") or t:find("menu") or t:find("waiting") or t:find("afk") then return true end
    end
    local gui = player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("MainGameFrame")
    if not frame then return true end
    local score = frame:FindFirstChild("IngameScore")
    if not score then return true end
    if score:IsA("GuiObject") and not score.Visible then return true end
    local anyInGame = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local pHum = p.Character:FindFirstChildOfClass("Humanoid")
            if pHum and pHum.Health > 0 and not p.Character:FindFirstChildOfClass("ForceField") then
                anyInGame = true; break
            end
        end
    end
    if not anyInGame then return true end
    return false
end

local function isValid360Target(p)
    if not p or p == player then return false end
    local char = p.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end
    if not isEnemy(p) then return false end
    return true
end

local function getGun(char, backpack)
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and esPistola(tool) then return tool, true end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and esPistola(item) then return item, false end
        end
    end
    return nil, false
end

task.spawn(function()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    while task.wait(0.05) do
        if not state.macro360Enabled then
            m360.wasInLobby = true; m360.gameTicks = 0; m360.isEquipped = false
            continue
        end
        if isInLobbyRobust() then
            m360.gameTicks = 0; m360.wasInLobby = true
            if m360.isEquipped then
                local c = player.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h then pcall(function() h:UnequipTools() end) end
                m360.isEquipped = false
            end
            continue
        else
            m360.gameTicks = m360.gameTicks + 1
        end
        if m360.gameTicks < 2 then continue end
        m360.wasInLobby = false

        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not hrp then continue end

        local myPos = hrp.Position
        local bestPart, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if isValid360Target(p) then
                local enemyChar = p.Character
                local enemyHrp = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
                if enemyHrp then
                    local dist = (enemyHrp.Position - myPos).Magnitude
                    if dist <= state.macro360Fov then
                        params.FilterDescendantsInstances = { char, enemyChar }
                        local checkRay = workspace:Raycast(myPos, enemyHrp.Position - myPos, params)
                        if not checkRay then
                            for _, part in ipairs(enemyChar:GetChildren()) do
                                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Humanoid" then
                                    local partDist = (part.Position - myPos).Magnitude
                                    if partDist < bestDist then
                                        local partRay = workspace:Raycast(myPos, part.Position - myPos, params)
                                        if not partRay or partRay.Instance:IsDescendantOf(enemyChar) then
                                            bestDist = partDist; bestPart = part
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local backpack = player:FindFirstChildOfClass("Backpack")
        local tool, wasEquipped = getGun(char, backpack)

        if not bestPart then
            if m360.isEquipped then
                pcall(function() hum:UnequipTools() end)
                m360.isEquipped = false
            end
            continue
        end
        if not tool then continue end

        if not wasEquipped then
            if m360.isEquipped then continue end
            m360.isEquipped = true
            pcall(function() hum:EquipTool(tool) end)
            task.wait(0.08)
            if tool.Parent ~= char then continue end
        else
            m360.isEquipped = true
        end

        if tool.Parent == char then
            getgenv().NevadaTargetPart = bestPart
            pcall(function() tool:Activate() end)
            task.wait(0.05)
            pcall(function() tool:Deactivate() end)
            getgenv().NevadaTargetPart = nil
        end
    end
end)

print("[Nevada V8] ✅ Cargado · Macro normal, Macro 360 intacta, Auto-save activo")
