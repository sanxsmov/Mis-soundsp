-- LocalScript: Nevada v2 (Estilo Xero Hub + Fondo lol.jpg de GitHub)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

--------------------------------------------------------------------------------
-- CONFIGURACIÓN DE GITHUB (IMAGEN Y AUDIOS)
--------------------------------------------------------------------------------
local SCRIPT_NAME = "NEVADA | HUB"
local HUB_SUBTITLE = "NevadaHub"
local POWERED_BY = "POWERED BY SANXSMOV"

local GitHubUser = "sanxsmov"
local RepoName = "Mis-soundsp"
local FolderPath = "sounds"
local ImageFolder = "images"       
local ImageFileName = "lol.jpg" -- Nombre de tu foto en GitHub

local RawBaseURL = "https://raw.githubusercontent.com/" .. GitHubUser .. "/" .. RepoName .. "/main/"
local ApiURL = "https://api.github.com/repos/" .. GitHubUser .. "/" .. RepoName .. "/contents/" .. FolderPath
local ImageURL = RawBaseURL .. ImageFolder .. "/" .. ImageFileName

--------------------------------------------------------------------------------
-- FUNCIÓN PARA DESCARGAR LA IMAGEN DESDE GITHUB
--------------------------------------------------------------------------------
local function getCustomAssetImage(url, localName)
    if writefile and readfile and getcustomasset then
        if not isfile(localName) then
            local success, data = pcall(function() return game:HttpGet(url) end)
            if success and data then
                writefile(localName, data)
            end
        end
        return getcustomasset(localName)
    end
    return url
end

--------------------------------------------------------------------------------
-- CARGA DINÁMICA DE AUDIOS DESDE GITHUB
--------------------------------------------------------------------------------
local AvailableSounds = {}
local SoundURLs = {}

task.spawn(function()
    if httpRequest then
        pcall(function()
            local response = httpRequest({
                Url = ApiURL,
                Method = "GET",
                Headers = { ["User-Agent"] = "RobloxApp/1.0" }
            })

            if response and (response.StatusCode == 200 or response.StatusDescription == "OK") then
                local data = HttpService:JSONDecode(response.Body)
                for _, item in ipairs(data) do
                    if item.type == "file" and item.name:lower():match("%.mp3$") then
                        local cleanName = item.name:gsub("%.mp3$", "")
                        table.insert(AvailableSounds, cleanName)
                        SoundURLs[cleanName] = item.download_url or (RawBaseURL .. FolderPath .. "/" .. item.name)
                    end
                end
            end
        end)
    end

    if #AvailableSounds == 0 then
        AvailableSounds = {"Rust", "Skeet", "Hitmarker", "TF2", "Neverlose"}
        for _, name in ipairs(AvailableSounds) do
            SoundURLs[name] = RawBaseURL .. FolderPath .. "/" .. name .. ".mp3"
        end
    end
end)

local SelectedSounds = {
    Disparar = { Name = "Rust", URL = RawBaseURL .. FolderPath .. "/Rust.mp3", Enabled = true },
    Saltar   = { Name = "TF2", URL = RawBaseURL .. FolderPath .. "/TF2.mp3", Enabled = true },
    Matar    = { Name = "TF2", URL = RawBaseURL .. FolderPath .. "/TF2.mp3", Enabled = true }
}

local SelectedMacros = {
    Pistola  = { Enabled = false, Delay = 0.01 },
    Cuchillo = { Enabled = false, Delay = 0.01 }
}

local SoundCache = {}

local function playAudioUrl(url)
    if not url or url == "" then return end
    local soundAssetId = SoundCache[url]

    if not soundAssetId then
        local sanitizeName = url:match("([^/]+)%.mp3$") or ("sound_" .. tick())
        local fileName = "sanxsmov_" .. sanitizeName .. ".mp3"

        if writefile and readfile and getcustomasset then
            if not isfile(fileName) then
                local success, audioData = pcall(function() return game:HttpGet(url) end)
                if success and audioData then writefile(fileName, audioData) else return end
            end
            soundAssetId = getcustomasset(fileName)
            SoundCache[url] = soundAssetId
        else
            soundAssetId = url
        end
    end

    local sound = Instance.new("Sound")
    sound.SoundId = soundAssetId
    sound.Volume = 1
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
end

--------------------------------------------------------------------------------
-- LÓGICA DE MACRO (MÓVIL / TOUCH)
--------------------------------------------------------------------------------
local isMacroRunning = false

local function runMacro(macroType)
    if isMacroRunning then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChild("Backpack")

    if not hum or hum.Health <= 0 then return end
    isMacroRunning = true

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool and backpack then
        local foundTool = backpack:FindFirstChildOfClass("Tool")
        if foundTool then
            hum:EquipTool(foundTool)
            task.wait(0.02)
            tool = foundTool
        end
    end

    if tool then tool:Activate() end
    task.wait(SelectedMacros[macroType].Delay)
    isMacroRunning = false
end

--------------------------------------------------------------------------------
-- INTERFAZ GRÁFICA ESTILO XERO HUB
--------------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("XeroStyleNevadaUI") then
    playerGui.XeroStyleNevadaUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XeroStyleNevadaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Botón Flotante Abrir/Cerrar
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 110, 0, 36)
toggleButton.Position = UDim2.new(0.02, 0, 0.3, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
toggleButton.TextColor3 = Color3.fromRGB(220, 220, 220)
toggleButton.Text = "⚡ " .. SCRIPT_NAME
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 11
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleButton

-- Botones Móviles de Macro
local gunMacroBtn = Instance.new("TextButton")
gunMacroBtn.Size = UDim2.new(0, 70, 0, 42)
gunMacroBtn.Position = UDim2.new(0.85, 0, 0.45, 0)
gunMacroBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
gunMacroBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
gunMacroBtn.Text = "💥 Gun"
gunMacroBtn.Font = Enum.Font.GothamBold
gunMacroBtn.TextSize = 11
gunMacroBtn.Visible = false
gunMacroBtn.Parent = screenGui

local gunCorner = Instance.new("UICorner")
gunCorner.CornerRadius = UDim.new(0, 8)
gunCorner.Parent = gunMacroBtn

local knifeMacroBtn = Instance.new("TextButton")
knifeMacroBtn.Size = UDim2.new(0, 70, 0, 42)
knifeMacroBtn.Position = UDim2.new(0.85, 0, 0.58, 0)
knifeMacroBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
knifeMacroBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
knifeMacroBtn.Text = "🔪 Knife"
knifeMacroBtn.Font = Enum.Font.GothamBold
knifeMacroBtn.TextSize = 11
knifeMacroBtn.Visible = false
knifeMacroBtn.Parent = screenGui

local knifeCorner = Instance.new("UICorner")
knifeCorner.CornerRadius = UDim.new(0, 8)
knifeCorner.Parent = knifeMacroBtn

gunMacroBtn.MouseButton1Click:Connect(function() runMacro("Pistola") end)
knifeMacroBtn.MouseButton1Click:Connect(function() runMacro("Cuchillo") end)

-- Ventana Principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 310)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -155)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = mainFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(30, 30, 35)
frameStroke.Thickness = 1.2
frameStroke.Parent = mainFrame

-- IMAGEN DE FONDO (lol.jpg SUPERPUESTA CON TRANSPARENCIA)
local backgroundImage = Instance.new("ImageLabel")
backgroundImage.Size = UDim2.new(1, 0, 1, 0)
backgroundImage.Position = UDim2.new(0, 0, 0, 0)
backgroundImage.BackgroundTransparency = 1
backgroundImage.Image = getCustomAssetImage(ImageURL, "sanxsmov_" .. ImageFileName)
backgroundImage.ImageTransparency = 0.75 -- Transparencia suave
backgroundImage.ScaleType = Enum.ScaleType.Crop
backgroundImage.ZIndex = 0
backgroundImage.Parent = mainFrame

-- Capa oscura
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
overlay.BackgroundTransparency = 0.35
overlay.ZIndex = 0
overlay.Parent = mainFrame

-- TopBar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 2
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.Text = SCRIPT_NAME .. " <font color=\"#888888\">| 108 activos</font>"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
titleLabel.RichText = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 2
titleLabel.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 11
closeBtn.ZIndex = 2
closeBtn.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -48)
sidebar.Position = UDim2.new(0, 10, 0, 42)
sidebar.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
sidebar.BackgroundTransparency = 0.2
sidebar.ZIndex = 2
sidebar.Parent = mainFrame

local sideCorner = Instance.new("UICorner")
sideCorner.CornerRadius = UDim.new(0, 10)
sideCorner.Parent = sidebar

local sideStroke = Instance.new("UIStroke")
sideStroke.Color = Color3.fromRGB(35, 35, 40)
sideStroke.Parent = sidebar

-- Panel de Contenido
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -155, 1, -48)
contentFrame.Position = UDim2.new(0, 148, 0, 42)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.ZIndex = 2
contentFrame.Parent = mainFrame

local watermarkLabel = Instance.new("TextLabel")
watermarkLabel.Size = UDim2.new(0, 200, 0, 40)
watermarkLabel.Position = UDim2.new(0.05, 0, 0.4, 0)
watermarkLabel.BackgroundTransparency = 1
watermarkLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
watermarkLabel.TextTransparency = 0.88
watermarkLabel.Text = HUB_SUBTITLE
watermarkLabel.Font = Enum.Font.SpecialElite
watermarkLabel.TextSize = 36
watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
watermarkLabel.ZIndex = 2
watermarkLabel.Parent = contentFrame

--------------------------------------------------------------------------------
-- PESTAÑAS (Tabs)
--------------------------------------------------------------------------------
local tabs = {}
local tabButtons = {}

local function createTabButton(text, index, yOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 32)
    btn.Position = UDim2.new(0.05, 0, 0, yOffset)
    btn.BackgroundColor3 = (index == 1) and Color3.fromRGB(30, 30, 36) or Color3.fromRGB(14, 14, 16)
    btn.TextColor3 = (index == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160)
    btn.Text = "  " .. text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 10
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 3
    btn.Parent = sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 1, 0)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Visible = (index == 1)
    tabFrame.ZIndex = 3
    tabFrame.Parent = contentFrame

    tabs[index] = tabFrame
    tabButtons[index] = btn

    btn.MouseButton1Click:Connect(function()
        for i, t in ipairs(tabs) do t.Visible = (i == index) end
        for i, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (i == index) and Color3.fromRGB(30, 30, 36) or Color3.fromRGB(14, 14, 16)
            b.TextColor3 = (i == index) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160)
        end
    end)

    return tabFrame
end

local tabMacro = createTabButton("01 Macro", 1, 15)
local tabSounds = createTabButton("02 Sounds", 2, 52)

--------------------------------------------------------------------------------
-- CONTENIDO DE CONTROLES
--------------------------------------------------------------------------------
local function addMacroToggle(parent, title, key, targetBtn, yPos)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.75, 0, 0, 40)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    frame.BackgroundTransparency = 0.2
    frame.ZIndex = 3
    frame.Parent = parent

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 100, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = title
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 3
    label.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 24)
    toggleBtn.Position = UDim2.new(1, -60, 0.2, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    toggleBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    toggleBtn.Text = "OFF"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 9
    toggleBtn.ZIndex = 3
    toggleBtn.Parent = frame

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 4)
    tCorner.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        SelectedMacros[key].Enabled = not SelectedMacros[key].Enabled
        local enabled = SelectedMacros[key].Enabled
        toggleBtn.Text = enabled and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(40, 140, 70) or Color3.fromRGB(30, 30, 35)
        toggleBtn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
        targetBtn.Visible = enabled
    end)
end

addMacroToggle(tabMacro, "Macro Gun", "Pistola", gunMacroBtn, 10)
addMacroToggle(tabMacro, "Macro Knife", "Cuchillo", knifeMacroBtn, 60)

local function addSoundRow(parent, actionName, actionKey, yPos)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.75, 0, 0, 40)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    frame.BackgroundTransparency = 0.2
    frame.ZIndex = 3
    frame.Parent = parent

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 55, 0, 24)
    toggleBtn.Position = UDim2.new(0, 6, 0.2, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = actionName
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 9
    toggleBtn.ZIndex = 3
    toggleBtn.Parent = frame

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 90, 0, 24)
    selectBtn.Position = UDim2.new(0.35, 0, 0.2, 0)
    selectBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    selectBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    selectBtn.Text = SelectedSounds[actionKey].Name
    selectBtn.Font = Enum.Font.Gotham
    selectBtn.TextSize = 9
    selectBtn.ZIndex = 3
    selectBtn.Parent = frame

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 35, 0, 24)
    testBtn.Position = UDim2.new(0.82, 0, 0.2, 0)
    testBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    testBtn.TextColor3 = Color3.fromRGB(0, 170, 255)
    testBtn.Text = "▶"
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 9
    testBtn.ZIndex = 3
    testBtn.Parent = frame

    toggleBtn.MouseButton1Click:Connect(function()
        SelectedSounds[actionKey].Enabled = not SelectedSounds[actionKey].Enabled
        local enabled = SelectedSounds[actionKey].Enabled
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(40, 140, 70) or Color3.fromRGB(120, 40, 40)
    end)

    local currentIndex = 1
    selectBtn.MouseButton1Click:Connect(function()
        if #AvailableSounds == 0 then return end
        currentIndex = (currentIndex % #AvailableSounds) + 1
        local selectedName = AvailableSounds[currentIndex]
        selectBtn.Text = selectedName
        SelectedSounds[actionKey].Name = selectedName
        SelectedSounds[actionKey].URL = SoundURLs[selectedName]
    end)

    testBtn.MouseButton1Click:Connect(function() playAudioUrl(SelectedSounds[actionKey].URL) end)
end

addSoundRow(tabSounds, "Disparar", "Disparar", 10)
addSoundRow(tabSounds, "Saltar", "Saltar", 60)
addSoundRow(tabSounds, "Matar", "Matar", 110)

toggleButton.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

--------------------------------------------------------------------------------
-- EVENTOS DE JUEGO
--------------------------------------------------------------------------------
local boundTools = {}
local function bindTool(tool)
    if tool:IsA("Tool") and not boundTools[tool] then
        boundTools[tool] = true
        tool.Activated:Connect(function()
            if SelectedSounds.Disparar.Enabled then playAudioUrl(SelectedSounds.Disparar.URL) end
        end)
    end
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Jumping:Connect(function(isJumping)
            if isJumping and SelectedSounds.Saltar.Enabled then playAudioUrl(SelectedSounds.Saltar.URL) end
        end)
    end
    char.ChildAdded:Connect(bindTool)
    for _, item in ipairs(char:GetChildren()) do bindTool(item) end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
