-- NEVADA V36 | ESP 3D Puro + Auto-Save/Load Sin Errores
print("[Nevada] Iniciando script...")

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
-- HOOKS (NAMECALL)
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
-- CARGA DE WINDUI
-- ==========================================
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

-- ==========================================
-- ESTADO GLOBAL Y VARIABLES
-- ==========================================
local state = {
  macro = false, equipDelay = 0.05, shootDelay = 0.10,
  knifeMacroEnabled = false, knifeEquipDelay = 0.10, knifeThrowDelay = 0.10,
  macro360Enabled = false, macro360Fov = 120, macro360HitChance = 100, macro360Reaction = 0, macro360Cooldown = 0.05, 
  autoLoadSky = false, selectedSky = "",
  selected = {Arma={Name="Ninguno",URL=""}, Saltar={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
  enabled = {Arma=true, Saltar=true, Matar=true}, muted = {Arma=false, Saltar=false, Matar=false},
  folder = FOLDERS[1], animEnabled = false, animMode = "pack", selectedAnimPack = "Default",
  customMix = {Idle="Default", Walk="Default", Run="Default", Jump="Default", Fall="Default", Swim="Default", SwimIdle="Default"},
  espEnabled = false, espColor = Color3.fromRGB(255,255,255),
}
local sounds, soundCache, currentSoundCategory = {}, {}, "Arma"

local BG_LIST = {
    { name = "Fondo 1", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/1.jpg" },
    { name = "Fondo 2", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/2.jpg" },
    { name = "Fondo 3", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/3.jpg" },
    { name = "Fondo 4", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/4.jpg" },
    { name = "Fondo 5", url = "https://raw.githubusercontent.com/sanxsmov/Mis-soundsp/main/images/5.jpg" }
}

local AnimationPacks = {
    ["Default"]     = {Idle="507766666", Idle2="507766951", Walk="507777826", Run="507767714", Jump="507765000", Fall="507767968", Swim="507784897", SwimIdle="507785072"},
    ["Hombre Lobo"] = {Idle="1083195517", Idle2="1083214717", Walk="1083178339", Run="1083216690", Jump="1083218792", Fall="1083189019", Swim="1083178339", SwimIdle="1083214717"},
    ["Ninja"]       = {Idle="656117400", Idle2="656118341", Walk="656121766", Run="656118852", Jump="656117878", Fall="656115606", Swim="656119721", SwimIdle="656121397"},
    ["Zombie"]      = {Idle="616158929", Idle2="616160636", Walk="616168032", Run="616163682", Jump="616161997", Fall="616157476", Swim="616168032", SwimIdle="616158929"},
    ["Robot"]       = {Idle="616088211", Idle2="616089559", Walk="616095330", Run="616091570", Jump="616090535", Fall="616087089", Swim="616092998", SwimIdle="616094091"},
    ["Levitation"]  = {Idle="616006778", Idle2="616008087", Walk="616013216", Run="616010382", Jump="616008936", Fall="616005863", Swim="616011509", SwimIdle="616012453"},
    ["Toy"]         = {Idle="10921301576", Idle2="10921302241", Walk="10921312010", Run="10921306285", Jump="10921308158", Fall="10921307241", Swim="10921309319", SwimIdle="10921310341"},
    ["Superhero"]   = {Idle="10921288909", Idle2="10921290167", Walk="10921298616", Run="10921291831", Jump="10921294559", Fall="10921293373", Swim="10921295495", SwimIdle="10921297391"},
    ["Cartoony"]    = {Idle="742637544", Idle2="742638445", Walk="742640026", Run="742638842", Jump="742637942", Fall="742637151", Swim="742640026", SwimIdle="742638445"},
    ["Vampire"]     = {Idle="1083445855", Idle2="1083450166", Walk="1083473930", Run="1083462077", Jump="1083455352", Fall="1083443587", Swim="1083473930", SwimIdle="1083450166"},
    ["Elder"]       = {Idle="845397899", Idle2="845400520", Walk="845403856", Run="845386501", Jump="845398858", Fall="845396048", Swim="845403856", SwimIdle="845400520"},
    ["Stylish"]     = {Idle="616136790", Idle2="616138447", Walk="616146177", Run="616140816", Jump="616139451", Fall="616134815", Swim="616143378", SwimIdle="616138447"},
    ["Astronaut"]   = {Idle="891621366", Idle2="891633237", Walk="891667138", Run="891636393", Jump="891627522", Fall="891617961", Swim="891667138", SwimIdle="891633237"},
    ["Bubbly"]      = {Idle="910004836", Idle2="910009958", Walk="910034870", Run="910025107", Jump="910016857", Fall="910001910", Swim="910028158", SwimIdle="910009958"},
    ["Knight"]      = {Idle="657595757", Idle2="657568135", Walk="657552124", Run="657564596", Jump="658409194", Fall="657600338", Swim="657552124", SwimIdle="657568135"},
    ["Mage"]        = {Idle="707742142", Idle2="707855907", Walk="707897309", Run="707861613", Jump="707853694", Fall="707829716", Swim="707897309", SwimIdle="707855907"},
    ["Pirate"]      = {Idle="750781874", Idle2="750782770", Walk="750785693", Run="750783738", Jump="750782230", Fall="750780242", Swim="750785693", SwimIdle="750782770"},
    ["Patrol"]      = {Idle="1149612882", Idle2="1150842221", Walk="1151231493", Run="1150967949", Jump="1148811837", Fall="1148863382", Swim="1151231493", SwimIdle="1150842221"},
    ["Confident"]   = {Idle="1069977950", Idle2="1069987858", Walk="1070017263", Run="1070001516", Jump="1069984524", Fall="1069973677", Swim="1070017263", SwimIdle="1069987858"},
    ["Popstar"]     = {Idle="1212900985", Idle2="1150842221", Walk="1212980338", Run="1212980348", Jump="1212954642", Fall="1212900995", Swim="1212980338", SwimIdle="1150842221"},
    ["Cowboy"]      = {Idle="1014390418", Idle2="1014398616", Walk="1014421541", Run="1014401683", Jump="1014394726", Fall="1014384571", Swim="1014421541", SwimIdle="1014398616"},
    ["Sneaky"]      = {Idle="1132473842", Idle2="1132477671", Walk="1132510133", Run="1132494274", Jump="1132489853", Fall="1132469004", Swim="1132510133", SwimIdle="1132477671"},
    ["Princess"]    = {Idle="941003647", Idle2="941013098", Walk="941028902", Run="941015281", Jump="941008832", Fall="941000007", Swim="941028902", SwimIdle="941013098"},
}

-- ==========================================
-- CARGA Y GUARDADO DE CONFIGURACIÓN
-- ==========================================
local CONFIG_FOLDER = "NevadaV36_Configs"
if isfolder and not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
local AUTO_SAVE_FILE = CONFIG_FOLDER .. "/autosave.json"

local UI_Refs = {} -- Aquí guardaremos los objetos de la UI para actualizarlos

local function GetConfigData()
    return {
        macro = state.macro, equipDelay = state.equipDelay, shootDelay = state.shootDelay,
        knifeMacroEnabled = state.knifeMacroEnabled, knifeEquipDelay = state.knifeEquipDelay, knifeThrowDelay = state.knifeThrowDelay,
        macro360Enabled = state.macro360Enabled, macro360Fov = state.macro360Fov, macro360HitChance = state.macro360HitChance,
        macro360Reaction = state.macro360Reaction, macro360Cooldown = state.macro360Cooldown,
        espEnabled = state.espEnabled, espColor = {R=state.espColor.R, G=state.espColor.G, B=state.espColor.B},
        animEnabled = state.animEnabled, animMode = state.animMode, selectedAnimPack = state.selectedAnimPack,
        customMix = state.customMix, selected = state.selected, enabled = state.enabled, muted = state.muted,
        autoLoadSky = state.autoLoadSky, selectedSky = state.selectedSky
    }
end

local function SaveAutoConfig()
    if not writefile then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(GetConfigData()) end)
    if ok then pcall(writefile, AUTO_SAVE_FILE, encoded) end
end

local function LoadAutoConfig()
    if not isfile or not isfile(AUTO_SAVE_FILE) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(AUTO_SAVE_FILE)) end)
    if not ok or type(data) ~= "table" then return false end

    -- Aplicar a las variables internas
    for k, v in pairs(data) do
        if k == "espColor" then
            state.espColor = Color3.new(v.R, v.G, v.B)
        elseif k == "customMix" or k == "selected" or k == "enabled" or k == "muted" then
            for subK, subV in pairs(v) do state[k][subK] = subV end
        else
            state[k] = v
        end
    end
    return true
end

-- ==========================================
-- FUNCIONES AUXILIARES
-- ==========================================
local function CargarFondo(url)
    if not url or url == "" then return nil end
    if writefile and isfile and getcustomasset then
        local fileName = "NevadaBG_" .. tostring(url:match("([^/]+)$") or "default.jpg")
        if not isfile(fileName) then
            local ok, body = pcall(function() return game:HttpGet(url) end)
            if ok and body and #body > 0 then pcall(writefile, fileName, body) else return nil end
        end
        local success, asset = pcall(getcustomasset, fileName)
        if success then return asset end
    end
    return nil
end

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

-- ==========================================
-- ESP 3D (COMO XERO)
-- ==========================================
local espFolder = Instance.new("Folder")
espFolder.Name = "NevadaESP"
espFolder.Parent = game:GetService("CoreGui")
local activeHighlights = {}

local function update3DESP()
    if not state.espEnabled or estaEnLobby() then
        for p, hl in pairs(activeHighlights) do hl:Destroy() end
        activeHighlights = {}
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local char = p.Character
            if not activeHighlights[p] or not activeHighlights[p].Parent then
                local hl = Instance.new("Highlight")
                hl.Name = p.Name .. "_ESP"
                hl.FillColor = state.espColor
                hl.OutlineColor = state.espColor
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 1
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = char
                hl.Parent = espFolder
                activeHighlights[p] = hl
            else
                activeHighlights[p].Adornee = char
                activeHighlights[p].FillColor = state.espColor
                activeHighlights[p].OutlineColor = state.espColor
            end
        elseif activeHighlights[p] then
            activeHighlights[p]:Destroy()
            activeHighlights[p] = nil
        end
    end
end

task.spawn(function() while task.wait(0.5) do pcall(update3DESP) end end)

-- ==========================================
-- CREACIÓN DE LA INTERFAZ (WINDUI)
-- ==========================================
local FondoAsset = CargarFondo(BG_LIST[1].url)

local Window = WindUI:CreateWindow({
    Title = "Nevada | DUELS", Author = "by Ti", Theme = "Dark",
    Size = UDim2.fromOffset(620, 350), MinSize = Vector2.new(330, 270),
    Resizable = true, Transparent = false, Acrylic = false, ElementsRadius = 12,
    Background = FondoAsset, BackgroundImageTransparency = 0.25,
    OpenButton = { Enabled = true, Title = "Abrir NVD", Icon = "rbxassetid://85755059842228", OnlyMobile = false, Draggable = true, Scale = 0.82, StrokeThickness = 1, Color = ColorSequence.new(Color3.fromRGB(118,118,124), Color3.fromRGB(164,164,170)) }
})

local MainSection = Window:Section({ Title = "PRINCIPAL", Opened = true })
local PersonalSection = Window:Section({ Title = "PERSONAL", Opened = true })

local Tabs = {
    Inicio = MainSection:Tab({Title = "Inicio", Icon = "home"}),
    Macro = MainSection:Tab({Title = "Macro", Icon = "crosshair"}),
    Cuchillo = MainSection:Tab({Title = "Cuchillo", Icon = "target"}),
    Macro360 = MainSection:Tab({Title = "Macro 360", Icon = "eye"}),
    Visuales = MainSection:Tab({Title = "Visuales", Icon = "eye"}),
    Animaciones = PersonalSection:Tab({Title = "Animaciones", Icon = "activity"}),
    Sonidos = PersonalSection:Tab({Title = "Sonidos", Icon = "volume-2"}),
    Skybox = PersonalSection:Tab({Title = "Skybox", Icon = "cloud"}),
    Configs = PersonalSection:Tab({Title = "Configs", Icon = "settings"}),
}

-- Llenar los UI_Refs para poder actualizarlos después
UI_Refs.macro = Tabs.Macro:Toggle({ Title = "Activar Macro de Arma", Value = state.macro, Callback = function(v) state.macro = v; SaveAutoConfig() end })
UI_Refs.equipDelay = Tabs.Macro:Slider({ Title = "Tiempo de Equipar", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.equipDelay}, Callback = function(v) state.equipDelay = v; SaveAutoConfig() end })
UI_Refs.shootDelay = Tabs.Macro:Slider({ Title = "Tiempo de Disparo", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.shootDelay}, Callback = function(v) state.shootDelay = v; SaveAutoConfig() end })

UI_Refs.knifeMacroEnabled = Tabs.Cuchillo:Toggle({ Title = "Activar Macro Cuchillo (L2)", Value = state.knifeMacroEnabled, Callback = function(v) state.knifeMacroEnabled = v; SaveAutoConfig() end })
UI_Refs.knifeEquipDelay = Tabs.Cuchillo:Slider({ Title = "Delay al Equipar", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.knifeEquipDelay}, Callback = function(v) state.knifeEquipDelay = v; SaveAutoConfig() end })
UI_Refs.knifeThrowDelay = Tabs.Cuchillo:Slider({ Title = "Delay al Lanzar", Step = 0.01, Value = {Min = 0.01, Max = 0.50, Default = state.knifeThrowDelay}, Callback = function(v) state.knifeThrowDelay = v; SaveAutoConfig() end })

UI_Refs.macro360Enabled = Tabs.Macro360:Toggle({ Title = "Activar Auto Shoot / Macro 360", Value = state.macro360Enabled, Callback = function(v) state.macro360Enabled = v; SaveAutoConfig() end })
UI_Refs.macro360Fov = Tabs.Macro360:Slider({ Title = "Tamaño del FOV", Step = 10, Value = {Min = 10, Max = 500, Default = state.macro360Fov}, Callback = function(v) state.macro360Fov = v; SaveAutoConfig() end })
UI_Refs.macro360HitChance = Tabs.Macro360:Slider({ Title = "Probabilidad de acierto (%)", Step = 1, Value = {Min = 1, Max = 100, Default = state.macro360HitChance}, Callback = function(v) state.macro360HitChance = v; SaveAutoConfig() end })
UI_Refs.macro360Reaction = Tabs.Macro360:Slider({ Title = "Tiempo de reacción (s)", Step = 0.1, Value = {Min = 0, Max = 1, Default = state.macro360Reaction}, Callback = function(v) state.macro360Reaction = v; SaveAutoConfig() end })
UI_Refs.macro360Cooldown = Tabs.Macro360:Slider({ Title = "Delay entre Disparos (s)", Step = 0.01, Value = {Min = 0.01, Max = 1.0, Default = state.macro360Cooldown}, Callback = function(v) state.macro360Cooldown = v; SaveAutoConfig() end })

UI_Refs.espEnabled = Tabs.Visuales:Toggle({ Title = "Activar ESP 3D", Value = state.espEnabled, Callback = function(v) state.espEnabled = v; SaveAutoConfig() end })
UI_Refs.espColor = Tabs.Visuales:Colorpicker({ Title = "Color del ESP", Default = state.espColor, Callback = function(c) state.espColor = c; SaveAutoConfig() end })

Tabs.Configs:Button({ Title = "🗑️ Borrar Auto-Save", Callback = function()
    if isfile and isfile(AUTO_SAVE_FILE) then pcall(delfile, AUTO_SAVE_FILE); game:GetService("StarterGui"):SetCore("SendNotification", {Title="Nevada", Text="Auto-Save borrado. Reinicia el script."}) end
end })

-- ==========================================
-- CARGAR DATOS GUARDADOS Y ACTUALIZAR LA UI
-- ==========================================
local hasLoaded = LoadAutoConfig()
if hasLoaded then
    print("[Nevada] Auto-Save cargado exitosamente. Actualizando UI...")
    -- Actualizamos los elementos visuales (Toggles, Sliders, Colors)
    pcall(function() UI_Refs.macro:Set(state.macro) end)
    pcall(function() UI_Refs.equipDelay:Set(state.equipDelay) end)
    pcall(function() UI_Refs.shootDelay:Set(state.shootDelay) end)
    pcall(function() UI_Refs.knifeMacroEnabled:Set(state.knifeMacroEnabled) end)
    pcall(function() UI_Refs.knifeEquipDelay:Set(state.knifeEquipDelay) end)
    pcall(function() UI_Refs.knifeThrowDelay:Set(state.knifeThrowDelay) end)
    pcall(function() UI_Refs.macro360Enabled:Set(state.macro360Enabled) end)
    pcall(function() UI_Refs.macro360Fov:Set(state.macro360Fov) end)
    pcall(function() UI_Refs.macro360HitChance:Set(state.macro360HitChance) end)
    pcall(function() UI_Refs.macro360Reaction:Set(state.macro360Reaction) end)
    pcall(function() UI_Refs.macro360Cooldown:Set(state.macro360Cooldown) end)
    pcall(function() UI_Refs.espEnabled:Set(state.espEnabled) end)
    pcall(function() UI_Refs.espColor:Set(state.espColor) end)
    
    -- Actualizamos el botón flotante 360 si estaba activo
    if state.macro360Enabled then
        -- Si tienes un botón flotante, actualízalo aquí visualmente
    end
else
    print("[Nevada] No hay Auto-Save previo. Usando valores por defecto.")
end

-- ==========================================
-- BOTÓN FLOTANTE MACRO 360
-- ==========================================
local buttonGui = Instance.new("ScreenGui")
buttonGui.Name = "Nevada360Gui"
buttonGui.ResetOnSpawn = false
buttonGui.IgnoreGuiInset = true
buttonGui.DisplayOrder = 999
buttonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiParent = playerGui
pcall(function()
    if gethui then guiParent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(buttonGui); guiParent = game:GetService("CoreGui") end
end)
buttonGui.Parent = guiParent

local floatingBtn360 = Instance.new("TextButton")
floatingBtn360.Name = "Nevada360Btn"
floatingBtn360.Size = UDim2.fromOffset(156, 48)
floatingBtn360.Position = UDim2.new(0.8, -150, 0.5, 0)
floatingBtn360.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
floatingBtn360.BackgroundTransparency = 0.06
floatingBtn360.Text = ""
floatingBtn360.AutoButtonColor = false
floatingBtn360.Visible = true
floatingBtn360.ZIndex = 50
floatingBtn360.Parent = buttonGui

Instance.new("UICorner", floatingBtn360).CornerRadius = UDim.new(0, 12)
local stroke360 = Instance.new("UIStroke", floatingBtn360)
stroke360.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke360.Thickness = 1
stroke360.Color = Color3.fromRGB(60, 60, 60)
stroke360.Transparency = 0.2

local title360 = Instance.new("TextLabel", floatingBtn360)
title360.BackgroundTransparency = 1
title360.Position = UDim2.fromOffset(14, 6)
title360.Size = UDim2.new(1, -42, 0, 20)
title360.Font = Enum.Font.GothamMedium
title360.TextSize = 12
title360.TextColor3 = Color3.fromRGB(240, 240, 240)
title360.TextXAlignment = Enum.TextXAlignment.Left
title360.Text = "Macro 360"

local stateLabel360 = Instance.new("TextLabel", floatingBtn360)
stateLabel360.BackgroundTransparency = 1
stateLabel360.Position = UDim2.fromOffset(14, 26)
stateLabel360.Size = UDim2.new(1, -42, 0, 14)
stateLabel360.Font = Enum.Font.GothamMedium
stateLabel360.TextSize = 8
stateLabel360.TextColor3 = Color3.fromRGB(135, 135, 135)
stateLabel360.TextXAlignment = Enum.TextXAlignment.Left
stateLabel360.Text = "INACTIVO"

local dot360 = Instance.new("Frame", floatingBtn360)
dot360.AnchorPoint = Vector2.new(1, 0.5)
dot360.Position = UDim2.new(1, -14, 0.5, 0)
dot360.Size = UDim2.fromOffset(6, 6)
dot360.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
dot360.BorderSizePixel = 0
Instance.new("UICorner", dot360).CornerRadius = UDim.new(1, 0)

local hovered360 = false
local function updateVisual360()
    local enabled = state.macro360Enabled
    stateLabel360.Text = enabled and "ACTIVO" or "INACTIVO"
    dot360.BackgroundColor3 = enabled and Color3.fromRGB(242, 242, 242) or Color3.fromRGB(80, 80, 80)
    floatingBtn360.BackgroundColor3 = hovered360 and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(14, 14, 14)
    stroke360.Color = enabled and Color3.fromRGB(175, 175, 175) or Color3.fromRGB(60, 60, 60)
end

local dragging360, dragInput360, dragStart360, startPos360
floatingBtn360.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging360 = true; dragStart360 = input.Position; startPos360 = floatingBtn360.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging360 = false end
        end)
    end
end)
floatingBtn360.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput360 = input end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging360 and input == dragInput360 then
        local delta = input.Position - dragStart360
        floatingBtn360.Position = UDim2.new(startPos360.X.Scale, startPos360.X.Offset + delta.X, startPos360.Y.Scale, startPos360.Y.Offset + delta.Y)
    end
end)

local dragStartPos360 = nil; local validClick360 = false
floatingBtn360.InputBegan:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
        dragStartPos360 = input.Position; validClick360 = true 
    end 
end)
floatingBtn360.InputChanged:Connect(function(input) 
    if dragStartPos360 and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then 
        if (input.Position - dragStartPos360).Magnitude > 5 then validClick360 = false end 
    end 
end)
floatingBtn360.MouseButton1Click:Connect(function() 
    if not validClick360 then return end 
    state.macro360Enabled = not state.macro360Enabled
    updateVisual360()
    pcall(function() UI_Refs.macro360Enabled:Set(state.macro360Enabled) end)
    SaveAutoConfig()
end)
floatingBtn360.MouseEnter:Connect(function() hovered360 = true; updateVisual360() end)
floatingBtn360.MouseLeave:Connect(function() hovered360 = false; updateVisual360() end)
updateVisual360()

-- ==========================================
-- LÓGICA DE MACROS (GUN, CUCHILLO, MACRO 360)
-- ==========================================
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
  
  if not tool then 
      for _,item in ipairs(backpack:GetChildren()) do 
          if item:IsA("Tool") and (item.name:lower():find("pistol") or item.name:lower():find("gun") or item.name:lower():find("sheriff") or item.name:lower():find("revolver")) then 
              tool=item; break 
          end 
      end 
  end
  if not tool then return end

  local now=os.clock(); if now-lastMacro< (tonumber(state.shootDelay) or 0.10) then return end
  macroBusy=true; lastMacro=now
  
  task.spawn(function()
    local wasEquipped = (tool.Parent == char)
    if not wasEquipped then hum:EquipTool(tool); task.wait(math.max(0.01, tonumber(state.equipDelay) or 0.05)) end
    if state.macro and player.Character==char and hum.Health>0 and tool.Parent==char then
        pcall(function() tool:Activate(); task.delay(0.02, function() if tool.Parent == char then tool:Deactivate() end end) end)
    end
    if not wasEquipped and player.Character==char and hum.Parent==char then 
        task.wait(math.max(0.01, tonumber(state.shootDelay) or 0.10))
        pcall(function() hum:UnequipTools() end) 
    end
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
                local enemyHrp = enemyChar.HumanoidRootPart
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
            task.wait(math.max(0.02, tonumber(state.macro360Cooldown) or 0.05))
            pcall(function() tool:Deactivate() end)
            getgenv().NevadaTargetPart = nil
        end
    end
end)

print("[Nevada V36] ✅ Cargado correctamente y Auto-Save listo.")
