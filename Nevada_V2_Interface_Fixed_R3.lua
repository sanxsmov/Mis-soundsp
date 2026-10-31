-- NEVADA V40 | WindUI Real Completo (Diseño XeroHub + Todas las Funciones)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local requestFn = (syn and syn.request) or (http and http.request) or request or http_request

local CONFIG_FILE = "Nevada_WindUI_Config.json"
local OWNER, REPO, BRANCH = "sanxsmov", "Mis-soundsp", "main"
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"
local API_ROOT = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/contents/"
local SKYBOX_REPO = "sanxsmov/Onyx-web"
local SKYBOX_RAW = "https://raw.githubusercontent.com/" .. SKYBOX_REPO .. "/main/skyboxes/"

local state = {
    macro = false, equipDelay = 0.05, shootDelay = 0.10,
    knifeMacroEnabled = false,
    macro360Enabled = false, macro360Fov = 120, macro360HitChance = 100, macro360Cooldown = 0.05,
    autoLoadSky = false, selectedSky = "", selectedAnim = "",
    selected = {Arma={Name="Ninguno",URL=""}, Matar={Name="Ninguno",URL=""}},
    enabled = {Arma=true, Matar=true}, muted = {Arma=false, Matar=false}
}
local sounds, soundCache = {}, {}

-- ==========================================
-- CONFIGURACIÓN (Auto-Guardado)
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
-- LÓGICAS DE FONDO
-- ==========================================
-- 1. ANIMACIONES
local Animations = {
    ["Ninguna"] = {},
    ["Zombie"] = {idle=616006778, walk=616013216, run=616010382, jump=616008936, fall=616005863},
    ["Ninja"] = {idle=656117400, walk=656121766, run=656118852, jump=656117878, fall=656115606},
    ["Robot"] = {idle=616088211, walk=616095330, run=616091570, jump=616090535, fall=616087089},
}
local function applyAnimation(animName)
    local char = player.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    if animName == "Ninguna" or not Animations[animName] then return end
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
player.CharacterAdded:Connect(function() task.wait(1.5); applyAnimation(state.selectedAnim) end)

-- 2. SKYBOX
local originalSky = Lighting:FindFirstChildOfClass("Sky")
local function downloadImg(url, name)
    if not (writefile and isfile and getcustomasset) then return nil end
    local path = "NevadaSky_" .. name .. ".png"
    if not isfile(path) then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and body and #body > 0 then pcall(writefile, path, body) else return nil end
    end
    local success, asset = pcall(getcustomasset, path)
    return success and asset or nil
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
            local sky = originalSky or Instance.new("Sky")
            sky.Parent = Lighting
            sky.SkyboxBk = aBk; sky.SkyboxDn = aDn; sky.SkyboxFt = aFt
            sky.SkyboxLf = aLf; sky.SkyboxRt = aRt; sky.SkyboxUp = aUp
        end)
        return true
    end
    return false
end

-- 3. TEAM CHECK Y ANTI-LOBBY
local function getPlayerTeam(p)
    if not p then return nil end
    if p.Team and p.Team.Name ~= "" then return p.Team.Name end
    local score = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Main") and player.PlayerGui.Main:FindFirstChild("MainGameFrame") and player.PlayerGui.Main.MainGameFrame:FindFirstChild("IngameScore")
    if score then
        for _, t in ipairs({"TeamRed", "TeamBlue"}) do
            local f = score:FindFirstChild(t)
            if f and f:FindFirstChild(p.Name) then return t == "TeamRed" and "Red" or "Blue" end
        end
    end
    return nil
end
local function isEnemy(target)
    if not target or target == player then return false end
    local m, t = getPlayerTeam(player), getPlayerTeam(target)
    if m and t then return string.lower(m) ~= string.lower(t) end
    return false
end
local function estaEnLobby()
    local c = player.Character
    if not c or c:FindFirstChildOfClass("ForceField") then return true end
    return not (player.PlayerGui:FindFirstChild("Main") and player.PlayerGui.Main:FindFirstChild("MainGameFrame") and player.PlayerGui.Main.MainGameFrame:FindFirstChild("IngameScore"))
end
local function esPistola(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool:FindFirstChild("showBeam") ~= nil or tool.Name:lower():find("gun") or tool.Name:lower():find("pistol") or tool.Name:lower():find("revolver")
end

-- 4. SILENT AIM
getgenv().NevadaTargetPart = nil
if hookmetamethod and getnamecallmethod and checkcaller then
    local old = hookmetamethod(game, "__namecall", function(self, ...)
        if not checkcaller() and getgenv().NevadaTargetPart and getnamecallmethod() == "Raycast" and self == workspace then
            local t = getgenv().NevadaTargetPart
            if t and t.Parent then
                local o, d, p = ...
                if typeof(d) == "Vector3" and d.Magnitude > 20 and (o - workspace.CurrentCamera.CFrame.Position).Magnitude >= 1 then
                    return old(self, o, (t.Position - o).Unit * 5000, p)
                end
            end
        end
        return old(self, ...)
    end)
end

-- 5. SONIDOS
local function playSound(url)
    if not url or url == "" then return end
    if not soundCache[url] then
        if writefile and isfile and getcustomasset then
            local n = "n_" .. (url:match("([^/]+)$") or "s.mp3"):gsub("[^%w%._%-]", "_")
            if not isfile(n) then pcall(writefile, n, game:HttpGet(url)) end
            local ok, a = pcall(getcustomasset, n)
            if ok then soundCache[url] = a end
        end
    end
    local a = soundCache[url] or url
    local s = Instance.new("Sound", SoundService)
    s.SoundId, s.Volume = a, 1
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
end
local function watchSound(obj)
    if not obj:IsA("Sound") then return end
    obj.Played:Connect(function()
        local id = tostring(obj.SoundId):match("(%d+)")
        local cat = (id == "10209603" or obj.Name:lower():find("gun")) and "Arma" or ((id == "296102734" or obj.Name:lower():find("kill")) and "Matar" or nil)
        if cat and state.enabled[cat] and state.selected[cat].URL ~= "" then
            pcall(function() obj.Volume = 0 end)
            playSound(state.selected[cat].URL)
        end
    end)
end
workspace.DescendantAdded:Connect(watchSound)
SoundService.DescendantAdded:Connect(watchSound)
for _, v in ipairs(workspace:GetDescendants()) do if v:IsA("Sound") then watchSound(v) end end

-- 6. MACROS DE TECLADO (R2 y L2)
local macroBusy = false
local function runMacro()
    if not state.macro or macroBusy then return end
    local char = player.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local backpack = player:FindFirstChildOfClass("Backpack"); if not backpack then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and not esPistola(tool) then tool = nil end
    if not tool then for _, item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") and esPistola(item) then tool = item; break end end end
    if not tool then return end
    macroBusy = true
    task.spawn(function()
        pcall(function()
            if tool.Parent == backpack then hum:EquipTool(tool); task.wait(state.equipDelay) end
            if tool.Parent == char then tool:Activate(); task.wait(state.shootDelay); pcall(function() tool:Deactivate() end) end
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
            if knife.Parent ~= character then humanoid:EquipTool(knife); task.wait(0.1) end
            pcall(function() knife:Activate() end)
            task.wait(0.15)
            pcall(function() if humanoid and humanoid.Parent then humanoid:UnequipTools() end end)
        end)
        knifeBusy = false
    end)
end
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then runMacro() end
    if input.KeyCode == Enum.KeyCode.L2 then runKnifeMacro() end
end)

-- ==========================================
-- CARGAR WINDUI E INTERFAZ
-- ==========================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Nevada Hub",
    Author = "Custom",
    Icon = "shield",
    Folder = "NevadaUI",
    Size = UDim2.fromOffset(580, 380),
    Transparent = true,
    Theme = "Dark"
})

-- Pestaña de Combate
local TabCombat = Window:Tab({ Title = "Combat", Icon = "swords" })
TabCombat:Section({ Title = "Macro 360 (Silent Aim)" })
TabCombat:Toggle({
    Title = "Activar Macro 360",
    Value = state.macro360Enabled,
    Callback = function(v) state.macro360Enabled = v; saveConfig() end
})
TabCombat:Slider({
    Title = "FOV Size",
    Step = 1, Value = { Min = 10, Max = 500, Default = state.macro360Fov },
    Callback = function(v) state.macro360Fov = v; saveConfig() end
})
TabCombat:Slider({
    Title = "Hit Chance %",
    Step = 1, Value = { Min = 1, Max = 100, Default = state.macro360HitChance },
    Callback = function(v) state.macro360HitChance = v; saveConfig() end
})
TabCombat:Slider({
    Title = "Cooldown (s)",
    Step = 0.01, Value = { Min = 0.01, Max = 1, Default = state.macro360Cooldown },
    Callback = function(v) state.macro360Cooldown = v; saveConfig() end
})
TabCombat:Toggle({
    Title = "Macro de Cuchillo (L2)",
    Value = state.knifeMacroEnabled,
    Callback = function(v) state.knifeMacroEnabled = v; saveConfig() end
})

-- Pestaña de Visuales
local TabVisuals = Window:Tab({ Title = "Visuals", Icon = "eye" })
TabVisuals:Section({ Title = "Skybox" })
TabVisuals:Toggle({
    Title = "Auto-Cargar Skybox",
    Value = state.autoLoadSky,
    Callback = function(v) state.autoLoadSky = v; saveConfig() end
})
TabVisuals:Button({
    Title = "Aplicar Skybox (Aurora)",
    Callback = function()
        WindUI:Notify({ Title = "Skybox", Content = "Descargando Aurora...", Duration = 2 })
        local ok = applySkyFromGitHub("aurora")
        state.selectedSky = "aurora"; saveConfig()
    end
})

-- Pestaña de Animaciones
local TabAnim = Window:Tab({ Title = "Animations", Icon = "person-standing" })
TabAnim:Dropdown({
    Title = "Cambiar Animación",
    Values = {"Ninguna", "Zombie", "Ninja", "Robot"},
    Value = state.selectedAnim ~= "" and state.selectedAnim or "Ninguna",
    Callback = function(opt) state.selectedAnim = opt; applyAnimation(opt); saveConfig() end
})

-- Pestaña de Sonidos
local TabSounds = Window:Tab({ Title = "Sounds", Icon = "music" })
task.spawn(function()
    local ok, res = pcall(function() return requestFn({Url=API_ROOT.."sounds",Method="GET",Headers={ ["User-Agent"]="NevadaV2" }}) end)
    if ok and res and res.StatusCode == 200 then
        local data = HttpService:JSONDecode(res.Body)
        local soundNames = {"Ninguno"}
        for _, item in ipairs(data) do
            if item.name:match("%.mp3$") then table.insert(soundNames, item.name:gsub("%.mp3$", "")) end
        end
        TabSounds:Dropdown({
            Title = "Sonido de Disparo",
            Values = soundNames,
            Value = state.selected.Arma.Name,
            Callback = function(opt)
                for _, item in ipairs(data) do
                    if item.name:gsub("%.mp3$", "") == opt then state.selected.Arma = {Name=opt, URL=item.download_url} end
                end
                saveConfig()
            end
        })
    end
end)

-- ==========================================
-- BOTÓN FLOTANTE Y BUCLE DEL MACRO 360
-- ==========================================
local gui = Instance.new("ScreenGui")
gui.Name = "NevadaFloating"
gui.Parent = game:GetService("CoreGui")

local floatBtn = Instance.new("TextButton", gui)
floatBtn.Size = UDim2.new(0, 120, 0, 40)
floatBtn.Position = UDim2.new(0, 20, 0.5, 0)
floatBtn.BackgroundColor3 = state.macro360Enabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(200, 50, 50)
floatBtn.Text = state.macro360Enabled and "MACRO 360: ON" or "MACRO 360: OFF"
floatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 12
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0, 6)

local dragging, dragStart, startPos
floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = floatBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
floatBtn.MouseButton1Click:Connect(function()
    state.macro360Enabled = not state.macro360Enabled
    floatBtn.Text = state.macro360Enabled and "MACRO 360: ON" or "MACRO 360: OFF"
    floatBtn.BackgroundColor3 = state.macro360Enabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(200, 50, 50)
    saveConfig()
end)

task.spawn(function()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local lockedTargetPlayer, lockedTargetPart = nil, nil
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
                    if (lockedTargetPart.Position - myPos).Magnitude <= state.macro360Fov then
                        params.FilterDescendantsInstances = { char, lockedTargetPlayer.Character }
                        if not workspace:Raycast(myPos, lockedTargetPart.Position - myPos, params) then targetIsValid = true end
                    end
                end
            end
            if not targetIsValid then lockedTargetPlayer = nil; lockedTargetPart = nil end

            if not lockedTargetPlayer then
                local bestPart, bestDist, bestP = nil, math.huge, nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if isEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local eHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if eHum and eHum.Health > 0 then
                            local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                            if dist < state.macro360Fov and dist < bestDist then
                                params.FilterDescendantsInstances = { char, p.Character }
                                if not workspace:Raycast(myPos, p.Character.HumanoidRootPart.Position - myPos, params) then
                                    for _, part in ipairs(p.Character:GetChildren()) do
                                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Humanoid" then
                                            if (part.Position - myPos).Magnitude < bestDist then
                                                if not workspace:Raycast(myPos, part.Position - myPos, params) then bestDist = (part.Position - myPos).Magnitude; bestPart = part; bestP = p end
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
                    if tool.Parent == char and math.random(1, 100) <= state.macro360HitChance then
                        getgenv().NevadaTargetPart = lockedTargetPart
                        pcall(function() tool:Activate() end); task.wait(0.05); pcall(function() tool:Deactivate() end)
                        getgenv().NevadaTargetPart = nil
                    end
                end
                task.wait(state.macro360Cooldown)
            end
        else
            lockedTargetPlayer = nil; lockedTargetPart = nil
            if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then pcall(function() player.Character.Humanoid:UnequipTools() end) end
        end
    end
end)
