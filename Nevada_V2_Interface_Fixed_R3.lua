-- NEVADA V35 | EDICIÓN PREMIUM FINAL (UI Moderna + Todas las Funciones)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local requestFn = (syn and syn.request) or (http and http.request) or request or http_request

local CONFIG_FILE = "Nevada_Premium_Config.json"
local OWNER, REPO, BRANCH = "sanxsmov", "Mis-soundsp", "main"
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"
local API_ROOT = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/contents/"
local SKYBOX_REPO = "sanxsmov/Onyx-web"
local SKYBOX_RAW = "https://raw.githubusercontent.com/" .. SKYBOX_REPO .. "/main/skyboxes/"
local SKYBOX_API = "https://api.github.com/repos/" .. SKYBOX_REPO .. "/contents/skyboxes"

local state = {
    macro = false, equipDelay = 0.05, shootDelay = 0.10,
    knifeMacroEnabled = false, knifeEquipDelay = 0.10, knifeThrowDelay = 0.10,
    macro360Enabled = false, macro360Fov = 120, macro360HitChance = 100, macro360Reaction = 0, macro360Cooldown = 0.05,
    autoLoadSky = false, selectedSky = "", selectedAnim = "",
    selected = {Arma={Name="Ninguno",URL=""}, Saltar={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
    enabled = {Arma=true, Saltar=true, Matar=true}, muted = {Arma=false, Saltar=false, Matar=false},
    folder = "sounds"
}
local sounds, soundCache = {}, {}
local activeTab = nil

-- ==========================================
-- CONFIGURACIÓN
-- ==========================================
local function saveConfig()
    if not writefile then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(state) end)
    if ok then pcall(writefile, CONFIG_FILE, encoded) end
end
local function loadConfig()
    if not (readfile and isfile and isfile(CONFIG_FILE)) then return end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if ok and type(decoded) == "table" then
        for k, v in pairs(decoded) do if state[k] ~= nil then state[k] = v end end
    end
end
loadConfig()

-- ==========================================
-- ANIMACIONES GLOBALES
-- ==========================================
local Animations = {
    ["Ninguna"] = {},
    ["Zombie"] = {idle=616006778, walk=616013216, run=616010382, jump=616008936, fall=616005863},
    ["Ninja"] = {idle=656117400, walk=656121766, run=656118852, jump=656117878, fall=656115606},
    ["Robot"] = {idle=616088211, walk=616095330, run=616091570, jump=616090535, fall=616087089},
    ["Pirata"] = {idle=750781874, walk=750785693, run=750783738, jump=750782230, fall=750780242},
    ["Astronauta"] = {idle=891621366, walk=891667138, run=891636393, jump=891627522, fall=891617961},
}

local function applyAnimation(animName)
    local char = player.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    
    if animName == "Ninguna" or not Animations[animName] then
        for _, v in pairs(animate:GetDescendants()) do
            if v:IsA("Animation") then
                if v.Name == "Animation1" or v.Name == "Animation2" then v.AnimationId = "http://www.roblox.com/asset/?id=507766666"
                elseif v.Name == "WalkAnim" then v.AnimationId = "http://www.roblox.com/asset/?id=507777826"
                elseif v.Name == "RunAnim" then v.AnimationId = "http://www.roblox.com/asset/?id=507767714"
                elseif v.Name == "JumpAnim" then v.AnimationId = "http://www.roblox.com/asset/?id=507765000"
                elseif v.Name == "FallAnim" then v.AnimationId = "http://www.roblox.com/asset/?id=507767968"
                end
            end
        end
        return
    end

    local data = Animations[animName]
    for _, v in pairs(animate:GetDescendants()) do
        if v:IsA("Animation") then
            if (v.Name == "Animation1" or v.Name == "Animation2") and data.idle then v.AnimationId = "rbxassetid://" .. data.idle
            elseif v.Name == "WalkAnim" and data.walk then v.AnimationId = "rbxassetid://" .. data.walk
            elseif v.Name == "RunAnim" and data.run then v.AnimationId = "rbxassetid://" .. data.run
            elseif v.Name == "JumpAnim" and data.jump then v.AnimationId = "rbxassetid://" .. data.jump
            elseif v.Name == "FallAnim" and data.fall then v.AnimationId = "rbxassetid://" .. data.fall
            end
        end
    end
end

player.CharacterAdded:Connect(function(char)
    if state.selectedAnim and state.selectedAnim ~= "" and state.selectedAnim ~= "Ninguna" then
        task.wait(1.5)
        applyAnimation(state.selectedAnim)
    end
end)

-- ==========================================
-- SKYBOX Y DESCARGAS
-- ==========================================
local originalSky = Lighting:FindFirstChildOfClass("Sky")
local originalSkyProperties = nil
if originalSky then
    originalSkyProperties = {SkyboxBk = originalSky.SkyboxBk, SkyboxDn = originalSky.SkyboxDn, SkyboxFt = originalSky.SkyboxFt, SkyboxLf = originalSky.SkyboxLf, SkyboxRt = originalSky.SkyboxRt, SkyboxUp = originalSky.SkyboxUp}
end

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
            local sky = originalSky
            if not sky or not sky.Parent then sky = Instance.new("Sky"); sky.Parent = Lighting end
            sky.SkyboxBk = aBk; sky.SkyboxDn = aDn; sky.SkyboxFt = aFt
            sky.SkyboxLf = aLf; sky.SkyboxRt = aRt; sky.SkyboxUp = aUp
        end)
        return true
    end
    return false
end

-- ==========================================
-- TEAM CHECK Y ANTI-LOBBY
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

local function estaEnLobby()
    local character = player.Character
    if not character then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    if player.Team then
        local name = player.Team.Name:lower()
        if name:find("lobby") or name:find("spectat") or name:find("menu") then return true end
    end
    local gui = player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local frame = main and main:FindFirstChild("MainGameFrame")
    if not frame or not frame:FindFirstChild("IngameScore") then return true end
    return false
end

local function esPistola(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool:FindFirstChild("showBeam") ~= nil or tool.Name:lower():find("gun") or tool.Name:lower():find("pistol") or tool.Name:lower():find("revolver")
end

-- ==========================================
-- SILENT AIM (HOOK)
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
-- SONIDOS (GITHUB)
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
    else asset = url end
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
    local category = nil
    if id == ORIGINAL_SHOT or (obj.Name:lower():find("gun") and obj:FindFirstAncestorWhichIsA("Tool")) then category = "Arma"
    elseif id == ORIGINAL_KILL or obj.Name:lower():find("kill") then category = "Matar" end
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
  for _,folder in ipairs({"sounds", "SoundsV2"}) do if fetchFolder(folder) then loaded=true; break end end
  table.sort(sounds,function(a,b) return a.Name:lower()<b.Name:lower() end)
  return loaded
end

-- ==========================================
-- INTERFAZ PREMIUM (Optimizada)
-- ==========================================
if playerGui:FindFirstChild("NevadaPremium") then playerGui.NevadaPremium:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "NevadaPremium", false, true
gui.Parent = playerGui

local C = {bg=Color3.fromRGB(10,11,15), panel=Color3.fromRGB(15,17,22), card=Color3.fromRGB(22,25,32), edge=Color3.fromRGB(45,50,65), text=Color3.fromRGB(255,255,255), sub=Color3.fromRGB(140,150,165), accent=Color3.fromRGB(90,140,255), green=Color3.fromRGB(50,220,120), red=Color3.fromRGB(220,60,70)}
local function create(class, props, parent)
    local obj = Instance.new(class)
    for k,v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius) create("UICorner", {CornerRadius=UDim.new(0,radius or 10)}, obj) end
local function stroke(obj, color, thickness) create("UIStroke", {Color=color or C.edge, Thickness=thickness or 1, Transparency=0.2}, obj) end

-- Ventana Principal
local window = create("Frame", {Size=UDim2.new(0, 550, 0, 380), Position=UDim2.new(0.5, -275, 0.5, -190), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true}, gui)
corner(window, 15); stroke(window, C.edge, 1.5)

-- Barra Superior
local topBar = create("Frame", {Size=UDim2.new(1, 0, 0, 40), BackgroundColor3=C.panel}, window)
create("TextLabel", {Size=UDim2.new(1, -20, 1, 0), Position=UDim2.new(0, 15, 0, 0), BackgroundTransparency=1, Text="NEVADA | PREMIUM", Font=Enum.Font.GothamBold, TextSize=16, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Left}, topBar)
local close = create("TextButton", {Size=UDim2.new(0, 30, 0, 30), Position=UDim2.new(1, -35, 0, 5), BackgroundColor3=C.red, Text="X", TextColor3=C.text, Font=Enum.Font.GothamBold}, topBar)
corner(close, 6)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Sidebar (Tabs)
local sidebar = create("Frame", {Size=UDim2.new(0, 140, 1, -40), Position=UDim2.new(0, 0, 0, 40), BackgroundColor3=C.panel}, window)
create("UIListLayout", {Padding=UDim.new(0, 5), SortOrder=Enum.SortOrder.LayoutOrder, HorizontalAlignment=Enum.HorizontalAlignment.Center}, sidebar)
create("UIPadding", {PaddingTop=UDim.new(0, 10)}, sidebar)

-- Content
local content = create("Frame", {Size=UDim2.new(1, -140, 1, -40), Position=UDim2.new(0, 140, 0, 40), BackgroundTransparency=1}, window)

local pages = {}
local tabs = {}
local activeTab = nil

local function switchPage(name)
    if activeTab == name then return end
    activeTab = name
    for n, p in pairs(pages) do
        if n == name then
            p.Visible = true
            p.Position = UDim2.new(0, 20, 0, 0)
            TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 10, 0, 0)}):Play()
        else p.Visible = false end
    end
    for n, b in pairs(tabs) do
        if n == name then TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = C.accent, TextColor3 = C.text}):Play()
        else TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = C.card, TextColor3 = C.sub}):Play() end
    end
end

local function createTab(name, iconText)
    local btn = create("TextButton", {Size=UDim2.new(1, -20, 0, 35), BackgroundColor3=C.card, Text="  " .. iconText .. "  " .. name, TextColor3=C.sub, Font=Enum.Font.GothamMedium, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder = #tabs + 1}, sidebar)
    corner(btn, 8); stroke(btn, C.edge)
    tabs[name] = btn
    btn.MouseButton1Click:Connect(function() switchPage(name) end)
    
    local page = create("ScrollingFrame", {Size=UDim2.new(1, -20, 1, -10), BackgroundTransparency=1, ScrollBarThickness=3, CanvasSize=UDim2.new()}, content)
    create("UIListLayout", {Padding=UDim.new(0, 10), SortOrder=Enum.SortOrder.LayoutOrder}, page)
    pages[name] = page
    return page
end

local homePage = createTab("Inicio", "⌂")
local combatPage = createTab("Combate", "⚔")
local animPage = createTab("Animaciones", "💃")
local visualPage = createTab("Visuales", "☁")
local settingsPage = createTab("Config", "⚙")
switchPage("Inicio")

-- Helpers UI
local function addCard(parent, title, desc, height)
    local f = create("Frame", {Size=UDim2.new(1, 0, 0, height or 60), BackgroundColor3=C.card, LayoutOrder = #parent:GetChildren()}, parent)
    corner(f, 8); stroke(f, C.edge)
    create("TextLabel", {Size=UDim2.new(1, -20, 0, 20), Position=UDim2.new(0, 10, 0, 8), BackgroundTransparency=1, Text=title, Font=Enum.Font.GothamBold, TextSize=14, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, f)
    if desc then create("TextLabel", {Size=UDim2.new(1, -20, 0, 15), Position=UDim2.new(0, 10, 0, 26), BackgroundTransparency=1, Text=desc, Font=Enum.Font.Gotham, TextSize=11, TextColor3=C.sub, TextXAlignment=Enum.TextXAlignment.Left}, f) end
    return f
end

local function addToggle(parent, title, default, callback)
    local f = addCard(parent, title, nil, 40)
    local btn = create("TextButton", {Size=UDim2.new(0, 40, 0, 20), Position=UDim2.new(1, -50, 0.5, -10), BackgroundColor3=default and C.green or C.bg, Text="", AutoButtonColor=false}, f)
    corner(btn, 10)
    local isOn = default
    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = isOn and C.green or C.bg}):Play()
        callback(isOn)
        saveConfig()
    end)
    return btn
end

local function addSlider(parent, title, minV, maxV, default, callback)
    local f = addCard(parent, title..": "..tostring(default), nil, 50)
    local bar = create("Frame", {Size=UDim2.new(1, -30, 0, 4), Position=UDim2.new(0, 15, 0, 35), BackgroundColor3=C.bg}, f)
    corner(bar, 2)
    local fill = create("Frame", {Size=UDim2.new((default - minV) / (maxV - minV), 0, 1, 0), BackgroundColor3=C.accent}, bar)
    corner(fill, 2)
    local hit = create("TextButton", {Size=UDim2.new(1, 0, 1, 0), BackgroundTransparency=1, Text=""}, bar)
    local dragging = false
    local function update(input)
        local p = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor((minV + p * (maxV - minV)) * 100) / 100
        fill.Size = UDim2.new(p, 0, 1, 0)
        f:FindFirstChildOfClass("TextLabel").Text = title..": "..tostring(val)
        callback(val)
        saveConfig()
    end
    hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i) end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
end

local function addDropdown(parent, title, options, default, callback)
    local f = addCard(parent, title, nil, 40)
    local btn = create("TextButton", {Size=UDim2.new(0, 120, 0, 25), Position=UDim2.new(1, -130, 0.5, -12), BackgroundColor3=C.bg, Text=tostring(default), TextColor3=C.accent, Font=Enum.Font.GothamMedium, TextSize=12}, f)
    corner(btn, 6); stroke(btn, C.edge)
    
    local list = create("ScrollingFrame", {Size=UDim2.new(0, 120, 0, math.min(#options * 25, 100)), Position=UDim2.new(1, -130, 1, 2), BackgroundColor3=C.bg, Visible=false, ZIndex=10}, f)
    corner(list, 6); stroke(list, C.accent)
    create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder}, list)
    
    for i, opt in ipairs(options) do
        local oBtn = create("TextButton", {Size=UDim2.new(1, 0, 0, 25), BackgroundTransparency=1, Text=opt, TextColor3=C.text, Font=Enum.Font.Gotham, TextSize=11, LayoutOrder=i}, list)
        oBtn.MouseButton1Click:Connect(function()
            btn.Text = opt
            list.Visible = false
            callback(opt)
            saveConfig()
        end)
    end
    btn.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
end

-- ==========================================
-- CONSTRUCCIÓN DE PÁGINAS
-- ==========================================
addCard(homePage, "Bienvenido a Nevada Premium", "Team Check, Silent Aim, Animaciones y más.", 60)

-- COMBATE
local toggle360 = addToggle(combatPage, "Macro 360 (Silent Aim)", state.macro360Enabled, function(v) state.macro360Enabled = v; setMacro360State(v) end)
addSlider(combatPage, "FOV Size", 10, 500, state.macro360Fov, function(v) state.macro360Fov = v end)
addSlider(combatPage, "Hit Chance %", 1, 100, state.macro360HitChance, function(v) state.macro360HitChance = v end)
addSlider(combatPage, "Cooldown (s)", 0.01, 1, state.macro360Cooldown, function(v) state.macro360Cooldown = v end)
addToggle(combatPage, "Macro Cuchillo (L2)", state.knifeMacroEnabled, function(v) state.knifeMacroEnabled = v end)

-- ANIMACIONES
local animNames = {"Ninguna", "Zombie", "Ninja", "Robot", "Pirata", "Astronauta"}
addDropdown(animPage, "Cambiar Animación", animNames, state.selectedAnim ~= "" and state.selectedAnim or "Ninguna", function(opt)
    state.selectedAnim = opt
    applyAnimation(opt)
end)

-- VISUALES (Sonidos y Skybox)
local soundOptions = {"Ninguno"}
for _, s in ipairs(sounds) do table.insert(soundOptions, s.Name) end
addDropdown(visualPage, "Sonido de Disparo", soundOptions, state.selected.Arma.Name, function(opt)
    for _, s in ipairs(sounds) do if s.Name == opt then state.selected.Arma = {Name=s.Name, URL=s.URL} end end
end)
addToggle(visualPage, "Auto-Cargar Skybox", state.autoLoadSky, function(v) 
    state.autoLoadSky = v
    if v and state.selectedSky ~= "" then applySkyFromGitHub(state.selectedSky) end
end)
local skyBtn = create("TextButton", {Size=UDim2.new(1, -20, 0, 35), Position=UDim2.new(0, 10, 0, 50), BackgroundColor3=C.accent, Text="Aplicar Skybox (Aurora)", TextColor3=C.text, Font=Enum.Font.GothamBold}, visualPage:FindFirstChildOfClass("Frame"))
corner(skyBtn, 6)
skyBtn.MouseButton1Click:Connect(function()
    state.selectedSky = "aurora"
    applySkyFromGitHub("aurora")
    saveConfig()
    skyBtn.Text = "¡Aurora Aplicada!"
    task.delay(2, function() skyBtn.Text = "Aplicar Skybox (Aurora)" end)
end)

-- ==========================================
-- BOTÓN FLOTANTE Y LÓGICA MACRO 360
-- ==========================================
local floatingBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 45), Position = UDim2.new(0, 20, 0.5, 0), BackgroundColor3 = state.macro360Enabled and C.green or C.red, Text = state.macro360Enabled and "MACRO 360: ON" or "MACRO 360: OFF", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, ZIndex = 100}, gui)
corner(floatingBtn, 8); stroke(floatingBtn, state.macro360Enabled and C.green or C.red, 1, 0.5)

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

local function setMacro360State(v)
    state.macro360Enabled = v
    if floatingBtn then
        if v then
            floatingBtn.Text = "MACRO 360: ON"
            floatingBtn.BackgroundColor3 = C.green
            for _,s in pairs(floatingBtn:GetChildren()) do if s:IsA("UIStroke") then s.Color = C.green end end
        else
            floatingBtn.Text = "MACRO 360: OFF"
            floatingBtn.BackgroundColor3 = C.red
            for _,s in pairs(floatingBtn:GetChildren()) do if s:IsA("UIStroke") then s.Color = C.red end end
        end
    end
    saveConfig()
end

floatingBtn.MouseButton1Click:Connect(function() setMacro360State(not state.macro360Enabled) end)

-- BUCLE MACRO 360
task.spawn(function()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local lockedTargetPlayer = nil
    local lockedTargetPart = nil

    while task.wait(0.05) do 
        if state.macro360Enabled and not estaEnLobby() then
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local myPos = char.HumanoidRootPart.Position
            
            local targetIsValid = false
            if lockedTargetPlayer and lockedTargetPart and lockedTargetPart.Parent then
                local eHum = lockedTargetPlayer.Character and lockedTargetPlayer.Character:FindFirstChildOfClass("Humanoid")
                if eHum and eHum.Health > 0 and isEnemy(lockedTargetPlayer) then
                    local dist = (lockedTargetPart.Position - myPos).Magnitude
                    if dist <= state.macro360Fov then
                        params.FilterDescendantsInstances = { char, lockedTargetPlayer.Character }
                        local ray = workspace:Raycast(myPos, lockedTargetPart.Position - myPos, params)
                        if not ray or ray.Instance:IsDescendantOf(lockedTargetPlayer.Character) then targetIsValid = true end
                    end
                end
            end
            if not targetIsValid then lockedTargetPlayer = nil; lockedTargetPart = nil end

            if not lockedTargetPlayer then
                local bestPart, bestDist, bestP = nil, math.huge, nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local eHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if eHum and eHum.Health > 0 and not p.Character:FindFirstChildOfClass("ForceField") then
                            local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                            if dist < state.macro360Fov and dist < bestDist then
                                params.FilterDescendantsInstances = { char, p.Character }
                                local ray = workspace:Raycast(myPos, p.Character.HumanoidRootPart.Position - myPos, params)
                                if not ray then
                                    for _, part in ipairs(p.Character:GetChildren()) do
                                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Humanoid" then
                                            local partDist = (part.Position - myPos).Magnitude
                                            if partDist < bestDist then
                                                local pRay = workspace:Raycast(myPos, part.Position - myPos, params)
                                                if not pRay or pRay.Instance:IsDescendantOf(p.Character) then bestDist = partDist; bestPart = part; bestP = p end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if bestPart then lockedTargetPlayer = bestP; lockedTargetPart = bestPart end
            end

            if lockedTargetPlayer and lockedTargetPart then
                local backpack = player:FindFirstChildOfClass("Backpack")
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and not esPistola(tool) then tool = nil end
                if not tool and backpack then for _, item in ipairs(backpack:GetChildren()) do if esPistola(item) then tool = item; break end end end
                if tool then
                    if tool.Parent ~= char then hum:EquipTool(tool); task.wait(0.1) end
                    if tool.Parent == char then
                        if math.random(1, 100) <= state.macro360HitChance then
                            getgenv().NevadaTargetPart = lockedTargetPart
                            pcall(function() tool:Activate() end)
                            task.wait(0.05)
                            pcall(function() tool:Deactivate() end)
                            getgenv().NevadaTargetPart = nil
                        end
                    end
                end
                task.wait(state.macro360Cooldown)
            end
        else
            lockedTargetPlayer = nil; lockedTargetPart = nil
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:UnequipTools() end) end
        end
    end
end)

-- ==========================================
-- MACROS DE TECLADO (R2 y L2)
-- ==========================================
local macroBusy=false
local function runMacro()
  if not state.macro or macroBusy then return end
  local char=player.Character; if not char then return end
  local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
  local backpack=player:FindFirstChildOfClass("Backpack"); if not backpack then return end
  local tool=char:FindFirstChildOfClass("Tool")
  if tool and not esPistola(tool) then tool = nil end
  if not tool then for _,item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") and esPistola(item) then tool=item; break end end end
  if not tool then return end
  macroBusy=true
  task.spawn(function()
    pcall(function()
      if tool.Parent==backpack then hum:EquipTool(tool); task.wait(state.equipDelay) end
      if tool.Parent==char then tool:Activate(); task.wait(state.shootDelay); pcall(function() tool:Deactivate() end) end
      pcall(function() hum:UnequipTools() end)
    end)
    macroBusy=false
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
        if knife.Parent ~= character then humanoid:EquipTool(knife); task.wait(0.1) end
        pcall(function() knife:Activate() end)
        task.wait(state.knifeThrowDelay)
        pcall(function() if humanoid and humanoid.Parent then humanoid:UnequipTools() end end)
    end)
    knifeBusy = false
  end)
end

UserInputService.InputBegan:Connect(function(input, processed)
  if processed then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then runMacro() end
  if input.KeyCode == Enum.KeyCode.L2 then runKnifeMacro() end
end)

-- Cargar Sonidos y Skybox al iniciar
task.spawn(function()
    refreshCatalog()
    local soundOptions = {"Ninguno"}
    for _, s in ipairs(sounds) do table.insert(soundOptions, s.Name) end
    if soundDropdown then soundDropdown:Refresh(soundOptions) end
end)

if state.autoLoadSky and state.selectedSky ~= "" then
    task.spawn(function()
        task.wait(1)
        applySkyFromGitHub(state.selectedSky)
    end)
end
